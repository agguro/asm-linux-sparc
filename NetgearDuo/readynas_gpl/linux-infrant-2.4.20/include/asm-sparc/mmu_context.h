#ifndef __SPARC_MMU_CONTEXT_H
#define __SPARC_MMU_CONTEXT_H

#include <asm/head.h>
#include <asm/pgalloc.h>

#ifndef __ASSEMBLY__

#define enter_lazy_tlb(mm, tsk, cpu)	do { } while(0)

/*
 * Initialize a new mmu context.  This is invoked when a new
 * address space instance (unique or shared) is instantiated.
 */
#define init_new_context(tsk, mm) 		0

/*
 * Destroy a dead context.  This occurs when mmput drops the
 * mm_users count to zero, the mmaps have been released, and
 * all the page tables have been flushed.  Our job is to destroy
 * any remaining processor-specific state.
 */
#define destroy_context(mm) 			do { } while(0)

/* Switch the current MM context. */
extern u32 current_pgd;
#ifdef CONFIG_PADRE_BUG179
struct bug179_struct {
	   u32 pte0;
	   u32 pmd0;
	   u32 pgd0;
	   u32 fault;
	   u32 pte;
	   u32 pid;
	   u32 pmd;
	   u32 pgd;
};
extern struct bug179_struct bug179_data[];
extern u32 last_bug179;
#endif


static inline void switch_mm(struct mm_struct *prev, struct mm_struct *next,
	   							 struct task_struct *tsk, unsigned cpu)
{
	if( prev != next) {
		register u32 pgd;
	
	    //memcpy(next->pgd+VMALLOC_PTRS_PER_PGD,swapper_pg_dir+VMALLOC_PTRS_PER_PGD,
		//	               (PTRS_PER_PGD-VMALLOC_PTRS_PER_PGD)*sizeof(pgd_t));
	
#ifdef CONFIG_PADRE_BUG179

		if(bug179_data[last_bug179].pid == current->pid	) {
			pgd_t *pgd;
			pmd_t *pmd;
			pte_t *pte;
			pgd = pgd_offset(prev,0xa9000);
			pmd = pmd_offset(pgd,0xa9000);
			pte = pte_offset(pmd,0xa9000);
														 
			bug179_data[last_bug179].pte0 = *pte;
			bug179_data[last_bug179].pmd0 = *pmd;
			bug179_data[last_bug179].pgd0 = (u32)pgd;

		}
#endif
		current_pgd = (u32)next->pgd;
		pgd = ((u32)(next->pgd) - 0x40000000) | PADRE_MMU_PGT_EN | 
			PADRE_MMU_PGT_FL
#ifdef CONFIG_PADRE_PGTCACHE
			| PADRE_MMU_PGT_CACHE
#endif
	    ;
		__asm__ __volatile__(
				"sta %0, [%1]%2"
				:
				:"r"(pgd),"r"(PADRE_MMU_PGT),"i"(ASI_MMU));
	}
}

/* Activate a new MM instance for the current task. */
#define activate_mm(active_mm, mm) switch_mm((active_mm), (mm), NULL, smp_processor_id())

#endif /* !(__ASSEMBLY__) */

#endif /* !(__SPARC_MMU_CONTEXT_H) */
