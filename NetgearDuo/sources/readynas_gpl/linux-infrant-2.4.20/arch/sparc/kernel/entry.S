/* $Id: entry.S,v 1.169 2001/01/25 21:47:20 davem Exp $
 * arch/sparc/kernel/entry.S:  Sparc trap low-level entry points.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 * Copyright (C) 1996 Eddie C. Dost   (ecd@skynet.be)
 * Copyright (C) 1996 Miguel de Icaza (miguel@nuclecu.unam.mx)
 * Copyright (C) 1996-1999 Jakub Jelinek   (jj@sunsite.mff.cuni.cz)
 * Copyright (C) 1997 Anton Blanchard (anton@progsoc.uts.edu.au)
 */

#include <linux/config.h>
#include <linux/errno.h>

#include <asm/head.h>
#include <asm/smp.h>
#include <asm/kgdb.h>
#include <asm/ptrace.h>
#include <asm/psr.h>
#include <asm/cprefix.h>
#include <asm/page.h>
#include <asm/winmacro.h>
#include <asm/signal.h>

#include <asm/asmmacro.h>

//#define DEBUG_IRAM
#define curptr      g6

#define NR_SYSCALLS 256      /* Each OS is different... */

#define MYSGMT .section .ic3.init,"ax",@progbits

/* First, KGDB low level things.  This is a rewrite
 * of the routines found in the sparc-stub.c asm() statement
 * from the gdb distribution.  This is also dual-purpose
 * as a software trap for userlevel programs.
 */
	!.data
	.section .dc3.init,"aw",@progbits
	.align	4

in_trap_handler:
	.word	0

	MYSGMT
	.align	4

! This function is called when any SPARC trap (except window overflow or
! underflow) occurs.  It makes sure that the invalid register window is still
! available before jumping into C code.  It will also restore the world if you
! return from handle_exception.

	.globl	C_LABEL(trap_low)
C_LABEL(trap_low):
	rd	%wim, %l3
	SAVE_ALL

	sethi	%hi(in_trap_handler), %l4
	ld	[%lo(in_trap_handler) + %l4], %l5
	inc	%l5
	st	%l5, [%lo(in_trap_handler) + %l4]

	/* Make sure kgdb sees the same state we just saved. */
	LOAD_PT_GLOBALS(sp)
	LOAD_PT_INS(sp)
	ld	[%sp + REGWIN_SZ + PT_Y], %l4
	ld	[%sp + REGWIN_SZ + PT_WIM], %l3
	ld	[%sp + REGWIN_SZ + PT_PSR], %l0
	ld	[%sp + REGWIN_SZ + PT_PC], %l1
	ld	[%sp + REGWIN_SZ + PT_NPC], %l2
	rd	%tbr, %l5	/* Never changes... */

	/* Make kgdb exception frame. */	
	sub	%sp,(16+1+6+1+72)*4,%sp	! Make room for input & locals
 					! + hidden arg + arg spill
					! + doubleword alignment
					! + registers[72] local var
	SAVE_KGDB_GLOBALS(sp)
	SAVE_KGDB_INS(sp)
	SAVE_KGDB_SREGS(sp, l4, l0, l3, l5, l1, l2)

	/* We are increasing PIL, so two writes. */
	or	%l0, PSR_PIL, %l0
	wr	%l0, 0, %psr
	WRITE_PAUSE
	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	call	C_LABEL(handle_exception)
	 add	%sp, REGWIN_SZ, %o0	! Pass address of registers

	/* Load new kgdb register set. */
	LOAD_KGDB_GLOBALS(sp)
	LOAD_KGDB_INS(sp)
	LOAD_KGDB_SREGS(sp, l4, l0, l3, l5, l1, l2)
	wr      %l4, 0x0, %y

	sethi	%hi(in_trap_handler), %l4
	ld	[%lo(in_trap_handler) + %l4], %l5
	dec	%l5
	st	%l5, [%lo(in_trap_handler) + %l4]

	add	%sp,(16+1+6+1+72)*4,%sp	! Undo the kgdb trap frame.

	/* Now take what kgdb did and place it into the pt_regs
	 * frame which SparcLinux RESTORE_ALL understands.,
	 */
	STORE_PT_INS(sp)
	STORE_PT_GLOBALS(sp)
	STORE_PT_YREG(sp, g2)
	STORE_PT_PRIV(sp, l0, l1, l2)

	RESTORE_ALL

	/* Bad trap handler */
	.globl	bad_trap_handler
bad_trap_handler:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	mov	%l7, %o0		! trap number
	mov	%l0, %o1		! psr
	call	C_LABEL(do_hw_interrupt)
	 mov	%l1, %o2		! pc

	RESTORE_ALL
	
/* For now all IRQ's not registered get sent here. handler_irq() will
 * see if a routine is registered to handle this interrupt and if not
 * it will say so on the console.
 */

	.text
	.align	4
	.globl	real_irq_entry
real_irq_entry:
	SAVE_ALL

	or	%l0, PSR_PIL, %g2
	wr	%g2, 0x0, %psr
	WRITE_PAUSE
	wr	%g2, PSR_ET, %psr
	WRITE_PAUSE
	mov	%l7, %o0		! irq level

	call 	C_LABEL(do_IRQ)
	 add	%sp, REGWIN_SZ, %o1	! pt_regs ptr
	or	%l0, PSR_PIL, %g2	! restore PIL after handler_irq
	wr	%g2, PSR_ET, %psr	! keep ET up
	WRITE_PAUSE

	RESTORE_ALL
	
	.text
	.align	4
	.globl  real_irq_entry_gmrx
real_irq_entry_gmrx:
	set cached_irq_mask_l, %l4
	ld  [%l4], %l5
	sethi %hi(0x40000000), %l7
	andn %l5, %l7, %l5
	st  %l5, [%l4]
	set PADRE_INTC0_MASK_L, %l4
	st  %l5, [%l4]
	set 3, %l7

	SAVE_ALL

	or	%l0, PSR_PIL, %g2
	wr	%g2, 0x0, %psr
	WRITE_PAUSE
	wr	%g2, PSR_ET, %psr
	WRITE_PAUSE
	mov	%l7, %o0		! irq level

	call 	C_LABEL(do_IRQ)
	 add	%sp, REGWIN_SZ, %o1	! pt_regs ptr
	or	%l0, PSR_PIL, %g2	! restore PIL after handler_irq
	wr	%g2, PSR_ET, %psr	! keep ET up
	WRITE_PAUSE

	RESTORE_ALL

	.text
	.align	4
	.globl  real_irq_entry_gmtx
real_irq_entry_gmtx:
	set cached_irq_mask_l, %l4
	ld  [%l4], %l5
	sethi %hi(0x80000000), %l7
	andn %l5, %l7, %l5
	st  %l5, [%l4]
	set PADRE_INTC0_MASK_L, %l4
	st  %l5, [%l4]
	set 4, %l7

	SAVE_ALL

	or	%l0, PSR_PIL, %g2
	wr	%g2, 0x0, %psr
	WRITE_PAUSE
	wr	%g2, PSR_ET, %psr
	WRITE_PAUSE
	mov	%l7, %o0		! irq level

	call 	C_LABEL(do_IRQ)
	 add	%sp, REGWIN_SZ, %o1	! pt_regs ptr
	or	%l0, PSR_PIL, %g2	! restore PIL after handler_irq
	wr	%g2, PSR_ET, %psr	! keep ET up
	WRITE_PAUSE

	RESTORE_ALL

	/* This routine handles illegal instructions and privileged
	 * instruction attempts from user code.
	 */
/* #define DEBUG_PROBE */


	.text
	.align	4
	.globl	bad_instruction
bad_instruction:
    sethi   %hi(0xc1f80000), %l4
    ld  [%l1], %l5
    sethi   %hi(0x81d80000), %l7
    and %l5, %l4, %l6
    cmp %l6, %l7
    be  1f
#ifdef DEBUG_IRAM
	 nop
	set PADRE_ICMU_CTRL, %l4
	lda [%l4]ASI_ICMU, %l5
	andn %l5, 0x5, %l5
	sta %l5, [%l4]ASI_ICMU
	nop; nop; nop
	or %l5, 0x2, %l5
	sta %l5, [%l4]ASI_ICMU
	nop; nop; nop
	set PADRE_ICMU_IRD, %l4
	set 0x3fff, %l6
	and %l1, %l6, %l6
	add %l4, %l6, %l4
	lda [%l4]ASI_ICMU, %l6
	lda [%l4]ASI_ICMU, %l6
	nop	
	SAVE_ALL
#else
    SAVE_ALL
#endif

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(do_illegal_instruction)
	 mov	%l0, %o3

	RESTORE_ALL
1:
	set tmp_register, %l7
	srl %l5, 13, %l4
	btst 0x1, %l4
	be	5f		! check immed bit
	 srl %l5,14, %l4
	and %l4, 0x1f, %l4	! extract rs1 field
	sll %l5, 19, %l5
	sra	%l5, 19, %l6	! extract simm13 field
	cmp %l4, 16
	blu 1f
	 or %l1, 1, %l1
	b 2f
	 nop

	!! rs1+rs2
5:
	and %l4, 0x1f, %l4	! extract rs1
	and %l5, 0x1f, %l6	! extract rs2

	cmp %l4, 16
	blu 4f
	 cmp %l6, 16
	blu 3f
	 nop
	b 2f
	 nop

4:	!! rs1+rs2  rs1=r0-r15  rs2=?
	blu 1f
	 nop
	b 3f
	 nop

	!! rs1+simm13  rs1=r0-r15 (g0-g7,o0-o7)
	!! rs1+rs2  rs1=r0-r15  rs2=r0-r15
1:
	std %g0, [%l7]		! save r0-r7(g0-g7), r24-r31(i0-i7)
	std %g2, [%l7+8]
	std %g4, [%l7+16]
	std %g6, [%l7+24]
	std %i0, [%l7+32]
	std %i2, [%l7+40]
	std %i4, [%l7+48]
	std %i6, [%l7+56]
	b flush_now
	 nop

2:	!! rs1+rs2  rs1=r16-r31 (l0-l7,i0-i7)
	wr %g0, 0x0 , %wim
	mov %g1, %l5
	mov %l7, %g1
	restore 
	std %l0, [%g1+64]
	std %l2, [%g1+72]
	std %l4, [%g1+80]
	std %l6, [%g1+88]
	std %i0, [%g1+96]
	std %i2, [%g1+104]
	std %i4, [%g1+112]
	std %i6, [%g1+120]
	save
	wr %l3, 0x0, %wim
	b flush_now
	 mov %l5, %g1
	
3:	!! rs1+rs2  rs1=r0-r15 (g0-g7,o0-o7), rs2=r16-r31 (l0-l7,i0-i7)
	std %g0, [%l7]
	std %g2, [%l7+8]
	std %g4, [%l7+16]
	std %g6, [%l7+24]
	std %i0, [%l7+32]
	std %i2, [%l7+40]
	std %i4, [%l7+48]
	std %i6, [%l7+56]

	wr %g0, 0x0 , %wim
	mov %g1, %l5
	mov %l7, %g1
	restore 
	std %l0, [%g1+64]
	std %l2, [%g1+72]
	std %l4, [%g1+80]
	std %l6, [%g1+88]
	std %i0, [%g1+96]
	std %i2, [%g1+104]
	std %i4, [%g1+112]
	std %i6, [%g1+120]
	save
	wr %l3, 0x0, %wim
	b flush_now
	 mov %l5, %g1

flush_now:
	!! %l1 ... immd flag (bit0 only) =(instr>>13)&1
	!! %l4 ... rs1 field
	!! %l6 ... rs2 field or sext(simmd13)
	btst 1, %l1
	bne 1f
	 sll %l4, 2, %l4
	sll %l6, 2, %l6
	ld  [%l7 + %l6], %l6
1:
	ld  [%l7 + %l4], %l4
	add %l4, %l6, %l4
	/* and %l4, 0xff0, %l4 */

#ifdef CONFIG_PADRE_DCACHE_WB
#ifdef CONFIG_PADRE_DCACHE_PROBE
    andn %l4, 0xf, %l4
    set PADRE_DCMU_CTRL, %l5
    lda [%l5]ASI_DCMU, %l6
    or %l6, PADRE_DCMU_CTRL_PROBE__CLEAN << 4, %l6
    sta %l6, [%l5]ASI_DCMU
    ld [%l4], %g0
    andn %l6, 0x3 << 4, %l6
    sta %l6, [%l5]ASI_DCMU
    and %l4, 0xff0, %l4
#else
#ifdef DEBUG_PROBE
	/* save virtual address on 0x70000004 */
	set 0x70000000, %l5
	st %l4, [%l5 + 4]
	/* save current_pdg to %l7 */
	set current_pgd, %l7
	ld [%l7], %l7
	st %l7, [%l5+8]

	/* clean the dcache using hardware */
    andn %l4, 0xf, %l3
    set PADRE_DCMU_CTRL, %l5
    lda [%l5]ASI_DCMU, %l6
    or %l6, PADRE_DCMU_CTRL_PROBE__CLEAN << 4, %l6
    sta %l6, [%l5]ASI_DCMU
    ld [%l3], %g0
    andn %l6, 0x3 << 4, %l6
    sta %l6, [%l5]ASI_DCMU

	/* calculate physical address from virtual address */
	srl %l4, 22, %l3
	and %l3, 0x3ff, %l3
	sll %l3, 2, %l3
	set current_pgd, %l5
	ld [%l5], %l5

	/* compare value for current_pgd */
	cmp %l5, %l7
probe_bug:
	bne probe_bug
	 nop
	add %l5, %l3, %l3
	ld [%l3], %l3
	andn %l3, 0xfff, %l3
	sethi %hi(0x40000000), %l5
	add %l3, %l5, %l3
	srl %l4, 12, %l6
	and %l6, 0x3ff, %l6
	sll %l6, 2, %l6
	add %l3, %l6, %l3
	ld [%l3], %l3
	andn %l3, 0xfff, %l3
	set 0x70000000, %l5
	st %l3, [%l5]
#endif

    and %l4, 0xff0, %l4
	set PADRE_DCMU_CTRL, %l5
	set PADRE_DCMU_CTRL_TM, %l6
	sethi %hi(PADRE_S3_RAMTOP), %l7
	sta %g0, [%l5]ASI_DCMU
	 nop;nop; ld [%l7], %g0
	sta %l6, [%l5]ASI_DCMU
	 nop;nop; ld [%l7], %g0
	set PADRE_DCMU_DTAG, %l7
	set 0x1000, %l6
	set 0x5, %l3

1:
	deccc 1, %l3
	be 2f
	 nop
	lda [%l7+%l4]ASI_DCMU, %l1
	lda [%l7+%l4]ASI_DCMU, %l1

	and %l1, 0x3, %l5
	cmp %l5, 0x3
	bne,a 1b
	 add %l7, %l6, %l7
#ifdef DEBUG_RPOBE
	bclr 0xfff, %l1
	set 0x70000000, %l5
	ld [%l5], %l5
	cmp %l5, %l1
	or %l1, 1, %l1
	bne,a 1b
	 add %l7, %l6, %l7
#endif

	andn %l1, 0x2, %l1
	sta %l1, [%l7+%l4]ASI_DCMU
	set	PADRE_DCMU_DTAG, %l5
	sub %l7, %l5, %l5
	add %l7, %l6, %l7

	bclr 0xfff, %l1
	add %l1, %l4, %l1
	sethi %hi(0x40000000), %l0
	add %l1, %l0, %l1
	lda [%l5+%l4]ASI_DCMU, %l0		! pipeline first
	add %l5, 4, %l5
	lda [%l5+%l4]ASI_DCMU, %l0
	st	%l0, [%l1+0x0]
	add %l5, 4, %l5
	lda [%l5+%l4]ASI_DCMU, %l0
	st	%l0, [%l1+0x4]
	add %l5, 4, %l5
	lda [%l5+%l4]ASI_DCMU, %l0
	st	%l0, [%l1+0x8]
	lda [%l5+%l4]ASI_DCMU, %l0
	b 1b
	 st	%l0, [%l1+0xc]

2:
	set PADRE_DCMU_CTRL, %l5

	sethi %hi(dcmu_ctrl), %l7
	ld [%l7+%lo(dcmu_ctrl)], %l6
	! set PADRE_DCMU_CTRL_EN, %l6

	sethi %hi(PADRE_S3_RAMTOP), %l7
	sta %g0, [%l5]ASI_DCMU
	 nop;nop; ld [%l7], %g0
	sta %l6, [%l5]ASI_DCMU
	 nop;nop; ld [%l7], %g0
#endif
#else
    and %l4, 0xff0, %l4
#endif

#ifdef CONFIG_PADRE_ICACHE
#ifdef DEBUG_IRAM
    .macro nop16
    nop;nop;nop;nop; nop;nop;nop;nop; nop;nop;nop;nop; nop;nop;nop;nop;
    .endm\n
    .macro nop256
    nop16;nop16;nop16;nop16;nop16;nop16;nop16;nop16;
    nop16;nop16;nop16;nop16;nop16;nop16;nop16;nop16;
    .endm
    .macro nop4096
    nop256;nop256;nop256;nop256;
    nop256;nop256;nop256;nop256;
    nop256;nop256;nop256;nop256;
    nop256;nop256;nop256;nop256;
    .endm
    nop4096
    nop4096
    nop4096
    nop4096
#else
	set PADRE_ICMU_ITAG, %l7
	set PADRE_ICMU_CTRL, %l5
	set PADRE_ICMU_CTRL_TM, %l6
	sta %g0, [%l5]ASI_ICMU
	 nop; nop; nop
	sta %l6, [%l5]ASI_ICMU
	 nop; nop; nop
	set 0x1000, %l6
	sta %g0, [%l7+%l4]ASI_ICMU
	add %l7, %l6, %l7
	sta %g0, [%l7+%l4]ASI_ICMU
	add %l7, %l6, %l7
	sta %g0, [%l7+%l4]ASI_ICMU
	add %l7, %l6, %l7
	sta %g0, [%l7+%l4]ASI_ICMU

	sethi %hi(icmu_ctrl), %l7
	ld [%l7+%lo(icmu_ctrl)], %l6
	! set PADRE_ICMU_CTRL_EN, %l6
	sta %g0, [%l5]ASI_ICMU
	 nop; nop; nop
	sta %l6, [%l5]ASI_ICMU
	 nop; nop; nop
#endif
#endif
	

	jmpl	%l2, %g0
	 rett	%l2 + 4

	.text
	.align	4
	.globl	priv_instruction
priv_instruction:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(do_priv_instruction)
	 mov	%l0, %o3

	RESTORE_ALL

	/* This routine handles unaligned data accesses. */
	.text
	.align	4
	.globl	mna_handler
mna_handler:
	andcc	%l0, PSR_PS, %g0
	be	mna_fromuser
	 nop

	SAVE_ALL

	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	ld	[%l1], %o1
	call	C_LABEL(kernel_unaligned_trap)
	 add	%sp, REGWIN_SZ, %o0

	RESTORE_ALL

mna_fromuser:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	ld	[%l1], %o1
	call	C_LABEL(user_unaligned_trap)
	 add	%sp, REGWIN_SZ, %o0

	RESTORE_ALL

	/* This routine handles floating point disabled traps. */
	.text
	.align	4
	.globl	fpd_trap_handler
fpd_trap_handler:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(do_fpd_trap)
	 mov	%l0, %o3

	RESTORE_ALL

	/* This routine handles Tag Overflow Exceptions. */
	.text
	.align	4
	.globl	do_tag_overflow
do_tag_overflow:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(handle_tag_overflow)
	 mov	%l0, %o3

	RESTORE_ALL

	/* This routine handles Watchpoint Exceptions. */
	.text
	.align	4
	.globl	do_watchpoint
do_watchpoint:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(handle_watchpoint)
	 mov	%l0, %o3

	RESTORE_ALL

	/* This routine handles Co-Processor Disabled Exceptions. */
	.text
	.align	4
	.globl	do_cp_disabled
do_cp_disabled:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(handle_cp_disabled)
	 mov	%l0, %o3

	RESTORE_ALL

	/* This routine handles Hardware Divide By Zero Exceptions. */
	.text
	.align	4
	.globl	do_hw_divzero
do_hw_divzero:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr		! re-enable traps
	WRITE_PAUSE

	add	%sp, REGWIN_SZ, %o0
	mov	%l1, %o1
	mov	%l2, %o2
	call	C_LABEL(handle_hw_divzero)
	 mov	%l0, %o3

	RESTORE_ALL

	MYSGMT
	.align	4
	.globl	do_flush_windows
do_flush_windows:
	SAVE_ALL

	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	andcc	%l0, PSR_PS, %g0
	bne	dfw_kernel
	 nop

	call	C_LABEL(flush_user_windows)
	 nop

	/* Advance over the trap instruction. */
	ld	[%sp + REGWIN_SZ + PT_NPC], %l1
	add	%l1, 0x4, %l2
	st	%l1, [%sp + REGWIN_SZ + PT_PC]
	st	%l2, [%sp + REGWIN_SZ + PT_NPC]

	RESTORE_ALL

	/* We get these for debugging routines using __builtin_return_address() */
dfw_kernel:
	FLUSH_ALL_KERNEL_WINDOWS

	/* Advance over the trap instruction. */
	ld	[%sp + REGWIN_SZ + PT_NPC], %l1
	add	%l1, 0x4, %l2
	st	%l1, [%sp + REGWIN_SZ + PT_PC]
	st	%l2, [%sp + REGWIN_SZ + PT_NPC]

	RESTORE_ALL

	/* The getcc software trap.  The user wants the condition codes from
	 * the %psr in register %g1.
	 */

	.text
	.align	4
	.globl	getcc_trap_handler
getcc_trap_handler:
	srl	%l0, 20, %g1	! give user
	and	%g1, 0xf, %g1	! only ICC bits in %psr
	jmp	%l2		! advance over trap instruction
	rett	%l2 + 0x4	! like this...

	/* The setcc software trap.  The user has condition codes in %g1
	 * that it would like placed in the %psr.  Be careful not to flip
	 * any unintentional bits!
	 */

	.text
	.align	4
	.globl	setcc_trap_handler
setcc_trap_handler:
	sll	%g1, 0x14, %l4
	set	PSR_ICC, %l5
	andn	%l0, %l5, %l0	! clear ICC bits in %psr
	and	%l4, %l5, %l4	! clear non-ICC bits in user value
	or	%l4, %l0, %l4	! or them in... mix mix mix

	wr	%l4, 0x0, %psr	! set new %psr
	WRITE_PAUSE		! TI scumbags...

	jmp	%l2		! advance over trap instruction
	rett	%l2 + 0x4	! like this...

	MYSGMT
	.align	4
	.globl  sparc_dfault

! %l0 = %psr
! %l1 = %pc
! %l2 = %npc
! %l3 = %wim
sparc_dfault:
	set PADRE_MMU_DFSR, %l4
	lda [%l4]ASI_MMU, %l5
	set PADRE_MMU_DFADDR, %l4
	lda [%l4]ASI_MMU, %l6
	andn %l6, 0xfff, %l6
	srl %l5, 8, %l5
	and %l5, 0x1f, %l5
	or %l6, %l5, %l7

#if 0
    set 0xa5000, %l4
    cmp %l6, %l4
    bne dfault_save_all
     cmp %l5, 0x12
    bne dfault_save_all
     sethi %hi(current_pgd), %l4
    or %l4, %lo(current_pgd), %l4
    ld [%l4], %l5
    andn %l5, 0xfff, %l5
    ld [%l5], %l5
    andn %l5, 0xfff, %l5
    sethi %hi(0x40000000), %l6
    add %l5, %l6, %l5
    ld [%l5+0x294], %l4

    and %l4, 0x3cd, %l4
    cmp %l4, 0x3cd
    bne dfault_save_all
     nop

    set 0xf11f, %l7


dfault_save_all:
#endif
	
	SAVE_ALL

	and %l7, 0x1f, %o1
	andn %l7, 0x1f, %o2

	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	call	C_LABEL(do_sparc_fault)
	 add	%sp, REGWIN_SZ, %o0	! arg1 = pt_regs ptr

	RESTORE_ALL

	MYSGMT
	.align	4
	.globl  sparc_ifault

! %l0 = %psr
! %l1 = %pc
! %l2 = %npc
! %l3 = %wim
sparc_ifault:
	set PADRE_MMU_IFSR, %l4
	lda [%l4]ASI_MMU, %l7
	srl %l7, 8, %l7
	and %l7, 0x1f, %l7
	SAVE_ALL

	mov %l7, %o1
	mov %l1, %o2
#ifdef CONFIG_PADRE_BUG179
	or %o1, 0x100, %o1
#endif

	wr	%l0, PSR_ET, %psr
	WRITE_PAUSE

	call	C_LABEL(do_sparc_fault)
	 add	%sp, REGWIN_SZ, %o0	! arg1 = pt_regs ptr

	RESTORE_ALL

	.text
	.align	4
	.globl	C_LABEL(sys_nis_syscall)
C_LABEL(sys_nis_syscall):
	mov	%o7, %l5
	add	%sp, REGWIN_SZ, %o0		! pt_regs *regs arg
	call	C_LABEL(c_sys_nis_syscall)
	 mov	%l5, %o7

	.text
	.align 4
	.globl	C_LABEL(sys_ptrace)
C_LABEL(sys_ptrace):
	call	C_LABEL(do_ptrace)
	 add	%sp, REGWIN_SZ, %o0

	ld	[%curptr + AOFF_task_ptrace], %l5
	andcc	%l5, 0x02, %g0
	be	1f
	 nop

	call	C_LABEL(syscall_trace)
	 nop

1:
	RESTORE_ALL

	MYSGMT
	.align	4
	.globl	C_LABEL(sys_execve)
C_LABEL(sys_execve):
	mov	%o7, %l5
	add	%sp, REGWIN_SZ, %o0		! pt_regs *regs arg
	call	C_LABEL(sparc_execve)
	 mov	%l5, %o7

	MYSGMT
	.align	4
	.globl	C_LABEL(sys_pipe)
C_LABEL(sys_pipe):
	mov	%o7, %l5
	add	%sp, REGWIN_SZ, %o0		! pt_regs *regs arg
	call	C_LABEL(sparc_pipe)
	 mov	%l5, %o7

	.text
	.align	4
	.globl	C_LABEL(sys_sigaltstack)
C_LABEL(sys_sigaltstack):
	mov	%o7, %l5
	mov	%fp, %o2
	call	C_LABEL(do_sigaltstack)
	 mov	%l5, %o7

	.text
	.align	4
	.globl	C_LABEL(sys_sigstack)
C_LABEL(sys_sigstack):
	mov	%o7, %l5
	mov	%fp, %o2
	call	C_LABEL(do_sys_sigstack)
	 mov	%l5, %o7

	.text
	.align	4
	.globl	C_LABEL(sys_sigpause)
C_LABEL(sys_sigpause):
	/* Note: %o0 already has correct value... */
	call	C_LABEL(do_sigpause)
	 add	%sp, REGWIN_SZ, %o1

	ld	[%curptr + AOFF_task_ptrace], %l5
	andcc	%l5, 0x02, %g0
	be	1f
	 nop

	call	C_LABEL(syscall_trace)
	 nop

1:
	/* We are returning to a signal handler. */
	RESTORE_ALL

	.text
	.align	4
	.globl	C_LABEL(sys_sigsuspend)
C_LABEL(sys_sigsuspend):
	call	C_LABEL(do_sigsuspend)
	 add	%sp, REGWIN_SZ, %o0

	ld	[%curptr + AOFF_task_ptrace], %l5
	andcc	%l5, 0x02, %g0
	be	1f
	 nop

	call	C_LABEL(syscall_trace)
	 nop

1:
	/* We are returning to a signal handler. */
	RESTORE_ALL

	.text
	.align	4
	.globl	C_LABEL(sys_rt_sigsuspend)
C_LABEL(sys_rt_sigsuspend):
	/* Note: %o0, %o1 already have correct value... */
	call	C_LABEL(do_rt_sigsuspend)
	 add	%sp, REGWIN_SZ, %o2

	ld	[%curptr + AOFF_task_ptrace], %l5
	andcc	%l5, 0x02, %g0
	be	1f
	 nop

	call	C_LABEL(syscall_trace)
	 nop

1:
	/* We are returning to a signal handler. */
	RESTORE_ALL

	.text
	.align	4
	.globl	C_LABEL(sys_sigreturn)
C_LABEL(sys_sigreturn):
	call	C_LABEL(do_sigreturn)
	 add	%sp, REGWIN_SZ, %o0

	ld	[%curptr + AOFF_task_ptrace], %l5
	andcc	%l5, 0x02, %g0
	be	1f
	 nop

	call	C_LABEL(syscall_trace)
	 nop

1:
	/* We don't want to muck with user registers like a
	 * normal syscall, just return.
	 */
	RESTORE_ALL

	.text
	.align	4
	.globl	C_LABEL(sys_rt_sigreturn)
C_LABEL(sys_rt_sigreturn):
	call	C_LABEL(do_rt_sigreturn)
	 add	%sp, REGWIN_SZ, %o0

	ld	[%curptr + AOFF_task_ptrace], %l5
	andcc	%l5, 0x02, %g0
	be	1f
	 nop

	call	C_LABEL(syscall_trace)
	 nop

1:
	/* We are returning to a signal handler. */
	RESTORE_ALL

	/* Now that we have a real sys_clone, sys_fork() is
	 * implemented in terms of it.  Our _real_ implementation
	 * of SunOS vfork() will use sys_vfork().
	 *
	 * XXX These three should be consolidated into mostly shared
	 * XXX code just like on sparc64... -DaveM
	 */
	.text
	.align	4
	.globl	C_LABEL(sys_fork)
C_LABEL(sys_fork):
	mov	%o7, %l5
	FLUSH_ALL_KERNEL_WINDOWS;
	rd	%psr, %g4
	WRITE_PAUSE
	mov	SIGCHLD, %o0			! arg0:	clone flags
	rd	%wim, %g5
	WRITE_PAUSE
	mov	%fp, %o1			! arg1:	usp
	std	%g4, [%curptr + AOFF_task_thread + AOFF_thread_fork_kpsr]
	add	%sp, REGWIN_SZ, %o2		! arg2:	pt_regs ptr
	mov	0, %o3
	call	C_LABEL(do_fork)
	 mov	%l5, %o7
	
	/* Whee, kernel threads! */
	.globl	C_LABEL(sys_clone)
C_LABEL(sys_clone):
	mov	%o7, %l5
	FLUSH_ALL_KERNEL_WINDOWS;
	rd	%psr, %g4
	WRITE_PAUSE

	/* arg0,1: flags,usp  -- loaded already */
	cmp	%o1, 0x0			! Is new_usp NULL?
	rd	%wim, %g5
	WRITE_PAUSE
	be,a	1f
	 mov	%fp, %o1			! yes, use callers usp
	andn	%o1, 7, %o1			! no, align to 8 bytes
1:
	std	%g4, [%curptr + AOFF_task_thread + AOFF_thread_fork_kpsr]
	add	%sp, REGWIN_SZ, %o2		! arg2:	pt_regs ptr
	mov	0, %o3
	call	C_LABEL(do_fork)
	 mov	%l5, %o7

	/* Whee, real vfork! */
	.globl	C_LABEL(sys_vfork)
C_LABEL(sys_vfork):
	FLUSH_ALL_KERNEL_WINDOWS;
	rd	%psr, %g4
	WRITE_PAUSE
	rd	%wim, %g5
	WRITE_PAUSE
	std	%g4, [%curptr + AOFF_task_thread + AOFF_thread_fork_kpsr]
	sethi	%hi(0x4000 | 0x0100 | SIGCHLD), %o0
	mov	%fp, %o1
	or	%o0, %lo(0x4000 | 0x0100 | SIGCHLD), %o0
	sethi	%hi(C_LABEL(do_fork)), %l1
	mov	0, %o3
	jmpl	%l1 + %lo(C_LABEL(do_fork)), %g0
	 add	%sp, REGWIN_SZ, %o2

	.text
        .align  4
linux_sparc_ni_syscall:
	sethi   %hi(C_LABEL(sys_ni_syscall)), %l7
	b       syscall_is_too_hard
	 or     %l7, %lo(C_LABEL(sys_ni_syscall)), %l7

linux_fast_syscall:
	andn	%l7, 3, %l7
	mov	%i0, %o0
	mov	%i1, %o1
	mov 	%i2, %o2
	jmpl	%l7 + %g0, %g0
	 mov	%i3, %o3

linux_syscall_trace:
	call	C_LABEL(syscall_trace)
	 nop
	mov	%i0, %o0
	mov	%i1, %o1
	mov	%i2, %o2
	mov	%i3, %o3
	b	2f
	 mov	%i4, %o4

	.globl	C_LABEL(ret_from_fork)
C_LABEL(ret_from_fork):
    call    schedule_tail
     mov    %g3, %o0
	b	C_LABEL(ret_sys_call)
	 ld	[%sp + REGWIN_SZ + PT_I0], %o0

	/* Linux native and SunOS system calls enter here... */
	MYSGMT
	.align	4
	.globl	linux_sparc_syscall
linux_sparc_syscall:
	/* Direct access to user regs, must faster. */
	cmp	%g1, NR_SYSCALLS
	bgeu	linux_sparc_ni_syscall
	 sll	%g1, 2, %l4
	ld	[%l7 + %l4], %l7
	andcc	%l7, 1, %g0
	bne	linux_fast_syscall
	 /* Just do first insn from SAVE_ALL in the delay slot */

	.globl	syscall_is_too_hard
syscall_is_too_hard:
	SAVE_ALL_HEAD
	 rd	%wim, %l3

	wr	%l0, PSR_ET, %psr
	mov	%i0, %o0
	mov	%i1, %o1
	mov	%i2, %o2

	ld	[%curptr + AOFF_task_ptrace], %l5
	mov	%i3, %o3
	andcc	%l5, 0x02, %g0
	mov	%i4, %o4
	bne	linux_syscall_trace
	 mov	%i0, %l5
2:
	call	%l7
	 mov	%i5, %o5

	st	%o0, [%sp + REGWIN_SZ + PT_I0]

	.globl	C_LABEL(ret_sys_call)
C_LABEL(ret_sys_call):
	ld	[%curptr + AOFF_task_ptrace], %l6
	cmp	%o0, -ENOIOCTLCMD
	ld	[%sp + REGWIN_SZ + PT_PSR], %g3
	set	PSR_C, %g2
	bgeu	1f
	 andcc	%l6, 0x02, %l6	

	/* System call success, clear Carry condition code. */
	andn	%g3, %g2, %g3
	clr	%l6
	st	%g3, [%sp + REGWIN_SZ + PT_PSR]	
	bne	linux_syscall_trace2
	 ld	[%sp + REGWIN_SZ + PT_NPC], %l1 /* pc = npc */
	add	%l1, 0x4, %l2			/* npc = npc+4 */
	st	%l1, [%sp + REGWIN_SZ + PT_PC]
	b	ret_trap_entry
	 st	%l2, [%sp + REGWIN_SZ + PT_NPC]
1:
	/* System call failure, set Carry condition code.
	 * Also, get abs(errno) to return to the process.
	 */
	sub	%g0, %o0, %o0
	or	%g3, %g2, %g3
	st	%o0, [%sp + REGWIN_SZ + PT_I0]
	mov	1, %l6
	st	%g3, [%sp + REGWIN_SZ + PT_PSR]
	bne	linux_syscall_trace2
	 ld	[%sp + REGWIN_SZ + PT_NPC], %l1 /* pc = npc */
	add	%l1, 0x4, %l2			/* npc = npc+4 */
	st	%l1, [%sp + REGWIN_SZ + PT_PC]
	b	ret_trap_entry
	 st	%l2, [%sp + REGWIN_SZ + PT_NPC]

linux_syscall_trace2:
	call	C_LABEL(syscall_trace)
	 add	%l1, 0x4, %l2			/* npc = npc+4 */
	st	%l1, [%sp + REGWIN_SZ + PT_PC]
	b	ret_trap_entry
	 st	%l2, [%sp + REGWIN_SZ + PT_NPC]


	.globl	C_LABEL(udelay) 
C_LABEL(udelay):
#if 0
	save	%sp, -REGWIN_SZ, %sp
	mov	%i0, %o0
	sethi	%hi(C_LABEL(loops_per_us)), %o3
	call	.umul
	 ld	[%o3 + %lo(C_LABEL(loops_per_us))], %o1

	cmp	%o0, 0x0
1:
	bne	1b
	 subcc	%o0, 1, %o0
	
	ret
	restore
#else
	save	%sp, -REGWIN_SZ, %sp
	mov	%i0, %o0
	sethi	%hi(0x10c6), %o1
	call	.umul
	 or	%o1, %lo(0x10c6), %o1
	sethi	%hi(C_LABEL(loops_per_jiffy)), %o3
	call	.umul
	 ld	[%o3 + %lo(C_LABEL(loops_per_jiffy))], %o1
	call	.umul
	 mov	100, %o0

	cmp	%o0, 0x0
1:
	bne	1b
	 subcc	%o0, 1, %o0
	
	ret
	restore
#endif

	/* Handle a software breakpoint */
	/* We have to inform parent that child has stopped */
	.text
	.align 4
	.globl breakpoint_trap
breakpoint_trap:
	rd	%wim,%l3
	SAVE_ALL
	wr 	%l0, PSR_ET, %psr
	WRITE_PAUSE

	st	%i0, [%sp + REGWIN_SZ + PT_G0] ! for restarting syscalls
	call	C_LABEL(sparc_breakpoint)
	 add	%sp, REGWIN_SZ, %o0

	RESTORE_ALL

	.text
	.align	4
	.globl	C_LABEL(__handle_exception)
C_LABEL(__handle_exception):
	FLUSH_ALL_KERNEL_WINDOWS;
	ldd	[%o0], %o6
	jmpl	%o7 + 0xc, %g0			! see asm-sparc/processor.h
	 mov	1, %g1				! signal EFAULT condition

	.text
	.align	4
	.globl	C_LABEL(kill_user_windows)

	/* No matter how much overhead this routine has in the worst
	 * case scenerio, it is several times better than taking the
	 * traps with the old method of just doing flush_user_windows().
	 */
C_LABEL(kill_user_windows):
	ld	[%g6 + AOFF_task_thread + AOFF_thread_uwinmask], %o0	! get current umask
	orcc	%g0, %o0, %g0			! if no bits set, we are done
	be	3f				! nothing to do
	 rd	%psr, %o5			! must clear interrupts
	or	%o5, PSR_PIL, %o4		! or else that could change
	wr	%o4, 0x0, %psr			! the uwinmask state
	WRITE_PAUSE				! burn them cycles
1:
	ld	[%g6 + AOFF_task_thread + AOFF_thread_uwinmask], %o0	! get consistant state
	orcc	%g0, %o0, %g0			! did an interrupt come in?
	be	4f				! yep, we are done
	 rd	%wim, %o3			! get current wim
	srl	%o3, 1, %o4			! simulate a save
kuw:
	sll	%o3, 7, %o3			! compute next wim
	or	%o4, %o3, %o3			! result
	andncc	%o0, %o3, %o0			! clean this bit in umask
	bne	kuw				! not done yet
	 srl	%o3, 1, %o4			! begin another save simulation
	wr	%o3, 0x0, %wim			! set the new wim
	st	%g0, [%g6 + AOFF_task_thread + AOFF_thread_uwinmask]	! clear uwinmask
4:
	wr	%o5, 0x0, %psr			! re-enable interrupts
	WRITE_PAUSE				! burn baby burn
3:
	retl					! return
	 st	%g0, [%g6 + AOFF_task_thread + AOFF_thread_w_saved]	! no windows saved

	.text
	.align	4
	.globl	C_LABEL(restore_current)
C_LABEL(restore_current):
	LOAD_CURRENT(g6, o0)
	retl
	 nop

/* End of entry.S */
