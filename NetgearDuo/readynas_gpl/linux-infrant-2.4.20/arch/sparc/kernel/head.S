/* $Id: head.S,v 1.105 2001/08/12 09:08:56 davem Exp $
 * head.S: The initial boot code for the Sparc port of Linux.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 * Copyright (C) 1995,1999 Pete Zaitcev   (zaitcev@yahoo.com)
 * Copyright (C) 1996 Miguel de Icaza (miguel@nuclecu.unam.mx)
 * Copyright (C) 1997 Jakub Jelinek   (jj@sunsite.mff.cuni.cz)
 * Copyright (C) 1997 Michael A. Griffith (grif@acm.org)
 *
 * CompactPCI platform by Eric Brower, 1999.
 */

#include <linux/version.h>
#include <linux/config.h>
#include <linux/init.h>

#include <asm/cprefix.h>
#include <asm/head.h>
#include <asm/ptrace.h>
#include <asm/psr.h>
#include <asm/page.h>
#include <asm/kdebug.h>
#include <asm/winmacro.h>
#include <asm/errno.h>

#ifndef CONFIG_SUNOS_EMUL
#undef SUNOS_SYSCALL_TRAP
#define SUNOS_SYSCALL_TRAP SUNOS_NO_SYSCALL_TRAP
#endif

	/* The Sparc trap table, bootloader gives us control at _start. */
	.text
	.globl	start, _stext, _start, __stext
	.globl  C_LABEL(trapbase)
_start:   /* danger danger */
__stext:
_stext:
start:
C_LABEL(trapbase):
/* We get control passed to us here at t_zero. */
t_zero:	b gokernel; nop; nop; nop;
t_tflt:	SPARC_IFAULT                        /* Inst. Access Exception        */
t_bins:	TRAP_ENTRY(0x2, bad_instruction)    /* Illegal Instruction           */
t_pins:	TRAP_ENTRY(0x3, priv_instruction)   /* Privileged Instruction        */
#ifndef CONFIG_PADRE_SFP
t_fpd:  SKIP_TRAP(0x4,fpd) 
#else
t_fpd:	TRAP_ENTRY(0x4, fpd_trap_handler)   /* Floating Point Disabled       */
#endif
t_wovf:	WINDOW_SPILL                        /* Window Overflow               */
t_wunf:	WINDOW_FILL                         /* Window Underflow              */
t_mna:	TRAP_ENTRY(0x7, mna_handler)        /* Memory Address Not Aligned    */
t_fpe:	BAD_TRAP(0x8)   					/* Floating Point Exception      */
t_dflt:	SPARC_DFAULT                        /* Data Miss Exception           */
t_tio:	TRAP_ENTRY(0xa, do_tag_overflow)    /* Tagged Instruction Ovrflw     */
t_wpt:	TRAP_ENTRY(0xb, do_watchpoint)      /* Watchpoint Detected           */
t_badc:	BAD_TRAP(0xc) BAD_TRAP(0xd) BAD_TRAP(0xe) BAD_TRAP(0xf) 
! t_dbgnmi:SKIP_TRAP(0x10,dbgnmi)				/* This trap cause by bug 505 	 */
t_dbgnmi:BAD_TRAP(0x10)						/* This trap cause by bug 505 	 */
t_irq1:	TRAP_ENTRY_INTERRUPT(1)             /* IRQ Software/SBUS Level 1     */
t_irq2:	TRAP_ENTRY_INTERRUPT(2)	            /* IRQ PCI PINA,PINB and GPIO    */
t_irq3:	TRAP_ENTRY_INTERRUPT_GMRX           /* IRQ GMAC RX				     */
t_irq4:	TRAP_ENTRY_INTERRUPT_GMTX           /* IRQ GMAC TX				     */
t_irq5:	TRAP_ENTRY_INTERRUPT(5)             /* IRQ SBUS/Ethernet Level 5     */
t_irq6:	TRAP_ENTRY_INTERRUPT(6)             /* IRQ Software Level 6          */
t_irq7:	TRAP_ENTRY_INTERRUPT(7)             /* IRQ Video/SBUS Level 5        */
t_irq8:	TRAP_ENTRY_INTERRUPT(8)             /* IRQ SBUS Level 6              */
t_irq9:	TRAP_ENTRY_INTERRUPT(9)             /* IRQ M41  9		             */
t_irq10:TRAP_ENTRY_INTERRUPT(10)            /* IRQ M40  10					 */
t_irq11:TRAP_ENTRY_INTERRUPT(11)            /* IRQ Floppy Intr.              */
t_irq12:TRAP_ENTRY_INTERRUPT(12)            /* IRQ LP1				         */
t_irq13:TRAP_ENTRY_INTERRUPT(13)            /* IRQ LP0	 		             */
t_irq14:TRAP_ENTRY_INTERRUPT(14)            /* IRQ Timer #2                  */
t_nmi:	BAD_TRAP(0x1f)                      /* Level 15 (NMI)                */
t_racc:	BAD_TRAP(0x20)     					/* General Register Access Error */
t_iacce:BAD_TRAP(0x21)                      /* Instr Access Error            */
t_bad22:BAD_TRAP(0x22) BAD_TRAP(0x23)
t_cpdis:TRAP_ENTRY(0x24, do_cp_disabled)    /* Co-Processor Disabled         */
t_uflsh:BAD_TRAP(0x25)        				/* Unimplemented FLUSH inst.     */
t_bad26:BAD_TRAP(0x26) BAD_TRAP(0x27)
t_cpexc:BAD_TRAP(0x28)   					/* Co-Processor Exception        */
t_dacce:BAD_TRAP(0x29)                      /* Data Access Error             */
t_hwdz:	TRAP_ENTRY(0x2a, do_hw_divzero)     /* Division by zero, you lose... */
t_dserr:BAD_TRAP(0x2b)                      /* Data Store Error              */
t_daccm:SPARC_DFAULT						/* Padre data tlb missing		 */
t_bad2d:BAD_TRAP(0x2d) BAD_TRAP(0x2e) BAD_TRAP(0x2f) BAD_TRAP(0x30) BAD_TRAP(0x31)
t_bad32:BAD_TRAP(0x32) BAD_TRAP(0x33) BAD_TRAP(0x34) BAD_TRAP(0x35) BAD_TRAP(0x36)
t_bad37:BAD_TRAP(0x37) BAD_TRAP(0x38) BAD_TRAP(0x39) BAD_TRAP(0x3a) BAD_TRAP(0x3b)
t_iaccm:SPARC_IFAULT						/* PADRE intruction tlb missing  */
t_bad3d:BAD_TRAP(0x3d) BAD_TRAP(0x3e) BAD_TRAP(0x3f) BAD_TRAP(0x40) BAD_TRAP(0x41)
t_bad42:BAD_TRAP(0x42) BAD_TRAP(0x43) BAD_TRAP(0x44) BAD_TRAP(0x45) BAD_TRAP(0x46)
t_bad47:BAD_TRAP(0x47) BAD_TRAP(0x48) BAD_TRAP(0x49) BAD_TRAP(0x4a) BAD_TRAP(0x4b)
t_bad4c:BAD_TRAP(0x4c) BAD_TRAP(0x4d) BAD_TRAP(0x4e) BAD_TRAP(0x4f) BAD_TRAP(0x50)
t_bad51:BAD_TRAP(0x51) BAD_TRAP(0x52) BAD_TRAP(0x53) BAD_TRAP(0x54) BAD_TRAP(0x55)
t_bad56:BAD_TRAP(0x56) BAD_TRAP(0x57) BAD_TRAP(0x58) BAD_TRAP(0x59) BAD_TRAP(0x5a)
t_bad5b:BAD_TRAP(0x5b) BAD_TRAP(0x5c) BAD_TRAP(0x5d) BAD_TRAP(0x5e) BAD_TRAP(0x5f)
t_bad60:BAD_TRAP(0x60) BAD_TRAP(0x61) BAD_TRAP(0x62) BAD_TRAP(0x63) BAD_TRAP(0x64)
t_bad65:BAD_TRAP(0x65) BAD_TRAP(0x66) BAD_TRAP(0x67) BAD_TRAP(0x68) BAD_TRAP(0x69)
t_bad6a:BAD_TRAP(0x6a) BAD_TRAP(0x6b) BAD_TRAP(0x6c) BAD_TRAP(0x6d) BAD_TRAP(0x6e)
t_bad6f:BAD_TRAP(0x6f) BAD_TRAP(0x70) BAD_TRAP(0x71) BAD_TRAP(0x72) BAD_TRAP(0x73)
t_bad74:BAD_TRAP(0x74) BAD_TRAP(0x75) BAD_TRAP(0x76) BAD_TRAP(0x77) BAD_TRAP(0x78)
t_bad79:BAD_TRAP(0x79) BAD_TRAP(0x7a) BAD_TRAP(0x7b) BAD_TRAP(0x7c) BAD_TRAP(0x7d)
t_bad7e:BAD_TRAP(0x7e) BAD_TRAP(0x7f)
t_sunos:BAD_TRAP(0x80)                      /* SunOS System Call             */
t_sbkpt:BREAKPOINT_TRAP                     /* Software Breakpoint/KGDB      */
t_divz:	TRAP_ENTRY(0x82, do_hw_divzero)     /* Divide by zero trap           */
t_flwin:TRAP_ENTRY(0x83, do_flush_windows)  /* Flush Windows Trap            */
t_clwin:BAD_TRAP(0x84)                      /* Clean Windows Trap            */
t_rchk:	BAD_TRAP(0x85)                      /* Range Check                   */
t_funal:BAD_TRAP(0x86)                      /* Fix Unaligned Access Trap     */
t_iovf:	BAD_TRAP(0x87)                      /* Integer Overflow Trap         */
t_slowl:BAD_TRAP(0x88)                		/* Slowaris System Call          */
t_netbs:BAD_TRAP(0x89)		                /* Net-B.S. System Call          */
t_bad8a:BAD_TRAP(0x8a) BAD_TRAP(0x8b) BAD_TRAP(0x8c) BAD_TRAP(0x8d) BAD_TRAP(0x8e)
t_bad8f:BAD_TRAP(0x8f)
t_linux:LINUX_SYSCALL_TRAP                  /* Linux System Call             */
t_bad91:BAD_TRAP(0x91) BAD_TRAP(0x92) BAD_TRAP(0x93) BAD_TRAP(0x94) BAD_TRAP(0x95)
t_bad96:BAD_TRAP(0x96) BAD_TRAP(0x97) BAD_TRAP(0x98) BAD_TRAP(0x99) BAD_TRAP(0x9a)
t_bad9b:BAD_TRAP(0x9b) BAD_TRAP(0x9c) BAD_TRAP(0x9d) BAD_TRAP(0x9e) BAD_TRAP(0x9f)
t_getcc:GETCC_TRAP                          /* Get Condition Codes           */
t_setcc:SETCC_TRAP                          /* Set Condition Codes           */
t_getpsr:GETPSR_TRAP                        /* Get PSR Register              */
t_bada3:BAD_TRAP(0xa3) BAD_TRAP(0xa4) BAD_TRAP(0xa5) BAD_TRAP(0xa6)
t_slowi:BAD_TRAP(0xa7)						/* Indirect solaris syscall      */
t_bada8:BAD_TRAP(0xa8) BAD_TRAP(0xa9) BAD_TRAP(0xaa) BAD_TRAP(0xab)
t_badac:BAD_TRAP(0xac) BAD_TRAP(0xad) BAD_TRAP(0xae) BAD_TRAP(0xaf) BAD_TRAP(0xb0)
t_badb1:BAD_TRAP(0xb1) BAD_TRAP(0xb2) BAD_TRAP(0xb3) BAD_TRAP(0xb4) BAD_TRAP(0xb5)
t_badb6:BAD_TRAP(0xb6) BAD_TRAP(0xb7) BAD_TRAP(0xb8) BAD_TRAP(0xb9) BAD_TRAP(0xba)
t_badbb:BAD_TRAP(0xbb) BAD_TRAP(0xbc) BAD_TRAP(0xbd) BAD_TRAP(0xbe) BAD_TRAP(0xbf)
t_badc0:BAD_TRAP(0xc0) BAD_TRAP(0xc1) BAD_TRAP(0xc2) BAD_TRAP(0xc3) BAD_TRAP(0xc4)
t_badc5:BAD_TRAP(0xc5) BAD_TRAP(0xc6) BAD_TRAP(0xc7) BAD_TRAP(0xc8) BAD_TRAP(0xc9)
t_badca:BAD_TRAP(0xca) BAD_TRAP(0xcb) BAD_TRAP(0xcc) BAD_TRAP(0xcd) BAD_TRAP(0xce)
t_badcf:BAD_TRAP(0xcf) BAD_TRAP(0xd0) BAD_TRAP(0xd1) BAD_TRAP(0xd2) BAD_TRAP(0xd3)
t_badd4:BAD_TRAP(0xd4) BAD_TRAP(0xd5) BAD_TRAP(0xd6) BAD_TRAP(0xd7) BAD_TRAP(0xd8)
t_badd9:BAD_TRAP(0xd9) BAD_TRAP(0xda) BAD_TRAP(0xdb) BAD_TRAP(0xdc) BAD_TRAP(0xdd)
t_badde:BAD_TRAP(0xde) BAD_TRAP(0xdf) BAD_TRAP(0xe0) BAD_TRAP(0xe1) BAD_TRAP(0xe2)
t_bade3:BAD_TRAP(0xe3) BAD_TRAP(0xe4) BAD_TRAP(0xe5) BAD_TRAP(0xe6) BAD_TRAP(0xe7)
t_bade8:BAD_TRAP(0xe8) BAD_TRAP(0xe9) BAD_TRAP(0xea) BAD_TRAP(0xeb) BAD_TRAP(0xec)
t_baded:BAD_TRAP(0xed) BAD_TRAP(0xee) BAD_TRAP(0xef) BAD_TRAP(0xf0) BAD_TRAP(0xf1)
t_badf2:BAD_TRAP(0xf2) BAD_TRAP(0xf3) BAD_TRAP(0xf4) BAD_TRAP(0xf5) BAD_TRAP(0xf6)
t_badf7:BAD_TRAP(0xf7) BAD_TRAP(0xf8) BAD_TRAP(0xf9) BAD_TRAP(0xfa) BAD_TRAP(0xfb)
t_badfc:BAD_TRAP(0xfc) BAD_TRAP(0xfd)
dbtrap:	BAD_TRAP(0xfe)                      /* Debugger/PROM breakpoint #1   */
dbtrap2:BAD_TRAP(0xff)                      /* Debugger/PROM breakpoint #2   */	

	.globl	C_LABEL(end_traptable)
C_LABEL(end_traptable):

	.align PAGE_SIZE

/* This was the only reasonable way I could think of to properly align
 * these page-table data structures.
 */
	.globl C_LABEL(pg0), C_LABEL(pg1), C_LABEL(pg2), C_LABEL(pg3)
	.globl C_LABEL(empty_bad_page)
	.globl C_LABEL(empty_bad_page_table)
	.globl C_LABEL(empty_zero_page)
	.globl C_LABEL(swapper_pg_dir)
C_LABEL(swapper_pg_dir):		.skip PAGE_SIZE
C_LABEL(pg0):				.skip PAGE_SIZE
C_LABEL(pg1):				.skip PAGE_SIZE
C_LABEL(pg2):				.skip PAGE_SIZE
C_LABEL(pg3):				.skip PAGE_SIZE
C_LABEL(empty_bad_page):		.skip PAGE_SIZE
C_LABEL(empty_bad_page_table):		.skip PAGE_SIZE
C_LABEL(empty_zero_page):		.skip PAGE_SIZE

	.global C_LABEL(root_flags)
	.global C_LABEL(ram_flags)
	.global C_LABEL(root_dev)
	.global C_LABEL(sparc_ramdisk_image)
	.global C_LABEL(sparc_ramdisk_size)

/* This stuff has to be in sync with SILO and other potential boot loaders
 * Fields should be kept upward compatible and whenever any change is made,
 * HdrS version should be incremented.
 */
	.ascii	"HdrS"
	.word	LINUX_VERSION_CODE
	.half	0x0203		/* HdrS version */
C_LABEL(root_flags):
	.half	1
C_LABEL(root_dev):
	.half	0
C_LABEL(ram_flags):
	.half	0
C_LABEL(sparc_ramdisk_image):
	.word	0
C_LABEL(sparc_ramdisk_size):
	.word	0
	.word	C_LABEL(reboot_command)
	.word	0, 0, 0
	.word	_end

/* Cool, here we go. Pick up the romvec pointer in %o0 and stash it in
 * %g7 and at prom_vector_p. And also quickly check whether we are on
 * a v0, v2, or v3 prom.
 */
gokernel:
		/* Ok, it's nice to know, as early as possible, if we
		 * are already mapped where we expect to be in virtual
		 * memory.  The Solaris /boot elf format bootloader
		 * will peek into our elf header and load us where
		 * we want to be, otherwise we have to re-map.
		 *
		 * Some boot loaders don't place the jmp'rs address
		 * in %o7, so we do a pc-relative call to a local
		 * label, then see what %o7 has.
		 */

    	.macro led val
    	sethi   %hi(X2_LED),%l7
    	set     \val,%l6
    	st     %l6,[%l7 + %lo(X2_LED)]
    	set 0x2000, %l0
1:
    	subcc %l0, 1, %l0
    	bne 1b
     	nop
    	.endm
 
    	.macro printch ch
    	sethi   %hi(PADRE_UART0_STAT), %l7
1:
    	ld      [%l7+%lo(PADRE_UART0_STAT)],%l6
    	btst    0x4, %l6
    	be  1b
		 nop
     	sethi  %hi(PADRE_UART0_DATA), %l7
    	set     \ch, %l6
    	st      %l6, [%l7 + %lo(PADRE_UART0_DATA)]
    	.endm

    	.macro print1ch ch
    	sethi   %hi(PADRE_UART1_STAT), %l7
1:
    	ld      [%l7+%lo(PADRE_UART1_STAT)],%l6
    	btst    0x4, %l6
    	be  1b
		 nop
     	sethi  %hi(PADRE_UART1_DATA), %l7
    	set     \ch, %l6
    	st      %l6, [%l7 + %lo(PADRE_UART1_DATA)]
    	.endm

    	.macro delay
    	set     500, %l7
1:
    	deccc   %l7
    	bne 1b
     	 nop
    	.endm

#if 0
   		wr  %g0, 0xfc7, %psr 		
		WRITE_PAUSE

    	wr  %g0, 0, %wim        ! No invalid windows (yet)
		WRITE_PAUSE

    	sethi   %hi(_start), %g1
    	andn    %g1, 0xfff, %g1     ! should not be needed
    	wr  %g1, 0, %tbr        ! Traps are at reset_vector
		WRITE_PAUSE
#endif

		
		! printch '1'
init_tlb:
        set tlb_address, %g1
        jmpl %g1, %g0
         nop
tlb_address:
        set PADRE_MMU_CONTROL, %g1
        set PADRE_MMU_CONTROL_FL, %g2
        sta %g2, [%g1]ASI_MMU
        set PADRE_MMU_CONTROL_DE | PADRE_MMU_CONTROL_IE, %g2
        sta %g2, [%g1]ASI_MMU
        nop
        nop
        nop
        nop

		! printch '2'
 
  		set PADRE_MMU_CONTROL, %g1
    	lda [%g1] ASI_MMU, %g2
    	srl %g2, 20, %g2
    	and %g2, 0xf, %g2
     	cmp %g2, 1
    	be init_cache
     	nop
		
init_cache:
		sethi %hi(0x80000000), %g3

		set PADRE_ICMU_CTRL, %g1
		sta %g0, [%g1] ASI_ICMU
		WRITE_PAUSE

		set PADRE_DCMU_CTRL, %g1
		sta %g0, [%g1] ASI_DCMU
		WRITE_PAUSE
		ld [%g3], %g0

#if 1
		! set PADRE_MMU_CACHEABLE_TH, %g2
		! set 0x7000000, %g2
		set 0x80000000, %g2
		ld [%g2], %g2
		srl %g2, 24, %g2
#ifdef CONFIG_PADRE_2CPU
#ifndef CONFIG_PADRE_CPU1
		set CONFIG_PADRE_CPU0_SIZE, %g2
#endif
#endif
		sub %g2, CONFIG_PADRE_NONCACHESIZE, %g2
		sll %g2, 24, %g2
		set PADRE_MMU_CACHEABLE, %g1
		sta %g2, [%g1]ASI_MMU
#endif

!! #if CONFIG_PADRE_PASEO
#define _IC3_SIZE 0x4000
!! #else
!! #define _IC3_SIZE 0x1000
!! #endif

#define _DC3_SIZE 0x800
	
#if defined(CONFIG_PADRE_IC3) || defined(CONFIG_PADRE_ICACHE)
		set PADRE_ICMU_CTRL, %g1
		set PADRE_ICMU_CTRL_TM, %g2
		sta %g2, [%g1] ASI_ICMU


#ifdef CONFIG_PADRE_IC3
		set PADRE_ICMU_IRD, %g1
		set __ic3_begin, %g2
		set PADRE_ICMU_IRD+_IC3_SIZE, %g3
1:		
		ld  [%g2], %g4
		st  %g0, [%g2]		! test only
		sta %g4, [%g1]ASI_ICMU
		add %g1, 4, %g1
		cmp %g1, %g3
		bne 1b
		 add %g2, 4, %g2
#endif
		
#ifdef CONFIG_PADRE_ICACHE
		set	PADRE_ICMU_ITAG, %g1
		set	PADRE_ICMU_ITAG+0x3ffc, %g2
1:
		sta %g0, [%g1]ASI_ICMU
		cmp %g1, %g2
		blu 1b
		 add %g1, 0x4, %g1
#endif

		set PADRE_ICMU_CTRL, %g1
#ifdef CONFIG_PADRE_IC3
		set __ic3_begin-0x40000000, %g2
		or %g2, PADRE_ICMU_CTRL_IC3, %g2
#else
		mov %g0, %g2
#endif

#ifdef CONFIG_PADRE_ICACHE
		or %g2, PADRE_ICMU_CTRL_EN, %g2
#endif
		sta %g0, [%g1] ASI_ICMU
		nop
		nop
		nop
		sta %g2, [%g1] ASI_ICMU
		nop
		nop
		nop
#endif

		
#if  defined(CONFIG_PADRE_DC3) || defined(CONFIG_PADRE_DCACHE)
		set PADRE_DCMU_CTRL, %g1
		set PADRE_DCMU_CTRL_TM, %g2
		sta %g2, [%g1] ASI_DCMU

#ifdef CONFIG_PADRE_DC3
		set PADRE_DCMU_DRD, %g1
		set __dc3_begin, %g2
		set PADRE_DCMU_DRD+_DC3_SIZE, %g3
1:		
		ld  [%g2], %g4
		st  %g0, [%g2]		! test only
		sta %g4, [%g1]ASI_DCMU
		add %g1, 4, %g1
		cmp %g1, %g3
		bne 1b
		 add %g2, 4, %g2
#endif

#ifdef CONFIG_PADRE_DCACHE
		set PADRE_DCMU_DTAG, %g1
		set	PADRE_DCMU_DTAG+0x3ffc, %g2
1:
		sta %g0, [%g1]ASI_DCMU
		cmp %g1, %g2
		blu 1b
		 add %g1, 0x4, %g1
#endif
		set PADRE_S3_RAMTOP, %g3		
		set PADRE_DCMU_CTRL, %g1
#ifdef CONFIG_PADRE_DC3
		set __dc3_begin-0x40000000, %g2
		or %g2, PADRE_DCMU_CTRL_DC3, %g2
#else
		mov %g0, %g2
#endif

#ifdef CONFIG_PADRE_DCACHE_WB
		or %g2, PADRE_DCMU_CTRL_EN, %g2
#endif
#ifdef CONFIG_PADRE_DCACHE_WT
		or %g2, PADRE_DCMU_CTRL_EN | PADRE_DCMU_CTRL_WT, %g2
#endif
		
		sta %g0, [%g1] ASI_DCMU
		nop
		nop
		ld  [%g3], %g0
		sta %g2, [%g1] ASI_DCMU
		nop
		nop
		ld  [%g3], %g0
#endif

#ifndef CONFIG_PADRE_CPU1
load_lp:
		set	PADRE_SYS_ID, %g1
		ld	[%g1], %g1
		set	0x1008, %g2
		set	0x3107, %g3
		srl	%g1, 16, %g1
		cmp	%g1, %g2
		beq	load_lp_it1008
		cmp	%g1, %g3
		beq	load_lp_it3107

		! default to to padre
load_lp_it1008:
		sethi	%hi(0x70000000), %g1
		b	load_lp_common
		nop
load_lp_it3107:		
		set	0x70007ffc, %g1
load_lp_common:
		set init_lp, %g2
		sethi %hi(0x40000000), %g3
		subcc %g2, %g3, %g2
		st  %g2, [%g1]

 		set PADRE_SYS_CTRL, %g3
    	set 0x2 << 12, %g4
    	st  %g4, [%g3]

1:
		ld  [%g1], %g2
		cmp %g2, %g0
		bne 1b
		 nop
#endif
		b go_to_highmem
		 nop
init_lp:
        set PADRE_ICMU_CTRL, %g1
        set PADRE_ICMU_CTRL_TM, %g2
        sta %g2, [%g1] ASI_ICMU
        set PADRE_ICMU_IRD, %g1
#ifdef CONFIG_PADRE_PASEO_FPGA
        set PADRE_ICMU_IRD+0x1000, %g3
#else
        set PADRE_ICMU_IRD+0x4000, %g3
#endif
        set lp_s_code, %g4
        sethi %hi(0x40000000), %g5
        sub %g4, %g5, %g4
1:
        ld  [%g4], %g2
        sta %g2, [%g1] ASI_ICMU
        add %g4,0x4, %g4
        add %g1,0x4, %g1
        cmp %g1, %g3
        bl  1b
         nop

!! load lp data
        set PADRE_DCMU_CTRL, %g1
        set PADRE_DCMU_CTRL_TM, %g2
        sta %g2, [%g1] ASI_DCMU
        set PADRE_DCMU_DRD, %g1
#ifdef CONFIG_PADRE_PASEO_FPGA
        set PADRE_DCMU_DRD+0x800, %g3
#else
        set PADRE_DCMU_DRD+0x1000, %g3
#endif

        set lp_s_data, %g4
        sethi %hi(0x40000000), %g5
        sub %g4, %g5, %g4
1:
        ld  [%g4], %g2
        sta %g2, [%g1] ASI_DCMU
        add %g4,0x4, %g4
        add %g1,0x4, %g1
        cmp %g1, %g3
        bl  1b
         nop

#define INST_RAM_TOP    0x10000
#define INST_RAM_SIZE   0x1000
#define DATA_RAM_TOP    0x00000
#define DATA_RAM_SIZE   0x800

        set INST_RAM_TOP, %g3
        mov %g3, %tbr

        mov %g0, %wim
        WRITE_PAUSE

        set 0x10e0, %g1
        mov %g1, %psr
        WRITE_PAUSE

set_ic3:
        set PADRE_ICMU_CTRL, %g3
        set INST_RAM_TOP & PADRE_ICMU_CTRL_IC3TAG | PADRE_ICMU_CTRL_IC3 | PADRE_ICMU_CTRL_EN, %g4
        sta %g4, [%g3]ASI_ICMU
set_id3:
        set PADRE_DCMU_CTRL, %g3
        set DATA_RAM_TOP & PADRE_DCMU_CTRL_DC3TAG | PADRE_DCMU_CTRL_DC3 | PADRE_DCMU_CTRL_EN, %g4
        sta %g4, [%g3]ASI_DCMU

        !set DATA_RAM_TOP+DATA_RAM_SIZE-104, %sp
        set DATA_RAM_TOP+DATA_RAM_SIZE-4, %sp
        mov %sp, %g3

        set INST_RAM_TOP+0x134, %g1
        jmp %g1
         nop


load_cpu1:
		set	PADRE_SYS_ID, %g1
		ld	[%g1], %g1
		set	0x1008, %g2
		set	0x3107, %g3
		srl	%g1, 16, %g1
		cmp	%g1, %g2
		beq	load_cpu1_it1008
		cmp	%g1, %g3
		beq	load_cpu1_it3107

		! default to to padre
load_cpu1_it1008:
		sethi	%hi(0x70000000), %g1
		b	load_cpu1_common
		nop
load_cpu1_it3107:		
		set	0x70007ffc, %g1

load_cpu1_common:
		set init_cpu1, %g2
		st  %g2, [%g1]

 		set PADRE_SYS_CTRL, %g3
    	st  %g0, [%g3]

1:
		ld  [%g1], %g2
		cmp %g2, %g0
		bne 1b
		 nop
		b go_to_highmem
		 nop
init_cpu1:
		nop


/* Now do a non-relative jump so that PC is in high-memory */
go_to_highmem:
		set	execute_in_high_mem, %g1
		jmpl	%g1, %g0
		 nop

	/* This is to align init_task_union properly, be careful. -DaveM */
#ifdef CONFIG_PADRE_STACK_16K
    .align 16384
#else
	.align	8192
#endif

/* The code above should be at beginning and we have to take care about
 * short jumps, as branching to .text.init section from .text is usually
 * impossible */
		__INIT
/* Acquire boot time privileged register values, this will help debugging.
 * I figure out and store nwindows and nwindowsm1 later on.
 */
execute_in_high_mem:
		! printch '5'

/* Aieee, now set PC and nPC, enable traps, give ourselves a stack and it's
 * show-time!
 */

		/* Turn on Supervisor, DisableFloating, and all the PIL bits.
		 * Also puts us in register window zero with traps off.
		 */
		set	(PSR_PS | PSR_S | PSR_PIL ), %g2		! no floating
		wr	%g2, 0x0, %psr
		WRITE_PAUSE

		/* I want a kernel stack NOW! */
		set	C_LABEL(init_task_union), %g1
		set	(TASK_UNION_SIZE - REGWIN_SZ), %g2
		add	%g1, %g2, %sp
		mov	0, %fp			/* And for good luck */

		/* Zero out our BSS section. */
		set	C_LABEL(__bss_start) , %o0	! First address of BSS
		set	C_LABEL(end) , %o1		! Last address of BSS
		add	%o0, 0x1, %o0
1:	
		stb	%g0, [%o0]
		subcc	%o0, %o1, %g0
		bl	1b
		 add	%o0, 0x1, %o0

		/* Initialize the umask value for init_task just in case.
		 * But first make current_set[boot_cpu_id] point to something useful.
		 */
		set	C_LABEL(init_task_union), %g6
		set	C_LABEL(current_set), %g2
		st	%g6, [%g2]

		st	%g0, [%g6 + AOFF_task_thread + AOFF_thread_uwinmask]

		mov	2, %g1
		wr	%g1, 0x0, %wim			! make window 1 invalid
		WRITE_PAUSE


		/* Here we go, start using Linux's trap table... */
		set	C_LABEL(trapbase), %g3
		wr	%g3, 0x0, %tbr
		WRITE_PAUSE

		/* Finally, turn on traps so that we can call c-code. */
		rd	%psr, %g3
		wr	%g3, 0x0, %psr
		WRITE_PAUSE

		wr	%g3, PSR_ET, %psr
		WRITE_PAUSE
		! printch '6'

		call 	C_LABEL(start_kernel)
		 nop
	
		/* We should not get here. */
		call	halt_me
		 nop

		/* Not reached */
halt_me:
		ld	[%g7 + 0x74], %o0
		call	%o0			! Get us out of here...
		 nop				! Apparently Solaris is better.


        .section        ".fixup",#alloc,#execinstr
        .globl  __ret_efault
__ret_efault:
        ret
         restore %g0, -EFAULT, %o0

