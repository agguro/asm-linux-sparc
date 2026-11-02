/* $Id: sparc_ksyms.c,v 1.107 2001/07/17 16:17:33 anton Exp $
 * arch/sparc/kernel/ksyms.c: Sparc specific ksyms support.
 *
 * Copyright (C) 1996 David S. Miller (davem@caip.rutgers.edu)
 * Copyright (C) 1996 Eddie C. Dost (ecd@skynet.be)
 */

/* Tell string.h we don't want memcpy etc. as cpp defines */
#define EXPORT_SYMTAB_STROPS
#define PROMLIB_INTERNAL

#include <linux/config.h>
#include <linux/module.h>
#include <linux/smp.h>
#include <linux/types.h>
#include <linux/string.h>
#include <linux/sched.h>
#include <linux/interrupt.h>
#include <linux/in6.h>
#include <linux/spinlock.h>
#include <linux/mm.h>
#include <linux/irq.h>
#ifdef CONFIG_PCI
#include <linux/pci.h>
#endif

#include <asm/delay.h>
#include <asm/system.h>
#include <asm/pgtable.h>
#include <asm/io.h>
#include <asm/irq.h>
#include <asm/svr4.h>
#include <asm/head.h>
#include <asm/smp.h>
#include <asm/ptrace.h>
#include <asm/softirq.h>
#include <asm/hardirq.h>
#include <asm/user.h>
#include <asm/uaccess.h>
#include <asm/checksum.h>
#include <asm/a.out.h>
#include <asm/padre_hw_io.h>

struct poll {
	int fd;
	short events;
	short revents;
};

extern int svr4_getcontext (svr4_ucontext_t *, struct pt_regs *);
extern int svr4_setcontext (svr4_ucontext_t *, struct pt_regs *);
void _sigpause_common (unsigned int set, struct pt_regs *);
extern void (*__copy_1page)(void *, const void *);
extern void __memmove(void *, const void *, __kernel_size_t);
extern void (*bzero_1page)(void *);
extern void *__bzero(void *, size_t);
extern void *__memscan_zero(void *, size_t);
extern void *__memscan_generic(void *, int, size_t);
extern int __memcmp(const void *, const void *, __kernel_size_t);
extern int __strncmp(const char *, const char *, __kernel_size_t);
extern char saved_command_line[];

extern void bcopy (const char *, char *, int);
extern int __ashrdi3(int, int);
extern int __ashldi3(int, int);
extern int __lshrdi3(int, int);
extern int __muldi3(int, int);
extern int __divdi3(int, int);

extern irq_desc_t irq_desc[NR_IRQS];


extern void dump_thread(struct pt_regs *, struct user *);

#ifdef CONFIG_SMP
extern spinlock_t kernel_flag;
#endif

/* One thing to note is that the way the symbols of the mul/div
 * support routines are named is a mess, they all start with
 * a '.' which makes it a bitch to export, here is the trick:
 */

#define EXPORT_SYMBOL_DOT(sym)					\
extern int __sparc_dot_ ## sym (int) __asm__("." #sym);		\
__EXPORT_SYMBOL(__sparc_dot_ ## sym, "." #sym)

#define EXPORT_SYMBOL_PRIVATE(sym)				\
extern int __sparc_priv_ ## sym (int) __asm__("__" #sym);	\
const struct module_symbol __export_priv_##sym			\
__attribute__((section("__ksymtab"))) =				\
{ (unsigned long) &__sparc_priv_ ## sym, "__" #sym }

/* used by various drivers */
//EXPORT_SYMBOL(sparc_cpu_model);
EXPORT_SYMBOL(kernel_thread);
#ifdef SPIN_LOCK_DEBUG
EXPORT_SYMBOL(_do_spin_lock);
EXPORT_SYMBOL(_do_spin_unlock);
EXPORT_SYMBOL(_spin_trylock);
EXPORT_SYMBOL(_do_read_lock);
EXPORT_SYMBOL(_do_read_unlock);
EXPORT_SYMBOL(_do_write_lock);
EXPORT_SYMBOL(_do_write_unlock);
#else
EXPORT_SYMBOL_PRIVATE(_rw_read_enter);
EXPORT_SYMBOL_PRIVATE(_rw_read_exit);
EXPORT_SYMBOL_PRIVATE(_rw_write_enter);
#endif
/* semaphores */
EXPORT_SYMBOL(__up);
EXPORT_SYMBOL(__down);
EXPORT_SYMBOL(__down_trylock);
EXPORT_SYMBOL(__down_interruptible);

/* Atomic operations. */
EXPORT_SYMBOL_PRIVATE(_atomic_add);
EXPORT_SYMBOL_PRIVATE(_atomic_sub);

/* Bit operations. */
EXPORT_SYMBOL_PRIVATE(_set_bit);
EXPORT_SYMBOL_PRIVATE(_clear_bit);
EXPORT_SYMBOL_PRIVATE(_change_bit);

#ifdef CONFIG_SMP
/* Kernel wide locking */
EXPORT_SYMBOL(kernel_flag);

/* IRQ implementation. */
EXPORT_SYMBOL(global_irq_holder);
EXPORT_SYMBOL(synchronize_irq);
EXPORT_SYMBOL(__global_cli);
EXPORT_SYMBOL(__global_sti);
EXPORT_SYMBOL(__global_save_flags);
EXPORT_SYMBOL(__global_restore_flags);

/* Misc SMP information */
EXPORT_SYMBOL(smp_num_cpus);
EXPORT_SYMBOL(__cpu_number_map);
EXPORT_SYMBOL(__cpu_logical_map);
#endif

EXPORT_SYMBOL(udelay);
#if CONFIG_SUN_AUXIO
EXPORT_SYMBOL(auxio_register);
#endif
//EXPORT_SYMBOL(io_remap_page_range);
  /* P3: iounit_xxx may be needed, sun4d users */
/* EXPORT_SYMBOL(iounit_map_dma_init); */
/* EXPORT_SYMBOL(iounit_map_dma_page); */

EXPORT_SYMBOL_NOVERS(___xchg32);
EXPORT_SYMBOL_NOVERS(enable_irq);
EXPORT_SYMBOL_NOVERS(disable_irq);

#if CONFIG_PCI
/* Actually, ioremap/iounmap are not PCI specific. But it is ok for drivers. */

EXPORT_SYMBOL(insl);
EXPORT_SYMBOL(outsl);
EXPORT_SYMBOL(pci_alloc_consistent);
EXPORT_SYMBOL(pci_free_consistent);
EXPORT_SYMBOL(pci_map_single);
EXPORT_SYMBOL(pci_unmap_single);
EXPORT_SYMBOL(pci_dma_sync_single);
#endif

/* Solaris/SunOS binary compatibility */
EXPORT_SYMBOL(svr4_setcontext);
EXPORT_SYMBOL(svr4_getcontext);
EXPORT_SYMBOL(_sigpause_common);

/* Should really be in linux/kernel/ksyms.c */
EXPORT_SYMBOL(dump_thread);

/* sparc library symbols */
EXPORT_SYMBOL(bcopy);
EXPORT_SYMBOL_NOVERS(memscan);
EXPORT_SYMBOL_NOVERS(strlen);
EXPORT_SYMBOL(strnlen);
EXPORT_SYMBOL(strcpy);
EXPORT_SYMBOL(strncpy);
EXPORT_SYMBOL(strcat);
EXPORT_SYMBOL(strncat);
EXPORT_SYMBOL(strcmp);
EXPORT_SYMBOL_NOVERS(strncmp);
EXPORT_SYMBOL(strchr);
EXPORT_SYMBOL(strrchr);
EXPORT_SYMBOL(strpbrk);
EXPORT_SYMBOL(strtok);
EXPORT_SYMBOL(strstr);

/* Special internal versions of library functions. */
EXPORT_SYMBOL(__copy_1page);
EXPORT_SYMBOL(__memcpy);
EXPORT_SYMBOL(__memset);
EXPORT_SYMBOL(bzero_1page);
EXPORT_SYMBOL(__bzero);
EXPORT_SYMBOL(__memscan_zero);
EXPORT_SYMBOL(__memscan_generic);
EXPORT_SYMBOL(__memcmp);
EXPORT_SYMBOL(__strncmp);
EXPORT_SYMBOL(__memmove);

/* Moving data to/from userspace. */
EXPORT_SYMBOL(__copy_user);
EXPORT_SYMBOL(__strncpy_from_user);

/* Networking helper routines. */
/* XXX This is NOVERS because C_LABEL_STR doesn't get the version number. -DaveM */
EXPORT_SYMBOL_NOVERS(__csum_partial_copy_sparc_generic);

/* No version information on this, heavily used in inline asm,
 * and will always be 'void __ret_efault(void)'.
 */
EXPORT_SYMBOL_NOVERS(__ret_efault);

/* No version information on these, as gcc produces such symbols. */
EXPORT_SYMBOL_NOVERS(memcmp);
EXPORT_SYMBOL_NOVERS(memcpy);
EXPORT_SYMBOL_NOVERS(memset);
EXPORT_SYMBOL_NOVERS(memmove);
EXPORT_SYMBOL_NOVERS(__ashrdi3);
EXPORT_SYMBOL_NOVERS(__ashldi3);
EXPORT_SYMBOL_NOVERS(__lshrdi3);
EXPORT_SYMBOL_NOVERS(__muldi3);
EXPORT_SYMBOL_NOVERS(__divdi3);

EXPORT_SYMBOL_DOT(rem);
EXPORT_SYMBOL_DOT(urem);
EXPORT_SYMBOL_DOT(mul);
EXPORT_SYMBOL_DOT(umul);
EXPORT_SYMBOL_DOT(div);
EXPORT_SYMBOL_DOT(udiv);

extern int padre_cachefix;
extern void flush_cache_dma(int);
extern void flush_dcache_range(unsigned long, unsigned long);
extern void init_eth_desc ( void );
extern unsigned long alloc_eth_desc ( void );
extern void free_eth_desc(unsigned long addr);	
extern unsigned int g_sys_type;
extern unsigned int g_sys_asicid;
extern void ics_get_freq(unsigned long *fcpu, unsigned long *fpci);
extern u32 __udivdi3(u64 a, u32 b);
extern unsigned long *register_padre_ecounter(char *name, unsigned long *counter);
extern int unregister_padre_ecounter(unsigned long *counter);
extern void LCD_display(unsigned char * info);

extern struct usb_ecounter usb_ec;

/* PADRE SYMBOLS */
EXPORT_SYMBOL(cpu_id);
EXPORT_SYMBOL(padre_boot_param);
EXPORT_SYMBOL(padre_cachefix);
EXPORT_SYMBOL(flush_cache_dma);
EXPORT_SYMBOL(flush_dcache_range);
EXPORT_SYMBOL(init_eth_desc);
EXPORT_SYMBOL(alloc_eth_desc);
EXPORT_SYMBOL(free_eth_desc);
EXPORT_SYMBOL(PAGE_NONCACHE_MARK);
EXPORT_SYMBOL(padre_led_handler);
EXPORT_SYMBOL(g_sys_type);
EXPORT_SYMBOL(g_sys_asicid);
EXPORT_SYMBOL(__udivdi3);
EXPORT_SYMBOL(padre_NSPIO);
EXPORT_SYMBOL(irq_desc);
EXPORT_SYMBOL(register_padre_ecounter);
EXPORT_SYMBOL(unregister_padre_ecounter);
EXPORT_SYMBOL(usb_ec);
EXPORT_SYMBOL(LCD_display);

extern rwlock_t xtime_lock;
EXPORT_SYMBOL(xtime_lock);

extern unsigned long ec_tcp_retrans;
extern unsigned long ec_tcp_retrans_unrecover;
EXPORT_SYMBOL(ec_tcp_retrans);
EXPORT_SYMBOL(ec_tcp_retrans_unrecover);

