/* $Id: pgalloc.h,v 1.13 2001/07/17 16:17:33 anton Exp $ */
#ifndef _SPARC_PGALLOC_H
#define _SPARC_PGALLOC_H

#include <linux/config.h>
#include <linux/kernel.h>
#include <linux/sched.h>
#include <linux/mm.h>

#include <asm/head.h>
#include <asm/page.h>
#include <asm/io.h>

#define flush_cache_all()		do { } while(0)
#define flush_cache_mm(mm)	do { } while(0)
#define flush_cache_range(mm,start,end) 	do { } while(0)
#define flush_cache_page(vma,page)			do { } while(0)
#define flush_dcache_page(page)				do { } while(0)
extern void clean_dcache_range(unsigned long start, unsigned long end);
extern void flush_dcache_range(unsigned long start, unsigned long end);
extern void flush_icache_page(struct vm_area_struct *vma, struct page *page);
extern void flush_sig_insns(struct mm_struct *mm, unsigned long insn_addr);
extern void flush_cache_dma(int direction);  
extern void flush_page_to_ram(struct page *page);
#define flush_icache_user_range(vma,pg,adr,len) flush_icache_range(adr,adr+len)

#define __flush_tlb()												\
	do {															\
		unsigned int flush_cmd = (PADRE_MMU_CONTROL_FL |			\
								  PADRE_MMU_CONTROL_DE |			\
							  	  PADRE_MMU_CONTROL_IE);			\
	  	__asm__ __volatile__(										\
			"sta %0, [%1]%2"										\
			:														\
			:"r"(flush_cmd),"r"(PADRE_MMU_CONTROL),"i"(ASI_MMU));	\
	} while(0)
			
		
#define flush_tlb_all()	__flush_tlb()	

static inline void flush_tlb_mm(struct mm_struct *mm)
{
    if( mm == current->active_mm)
		__flush_tlb();	
}

#define flush_tlb_range(mm,start,end) flush_tlb_mm(mm)

static inline void flush_tlb_pgtables(struct mm_struct *mm,
		unsigned long start, unsigned long end)
{
}


static inline void flush_tlb_page(struct vm_area_struct *vma,unsigned long addr)
{
	if( vma->vm_mm == current->active_mm) {
		pgd_t *pgd;
		pmd_t *pmd;
		pte_t *pte,ptev;
		unsigned long flags;

#ifdef CONFIG_PADRE_8K
        unsigned long addr1;
        addr = ((addr >> PAGE_SHIFT) << PAGE_SHIFT);
        addr1 = addr + 0x1000;
#endif
		
		local_irq_save(flags);
   		pgd = pgd_offset(vma->vm_mm,addr);
        pmd = pmd_offset(pgd,addr);
		pte = pte_offset(pmd,addr);
		ptev = *pte;
		   	   
									  
   		__asm__ __volatile__(
	   		"sta %%g0, [%0]%1\n"
#ifdef CONFIG_PADRE_8K
            "sta %%g0, [%2]%1\n"
#endif
			:
			:"r"(addr),"i"(ASI_TLBPROBE)
#ifdef CONFIG_PADRE_8K
            ,"r"(addr1)
#endif
            );
		
		writel(ptev,(unsigned long)pte);
#ifdef CONFIG_PADRE_8K
        writel(ptev+0x1000,(unsigned long)(pte+1));
#endif
		
		local_irq_restore(flags);
		   
	}
}

#if 1
#define update_mmu_cache(vma,address,pte)
#else
static inline void update_mmu_cache(struct vm_area_struct *vma,unsigned long address,pte_t pte)
{
	if( vma->vm_mm == current->active_mm) {
		if(pte >= PAGE_NONCACHE_MARK)
			pte &= ~_PAGE_C;
		__asm__ __volatile__(
			"sta %0, [%1]%2"
			:
			: "r"(pte),"r"(address),"i"(ASI_TLBPROBE));
	}
}
#endif

extern struct pgtable_cache_struct {
	unsigned long *pgd_cache;
	unsigned long *pte_cache;
	unsigned long pgtable_cache_sz;
	unsigned long pgd_cache_sz;
} pgt_quicklists;
#define pgd_quicklist           (pgt_quicklists.pgd_cache)
#define pmd_quicklist           ((unsigned long *)0)
#define pte_quicklist           (pgt_quicklists.pte_cache)
#define pgtable_cache_size      (pgt_quicklists.pgtable_cache_sz)
#define pgd_cache_size			(pgt_quicklists.pgd_cache_sz)

static __inline__ pgd_t *get_pgd_slow(void)
{
	pgd_t *pgd = (pgd_t *)__get_free_page(GFP_KERNEL | GFP_DMA);
		 
	if (pgd) {
		memset(pgd, 0, USER_PTRS_PER_PGD * sizeof(pgd_t));
		memcpy(pgd+VMALLOC_PTRS_PER_PGD,swapper_pg_dir+VMALLOC_PTRS_PER_PGD,
			   (PTRS_PER_PGD-VMALLOC_PTRS_PER_PGD)*sizeof(pgd_t));	
	}
	return pgd;
}

static __inline__ pgd_t *get_pgd_fast(void)
{
	unsigned long *ret;
		 
	if ((ret = pgd_quicklist) != NULL) {
		pgd_quicklist = (unsigned long *)(*ret);
		ret[0] = ret[1];
		pgtable_cache_size--;
	} else
		ret = (unsigned long *)get_pgd_slow();
	return (pgd_t *)ret;
}

static __inline__ void free_pgd_fast(pgd_t *pgd)
{
	*(unsigned long *)pgd = (unsigned long) pgd_quicklist;
	pgd_quicklist = (unsigned long *) pgd;
	pgtable_cache_size++;
}

static __inline__ void free_pgd_slow(pgd_t *pgd)
{
	free_page((unsigned long)pgd);
}

static inline pte_t *pte_alloc_one(struct mm_struct *mm, unsigned long address)
{
	pte_t *pte;
		    
	pte = (pte_t *) __get_free_page(GFP_KERNEL|GFP_DMA);
    if (pte)
		clear_page(pte);
	return pte;
}

static inline pte_t *pte_alloc_one_fast(struct mm_struct *mm, unsigned long address)
{
    unsigned long *ret;
		 
	if ((ret = (unsigned long *)pte_quicklist) != NULL) {
		pte_quicklist = (unsigned long *)(*ret);
		ret[0] = ret[1];
		pgtable_cache_size--;
	}
	return (pte_t *)ret;
}

static __inline__ void pte_free_fast(pte_t *pte)
{
    *(unsigned long *)pte = (unsigned long) pte_quicklist;
    pte_quicklist = (unsigned long *) pte;
    pgtable_cache_size++;
}

static __inline__ void pte_free_slow(pte_t *pte)
{
	free_page((unsigned long)pte);
}

#define pte_free(pte)	pte_free_slow(pte)
#define pgd_free(pgd)	free_pgd_fast(pgd)
#define pgd_alloc(mm)	get_pgd_fast()

#define pmd_alloc_one_fast(mm, addr)    ({ BUG(); ((pmd_t *)1); })
#define pmd_alloc_one(mm, addr)     ({ BUG(); ((pmd_t *)2); })
#define pmd_free_slow(x)    do { } while (0)
#define pmd_free_fast(x)    do { } while (0)
#define pmd_free(x)         do { } while (0)
#define pgd_populate(MM, PGD, PMD)      BUG()

extern int do_check_pgt_cache(int,int);

#define pmd_populate(mm, pmd, pte) \
        set_pmd(pmd, __pmd(_PAGE_TABLE + ((unsigned long)pte)-0x40000000))

#endif /* _SPARC_PGALLOC_H */
