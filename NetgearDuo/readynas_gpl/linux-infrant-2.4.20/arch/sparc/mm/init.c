/*  $Id: init.c,v 1.99 2001/07/17 16:17:33 anton Exp $
 *  linux/arch/sparc/mm/init.c
 *
 *  Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 *  Copyright (C) 1995 Eddie C. Dost (ecd@skynet.be)
 *  Copyright (C) 1998 Jakub Jelinek (jj@sunsite.mff.cuni.cz)
 *  Copyright (C) 2000 Anton Blanchard (anton@samba.org)
 */

#include <linux/config.h>
#include <linux/signal.h>
#include <linux/sched.h>
#include <linux/kernel.h>
#include <linux/errno.h>
#include <linux/string.h>
#include <linux/types.h>
#include <linux/ptrace.h>
#include <linux/mman.h>
#include <linux/mm.h>
#include <linux/swap.h>
#include <linux/swapctl.h>
#ifdef CONFIG_BLK_DEV_INITRD
#include <linux/blk.h>
#endif
#include <linux/init.h>
#include <linux/highmem.h>
#include <linux/bootmem.h>

#include <asm/system.h>
#include <asm/segment.h>
#include <asm/page.h>
#include <asm/pgtable.h>

struct eth_desc_list
{
	struct eth_desc_list *next;
	int data;
};

#define S3_RAMTOP       0x70001000
#define SLOW_LIST_SIZE  (1024*128)
#define FAST_LIST_SIZE  (1024*4*2)
#define DESC_SIZE       (16)

static struct eth_desc_list *fast_eth_head, *slow_eth_head;
static unsigned long slow_eth_data[SLOW_LIST_SIZE];
static struct eth_desc_list fast_eth_l[FAST_LIST_SIZE/DESC_SIZE];
static struct eth_desc_list slow_eth_l[SLOW_LIST_SIZE/DESC_SIZE];
static int fast_eth_count,slow_eth_count;
unsigned long PAGE_NONCACHE_MARK __dc3data ____cacheline_aligned;

void init_eth_desc ( void )
{
	int i;
	struct eth_desc_list *head;
	head = NULL;
	slow_eth_count = SLOW_LIST_SIZE/DESC_SIZE;
	for( i = 0 ; i < slow_eth_count; i++ ) {
		slow_eth_l[i].data = (unsigned long)&slow_eth_data[i*DESC_SIZE];
		slow_eth_l[i].next = head;
		head = &slow_eth_l[i];
	}
	slow_eth_head = head;

	head = NULL;
	fast_eth_count = FAST_LIST_SIZE/DESC_SIZE;
	for( i = 0 ; i < fast_eth_count; i++) {
		fast_eth_l[i].data = i *DESC_SIZE+S3_RAMTOP;
		fast_eth_l[i].next = head;
		head = &fast_eth_l[i];
	}
	fast_eth_head = head;
}

unsigned long alloc_eth_desc ( void )
{
	unsigned long addr;
	if( fast_eth_count > 0 ) {
		addr = fast_eth_head->data;
		fast_eth_head = fast_eth_head->next;
		fast_eth_count--;
	}
	else if( slow_eth_count > 0 ) {
		addr = slow_eth_head->data;
		slow_eth_head = slow_eth_head->next;
		slow_eth_count--;
	}
	else
		panic("no enough descriptor memory\n");
	return addr;
}

void free_eth_desc(unsigned long addr)
{
	if( addr < 0x80000000 ) {
		addr = (addr - S3_RAMTOP)>>4;
		fast_eth_l[addr].next = fast_eth_head;
		fast_eth_head = &fast_eth_l[addr];
		fast_eth_count++;
	}
	else {
		addr = (addr - (unsigned long)(&slow_eth_data[0])) >>4;
		slow_eth_l[addr].next = slow_eth_head;
		slow_eth_head =  &slow_eth_l[addr];
		slow_eth_count++;
	}
}


struct pgtable_cache_struct pgt_quicklists;

/* References to section boundaries */
extern char __init_begin, __init_end, _start, _end, etext , edata;
unsigned long totalram_pages;

int do_check_pgt_cache(int low, int high)
{
	int freed = 0;
	if(pgtable_cache_size > high) {
		do {
			if (pgd_quicklist) {
				free_pgd_slow(get_pgd_fast());
				freed++;
			}
			if (pte_quicklist) {
				pte_free_slow(pte_alloc_one_fast(NULL, 0));
				freed++;
			}
		} while(pgtable_cache_size > low);
	}
	return freed;
}

void show_mem(void)
{
	printk("Mem-info:\n");
	show_free_areas();
	printk("Free swap:       %6dkB\n", nr_swap_pages << (PAGE_SHIFT-10));
	printk("%ld pages of RAM\n", totalram_pages);
	printk("%d free pages\n", nr_free_pages());
	printk("%ld pages in page table cache\n",pgtable_cache_size);
	printk("%ld entries in page dir cache\n",pgd_cache_size);
	show_buffers();
}


#define DEBUG_BOOTMEM

void __init paging_init(void)
{
	unsigned long zones_size[MAX_NR_ZONES] = {0, 0, 0};

	memset((void*)&swapper_pg_dir,0,PAGE_SIZE);

	zones_size[ZONE_DMA] = CONFIG_PADRE_NONCACHESIZE*4096;
	zones_size[ZONE_NORMAL] = max_low_pfn-zones_size[ZONE_DMA];
	free_area_init(zones_size);
}

void __init mem_init(void)
{
    int codesize, reservedpages, datasize, initsize;
    int tmp;

    if (!mem_map)
		BUG();
 
    max_mapnr = num_physpages = max_low_pfn;
	high_memory = (void *) __va(max_low_pfn * PAGE_SIZE);
	
    /* clear the zero-page */
	memset((void*)&empty_zero_page, 0, PAGE_SIZE);

    /* this will put all low memory onto the freelists */
    totalram_pages += free_all_bootmem();

    reservedpages = 0;
    for (tmp = 0; tmp < max_low_pfn; tmp++)
		if ( PageReserved(mem_map+tmp))
			reservedpages++;

    codesize =  (unsigned long) &etext - (unsigned long) &_start;
    datasize =  (unsigned long) &edata - (unsigned long) &etext;
    initsize =  (unsigned long) &__init_end - (unsigned long) &__init_begin;
 
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
    printk("Memory: %luk/%luk available (%dk kernel code, %dk reserved, %dk data, %dk init)\n",
		(unsigned long) nr_free_pages() << (PAGE_SHIFT-10),
		max_mapnr << (PAGE_SHIFT-10),
		codesize >> 10,
		reservedpages << (PAGE_SHIFT-10),
		datasize >> 10,
		initsize >> 10);
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
}

void free_initmem (void)
{
	unsigned long addr;

	addr = (unsigned long)(&__init_begin);
	for (; addr < (unsigned long)(&__init_end); addr += PAGE_SIZE) {
		struct page *p;
		p = virt_to_page(addr);
		ClearPageReserved(p);
		set_page_count(p, 1);
		__free_page(p);
		totalram_pages++;
		num_physpages++;
	}
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
	printk ("Freeing unused kernel memory: %dk freed\n", (&__init_end - &__init_begin) >> 10);
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
}

#ifdef CONFIG_BLK_DEV_INITRD
void free_initrd_mem(unsigned long start, unsigned long end)
{
	if (end < PAGE_OFFSET) return;
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
	if (start < end)
		printk ("Freeing initrd memory: %ldk freed\n", (end - start) >> 10);
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
	for (; start < end; start += PAGE_SIZE) {
		struct page *p = virt_to_page(start);

		ClearPageReserved(p);
		set_page_count(p, 1);
		__free_page(p);
		num_physpages++;
	}
}
#endif

void si_meminfo(struct sysinfo *val)
{
	val->totalram = totalram_pages;
	val->sharedram = 0;
	val->freeram = nr_free_pages();
	val->bufferram = atomic_read(&buffermem_pages);
	val->totalhigh = 0;
	val->freehigh = nr_free_highpages();
	val->mem_unit = PAGE_SIZE;
}
