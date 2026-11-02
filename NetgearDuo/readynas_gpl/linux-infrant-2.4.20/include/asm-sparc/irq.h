/* $Id: irq.h,v 1.32 2000/08/26 02:42:28 anton Exp $
 * irq.h: IRQ registers on the Sparc.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 */

#ifndef _SPARC_IRQ_H
#define _SPARC_IRQ_H

#include <linux/config.h>
#include <linux/linkage.h>
#include <asm/hw_irq.h>

#define NR_IRQS   48

#define TIMER1_IRQ	46
#define TIMER2_IRQ	45

#define irq_cannonicalize(x) (x)

static __inline__ char *__irq_itoa(unsigned int irq)
{
	static char buff[8];

	sprintf(buff, "%d", irq);
	return buff;
}


struct irqaction;
extern void disable_irq(unsigned int);
extern void disable_irq_nosync(unsigned int);
extern void enable_irq(unsigned int);
extern int setup_irq(unsigned int, struct irqaction *); 
extern unsigned long lp_ch_ipend0, lp_ch_ipend1; 

#endif
