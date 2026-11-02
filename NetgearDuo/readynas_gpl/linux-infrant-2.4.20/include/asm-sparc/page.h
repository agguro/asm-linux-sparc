/* $Id: page.h,v 1.55 2000/10/30 21:01:41 davem Exp $
 * page.h:  Various defines and such for MMU operations on the Sparc for
 *          the Linux kernel.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 */

#ifndef _SPARC_PAGE_H
#define _SPARC_PAGE_H

#include <linux/config.h>
#ifdef CONFIG_PADRE_8K
#define PAGE_SHIFT   13
#else
#define PAGE_SHIFT   12
#endif
#ifndef __ASSEMBLY__
#define PAGE_SIZE    (1UL << PAGE_SHIFT)
#else
#define PAGE_SIZE	 (1 << PAGE_SHIFT)
#endif
#define PAGE_MASK    (~(PAGE_SIZE-1))

#ifdef __KERNEL__

#include <asm/head.h>       /* for KERNBASE */

/* This is always 2048*sizeof(long), doesn't change with PAGE_SIZE */
#ifdef CONFIG_PADRE_STACK_16K
#define TASK_UNION_SIZE     0x4000
#else
#define TASK_UNION_SIZE		8192
#endif
#ifdef CONFIG_PADRE_2CPU
#define PADRE_CPU1_START	(0x80000000+(CONFIG_PADRE_CPU0_SIZE<<24))
#endif

#ifndef __ASSEMBLY__

extern unsigned long PAGE_NONCACHE_MARK;
#define BUG() do { \
	printk("kernel BUG at %s:%d!\n", __FILE__, __LINE__); *(int *)0=0; \
} while (0)
#define PAGE_BUG(page)	BUG()

#define clear_page(page)	 memset((void *)(page), 0, PAGE_SIZE)
#define copy_page(to,from) 	memcpy((void *)(to), (void *)(from), PAGE_SIZE)
#define clear_user_page(page, vaddr)	clear_page(page)
#define copy_user_page(to, from, vaddr)	copy_page(to, from)

/*
 * .. while these make it easier on the compiler
 */
typedef unsigned long pte_t;
typedef unsigned long pmd_t;
typedef unsigned long pgd_t;
typedef unsigned long pgprot_t;

#define pte_val(x)		(x)
#define pmd_val(x)      (x)
#define pgd_val(x)		(x)
#define pgprot_val(x)	(x)

#define __pte(x)		(x)
#define __pmd(x)        (x)
#define __pgd(x)		(x)
#define __pgprot(x)		(x)

#define PTE_MASK	PAGE_MASK
#define TASK_UNMAPPED_BASE	0x20000000
//#define TASK_UNMAPPED_BASE	(TASK_SIZE/3)

/* Pure 2^n version of get_order */
extern __inline__ int get_order(unsigned long size)
{
	int order;

	size = (size-1) >> (PAGE_SHIFT-1);
	order = -1;
	do {
		size >>= 1;
		order++;
	} while (size);
	return order;
}

#else /* !(__ASSEMBLY__) */

#define __pgprot(x)	(x)

#endif /* !(__ASSEMBLY__) */

/* to align the pointer to the (next) page boundary */
#define PAGE_ALIGN(addr)  		(((addr)+PAGE_SIZE-1)&PAGE_MASK)

#ifdef CONFIG_PADRE_2CPU
#ifdef CONFIG_PADRE_CPU1
#define PAGE_OFFSET				PADRE_CPU1_START
#else
#define PAGE_OFFSET				0x80000000
#endif
#else
#define PAGE_OFFSET				0x80000000
#endif

#define __pa(x)                 ((unsigned long)(x) - PAGE_OFFSET)
#define __va(x)                 ((void *)((unsigned long) (x) + PAGE_OFFSET))
#define virt_to_page(kaddr)		(mem_map + (__pa(kaddr) >> PAGE_SHIFT))
#define VALID_PAGE(page)		((page - mem_map) < max_mapnr)

#define VM_DATA_DEFAULT_FLAGS   (VM_READ | VM_WRITE | VM_EXEC | \
		                 VM_MAYREAD | VM_MAYWRITE | VM_MAYEXEC)

#endif /* __KERNEL__ */

#endif /* _SPARC_PAGE_H */
