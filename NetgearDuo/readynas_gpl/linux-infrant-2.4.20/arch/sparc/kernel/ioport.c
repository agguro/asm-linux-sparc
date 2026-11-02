/* $Id: ioport.c,v 1.45 2001/10/30 04:54:21 davem Exp $
 * ioport.c:  Simple io mapping allocator.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 * Copyright (C) 1995 Miguel de Icaza (miguel@nuclecu.unam.mx)
 *
 * 1996: sparc_free_io, 1999: ioremap()/iounmap() by Pete Zaitcev.
 *
 * 2000/01/29
 * <rth> zait: as long as pci_alloc_consistent produces something addressable, 
 *	things are ok.
 * <zaitcev> rth: no, it is relevant, because get_free_pages returns you a
 *	pointer into the big page mapping
 * <rth> zait: so what?
 * <rth> zait: remap_it_my_way(virt_to_phys(get_free_page()))
 * <zaitcev> Hmm
 * <zaitcev> Suppose I did this remap_it_my_way(virt_to_phys(get_free_page())).
 *	So far so good.
 * <zaitcev> Now, driver calls pci_free_consistent(with result of
 *	remap_it_my_way()).
 * <zaitcev> How do you find the address to pass to free_pages()?
 * <rth> zait: walk the page tables?  It's only two or three level after all.
 * <rth> zait: you have to walk them anyway to remove the mapping.
 * <zaitcev> Hmm
 * <zaitcev> Sounds reasonable
 */

#include <linux/config.h>
#include <linux/sched.h>
#include <linux/kernel.h>
#include <linux/errno.h>
#include <linux/types.h>
#include <linux/ioport.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/pci.h>		/* struct pci_dev */
#include <linux/proc_fs.h>

#include <asm/io.h>
#include <asm/page.h>
#include <asm/pgalloc.h>
#include <asm/pgtable.h>
#include <linux/perf.h>

#define mmu_inval_dma_area(p, l)	/* Anton pulled it out for 2.4.0-xx */

#ifdef CONFIG_PCI

/* Allocate and map kernel buffer using consistent mode DMA for a device.
 * hwdev should be valid struct pci_dev pointer for PCI devices.
 */
void *pci_alloc_consistent(struct pci_dev *pdev, size_t len, dma_addr_t *pba)
{
	void *ret;
	int gfp = GFP_ATOMIC;

#if 0	
	if (pdev == NULL || pdev->dma_mask != 0xffffffff)
		gfp |= GFP_DMA;
#else
		gfp |= GFP_DMA;
#endif
	
    ret = (void *)__get_free_pages(gfp, get_order(len));
	
	if (ret != NULL) {
		memset(ret, 0, len);
		*pba = virt_to_bus(ret);
	}
	return ret;
}

/* Free and unmap a consistent DMA buffer.
 * cpu_addr is what was returned from pci_alloc_consistent,
 * size must be the same as what as passed into pci_alloc_consistent,
 * and likewise dma_addr must be the same as what *dma_addrp was set to.
 *
 * References to the memory and mappings assosciated with cpu_addr/dma_addr
 * past this call are illegal.
 */
void pci_free_consistent(struct pci_dev *pdev, size_t n, void *p, dma_addr_t ba)
{
	free_pages((unsigned long)p, get_order(n));
}

/* Map a single buffer of the indicated size for DMA in streaming mode.
 * The 32-bit bus address to use is returned.
 *
 * Once the device is given the dma address, the device owns this memory
 * until either pci_unmap_single or pci_dma_sync_single is performed.
 */
dma_addr_t pci_map_single(struct pci_dev *hwdev, void *ptr, size_t size,
    int direction)
{
	if (direction == PCI_DMA_NONE)
		BUG();
	/* IIep is write-through, not flushing. */
	perf_count(dflush_pci_map_single);
  flush_cache_dma(direction);
	return virt_to_bus(ptr);
}

/* Unmap a single streaming mode DMA translation.  The dma_addr and size
 * must match what was provided for in a previous pci_map_single call.  All
 * other usages are undefined.
 *
 * After this call, reads by the cpu to the buffer are guarenteed to see
 * whatever the device wrote there.
 */
void pci_unmap_single(struct pci_dev *hwdev, dma_addr_t ba, size_t size,
    int direction)
{
	if (direction == PCI_DMA_NONE)
		BUG();
	if (direction != PCI_DMA_TODEVICE) {
		mmu_inval_dma_area((unsigned long)bus_to_virt(ba),
		    (size + PAGE_SIZE-1) & PAGE_MASK);
	}
}

dma_addr_t pci_map_page(struct pci_dev *hwdev, struct page *page,
		                unsigned long offset, size_t size, int direction)
{
	if (direction == PCI_DMA_NONE)
		BUG();

	return virt_to_bus(page_address(page));
	
}


void  pci_unmap_page(struct pci_dev *hwdev, dma_addr_t dma_address,
		                          size_t size, int direction)
{
	if (direction == PCI_DMA_NONE)
		BUG();
}

/* Map a set of buffers described by scatterlist in streaming
 * mode for DMA.  This is the scather-gather version of the
 * above pci_map_single interface.  Here the scatter gather list
 * elements are each tagged with the appropriate dma address
 * and length.  They are obtained via sg_dma_{address,length}(SG).
 *
 * NOTE: An implementation may be able to use a smaller number of
 *       DMA address/length pairs than there are SG table elements.
 *       (for example via virtual mapping capabilities)
 *       The routine returns the number of addr/length pairs actually
 *       used, at most nents.
 *
 * Device ownership issues as mentioned above for pci_map_single are
 * the same here.
 */
int pci_map_sg(struct pci_dev *hwdev, struct scatterlist *sg, int nents,
    int direction)
{
	int n;

	if (direction == PCI_DMA_NONE)
		BUG();
	/* IIep is write-through, not flushing. */
	for (n = 0; n < nents; n++) {
		sg->dvma_address = virt_to_bus(sg->address);
		sg->dvma_length = sg->length;
		sg++;
	}
	return nents;
}

/* Unmap a set of streaming mode DMA translations.
 * Again, cpu read rules concerning calls here are the same as for
 * pci_unmap_single() above.
 */
void pci_unmap_sg(struct pci_dev *hwdev, struct scatterlist *sg, int nents,
    int direction)
{
	int n;

	if (direction == PCI_DMA_NONE)
		BUG();
	if (direction != PCI_DMA_TODEVICE) {
		for (n = 0; n < nents; n++) {
			mmu_inval_dma_area((unsigned long)sg->address,
			    (sg->length + PAGE_SIZE-1) & PAGE_MASK);
			sg++;
		}
	}
}

/* Make physical memory consistent for a single
 * streaming mode DMA translation before or after a transfer.
 *
 * If you perform a pci_map_single() but wish to interrogate the
 * buffer using the cpu, yet do not wish to teardown the PCI dma
 * mapping, you must call this function before doing so.  At the
 * next point you give the PCI dma address back to the card, the
 * device again owns the buffer.
 */
void pci_dma_sync_single(struct pci_dev *hwdev, dma_addr_t ba, size_t size, int direction)
{
	if (direction == PCI_DMA_NONE)
		BUG();
	if (direction != PCI_DMA_TODEVICE) {
		mmu_inval_dma_area((unsigned long)bus_to_virt(ba),
		    (size + PAGE_SIZE-1) & PAGE_MASK);
	}
	perf_count(dflush_pci_sync_single);
  flush_cache_dma(direction);
}

/* Make physical memory consistent for a set of streaming
 * mode DMA translations after a transfer.
 *
 * The same as pci_dma_sync_single but for a scatter-gather list,
 * same rules and usage.
 */
void pci_dma_sync_sg(struct pci_dev *hwdev, struct scatterlist *sg, int nents, int direction)
{
	int n;

	if (direction == PCI_DMA_NONE)
		BUG();
	if (direction != PCI_DMA_TODEVICE) {
		for (n = 0; n < nents; n++) {
			mmu_inval_dma_area((unsigned long)sg->address,
			    (sg->length + PAGE_SIZE-1) & PAGE_MASK);
			sg++;
		}
	}
	flush_cache_dma(direction);
}
#endif /* CONFIG_PCI */

#ifdef CONFIG_PROC_FS

static int
_sparc_io_get_info(char *buf, char **start, off_t fpos, int length, int *eof,
    void *data)
{
	char *p = buf, *e = buf + length;
	struct resource *r;
	const char *nm;

	for (r = ((struct resource *)data)->child; r != NULL; r = r->sibling) {
		if (p + 32 >= e)	/* Better than nothing */
			break;
		if ((nm = r->name) == 0) nm = "???";
		p += sprintf(p, "%08lx-%08lx: %s\n", r->start, r->end, nm);
	}

	return p-buf;
}

#endif /* CONFIG_PROC_FS */

/*
 * This is a version of find_resource and it belongs to kernel/resource.c.
 * Until we have agreement with Linus and Martin, it lingers here.
 *
 * XXX Too slow. Can have 8192 DVMA pages on sun4m in the worst case.
 * This probably warrants some sort of hashing.
 */
struct resource *
_sparc_find_resource(struct resource *root, unsigned long hit)
{
        struct resource *tmp;

	for (tmp = root->child; tmp != 0; tmp = tmp->sibling) {
		if (tmp->start <= hit && tmp->end >= hit)
			return tmp;
	}
	return NULL;
}

void register_proc_sparc_ioport(void)
{
#ifdef CONFIG_PROC_FS
//	create_proc_read_entry("io_map",0,0,_sparc_io_get_info,&sparc_iomap);
//	create_proc_read_entry("dvma_map",0,0,_sparc_io_get_info,&_sparc_dvma);
#endif
}
