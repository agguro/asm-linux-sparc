/* $Id: pgtable.h,v 1.107 2001/08/06 13:16:37 davem Exp $ */
#ifndef _SPARC_PGTABLE_H
#define _SPARC_PGTABLE_H

/*  asm-sparc/pgtable.h:  Defines and functions used to work
 *                        with Sparc page tables.
 *
 *  Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 *  Copyright (C) 1998 Jakub Jelinek (jj@sunsite.mff.cuni.cz)
 */

#include <linux/config.h>
#ifdef CONFIG_PADRE_P0
#include <asm/padre0.h>
#else
#include <asm/padre.h>
#endif

#ifndef __ASSEMBLY__
#include <asm/processor.h>
#include <linux/threads.h>

extern pgd_t swapper_pg_dir[1024];
extern void paging_init(void);

#define PGDIR_SHIFT		22
#define PTRS_PER_PGD	1024

#define PMD_SHIFT		22
#define PTRS_PER_PMD	1

#define PTRS_PER_PTE	1024

#define pte_ERROR(e)	\
		printk("%s:%d: bad pte %08lx.\n", __FILE__, __LINE__, pte_val(e))
#define pmd_ERROR(e)	\
		printk("%s:%d: bad pmd %08lx.\n", __FILE__, __LINE__, pmd_val(e))
#define pgd_ERROR(e)	\
		printk("%s:%d: bad pgd %08lx.\n", __FILE__, __LINE__, pgd_val(e))

/*
 * The "pgd_xxx()" functions here are trivial for a folded two-level
 * setup: the pgd is never bad, and a pmd always exists (as it's folded
 * into the pgd entry)
 */
		
static inline int pgd_none(pgd_t pgd)		{ return 0; }
static inline int pgd_bad(pgd_t pgd)		{ return 0; }
static inline int pgd_present(pgd_t pgd)	{ return 1; }
#define pgd_clear(x)						do { } while (0)

/*
 * Certain architectures need to do special things when PTEs
 * within a page table are directly modified.  Thus, the following
 * hook is made available.
 */
//#define set_pte(pteptr,pteval)	(*(pteptr) = (pteval))
static inline void  set_pte(pte_t *pteptr, pte_t pteval)
{
#ifdef CONFIG_PADRE_8K
	if(((unsigned long)pteptr & 0x4) != 0) {
		printk("set_pte pteptr %p,pteval %08lx\n",pteptr,pteval);
		while(1);
	}
#endif
	if(pteval >= PAGE_NONCACHE_MARK)
		pteval &= ~_PAGE_C;
	(*(pteptr) = (pteval));
#ifdef CONFIG_PADRE_8K
	if(pteval == 0)
    	(*(pteptr+1)) = pteval;
	else
    	(*(pteptr+1)) = (pteval+0x1000);
#endif
}
/*
 * (pmds are folded into pgds so this doesnt get actually called,
 * but the define is needed for a generic inline function.)
 */
//#define set_pmd(pmdptr, pmdval) (*(pmdptr) = (pmdval))

extern u32 current_pgd; 
static inline void set_pmd(pmd_t *pmdptr, pmd_t pmdval)
{
	u32 pgd = (current_pgd - 0x40000000UL) | PADRE_MMU_PGT_EN 
#ifdef CONFIG_PADRE_PGTCACHE
		| PADRE_MMU_PGT_CACHE
#endif
		;
	*pmdptr = pmdval;
	__asm__ __volatile__(
		"sta %0, [%1]%2"
		:
		:"r"(pgd),"r"(PADRE_MMU_PGT),"i"(ASI_MMU));
}

#define set_pgd(pgdptr, pgdval) (*(pgdptr) = (pgdval))

#define pgd_page(pgd) \
		((unsigned long) __va(pgd_val(pgd) & PAGE_MASK))

static inline pmd_t * pmd_offset(pgd_t *dir, unsigned long address) 
{
	return (pmd_t*)dir;
}

#define pte_page(x)		(mem_map + ((unsigned long)((pte_val(x)-0x40000000) >> PAGE_SHIFT)))
#define pte_none(x) 	(!pte_val(x))

#define PGDIR_SIZE		(1UL << PGDIR_SHIFT)
#define PGDIR_MASK		(~(PGDIR_SIZE-1))
#define PGDIR_ALIGN(addr)	(((addr)+PGDIR_SIZE-1) & PGDIR_MASK)
	
#define PMD_SIZE		(1UL << PMD_SHIFT)
#define PMD_MASK		(~(PMD_SIZE-1))
#define PMD_ALIGN(addr)		(((addr)+PMD_SIZE-1) & PMD_MASK)

#define USER_PTRS_PER_PGD 	(TASK_SIZE/PGDIR_SIZE)
#define FIRST_USER_PGD_NR	0
	
#define VMALLOC_VMADDR(x) ((unsigned long)(x))

#define _PAGE_CHG_MASK	(PAGE_MASK | _PAGE_D)

#ifdef CONFIG_PADRE_DCACHE_WB
#define _PAGE_P			(_PAGE_V | _PAGE_C)
#else
#define _PAGE_P			(_PAGE_V | _PAGE_C | _PAGE_T)
#endif

#define _PAGE_USER		(_PAGE_U | _PAGE_R | _PAGE_X)

#define PAGE_NONE      __pgprot(0 | _PAGE_P)
#define PAGE_SHARED    __pgprot(_PAGE_W | _PAGE_U | _PAGE_R | _PAGE_X | _PAGE_P)
#define PAGE_COPY      __pgprot(_PAGE_U | _PAGE_R | _PAGE_X | _PAGE_P)
#define PAGE_READONLY  __pgprot(_PAGE_U | _PAGE_R | _PAGE_X | _PAGE_P)
#define PAGE_KERNEL	   __pgprot(_PAGE_W |  _PAGE_R | _PAGE_X | _PAGE_D | _PAGE_A | _PAGE_P)

#define _PAGE_TABLE	   __pgprot(_PAGE_W | _PAGE_D | _PAGE_R | _PAGE_X | _PAGE_P | _PAGE_U)
#define _KERNPG_TABLE  __pgprot(_PAGE_W | _PAGE_D | _PAGE_R | _PAGE_X | _PAGE_P )

/* Top-level page directory */
extern pgd_t swapper_pg_dir[1024];

#define __P000  PAGE_NONE
#define __P001  PAGE_READONLY
#define __P010  PAGE_COPY
#define __P011  PAGE_COPY
#define __P100  PAGE_READONLY
#define __P101  PAGE_READONLY
#define __P110  PAGE_COPY 
#define __P111  PAGE_COPY

#define __S000  PAGE_NONE
#define __S001  PAGE_READONLY
#define __S010  PAGE_SHARED
#define __S011  PAGE_SHARED
#define __S100  PAGE_READONLY
#define __S101  PAGE_READONLY
#define __S110  PAGE_SHARED
#define __S111  PAGE_SHARED

extern int num_contexts;
/* First physical page can be anywhere, the following is needed so that
 * va-->pa and vice versa conversions work properly without performance
 * hit for all __pa()/__va() operations.
 */


/*
 * BAD_PAGETABLE is used when we need a bogus page-table, while
 * BAD_PAGE is used for a bogus page.
 *
 * ZERO_PAGE is a global shared page that is always zero: used
 * for zero-mapped memory areas etc..
 */
extern pte_t * __bad_pagetable(void);
extern pte_t __bad_page(void);
extern unsigned long empty_zero_page;

#define BAD_PAGETABLE __bad_pagetable()
#define BAD_PAGE __bad_page()
#define ZERO_PAGE(vaddr) virt_to_page(&empty_zero_page)

/* number of bits that fit into a memory pointer */
#define BITS_PER_PTR      (8*sizeof(unsigned long))

/* to align the pointer to a pointer address */
#define PTR_MASK          (~(sizeof(void*)-1))

#define SIZEOF_PTR_LOG2   2

#define pgd_index(x) 			(((x) >> PGDIR_SHIFT) & (PTRS_PER_PGD-1))
#define pgd_offset(mm,x) 		((mm)->pgd + pgd_index(x))
#define pgd_offset_k(address) 	pgd_offset(&init_mm, address)

#define pmd_none(x)		(!pmd_val(x))
#define pmd_bad(x)		((pmd_val(x) & (~PAGE_MASK & ~_PAGE_U)) != _KERNPG_TABLE)	

#ifdef CONFIG_PADRE_OUTMEMORY_BUG
#define pmd_present(x)	(pmd_val(x) & _PAGE_V)
#else
#define pmd_present(x)	(pmd_val(x) & _PAGE_P)
#endif
#define pmd_clear(xp)	do { set_pmd(xp, __pmd(0)); } while(0)
#define pmd_page(x)   	((pmd_val(x) & PAGE_MASK)+0x40000000UL)

#ifdef CONFIG_PADRE_OUTMEMORY_BUG
#define pte_present(x)	(pte_val(x) & _PAGE_V)
#else
#define pte_present(x)	(pte_val(x) & _PAGE_P)
#endif

#define pte_clear(xp)   do { set_pte(xp, __pte(0)); } while(0)
#ifdef CONFIG_PADRE_8K
#define __pte_offset(x) ((((x) >> PAGE_SHIFT)<<1) & (PTRS_PER_PTE - 1))
#else
#define __pte_offset(x) (((x) >> PAGE_SHIFT) & (PTRS_PER_PTE - 1))
#endif
#define pte_offset(xp,x) ((pte_t*)pmd_page(*(xp)) + __pte_offset(x))
#define pte_write(x)	(pte_val(x) & _PAGE_W)
#define pte_read(x)		(pte_val(x) & _PAGE_USER)
#define pte_young(x)	(pte_val(x) & _PAGE_A)
#define pte_dirty(x)	(pte_val(x) & _PAGE_D)
#define pte_exec(x)		(pte_val(x) & _PAGE_USER)
#define pte_wrprotect(x)	(pte_val(x) & ~_PAGE_W)
#define pte_rdprotect(x)	(pte_val(x) & ~_PAGE_USER)
#define pte_exprotect(x)	(pte_val(x) & ~_PAGE_USER)
#define pte_mkread(x)	(pte_val(x) | _PAGE_USER)
#define pte_mkwrite(x)	(pte_val(x) | _PAGE_W)
#define pte_mkexec(x)	(pte_val(x) | _PAGE_USER)
#define pte_mkdirty(x)	(pte_val(x) | _PAGE_D)
#define pte_mkclean(x)	(pte_val(x) & ~_PAGE_D)
#define pte_mkyoung(x)	(pte_val(x) | _PAGE_A)
#define pte_mkold(x)	(pte_val(x) & ~_PAGE_A)
#define __mk_pte(page_nr,pgprot)		__pte((((page_nr) << PAGE_SHIFT)+0x40000000UL) |\
											pgprot_val(pgprot))
#define mk_pte(page,pgprot)				__mk_pte(((page)-mem_map),(pgprot))
#define mk_pte_phys(physpage,pgprot) 	__pte(((physpage) & PAGE_MASK) |\
											pgprot_val(pgprot))

#define page_pte_prot(page, prot)	mk_pte(page, prot)
#define page_pte(page)				page_pte_prot(page, __pgprot(0))

#define VMALLOC_OFFSET	0
#define VMALLOC_START	0xf8000000
#define VMALLOC_END		0xffff0000
#define VMALLOC_PER_PGD	
#define VMALLOC_PTRS_PER_PGD   (VMALLOC_START/PGDIR_SIZE)   
/* Permanent address of a page. */
//#define page_address(page)  ((page)->virtual)

static __inline__ pte_t pte_modify(pte_t pte, pgprot_t newprot)
{
	return __pte(( (pte_val(pte) & _PAGE_CHG_MASK) | pgprot_val(newprot)));
}

/* Encode and de-code a swap entry */
#define SWP_TYPE(x)					(((x).val >> 2) & 0x7f)
#define SWP_OFFSET(x)				(((x).val >> 9) & 0x3ffff)
#define SWP_ENTRY(type,offset)		((swp_entry_t) { (((type) & 0x7f) << 2) | (((offset) & 0x3ffff) << 9) })
#define pte_to_swp_entry(pte)		((swp_entry_t) { pte_val(pte) })
#define swp_entry_to_pte(x)			((pte_t) { (x).val })


#define PageSkip(page)          	(0)
#define kern_addr_valid(addr)		(1)
#define io_remap_page_range 		remap_page_range

#include <asm-generic/pgtable.h>

#endif /* !(__ASSEMBLY__) */

/*
 * No page table caches to initialise
 */
#define pgtable_cache_init()    do { } while (0)

#endif
