/* $Id: head.h,v 1.39 2000/05/26 22:18:45 ecd Exp $ */
#ifndef __SPARC_HEAD_H
#define __SPARC_HEAD_H

#include <linux/version.h>
#include <linux/config.h>
#ifdef CONFIG_PADRE_P0
#include <asm/padre0.h>
#else
#include <asm/padre.h>
#endif

/*
#define PADRE_SYSCLOCK          12500000
 
#define PADRE_UART_9600         (PADRE_SYSCLOCK/76800-1)
#define PADRE_UART_9600_F       (PADRE_SYSCLOCK*2/76800-1)
*/

#define WRITE_PAUSE      nop; nop; nop; /* Have to do this after %wim/%psr chg */
#define NOP_INSN         0x01000000     /* Used to patch sparc_save_state */

/* Generic trap entry. */
#define TRAP_ENTRY(type, label) \
	rd %psr, %l0; b label; rd %wim, %l3; nop;

#if 0	
#define SPARC_IFAULT nop; nop; b sparc_ifault; rd %wim, %l3;
#define SPARC_DFAULT nop; nop; b sparc_dfault; rd %wim, %l3;
#else
#define SPARC_IFAULT rd %psr, %l0; b sparc_ifault; rd %wim, %l3; nop;
#define SPARC_DFAULT rd %psr, %l0; b sparc_dfault; rd %wim, %l3; nop;
#endif
	
/* This is for traps we should NEVER get. */
#define BAD_TRAP(num) \
        rd %psr, %l0; mov num, %l7; b bad_trap_handler; rd %wim, %l3;

/* This is for traps when we want just skip the instruction which caused it */
#define SKIP_TRAP(type, name) \
	jmpl %l2, %g0; rett %l2 + 4; nop; nop;

/* Notice that for the system calls we pull a trick.  We load up a
 * different pointer to the system call vector table in %l7, but call
 * the same generic system call low-level entry point.  The trap table
 * entry sequences are also HyperSparc pipeline friendly ;-)
 */

/* Software trap for Linux system calls. */
#define LINUX_SYSCALL_TRAP \
        sethi %hi(C_LABEL(sys_call_table)), %l7; \
        or %l7, %lo(C_LABEL(sys_call_table)), %l7; \
        b linux_sparc_syscall; \
        rd %psr, %l0;

#define BREAKPOINT_TRAP \
	b breakpoint_trap; \
	rd %psr,%l0; \
	nop; \
	nop;

/* The Get Condition Codes software trap for userland. */
#define GETCC_TRAP \
        b getcc_trap_handler; mov %psr, %l0; nop; nop;

/* The Set Condition Codes software trap for userland. */
#define SETCC_TRAP \
        b setcc_trap_handler; mov %psr, %l0; nop; nop;

/* The Get PSR software trap for userland. */
#define GETPSR_TRAP \
	mov %psr, %i0; jmp %l2; rett %l2 + 4; nop;

/* This is for hard interrupts from level 1-14, 15 is non-maskable (nmi) and
 * gets handled with another macro.
 */
#define TRAP_ENTRY_INTERRUPT(int_level) \
        mov int_level, %l7; rd %psr, %l0; b real_irq_entry; rd %wim, %l3;

#define TRAP_ENTRY_INTERRUPT_GMRX \
        rd %psr, %l0; b real_irq_entry_gmrx; rd %wim, %l3; nop;
#define TRAP_ENTRY_INTERRUPT_GMTX \
        rd %psr, %l0; b real_irq_entry_gmtx; rd %wim, %l3; nop;
/* NMI's (Non Maskable Interrupts) are special, you can't keep them
 * from coming in, and basically if you get one, the shows over. ;(
 * On the sun4c they are usually asynchronous memory errors, on the
 * the sun4m they could be either due to mem errors or a software
 * initiated interrupt from the prom/kern on an SMP box saying "I
 * command you to do CPU tricks, read your mailbox for more info."
 */
#define NMI_TRAP \
        rd %wim, %l3; b linux_trap_nmi; mov %psr, %l0; nop;

/* Window overflows/underflows are special and we need to try to be as
 * efficient as possible here....
 */
#define WINDOW_SPILL \
        rd %psr, %l0; rd %wim, %l3; b spill_window_entry; andcc %l0, PSR_PS, %g0;

#define WINDOW_FILL \
        rd %psr, %l0; rd %wim, %l3; b fill_window_entry; andcc %l0, PSR_PS, %g0;


#define LOCK(n)		while(readl(PADRE_S3_LOCK(n))
#define UNLOCK(n)	writel(0,PADRE_S3_UNLOCK(n))
		
#endif /* __SPARC_HEAD_H */
