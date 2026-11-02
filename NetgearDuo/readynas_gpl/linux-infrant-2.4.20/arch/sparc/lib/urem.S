/* $Id: urem.S,v 1.4 1996/09/30 02:22:42 davem Exp $
 * urem.S:      This routine was taken from glibc-1.09 and is covered
 *              by the GNU Library General Public License Version 2.
 */

/* This file is generated from divrem.m4; DO NOT EDIT! */
/*
 * Division and remainder, from Appendix E of the Sparc Version 8
 * Architecture Manual, with fixes from Gordon Irlam.
 */

/*
 * Input: dividend and divisor in %o0 and %o1 respectively.
 *
 * m4 parameters:
 *  .urem	name of function to generate
 *  rem		rem=div => %o0 / %o1; rem=rem => %o0 % %o1
 *  false		false=true => signed; false=false => unsigned
 *
 * Algorithm parameters:
 *  N		how many bits per iteration we try to get (4)
 *  WORDSIZE	total number of bits (32)
 *
 * Derived constants:
 *  TOPBITS	number of bits in the top decade of a number
 *
 * Important variables:
 *  Q		the partial quotient under development (initially 0)
 *  R		the remainder so far, initially the dividend
 *  ITER	number of main division loop iterations required;
 *		equal to ceil(log2(quotient) / N).  Note that this
 *		is the log base (2^N) of the quotient.
 *  V		the current comparand, initially divisor*2^(ITER*N-1)
 *
 * Cost:
 *  Current estimate for non-large dividend is
 *	ceil(log2(quotient) / N) * (10 + 7N/2) + C
 *  A large dividend is one greater than 2^(31-TOPBITS) and takes a
 *  different path, as the upper bits of the quotient must be developed
 *  one bit at a time.
 */

	.globl .urem
.urem:
	wr	%g0, 0x0, %y
	nop
	nop
	nop
	udiv	%o0, %o1, %o2
	umul	%o2, %o1, %o2
	retl
	 sub	%o0, %o2, %o0
	nop

