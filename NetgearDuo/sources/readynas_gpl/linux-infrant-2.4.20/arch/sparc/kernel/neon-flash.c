/*
 * Flash memory access on Neon based devices
 * 
 */

#include <linux/config.h>
#include <linux/module.h>
#include <linux/types.h>
#include <linux/kernel.h>

#include <linux/mtd/mtd.h>
#include <linux/mtd/map.h>
#include <linux/mtd/partitions.h>

#ifdef CONFIG_PADRE_P0
#include <asm/padre0.h>
#else
#include <asm/padre.h>
#endif
#include <asm/io.h>


#ifndef CONFIG_PADRE
#error This is for PADRE architecture only
#endif


#define WINDOW_ADDR PADRE_ROM_SPACE

static __u8 neon_read8(struct map_info *map, unsigned long ofs)
{
	return *(volatile __u8*)(map->map_priv_1 + ofs);
}

static __u16 neon_read16(struct map_info *map, unsigned long ofs)
{
	return *(volatile __u16*)(map->map_priv_1 + ofs);
}

static __u32 neon_read32(struct map_info *map, unsigned long ofs)
{
	return *(volatile __u32*)(map->map_priv_1 + ofs);
}

static void neon_copy_from(struct map_info *map, void *to, unsigned long from, ssize_t len)
{
	memcpy(to, (void *)(map->map_priv_1 + from), len);
}

static void neon_write8(struct map_info *map, __u8 d, unsigned long adr)
{
	*(volatile __u8*)(map->map_priv_1 + adr) = d;
}

static void neon_write16(struct map_info *map, __u16 d, unsigned long adr)
{
	*(volatile __u16*)(map->map_priv_1 + adr) = d;
}

static void neon_write32(struct map_info *map, __u32 d, unsigned long adr)
{
	*(volatile __u32*)(map->map_priv_1 + adr) = d;
}

static void neon_copy_to(struct map_info *map, unsigned long to, const void *from, ssize_t len)
{
	memcpy((void *)(map->map_priv_1 + to), from, len);
}



static void neon_set_vpp(struct map_info *map, int vpp)
{
	__u32 set_vpp = vpp ? (PADRE_PCI_FLASH_OE_MRPn  | PADRE_PCI_FLASH_OE_MVPEN | 
						   PADRE_PCI_FLASH_DAT_MRPn | PADRE_PCI_FLASH_DAT_MVPEN ) :
						  (PADRE_PCI_FLASH_OE_MRPn  | PADRE_PCI_FLASH_OE_MVPEN |
					   	   PADRE_PCI_FLASH_DAT_MRPn);
	writel(set_vpp,PADRE_PCI_FLASH);
}


static struct map_info neon_map = {
	name:		"NEON flash",
	buswidth:	1,
	read8:		neon_read8,
	read16:		neon_read16,
	read32:		neon_read32,
	copy_from:	neon_copy_from,
	write8:		neon_write8,
	write16:	neon_write16,
	write32:	neon_write32,
	copy_to:	neon_copy_to,
	set_vpp:	neon_set_vpp,
	map_priv_1:	WINDOW_ADDR,
};


/*
 * Here are partition information for neon-based devices.
 * See include/linux/mtd/partitions.h for definition of the mtd_partition
 * structure.
 * 
 * The *_max_flash_size is the maximum possible mapped flash size which
 * is not necessarily the actual flash size.  It must correspond to the 
 * value specified in the mapping definition defined by the
 * "struct map_desc *_io_desc" for the corresponding machine.
 */

/* NEON has one 28F128J3A flash parts in bank 0: */
static unsigned long neon_max_flash_size = 0x01000000;
static struct mtd_partition neon_partitions[] = {
        {
                name: "bootloader",
                size: 0x00040000,
                offset: 0,
                mask_flags: MTD_WRITEABLE
        },
		{
                name: "free",
                size: MTDPART_SIZ_FULL,
                offset: MTDPART_OFS_APPEND,
                mask_flags: MTD_WRITEABLE
        }
};

#define NB_OF(x)  (sizeof(x)/sizeof(x[0]))


extern int parse_redboot_partitions(struct mtd_info *master, struct mtd_partition **pparts);
extern int parse_bootldr_partitions(struct mtd_info *master, struct mtd_partition **pparts);

static struct mtd_partition *parsed_parts;
static struct mtd_info *mymtd;

static int __init neon_mtd_init(void)
{
	struct mtd_partition *parts;
	int nb_parts = 0;
	int parsed_nr_parts = 0;
	char *part_type;
	
	/*
	 * Static partition definition selection
	 */
	/*
	part_type = "static";
	parts = neon_partitions;
	nb_parts = NB_OF(parts);
	*/
	neon_map.size = neon_max_flash_size;

	/*
	 * Now let's probe for the actual flash.  Do it here since
	 * specific machine settings might have been set above.
	 */
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
	printk(KERN_NOTICE "NEON flash: probing %d-bit flash bus\n", neon_map.buswidth*8);
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
	mymtd = do_map_probe("cfi_probe", &neon_map);
	if (!mymtd)
		mymtd = do_map_probe("atmel_flash",&neon_map);
	
	if (!mymtd)
		return -ENXIO;
	mymtd->module = THIS_MODULE;

	/*
	 * Dynamic partition selection stuff (might override the static ones)
	 */
#ifdef CONFIG_MTD_REDBOOT_PARTS
	if (parsed_nr_parts == 0) {
		int ret = parse_redboot_partitions(mymtd, &parsed_parts);
		
		if (ret > 0) {
			part_type = "RedBoot";
			parsed_nr_parts = ret;
		}
	}
#endif
#ifdef CONFIG_MTD_BOOTLDR_PARTS
	if (parsed_nr_parts == 0) {
		int ret = parse_bootldr_partitions(mymtd, &parsed_parts);
		if (ret > 0) {
			part_type = "Compaq bootldr";
			parsed_nr_parts = ret;
		}
	}
#endif

	if (parsed_nr_parts > 0) {
		parts = parsed_parts;
		nb_parts = parsed_nr_parts;
	}

	if (nb_parts == 0) {
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
		printk(KERN_NOTICE "NEON flash: no partition info available, registering whole flash at once\n");
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
		add_mtd_device(mymtd);
	} else {
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
		printk(KERN_NOTICE "Using %s partition definition\n", part_type);
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
		add_mtd_partitions(mymtd, parts, nb_parts);
	}
	return 0;
}

static void __exit neon_mtd_cleanup(void)
{
	if (mymtd) {
		del_mtd_partitions(mymtd);
		map_destroy(mymtd);
		if (parsed_parts)
			kfree(parsed_parts);
	}
}

module_init(neon_mtd_init);
module_exit(neon_mtd_cleanup);

MODULE_AUTHOR("Bin Zhang");
MODULE_DESCRIPTION("NEON CFI map driver");
MODULE_LICENSE("GPL");
