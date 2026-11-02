/* $Id: fault.c,v 1.120 2001/07/18 13:40:05 anton Exp $
 * fault.c:  Page fault handlers for the Sparc.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 * Copyright (C) 1996 Eddie C. Dost (ecd@skynet.be)
 * Copyright (C) 1997 Jakub Jelinek (jj@sunsite.mff.cuni.cz)
 */

#include <linux/config.h>
#include <asm/head.h>

#include <linux/string.h>
#include <linux/types.h>
#include <linux/ptrace.h>
#include <linux/mman.h>
#include <linux/threads.h>
#include <linux/kernel.h>
#include <linux/signal.h>
#include <linux/mm.h>
#include <linux/smp.h>
#include <linux/smp_lock.h>
#include <linux/interrupt.h>

#include <asm/system.h>
#include <asm/segment.h>
#include <asm/page.h>
#include <asm/pgtable.h>
#include <asm/smp.h>
#include <asm/traps.h>
#include <asm/kdebug.h>
#include <asm/uaccess.h>
#include <asm/pgalloc.h>
//#define DEBUG_IRAM
//#define TEST_CACHE_PROBE

#ifdef TEST_CACHE_PROBE
#include <linux/init.h>
#include <linux/module.h>
#endif
#include <linux/perf.h>

unsigned long tmp_register[32] __dc3data ____cacheline_aligned;
unsigned long icmu_ctrl=0,dcmu_ctrl=0;
extern int padre_cachefix;


static __inline__ void write_dcctrl(unsigned long val)
{
	__asm__ __volatile__(
		"sta %0, [%1]%2\n"
		:
		: "r"(val),"r"(PADRE_DCMU_CTRL),"i"(ASI_DCMU));
}

static __inline__ unsigned long read_dcctrl(void)
{
	unsigned long val;
	__asm__ __volatile__(
		"lda [%1]%2, %0\n"
		:"=r"(val)
		:"r"(PADRE_DCMU_CTRL),"i"(ASI_DCMU));
	return val;
}

static __inline__ void write_dcctrl_wait(unsigned long val)
{
	unsigned long dummy = PADRE_S3_RAMTOP;
	__asm__ __volatile__(
		"sta %0, [%1]%2\n"
		"nop; nop; ld [%3], %%g0\n"
		:
		: "r"(val),"r"(PADRE_DCMU_CTRL),
		"i"(ASI_DCMU),"r"(dummy));
}

//*************************************************************************
// LOCAL FUNC FOR WORKAROUND
//*************************************************************************
static void clean_dcache_range_workaround(unsigned long start,unsigned long end)
{
	unsigned long val;
#ifdef CONFIG_PADRE_PERFSTATS
  unsigned long length=end>start?end-start:0;
#endif
	unsigned long flags;

  perf_clock_start(dcache_clean_range);
  local_irq_save(flags);
  	val = read_dcctrl();
	write_dcctrl(val | (PADRE_DCMU_CTRL_PROBE__CLEAN<<4));
	__asm__ __volatile__(
		"1:\n"
		"ld [%0], %%g0\n"
		"cmp %0, %1\n"
		"bleu 1b\n"
		" add %0, 16, %0"
		: 
		: "r"(start),"r"(end));
	write_dcctrl(val);
	local_irq_restore(flags);
  perf_clock_stop(dcache_clean_range,length);

}

static void __ic3call flush_dcache_range_workaround(unsigned long start,unsigned long end)
{
	unsigned long val;
	unsigned long flags;

	local_irq_save(flags);
	val = read_dcctrl();
	write_dcctrl(val | (PADRE_DCMU_CTRL_PROBE__INVCLN<<4));
	__asm__ __volatile__(
		"1:\n"
		"ld [%0], %%g0\n"
		"cmp %0, %1\n"
		"bleu 1b\n"
		" add %0, 16, %0"
		: 
		: "r"(start), "r"(end));
	write_dcctrl(val);
	local_irq_restore(flags);
}

static __inline__ void __flush_icache_all_workaround(void)
{
/* Per Binz suggestion use the test mode icache flush for CPU1 because it is unclear what
 * the BIST_MODE stuff does
 * CL
 */
#ifdef CONFIG_PADRE_CPU1
	__asm__ __volatile__(
		".macro nop16\n"
		" nop;nop;nop;nop; nop;nop;nop;nop; nop;nop;nop;nop; nop;nop;nop;nop;\n"
		".endm\n"
		".macro nop256\n"
		" nop16;nop16;nop16;nop16;nop16;nop16;nop16;nop16;\n"
		" nop16;nop16;nop16;nop16;nop16;nop16;nop16;nop16;\n"
		".endm\n"
		".macro nop4096\n"
		" nop256;nop256;nop256;nop256;\n"
		" nop256;nop256;nop256;nop256;\n"
		" nop256;nop256;nop256;nop256;\n"
		" nop256;nop256;nop256;nop256;\n"
		".endm\n"
		" nop4096\n"
		" nop4096\n"
		" nop4096\n"
		" nop4096\n");
	
#else
	u32 reg = PADRE_ICMU_CTRL;
	u32 value = icmu_ctrl;

	__asm__ __volatile__(
		"sta %%g0, [%0]%1\n"
		"nop;nop;nop\n"
		:
		:"r"(reg),"i"(ASI_ICMU));
	writel(0x3ff,PADRE_MBIST_ADDR);
	writel(0x0,PADRE_MBIST_DATA);
	writel(PADRE_MBIST_MODE_EN | (PADRE_MBIST_MODE_ALGORITHM__W << 2) |
		   (1 << 20), PADRE_MBIST_MODE);
	
	while( ! (readl(PADRE_MBIST_MODE) & PADRE_MBIST_MODE_DONE));
	writel(0x0,PADRE_MBIST_MODE);
	
	__asm__ __volatile__(
		"sta %0, [%1]%2\n"
		"nop;nop;nop\n"
		:
		: "r"(value),"r"(reg),"i"(ASI_ICMU));	
#endif
}

static __inline__ void __flush_dcache_all_workaround(void)
{
	
	unsigned long val = read_dcctrl();
	unsigned long start = PADRE_S3_RAMTOP_CACHEABLE;
	unsigned long end = PADRE_S3_RAMTOP_CACHEABLE + 0x1000-16;
	write_dcctrl(val | (PADRE_DCMU_CTRL_PROBE__INVCLN<<4) | 
			PADRE_DCMU_CTRL_FORCE | 0x80);
	__asm__ __volatile__(
		"1:\n"
		"ld [%0], %%g0\n"
		"cmp %0, %1\n"
		"bleu 1b\n"
		" add %0, 16, %0"
		: 
		: "r"(start), "r"(end));
	write_dcctrl(val);
}

static void __ic3call flush_cache_dma_workaround(int direction)
{
#ifdef CONFIG_PADRE_DCACHE_WT
	unsigned long flags;
	if( direction == PADRE_DMA_TODEVICE)
		return;
	else {
    	local_irq_save(flags);
		__flush_dcache_all_workaround();
		local_irq_restore(flags);
	}

#else
	unsigned long flags;
    perf_clock_start(cacheflush);
    local_irq_save(flags);
#ifdef CONFIG_PADRE_DCACHE
	__flush_dcache_all_workaround();
#endif
	local_irq_restore(flags);
  perf_clock_stop(cacheflush,0);
#endif
}

static void flush_icache_range_workaround(unsigned long start, unsigned long end)
{
#ifdef CONFIG_PADRE_ICACHE
    unsigned long flags;


    perf_clock_start(icache);
    local_irq_save(flags);
#ifdef CONFIG_PADRE_DCACHE_WB
    __flush_dcache_all_workaround();
#endif
    __flush_icache_all_workaround();
    local_irq_restore(flags);
    perf_clock_stop(icache,0);
#endif
}

static void flush_icache_page_workaround(struct vm_area_struct *vma, struct page *page)
{
#ifdef CONFIG_PADRE_ICACHE
	{
		unsigned long flags;
		
		if (!(vma->vm_flags & VM_EXEC))
			return;

    perf_clock_start(icache_page);
    local_irq_save(flags);
#ifdef CONFIG_PADRE_DCACHE_WB
		clean_dcache_range_workaround((unsigned long)page_address(page),
					      (unsigned long)page_address(page)+PAGE_SIZE-16);
#endif 
		__flush_icache_all_workaround();
		local_irq_restore(flags);
    perf_clock_stop(icache_page,0);
	}
#endif
}


//*************************************************************************
// LOCAL FUNC FOR CACHEFIX
//*************************************************************************
static void __ic3call clean_dcache_range_cachefix(unsigned long start,unsigned long end)
{
	unsigned long val;
#ifdef CONFIG_PADRE_PERFSTATS
  unsigned long length=end>start?end-start:0;
#endif
	unsigned long flags;

	if ((start - 0x40000000ul) >= PAGE_NONCACHE_MARK) {
		// in non-cacheable, simply return.
		return;
	}

	perf_clock_start(dcache_clean_range);
	local_irq_save(flags);
	val = read_dcctrl();
	write_dcctrl(val | (PADRE_DCMU_CTRL_PROBE__CLEAN<<4));
	__asm__ __volatile__(
		"1:\n"
		"ld [%0+0x00], %%g0\n"
		"ld [%0+0x10], %%g0\n"
		"ld [%0+0x20], %%g0\n"
		"add %0, 0x40, %0\n"
		"cmp %0, %1\n"
		"bleu 1b\n"
		" ld [%0-0x10], %%g0\n"
		: 
		: "r"(start&~3),"r"(end)			// start/end is inclusive
		: "cc");
	write_dcctrl(val);
	local_irq_restore(flags);
	perf_clock_stop(dcache_clean_range,length);
}

static void __ic3call flush_dcache_range_cachefix(unsigned long start, unsigned long end)
{
	unsigned long val;
	unsigned long flags;

	local_irq_save(flags);
	val = read_dcctrl();
	write_dcctrl(val |
		     (PADRE_DCMU_CTRL_PROBE__INVCLN<<4) );
	__asm__ __volatile__(
		"ld [%0+%1], %%g0\n"
		"1:\n"
		"subcc %1, 0x10, %1\n"
		"bg 1b\n"
		" ld [%0+%1], %%g0\n"
		: 
		: "r"(start&~15), "r"((end&~15)-(start&~15))
		: "cc");
	write_dcctrl(val);
	local_irq_restore(flags);
}

static __inline__ void __flush_icache_all_cachefix(void)
{
	u32 reg = PADRE_ICMU_CTRL;
	u32 value = icmu_ctrl;

	__asm__ __volatile__(
		"sta %%g0, [%0]%1\n"
		"nop;nop;nop\n"
		:
		:"r"(reg),"i"(ASI_ICMU));
	writel(0x0ff,PADRE_MBIST_ADDR);
	writel(0x0,PADRE_MBIST_DATA);
	writel(PADRE_MBIST_MODE_EN | (PADRE_MBIST_MODE_ALGORITHM__W << 2) |
		   (1<<20) | (1<<10), PADRE_MBIST_MODE);
	
	while( ! (readl(PADRE_MBIST_MODE) & PADRE_MBIST_MODE_DONE));
	writel(0x0,PADRE_MBIST_MODE);
	
	__asm__ __volatile__(
		"sta %0, [%1]%2\n"
		"nop;nop;nop\n"
		:
		: "r"(value),"r"(reg),"i"(ASI_ICMU));	
}

static __ic3call void __flush_dcache_all_cachefix(int clean_only)
{
	
	unsigned long val = read_dcctrl();
	unsigned long start = PADRE_S3_RAMTOP_CACHEABLE;
	unsigned long end = PADRE_S3_RAMTOP_CACHEABLE + 0x1000-16;

	if (clean_only) {
		// flush using PROBE_CLEAN, but not bit7 (work around for bug#2122)
		write_dcctrl(val |
			     (PADRE_DCMU_CTRL_PROBE__CLEAN<<4) |
			     PADRE_DCMU_CTRL_FORCE );
		__asm__ __volatile__(
			"1:\n"
			"subcc %4, 16, %4\n"
			"ld [%0+%4], %%g0\n"
			"ld [%1+%4], %%g0\n"
			"ld [%2+%4], %%g0\n"
			"bg 1b\n"
			" ld [%3+%4], %%g0\n"
			: 
			: "r"(start), "r"(start+0x1000), "r"(start+0x2000), "r"(start+0x3000), "r"(0x1000)
			: "cc");
		write_dcctrl(val);
	}
	else {
		write_dcctrl(val |
			     (PADRE_DCMU_CTRL_PROBE__INVCLN<<4) |
			     PADRE_DCMU_CTRL_FORCE |
			     0x80);
		__asm__ __volatile__(
			"1:\n"
			"ld [%0], %%g0\n"
			"ld [%0+16], %%g0\n"
			"ld [%0+32], %%g0\n"
			"ld [%0+48], %%g0\n"
			"cmp %0, %1\n"
			"bleu 1b\n"
			" add %0, 64, %0"
			: 
			: "r"(start), "r"(end)
			: "cc");
		write_dcctrl(val);
	}
}

void __ic3call flush_cache_dma_cachefix(int direction)
{
#ifdef CONFIG_PADRE_DCACHE
#ifdef CONFIG_PADRE_DCACHE_WT
	unsigned long flags;
	if( direction == PADRE_DMA_TODEVICE)
		return;
	else {
    	local_irq_save(flags);
		__flush_dcache_all_cachefix(0);
		local_irq_restore(flags);
	}

#else
	unsigned long flags;
	perf_clock_start(cacheflush);
	local_irq_save(flags);
	if (direction==PADRE_DMA_TODEVICE) {
		// when direction is TODEVICE,
		// need write-back only and no need to invalidate.
		__flush_dcache_all_cachefix(1);
	}
	else {
		// when direction is FROMDEVICE or BIDIRECTIONAL,
		// need write-back and invalidate.
		__flush_dcache_all_cachefix(0);
	}
	local_irq_restore(flags);
	perf_clock_stop(cacheflush,0);
#endif
#endif
}

// NOTE: flush_icache_range() must flush corresponding dcache, because
//       our dcache does not perform snoop.  See Documentation/cachetlb.txt
static void flush_icache_range_cachefix(unsigned long start, unsigned long end)
{
#ifdef CONFIG_PADRE_ICACHE
	unsigned long flags;

	perf_clock_start(icache);
	local_irq_save(flags);
#ifdef CONFIG_PADRE_DCACHE_WB
	__flush_dcache_all_cachefix(0);
#endif
	__flush_icache_all_cachefix();

	local_irq_restore(flags);
	perf_clock_stop(icache,0);
#endif
}

static void __ic3call __clean_dcache_page_cachefix(unsigned long page)
{
	unsigned long val = read_dcctrl();

	write_dcctrl(val | (PADRE_DCMU_CTRL_PROBE__CLEAN<<4));
	__asm__ __volatile__(
		"1:\n"
		"ld [%0+0x00], %%g0\n"
		"ld [%0+0x10], %%g0\n"
		"ld [%0+0x20], %%g0\n"
		"add %0, 0x40, %0\n"
		"cmp %0, %1\n"
		"blu 1b\n"
		" ld [%0-0x10], %%g0\n"
		: 
		: "r"(page),"r"(page+0xff0)
		: "cc");
	write_dcctrl(val);
}

// NOTE: flush_icache_page() must flush corresponding dcache, because
//       our dcache does not perform snoop.  See Documentation/cachetlb.txt
static void flush_icache_page_cachefix(struct vm_area_struct *vma, struct page *page)
{
#ifdef CONFIG_PADRE_ICACHE
	unsigned long flags;
		
	if (!(vma->vm_flags & VM_EXEC))
		return;

	perf_clock_start(icache_page);
	local_irq_save(flags);
#ifdef CONFIG_PADRE_DCACHE_WB
	__clean_dcache_page_cachefix((unsigned long)page_address(page));
#endif 
	__flush_icache_all_cachefix();
	local_irq_restore(flags);
	perf_clock_stop(icache_page,0);
#endif
}

//***********************************************************************
// EXPORTED CACHE UTIL FUNC
//***********************************************************************
void __ic3call clean_dcache_range(unsigned long start,unsigned long end)
{
	if (padre_cachefix) clean_dcache_range_cachefix(start, end);
	else                clean_dcache_range_workaround(start, end);
}
void __ic3call flush_dcache_range(unsigned long start,unsigned long end)
{
	if (padre_cachefix) flush_dcache_range_cachefix(start, end);
	else                flush_dcache_range_workaround(start, end);
}
void __ic3call flush_cache_dma(int direction)
{
	if (padre_cachefix) flush_cache_dma_cachefix(direction);
	else                flush_cache_dma_workaround(direction);
}
void __ic3call flush_icache_range(unsigned long start, unsigned long end)
{
	if (padre_cachefix) flush_icache_range_cachefix(start, end);
	else                flush_icache_range_workaround(start, end);
}
void __ic3call flush_icache_page(struct vm_area_struct *vma, struct page *page)
{
	if (padre_cachefix) flush_icache_page_cachefix(vma, page);
	else                flush_icache_page_workaround(vma, page);
}
void __ic3call flush_page_to_ram(struct page *page)
{
}


//************************************************************************
//  FAULT HANDLING
//************************************************************************
extern void flush_sig_insns(struct mm_struct *mm, unsigned long insn_addr)
{
	unsigned long flags;

	printk("flush_sig_insns\n");
    local_irq_save(flags);
#ifdef CONFIG_PADRE_DCACHE_WB
	clean_dcache_range(insn_addr & 0xfffffff0UL,(insn_addr+4) & 0xfffffff0UL);
#endif
#ifdef CONFIG_PADRE_ICACHE
#ifdef DEBUG_IRAM
	__flush_icache_all();
#else
	
	__asm__ __volatile__(
		"sta %%g0, [%7]%0\n"
		"nop;nop;nop\n"
		"sta %8, [%7]%0\n"
		"nop;nop;nop\n"
		"1:\n"
		"sta %%g0, [%3+%1]%0\n"
		"sta %%g0, [%4+%1]%0\n"
		"sta %%g0, [%5+%1]%0\n"
		"sta %%g0, [%6+%1]%0\n"
		"sta %%g0, [%3+%2]%0\n"
		"sta %%g0, [%4+%2]%0\n"
		"sta %%g0, [%5+%2]%0\n"
		"sta %%g0, [%6+%2]%0\n"
		"sta %%g0, [%7]%0\n"
		"nop;nop;nop\n"
		"sta %9, [%7]%0\n"
		"nop;nop;nop\n"
		:
		:"i"(ASI_ICMU),"r"(insn_addr & 0xff0),"r"((insn_addr+4) & 0xff0),
		 "r"(PADRE_ICMU_ITAG),"r"(PADRE_ICMU_ITAG+0x1000),
		 "r"(PADRE_ICMU_ITAG+0x2000),"r"(PADRE_ICMU_ITAG+0x3000),
		 "r"(PADRE_ICMU_CTRL),"r"(PADRE_ICMU_CTRL_TM),"r"(icmu_ctrl)
		:"cc");
#endif
#endif
	local_irq_restore(flags);
}

static void unhandled_fault(unsigned long, struct task_struct *,
		struct pt_regs *) __attribute__ ((noreturn));

static void unhandled_fault(unsigned long address, struct task_struct *tsk,
                     struct pt_regs *regs)
{
	if((unsigned long) address < PAGE_SIZE) {
		printk(KERN_ALERT "Unable to handle kernel NULL "
		       "pointer dereference");
		LCD_display("Panic:kernel NULL pointer");
	} else {
		printk(KERN_ALERT "Unable to handle kernel paging request "
		       "at virtual address %08lx\n", address);
		LCD_display("Panic:kernel paging");
	}
	printk(KERN_ALERT "tsk->{mm,active_mm}->context = %08lx\n",
		(tsk->mm ? tsk->mm->context : tsk->active_mm->context));
	printk(KERN_ALERT "tsk->{mm,active_mm}->pgd = %08lx\n",
		(tsk->mm ? (unsigned long) tsk->mm->pgd :
		 	(unsigned long) tsk->active_mm->pgd));
	die_if_kernel("Oops", regs);
}

asmlinkage int lookup_fault(unsigned long pc, unsigned long ret_pc, 
			    unsigned long address)
{
	unsigned long g2;
	int i;
	unsigned insn;
	struct pt_regs regs;
	
	i = search_exception_table (ret_pc, &g2);
	switch (i) {
	/* load & store will be handled by fixup */
	case 3: return 3;
	/* store will be handled by fixup, load will bump out */
	/* for _to_ macros */
	case 1: insn = (unsigned)pc; if ((insn >> 21) & 1) return 1; break;
	/* load will be handled by fixup, store will bump out */
	/* for _from_ macros */
	case 2: insn = (unsigned)pc; 
		if (!((insn >> 21) & 1) || ((insn>>19)&0x3f) == 15) return 2; 
		break; 
	default: break;
	}
	memset (&regs, 0, sizeof (regs));
	regs.pc = pc;
	regs.npc = pc + 4;
	__asm__ __volatile__ ("
		rd %%psr, %0
		nop
		nop
		nop" : "=r" (regs.psr));
	unhandled_fault (address, current, &regs);
	/* Not reached */
	return 0;
}

u32 current_pgd;


asmlinkage void __ic3call do_sparc_fault(struct pt_regs *regs, unsigned long fault,
			       unsigned long address) 
{
	struct vm_area_struct *vma;
	struct task_struct *tsk = current;
	struct mm_struct *mm = tsk->mm;
	unsigned int fixup;
	unsigned long g2;
	siginfo_t info;
	int from_user = !(regs->psr & PSR_PS);
	int write_access;


	/*
	 * We fault-in kernel-space virtual memory on-demand. The
	 * 'reference' page table is init_mm.pgd.
	 *
	 * NOTE! We MUST NOT take any locks for this case. We may
	 * be in an interrupt or a critical region, and should
	 * only copy the information from the master page table,
	 * nothing more.
	 */
	if (!from_user && address >= TASK_SIZE) 
		goto vmalloc_fault;

	info.si_code = SEGV_MAPERR;

	/*
	 * If we're in an interrupt or have no user
	 * context, we must not take the fault..
	 */
    if (in_interrupt() || !mm) 
		goto no_context;

	down_read(&mm->mmap_sem);

	vma = find_vma(mm, address);
	if(!vma) 
		goto bad_area;
	
	if(vma->vm_start <= address)
		goto good_area;

	if(!(vma->vm_flags & VM_GROWSDOWN)) 
		goto bad_area;
	
	if(expand_stack(vma, address)) 
		goto bad_area;

	/*
	 * Ok, we have a good vm_area for this memory access, so
	 * we can handle it..
	 */
good_area:
	info.si_code = SEGV_ACCERR;
	if(fault & 0x2)
		write_access = 1;
	else
		write_access = 0;
	if( write_access) {
		if(!(vma->vm_flags & VM_WRITE)) 
			goto bad_area;
		
	} else {
		/* Allow reads even for write-only mappings */
		if(!(vma->vm_flags & (VM_READ | VM_EXEC))) 
			goto bad_area;
	}
	/*
	 * If for any reason at all we couldn't handle the fault,
	 * make sure we exit gracefully rather than endlessly redo
	 * the fault.
	 */
#ifdef CONFIG_PADRE_UNEXPECT_TLBTRAP
	{
   		pgd_t *pgd;
	    pmd_t *pmd;
		pte_t *pte;

		pgd = pgd_offset(mm,address);
		if (pgd_none(*pgd) || pgd_bad(*pgd))
			goto tlbtrap;
		pmd = pmd_offset(pgd,address);
		if (pmd_none(*pmd) || pmd_bad(*pmd))
		    goto tlbtrap;
		
		pte = pte_offset(pmd,address);
		if( !pte)
			goto tlbtrap;
		if( (*pte & 0x3c1) == 0x3c1 ) {
				printk("unexpect trap %x %d pte=%x\n",address,fault,*pte);
		}
tlbtrap:
	}
#endif
	switch (handle_mm_fault(mm, vma, address, write_access)) { 
	case 1:
		tsk->min_flt++;
		break;
	case 2:
		tsk->maj_flt++;
		break;
	case 0:
		goto do_sigbus;
	default:
		goto out_of_memory;
	}
	up_read(&mm->mmap_sem);

	return;

	/*
	 * Something tried to access memory that isn't in our memory map..
	 * Fix it, but check if it's kernel or user first..
	 */
bad_area:
	up_read(&mm->mmap_sem);

bad_area_nosemaphore:
	/* User mode accesses just cause a SIGSEGV */
	if(from_user) {
#if 0
		printk("Fault whee %s [%d]: segfaults at %08lx pc=%08lx\n",
		       tsk->comm, tsk->pid, address, regs->pc);
		
		show_regs(regs);
		show_maps();
        {
			struct reg_window *rw = (struct reg_window *)regs->u_regs[UREG_FP];
			unsigned int ins[8];
			while(rw && !(((unsigned long) rw) & 0x3)) {
				copy_from_user(ins, &rw->ins[0], sizeof(ins));
				printk("Caller[%08x](%08x,%08x,%08x,%08x,%08x,%08x)\n", ins[7], ins[0], ins[1], ins[2], ins[3], ins[4], ins[5]);
				rw = (struct reg_window *)(unsigned long)ins[6];
			}
		}

				
#endif
		
		info.si_signo = SIGSEGV;
		info.si_errno = 0;
		/* info.si_code set above to make clear whether
		   this was a SEGV_MAPERR or SEGV_ACCERR fault.  */
		info.si_addr = (void *)address;
		info.si_trapno = 0;
		force_sig_info (SIGSEGV, &info, tsk);
		return;
	}

	/* Is this in ex_table? */
no_context:
	//printk("no_context mm=%p pc=%x\n",mm,regs->pc);
			   
	g2 = regs->u_regs[UREG_G2];
	if (!from_user && (fixup = search_exception_table (regs->pc, &g2))) {
		if (fixup > 10) { /* Values below are reserved for other things */
			extern const unsigned __memset_start[];
			extern const unsigned __memset_end[];
			extern const unsigned __csum_partial_copy_start[];
			extern const unsigned __csum_partial_copy_end[];

#ifdef DEBUG_EXCEPTIONS
			printk("Exception: PC<%08lx> faddr<%08lx>\n", regs->pc, address);
			printk("EX_TABLE: insn<%08lx> fixup<%08x> g2<%08lx>\n",
				regs->pc, fixup, g2);
#endif
			if ((regs->pc >= (unsigned long)__memset_start &&
			     regs->pc < (unsigned long)__memset_end) ||
			    (regs->pc >= (unsigned long)__csum_partial_copy_start &&
			     regs->pc < (unsigned long)__csum_partial_copy_end)) {
			        regs->u_regs[UREG_I4] = address;
				regs->u_regs[UREG_I5] = regs->pc;
			}
			regs->u_regs[UREG_G2] = g2;
			regs->pc = fixup;
			regs->npc = regs->pc + 4;
			return;
		}
	}

	//printk("fixup=%x\n",fixup);	
	unhandled_fault (address, tsk, regs);
	do_exit(SIGKILL);

/*
 * We ran out of memory, or some other thing happened to us that made
 * us unable to handle the page fault gracefully.
 */
out_of_memory:
	up_read(&mm->mmap_sem);
	printk("VM: killing process %s\n", tsk->comm);
	if (from_user)
		do_exit(SIGKILL);
	goto no_context;

do_sigbus:
	up_read(&mm->mmap_sem);
	info.si_signo = SIGBUS;
	info.si_errno = 0;
	info.si_code = BUS_ADRERR;
	info.si_addr = (void *)address;
	info.si_trapno = 0;
	force_sig_info (SIGBUS, &info, tsk);
	if (!from_user)
		goto no_context;

vmalloc_fault:
	{
		/*
		 * Synchronize this task's top level page-table
		 * with the 'reference' page table.
		 */
        int offset = pgd_index(address);
		pgd_t *pgd, *pgd_k;
		pmd_t *pmd, *pmd_k;
		pte_t *pte_k;
						 
		pgd = tsk->active_mm->pgd + offset;
		pgd_k = init_mm.pgd + offset;
										 
		if (!pgd_present(*pgd)) {
			if (!pgd_present(*pgd_k))
				goto bad_area_nosemaphore;
			pgd_val(*pgd) = pgd_val(*pgd_k);
			return;
		}
												 
		pmd = pmd_offset(pgd, address);
		pmd_k = pmd_offset(pgd_k, address);
																 
		if (pmd_present(*pmd) || !pmd_present(*pmd_k))
			goto bad_area_nosemaphore;
		pmd_val(*pmd) = pmd_val(*pmd_k);
		
	    pte_k = pte_offset(pmd_k, address);         
	  	 
#ifdef CONFIG_PADRE_PGTCACHE	
		/* flush pgd cache because we add first level entry to pg table*/		
		__asm__ __volatile__(
			"sta %0, [%1]%2"
			:
			:"r"((current_pgd-0x40000000UL)|PADRE_MMU_PGT_EN
			 | PADRE_MMU_PGT_CACHE),"r"(PADRE_MMU_PGT),"i"(ASI_MMU));
#endif

		/* update ptek entry, our hardware is very special */
        __asm__ __volatile__(
		    "sta %0, [%1]%2\n"
#ifdef CONFIG_PADRE_8K
			"sta %3, [%4]%2\n"
#endif
			
			:
			: "r"(*pte_k),"r"(address),"i"(ASI_TLBPROBE)
#ifdef CONFIG_PADRE_8K
			, "r"(*pte_k+0x1000),"r"(address+0x1000)
#endif
			);

		
		//printk("init_mm.pgd=%p, pgd_k=%p, *pgd_k=%x, pte_k=%p,*pte_k=%x current_pgd=%x\n",
		//	init_mm.pgd, pgd_k,*pgd_k,pte_k,*pte_k,current_pgd);		
		
		return;
	}
}


/* This always deals with user addresses. */
inline void force_user_fault(unsigned long address, int write)
{
	struct vm_area_struct *vma;
	struct task_struct *tsk = current;
	struct mm_struct *mm = tsk->mm;
	siginfo_t info;

	info.si_code = SEGV_MAPERR;

#if 0
	printk("wf<pid=%d,wr=%d,addr=%08lx>\n",
	       tsk->pid, write, address);
#endif
	down_read(&mm->mmap_sem);
	vma = find_vma(mm, address);
	if(!vma)
		goto bad_area;
	if(vma->vm_start <= address)
		goto good_area;
	if(!(vma->vm_flags & VM_GROWSDOWN))
		goto bad_area;
	if(expand_stack(vma, address))
		goto bad_area;
good_area:
	info.si_code = SEGV_ACCERR;
	if(write) {
		if(!(vma->vm_flags & VM_WRITE))
			goto bad_area;
	} else {
		if(!(vma->vm_flags & (VM_READ | VM_EXEC)))
			goto bad_area;
	}
	if (!handle_mm_fault(mm, vma, address, write))
		goto do_sigbus;
	up_read(&mm->mmap_sem);
	return;
bad_area:
	up_read(&mm->mmap_sem);
#if 0
	printk("Window whee %s [%d]: segfaults at %08lx\n",
	       tsk->comm, tsk->pid, address);
#endif
	info.si_signo = SIGSEGV;
	info.si_errno = 0;
	/* info.si_code set above to make clear whether
	   this was a SEGV_MAPERR or SEGV_ACCERR fault.  */
	info.si_addr = (void *)address;
	info.si_trapno = 0;
	force_sig_info (SIGSEGV, &info, tsk);
	return;

do_sigbus:
	up_read(&mm->mmap_sem);
	info.si_signo = SIGBUS;
	info.si_errno = 0;
	info.si_code = BUS_ADRERR;
	info.si_addr = (void *)address;
	info.si_trapno = 0;
	force_sig_info (SIGBUS, &info, tsk);
}

void  window_overflow_fault(void)
{
	unsigned long sp;

	sp = current->thread.rwbuf_stkptrs[0];
	if(((sp + 0x38) & PAGE_MASK) != (sp & PAGE_MASK))
		force_user_fault(sp + 0x38, 1);
	force_user_fault(sp, 1);
}

void window_underflow_fault(unsigned long sp)
{
	if(((sp + 0x38) & PAGE_MASK) != (sp & PAGE_MASK))
		force_user_fault(sp + 0x38, 0);
	force_user_fault(sp, 0);
}

void window_ret_fault(struct pt_regs *regs)
{
	unsigned long sp;

	sp = regs->u_regs[UREG_FP];
	if(((sp + 0x38) & PAGE_MASK) != (sp & PAGE_MASK))
		force_user_fault(sp + 0x38, 0);
	force_user_fault(sp, 0);
}


