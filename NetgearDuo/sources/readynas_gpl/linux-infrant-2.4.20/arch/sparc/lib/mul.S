/* $Id: mul.S,v 1.4 1996/09/30 02:22:32 davem Exp $
 * mul.S:       This routine was taken from glibc-1.09 and is covered
 *              by the GNU Library General Public License Version 2.
 */

/*
 * Signed multiply, from Appendix E of the Sparc Version 8
 * Architecture Manual.
 */

/*
 * Returns %o0 * %o1 in %o1%o0 (i.e., %o1 holds the upper 32 bits of
 * the 64-bit product).
 */
#include <linux/config.h>

	.globl .mul
.mul:
#ifndef CONFIG_PADRE_MULTIPLIER_BUG
	nop
	nop
#endif
	smul	%o0, %o1, %o0
	retl
	 rd	%y, %o1
	nop
