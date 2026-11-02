/*
 * $Id: io.h,v 1.28 2000/09/17 05:12:00 davem Exp $
 */
#ifndef __SPARC_IO_H
#define __SPARC_IO_H

#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/ioport.h>  /* struct resource */

#include <asm/page.h>      /* IO address mapping routines need this */
#include <asm/system.h>

#define PADRE_DMA_BIDIRECTIONAL   0
#define PADRE_DMA_TODEVICE        1
#define PADRE_DMA_FROMDEVICE      2
#define PADRE_DMA_NONE            3

#define PHYS_BASE	0x40000000UL
#define virt_to_bus(addr)	((unsigned long)(addr) - PHYS_BASE)
#define bus_to_virt(addr)	((unsigned long)(addr) + PHYS_BASE)
#define page_to_phys(page)     ((((page) - mem_map) << PAGE_SHIFT)+PHYS_BASE)

static __inline__ u8 readb(unsigned long addr)
{
    return *(volatile u8 *)addr;
}
	
static __inline__ u16 readw(unsigned long addr)
{
    return *(volatile u16 *)addr;
}
	
static __inline__ unsigned long readl(unsigned long addr) 
{
	return *(volatile unsigned long*)addr;
}

static __inline__ void writeb(u8 b, unsigned long addr)
{
    *(volatile u8 *)addr = b;
}

static __inline__ void writew(u16 b, unsigned long addr)
{
	*(volatile u16 *)addr = b;
}

static __inline__ void writel(u32 b, unsigned long addr)
{
	*(volatile u32 *)addr = b;
}

#define __raw_readb readb
#define __raw_readw readw
#define __raw_readl readl
#define __raw_writeb writeb
#define __raw_writew writew
#define __raw_writel writel

/*
 * I/O space operations
 *
 * Arrangement on a Sun is somewhat complicated.
 *
 * First of all, we want to use standard Linux drivers
 * for keyboard, PC serial, etc. These drivers think
 * they access I/O space and use inb/outb.
 * On the other hand, EBus bridge accepts PCI *memory*
 * cycles and converts them into ISA *I/O* cycles.
 * Ergo, we want inb & outb to generate PCI memory cycles.
 *
 * If we want to issue PCI *I/O* cycles, we do this
 * with a low 64K fixed window in PCIC. This window gets
 * mapped somewhere into virtual kernel space and we
 * can use inb/outb again.
 */
#define inb_local(addr)     readb(addr)
#define inb(addr)       readb(addr)
#define inw(addr)       readw(addr)
#define inl(addr)       readl(addr)
#define inb_p(addr)     readb(addr)

#define outb_local(b, addr) writeb(b, addr)
#define outb(b, addr)       writeb(b, addr)
#define outw(b, addr)       writew(b, addr)
#define outl(b, addr)       writel(b, addr)
#define outb_p(b, addr)     writeb(b, addr)

extern void outsb(unsigned long addr, const void *src, unsigned long cnt);
extern void outsw(unsigned long addr, const void *src, unsigned long cnt);
extern void outsl(unsigned long addr, const void *src, unsigned long cnt);
extern void insb(unsigned long addr, void *dst, unsigned long count);
extern void insw(unsigned long addr, void *dst, unsigned long count);
extern void insl(unsigned long addr, void *dst, unsigned long count);

struct led_ctrl_func {
        void    (* do_power_led_ctrl)(int);
        void    (* do_misc_led_ctrl)(int led, int status);
        void    (* do_mount_led_ctrl)(int dev, int status);
        void    (* do_ata_led_wait)(int, int);
        void    (* do_ata_led)(int, int, int, int);
        void    (* do_ata_led_correct)(void);
};
extern struct led_ctrl_func padre_led_handler;

extern int i2c_device_exist(u8 dev_id);

extern void i2c_writeb(u8 dev_id,u8 data);
extern u8 i2c_readb(u8 dev_id);
extern void i2c_writew(u8 dev_id, u16 data);
extern u16 i2c_readw(u8 dev_id);

extern void i2c_writeb_idx(u8 dev_id, u8 idx, u8 data);
extern u8 i2c_readb_idx(u8 dev_id, u8 idx);
extern void i2c_writew_idx(u8 dev_id, u8 idx, u16 data);
extern u16 i2c_readw_idx(u8 dev_id, u8 idx);
extern u32 i2c_readl_idx(u8 dev_id, u8 idx);

extern void padre_ata_led(int ch, int on, int count, int type);
extern void padre_ate_let_correct(void);

#define IO_SPACE_LIMIT 0xffffffff

#ifdef __KERNEL__

#define ioremap(__offset,__size)	((void *)(__offset))
#define ioremap_nocache(X,Y)		ioremap((X),(Y))
#define iounmap(__addr)				do { } while(0)

#define virt_to_phys(x) __pa((unsigned long)(x))
#define phys_to_virt(x) __va((unsigned long)(x))

/*
 * At the moment, we do not use CMOS_READ anywhere outside of rtc.c,
 * so rtc_port is static in it. This should not change unless a new
 * hardware pops up.
 */
#define RTC_PORT(x)   (rtc_port + (x))
#define RTC_ALWAYS_BCD  0

/* Nothing to do */
/* P3: Only IDE DMA may need these. */

#define dma_cache_inv(_start,_size)		do { } while (0)
#define dma_cache_wback(_start,_size)		do { } while (0)
#define dma_cache_wback_inv(_start,_size)	do { } while (0)

#endif

#endif /* !(__SPARC_IO_H) */
