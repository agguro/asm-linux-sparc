/* $Id: traps.c,v 1.64 2000/09/03 15:00:49 anton Exp $
 * arch/sparc/kernel/traps.c
 *
 * Copyright 1995 David S. Miller (davem@caip.rutgers.edu)
 * Copyright 2000 Jakub Jelinek (jakub@redhat.com)
 */

/*
 * I hate traps on the sparc, grrr...
 */

#include <linux/config.h>
#include <linux/sched.h>  /* for jiffies */
#include <linux/kernel.h>
#include <linux/signal.h>
#include <linux/smp.h>
#include <linux/smp_lock.h>

#include <asm/delay.h>
#include <asm/system.h>
#include <asm/ptrace.h>
#include <asm/page.h>
#include <asm/pgtable.h>
#include <asm/kdebug.h>
#include <asm/unistd.h>
#include <asm/traps.h>

#include <linux/mm.h>
#define TRAP_DEBUG 

struct trap_trace_entry {
	unsigned long pc;
	unsigned long type;
};

int trap_curbuf = 0;
struct trap_trace_entry trapbuf[1024];
unsigned long SAVE_GLOB_TMP  __dc3data; 


void syscall_trace_entry(struct pt_regs *regs)
{
	printk("%s[%d]: ", current->comm, current->pid);
	printk("scall<%d> (could be %d)\n", (int) regs->u_regs[UREG_G1],
	       (int) regs->u_regs[UREG_I0]);
}

void syscall_trace_exit(struct pt_regs *regs)
{
}

void instruction_dump (unsigned long *pc)
{
	int i;
	
	if((((unsigned long) pc) & 3))
                return;

	for(i = -3; i < 6; i++)
		printk("%c%08lx%c",i?' ':'<',pc[i],i?' ':'>');
	printk("\n");
}

#define __SAVE __asm__ __volatile__("save %sp, -0x40, %sp\n\t")
#define __RESTORE __asm__ __volatile__("restore %g0, %g0, %g0\n\t")

void die_if_kernel(char *str, struct pt_regs *regs)
{
	int count = 0;

	/* Amuse the user. */
	printk(
"              \\|/ ____ \\|/\n"
"              \"@'/ ,. \\`@\"\n"
"              /_| \\__/ |_\\\n"
"                 \\__U_/\n");

	printk("%s(%d): %s\n", current->comm, current->pid, str);
	show_regs(regs);

	__SAVE; __SAVE; __SAVE; __SAVE;
	__SAVE; __SAVE; __SAVE; __SAVE;
	__RESTORE; __RESTORE; __RESTORE; __RESTORE;
	__RESTORE; __RESTORE; __RESTORE; __RESTORE;

	{
		struct reg_window *rw = (struct reg_window *)regs->u_regs[UREG_FP];

		/* Stop the back trace when we hit userland or we
		 * find some badly aligned kernel stack. Set an upper
		 * bound in case our stack is trashed and we loop.
		 */
		while(rw					&&
		      count++ < 30				&&
                      (((unsigned long) rw) >= PAGE_OFFSET)	&&
		      !(((unsigned long) rw) & 0x7)) {
			printk("Caller[%08lx]\n", rw->ins[7]);
			rw = (struct reg_window *)rw->ins[6];
		}
	}
	printk("Instruction DUMP:");
	instruction_dump ((unsigned long *) regs->pc);
	if(regs->psr & PSR_PS)
		do_exit(SIGKILL);
	do_exit(SIGSEGV);
}

void do_hw_interrupt(unsigned long type, unsigned long psr, unsigned long pc)
{
	siginfo_t info;

	printk("do_hw_interrupt\n");
	if(type < 0x80) {
		/* Sun OS's puke from bad traps, Linux survives! */
		printk("Unimplemented Sparc TRAP, type = %02lx\n", type);
		die_if_kernel("Whee... Hello Mr. Penguin", current->thread.kregs);
	}	

	if(psr & PSR_PS)
		die_if_kernel("Kernel bad trap", current->thread.kregs);

	info.si_signo = SIGILL;
	info.si_errno = 0;
	info.si_code = ILL_ILLTRP;
	info.si_addr = (void *)pc;
	info.si_trapno = type - 0x80;
	force_sig_info(SIGILL, &info, current);
}

#if 1
#define MAPS_LINE_FORMAT          "%08lx-%08lx %s %08lx %s %lu "

static inline void read_maps (void)
{
        struct vm_area_struct * map, * next;
        char * buffer;
        ssize_t i;

        buffer = (char*)__get_free_page(GFP_KERNEL);
        if (!buffer)
                return;

        for (map = current->mm->mmap ; map ; map = next ) {
                /* produce the next line */
                char *line;
                char str[5], *cp = str;
                int flags;
                kdev_t dev;
                unsigned long ino;

                /*
                 * Get the next vma now (but it won't be used if we sleep).
                 */
                next = map->vm_next;
                flags = map->vm_flags;

                *cp++ = flags & VM_READ ? 'r' : '-';
                *cp++ = flags & VM_WRITE ? 'w' : '-';
                *cp++ = flags & VM_EXEC ? 'x' : '-';
                *cp++ = flags & VM_MAYSHARE ? 's' : 'p';
                *cp++ = 0;

                dev = 0;
                ino = 0;
                if (map->vm_file != NULL) {
                        dev = map->vm_file->f_dentry->d_inode->i_dev;
                        ino = map->vm_file->f_dentry->d_inode->i_ino;
                        line = d_path(map->vm_file->f_dentry,
                                      map->vm_file->f_vfsmnt,
                                      buffer, PAGE_SIZE);
                }
                printk(MAPS_LINE_FORMAT, map->vm_start, map->vm_end, str, map->vm_pgoff << PAGE_SHIFT,
                              kdevname(dev), ino);
                if (map->vm_file != NULL)
                        printk("%s\n", line);
                else
                        printk("\n");
        }
        free_page((unsigned long)buffer);
        return;
}
#endif

static unsigned long illegal_instruction_count = 0;
void do_illegal_instruction(struct pt_regs *regs, unsigned long pc, unsigned long npc,
		                unsigned long psr)
{
    extern int do_user_muldiv (struct pt_regs *, unsigned long);
    siginfo_t info;

    if(psr & PSR_PS)
        die_if_kernel("Kernel illegal instruction", regs);
#ifdef TRAP_DEBUG
    printk("Ill instr. at pc=%08lx instruction is %08lx\n",
           regs->pc, *(unsigned long *)regs->pc);
#endif
    if (!do_user_muldiv (regs, pc))
        return;
	
#if 1
	if(illegal_instruction_count < 100) {
		read_maps();
		illegal_instruction_count++;
		flush_sig_insns(NULL,pc);
		return ;
	}

	illegal_instruction_count = 0;
#endif
	
    info.si_signo = SIGILL;
    info.si_errno = 0;
    info.si_code = ILL_ILLOPC;
    info.si_addr = (void *)pc;
    info.si_trapno = 0;
    send_sig_info(SIGILL, &info, current);
}


u32 read_asi_mmu(u32 address)
{
    u32 value;
    __asm__ __volatile__(
        "lda [%1]%2, %0"
         :"=r"(value)
         :"r"(address),"i"(ASI_MMU));
			 
    return value;
}
 
void write_asi_mmu(u32 address, u32 value)
{
    __asm__ __volatile__(
       "sta %0, [%1]%2"
       :
       :"r"(value),"r"(address),"i"(ASI_MMU));
}

static void display_tlb()
{
	int i;
	u32 ptel,pteh;
	for(i = 0; i< 16; i++) {
		write_asi_mmu(PADRE_MMU_CONTROL, 0xb | ( i << 12) );
		ptel = read_asi_mmu(PADRE_MMU_TLBL);
		pteh = read_asi_mmu(PADRE_MMU_TLBH);
		printk("entry=%d ptel=%x,pteh=%x\n",i,ptel,pteh);
	}
}
void do_priv_instruction(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			 unsigned long psr)
{
	siginfo_t info;
	printk("do_priv_instruction\n");
	show_regs(regs);

	display_tlb();
	if(psr & PSR_PS)
		die_if_kernel("Penguin instruction from Penguin mode??!?!", regs);
#ifdef TRAP_DEBUG
	//printk("priv instr. at pc=%08lx instruction is %08lx\n",
	//       regs->pc, *(unsigned long *)regs->pc);
#endif
	info.si_signo = SIGILL;
	info.si_errno = 0;
	info.si_code = ILL_PRVOPC;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGILL, &info, current);
}

#ifdef CONFIG_PADRE
void do_itlb_fault(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			 unsigned long psr)
{
	siginfo_t info;

	if(psr & PSR_PS)
		die_if_kernel("Impossible kernel inst access protection??!?!", regs);
	info.si_signo = SIGSEGV;
	info.si_errno = 0;
	info.si_code = SEGV_ACCERR;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGSEGV, &info, current);
}


void do_dtlb_fault(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			 unsigned long psr)
{
	siginfo_t info;

	if(psr & PSR_PS)
		die_if_kernel("Impossible kernel data access proctection??!?!", regs);
	info.si_signo = SIGSEGV;
	info.si_errno = 0;
	info.si_code = SEGV_ACCERR;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGSEGV, &info, current);
}
#endif

/* XXX User may want to be allowed to do this. XXX */

void do_memaccess_unaligned(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			    unsigned long psr)
{
	siginfo_t info;
	printk("do_memaccess_unaligned\n");

	if(regs->psr & PSR_PS) {
		printk("KERNEL MNA at pc %08lx npc %08lx called by %08lx\n", pc, npc,
		       regs->u_regs[UREG_RETPC]);
		die_if_kernel("BOGUS", regs);
		/* die_if_kernel("Kernel MNA access", regs); */
	}
#if 0
	show_regs (regs);
	instruction_dump ((unsigned long *) regs->pc);
	printk ("do_MNA!\n");
#endif
	info.si_signo = SIGBUS;
	info.si_errno = 0;
	info.si_code = BUS_ADRALN;
	info.si_addr = /* FIXME: Should dig out mna address */ (void *)0;
	info.si_trapno = 0;
	send_sig_info(SIGBUS, &info, current);
}

extern int do_mathemu(struct pt_regs *, struct task_struct *);

void do_fpd_trap(struct pt_regs *regs, unsigned long pc, unsigned long npc,
		 unsigned long psr)
{
	/* Sanity check... */
	if(psr & PSR_PS)
		die_if_kernel("Kernel gets FloatingPenguinUnit disabled trap", regs);

	last_task_used_math = current;
	current->used_math = 1;

	if(!do_mathemu(regs,last_task_used_math))
		printk("WARNING: FPU cannot be emulated\n");
	return;	
}

void handle_tag_overflow(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			 unsigned long psr)
{
	siginfo_t info;

	printk("handle_tag_overflow\n");
	show_regs(regs);
	if(psr & PSR_PS)
		die_if_kernel("Penguin overflow trap from kernel mode", regs);
	info.si_signo = SIGEMT;
	info.si_errno = 0;
	info.si_code = EMT_TAGOVF;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGEMT, &info, current);
}

void handle_watchpoint(struct pt_regs *regs, unsigned long pc, unsigned long npc,
		       unsigned long psr)
{
#ifdef TRAP_DEBUG
	printk("Watchpoint detected at PC %08lx NPC %08lx PSR %08lx\n",
	       pc, npc, psr);
#endif
	if(psr & PSR_PS)
		panic("Tell me what a watchpoint trap is, and I'll then deal "
		      "with such a beast...");
}

void handle_reg_access(struct pt_regs *regs, unsigned long pc, unsigned long npc,
		       unsigned long psr)
{
	siginfo_t info;

	printk("handle_reg_access\n");
	show_regs(regs);
#ifdef TRAP_DEBUG
	printk("Register Access Exception at PC %08lx NPC %08lx PSR %08lx\n",
	       pc, npc, psr);
#endif
	info.si_signo = SIGBUS;
	info.si_errno = 0;
	info.si_code = BUS_OBJERR;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	force_sig_info(SIGBUS, &info, current);
}

void handle_cp_disabled(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			unsigned long psr)
{
	siginfo_t info;

	info.si_signo = SIGILL;
	info.si_errno = 0;
	info.si_code = ILL_COPROC;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGILL, &info, current);
}

void handle_cp_exception(struct pt_regs *regs, unsigned long pc, unsigned long npc,
			 unsigned long psr)
{
	siginfo_t info;

#ifdef TRAP_DEBUG
	printk("Co-Processor Exception at PC %08lx NPC %08lx PSR %08lx\n",
	       pc, npc, psr);
#endif
	info.si_signo = SIGILL;
	info.si_errno = 0;
	info.si_code = ILL_COPROC;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGILL, &info, current);
}

void handle_hw_divzero(struct pt_regs *regs, unsigned long pc, unsigned long npc,
		       unsigned long psr)
{
	siginfo_t info;

	info.si_signo = SIGFPE;
	info.si_errno = 0;
	info.si_code = FPE_INTDIV;
	info.si_addr = (void *)pc;
	info.si_trapno = 0;
	send_sig_info(SIGFPE, &info, current);
}

/* Since we have our mappings set up, on multiprocessors we can spin them
 * up here so that timer interrupts work during initialization.
 */

extern void sparc_cpu_startup(void);

int linux_smp_still_initting;
unsigned int thiscpus_tbr;
int thiscpus_mid;

void trap_init(void)
{
	/* Attach to the address space of init_task. */
	atomic_inc(&init_mm.mm_count);
	current->active_mm = &init_mm;

	/* NOTE: Other cpus have this done as they are started
	 *       up on SMP.
	 */
}

#ifdef CONFIG_PADRE
void padre_halt(void)
{
	cli();
again:
	goto again;
}
#endif
		
	
