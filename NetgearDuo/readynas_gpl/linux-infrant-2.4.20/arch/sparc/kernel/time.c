/* $Id: time.c,v 1.58 2001/01/11 15:07:09 davem Exp $
 * linux/arch/sparc/kernel/time.c
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 * Copyright (C) 1996 Thomas K. Dyas (tdyas@eden.rutgers.edu)
 *
 * Chris Davis (cdavis@cois.on.ca) 03/27/1998
 * Added support for the intersil on the sun4/4200
 *
 * Gleb Raiko (rajko@mech.math.msu.su) 08/18/1998
 * Support for MicroSPARC-IIep, PCI CPU.
 *
 * This file handles the Sparc specific time handling details.
 *
 * 1997-09-10	Updated NTP code according to technical memorandum Jan '96
 *		"A Kernel Model for Precision Timekeeping" by Dave Mills
 */
#include <linux/config.h>
#include <linux/errno.h>
#include <linux/sched.h>
#include <linux/kernel.h>
#include <linux/param.h>
#include <linux/string.h>
#include <linux/mm.h>
#include <linux/interrupt.h>
#include <linux/timex.h>
#include <linux/init.h>
#include <linux/pci.h>
#include <linux/ioport.h>

#include <asm/segment.h>
#include <asm/system.h>
#include <asm/irq.h>
#include <asm/io.h>
#include <asm/page.h>
#include <asm/ds1337.h>

extern rwlock_t xtime_lock;
extern unsigned long wall_jiffies;
/* Number of usecs that the last interrupt was delayed */
static int delay_at_last_interrupt=0;

/* last time the cmos clock got updated */
static long last_rtc_update;

spinlock_t rtc_lock = SPIN_LOCK_UNLOCKED;

/*
 * This is the same as the above, except we _also_ save the current
 * Time Stamp Counter value at the time of the timer interrupt, so that
 * we later on can estimate the time of day more exactly.
 */

/*
 * BUG: This routine does not handle hour overflow properly; it just
 *      sets the minutes. Usually you won't notice until after reboot!
 * We need change after we have the real time clock     
 */
static int set_rtc_mmss(unsigned long nowtime)
{
    spin_lock(&rtc_lock);

#if 0	
    real_seconds = nowtime % 60;
    real_minutes = nowtime / 60;
 	
    retval = mach_set_rtc_mmss(nowtime);
#endif
	printk("nowtime=%x\n",nowtime);
    spin_unlock(&rtc_lock);
 	 
	return 0;
}
extern char _stext, _etext;

static void timer_interrupt(int irq, void *dev_id, struct pt_regs *regs)
{
	/*
	 * Here we are in the timer irq handler. We just have irqs locally
	 * disabled but we don't know if the timer_bh is running on the other
	 * CPU. We need to avoid to SMP race with it. NOTE: we don' t need
	 * the irq version of write_lock because as just said we have irq
	 * locally disabled. -arca
	 */
	write_lock(&xtime_lock);
	//delay_at_last_interrupt = readl(PADRE_TM_CNTDIAG);
	do_timer(regs);  

	if (!user_mode(regs)) {
		if( prof_buffer && current->pid) {
			unsigned long pc = regs->pc;
    		pc -= (unsigned long) &_stext;
    		pc >>= prof_shift;
    		if (pc > prof_len-1)
	        	pc = prof_len-1;
    		atomic_inc((atomic_t *)&prof_buffer[pc]);
		}
	}
#ifndef CONFIG_PADRE_CPU1	
    /*
	 * If we have an externally synchronized Linux clock, then update
	 * CMOS clock accordingly every ~11 minutes. Set_rtc_mmss() has to be
	 * called as close as possible to 500 ms before the new second starts.
	 */
    if ((time_status & STA_UNSYNC) == 0 &&
		xtime.tv_sec > last_rtc_update + 660 &&
		xtime.tv_usec >= 500000 - ((unsigned) tick) / 2 &&
		xtime.tv_usec <= 500000 + ((unsigned) tick) / 2) {
		if (set_rtc_mmss(xtime.tv_sec) == 0)
			last_rtc_update = xtime.tv_sec;
		else
			last_rtc_update = xtime.tv_sec - 600; /* do it again in 60 s */
	}	
#endif
    write_unlock(&xtime_lock);
}	

static struct irqaction irq_timer = { timer_interrupt, SA_INTERRUPT, 0, "timer", NULL, NULL};


static unsigned long get_rts_time()
{
#ifdef CONFIG_PADRE_I2C
    unsigned int year, mon, day, hour, min, sec;
	unsigned int century=0,pm=0;

// #ifndef CONFIG_PADRE_CPU1
   	spin_lock(&rtc_lock);     
	if( CMOS_READ(RTC_CONTROL) & RTC_CONTROL_EOSC) {
		CMOS_WRITE(0,RTC_CONTROL);
	}
	if( CMOS_READ(RTC_STATUS) & RTC_STATUS_OSF) {
		printk(KERN_INFO "RTC may be invalid.\n");
	}

#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
	printk("control=%x,status=%x\n",CMOS_READ(RTC_CONTROL), CMOS_READ(RTC_STATUS));
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
   	do 
   	{ /* Isn't this overkill ? UIP above should guarantee consistency */
   		sec = CMOS_READ(RTC_SECONDS);
	    min = CMOS_READ(RTC_MINUTES);
	    hour = CMOS_READ(RTC_HOURS);
	    day = CMOS_READ(RTC_DAY_OF_MONTH);
	    mon = CMOS_READ(RTC_MONTH);
        year = CMOS_READ(RTC_YEAR);
    } while (sec != CMOS_READ(RTC_SECONDS));		  
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
    printk("sec=%x,min=%x,hour=%x,mon=%x,day=%x,year=%x\n",
		sec,min,hour,mon,day,year);
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
	
	if(mon & RTC_MONTH_CENTURY) {
		century = 100;
		mon &= ~RTC_MONTH_CENTURY;
	}
    BCD_TO_BIN(sec);
    BCD_TO_BIN(min);
	BCD_TO_BIN(hour);
	BCD_TO_BIN(day);
	BCD_TO_BIN(mon);
	BCD_TO_BIN(year);
	year += (century+1900);
    spin_unlock(&rtc_lock);

// #endif
			
	if( year < 2003) year = 2003;

	return mktime(year, mon, day, hour, min, sec);      
#else
	return mktime(2003, 12, 1, 12, 0, 0);      
#endif
}

unsigned long f_timer1;

void do_gettimeofday(struct timeval *tv)
{
	unsigned long flags;
	unsigned long usec, sec;
  
	read_lock_irqsave(&xtime_lock, flags);

  //usec = PADRE_CLOCK_RATE - readl(PADRE_TM_CNTDIAG) ;
//	usec = 500000 / HZ;

// Time that has passed since the timer interrupt
  usec = ((f_timer1-readl(PADRE_TM_CNTDIAG))*1000000/HZ) / f_timer1;
	{
		unsigned long lost = jiffies - wall_jiffies;
		if (lost)
			usec += lost * 1000000 / HZ;
	}
	sec = xtime.tv_sec;
	usec += xtime.tv_usec;
	read_unlock_irqrestore(&xtime_lock, flags);
									 
	while (usec >= 1000000) {
		usec -= 1000000;
		sec++;
	}
										 
	tv->tv_sec = sec;
	tv->tv_usec = usec;
}

void do_settimeofday(struct timeval *tv)
{
	write_lock_irq(&xtime_lock);
	/*
	 * This is revolting. We need to set "xtime" correctly. However, the
	 * value in this location is the value at the most recent update of
	 * wall time.  Discover what correction gettimeofday() would have
	 * made, and then undo it!
	 */
	//tv->tv_usec -= readl(PADRE_TM_CNTDIAG);
	tv->tv_usec -= 500000 / HZ;
	tv->tv_usec -= (jiffies - wall_jiffies) * (1000000 / HZ);
				 
	while (tv->tv_usec < 0) {
		tv->tv_usec += 1000000;
		tv->tv_sec--;
	}
					 
	xtime = *tv;
	time_adjust = 0;        /* stop active adjtime() */
	time_status |= STA_UNSYNC;
	time_maxerror = NTP_PHASE_LIMIT;
	time_esterror = NTP_PHASE_LIMIT;
	write_unlock_irq(&xtime_lock);
}

#define PADRE_TM_CTRL_SEL_BIT(x)    ((x) << 13)
#define PADRE_TM_CTRL_LOAD_BIT(x)   (0x100 << (x))
#define PADRE_TM_CTRL_AUTO_BIT(x)   (0x10 << (x))
#define PADRE_TM_CTRL_INTEN_BIT(x)  (0x1 << (x))

#define PADRE_PRESCALE_VALUE	24


void __init time_init(void)
{
	unsigned long sys_clock;
	unsigned long x2_switch;
	unsigned long f_prescale;

#ifdef CONFIG_PADRE_PASEO_FPGA
	x2_switch = readl(X2_SWITCH) & 0x1;
#endif
#ifdef CONFIG_PADRE_CPU1
	unsigned long irq = TIMER2_IRQ;
	unsigned long timer = 2;
#define PADRE_TM_TIMER	PADRE_TM_TIMER2
#else
	unsigned long irq = TIMER1_IRQ;
	unsigned long timer = 1;
#define PADRE_TM_TIMER	PADRE_TM_TIMER1
#endif

	

#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
	if( x2_switch)
		printk("CPU running under 12.5 MHZ\n");
	else
		printk("CPU running under 25 MHZ\n");
#endif // CONFIG_PADRE_DEBUG_LEVEL_3

#ifdef CONFIG_PADRE_FIXTIMER
	sys_clock = 5000000;
#else
	sys_clock = x2_switch ? 12500000 : 25000000;
#endif
    xtime.tv_sec = get_rts_time();
	xtime.tv_usec = 0;

	f_prescale = sys_clock / (( PADRE_PRESCALE_VALUE + 1) * 4);
	f_timer1 = f_prescale / HZ * CONFIG_PADRE_HZ - 1;

	setup_irq(irq,&irq_timer);
	writel(PADRE_TM_CTRL_STP,PADRE_TM_CTRL);
    writel(PADRE_PRESCALE_VALUE, PADRE_TM_PS);
	writel(f_timer1,PADRE_TM_TIMER);
	writel(PADRE_TM_CTRL_AUTO_BIT(timer) | PADRE_TM_CTRL_LOAD_BIT(timer) |
	       PADRE_TM_CTRL_INTEN_BIT(timer) | PADRE_TM_CTRL_SEL_BIT(timer),PADRE_TM_CTRL);
}

