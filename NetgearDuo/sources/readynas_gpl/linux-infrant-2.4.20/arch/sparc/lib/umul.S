/* $Id: umul.S,v 1.4 1996/09/30 02:22:39 davem Exp $
 * umul.S:      This routine was taken from glibc-1.09 and is covered
 *              by the GNU Library General Public License Version 2.
 */


/*
 * Unsigned multiply.  Returns %o0 * %o1 in %o1%o0 (i.e., %o1 holds the
 * upper 32 bits of the 64-bit product).
 *
 * On return, overflow has occurred (%o1 is not zero) if and only if
 * the Z condition code is clear, allowing, e.g., the following:
 *
 *	call	.umul
 *	nop
 *	bnz	overflow	(or tnz)
 */
#include <linux/config.h>

	.globl .umul
.umul:
#ifndef CONFIG_PADRE_MULTIPLIER_BUG
	nop
	nop
#endif
	umul	%o0, %o1, %o0
	retl
	 rd	%y, %o1
	nop
