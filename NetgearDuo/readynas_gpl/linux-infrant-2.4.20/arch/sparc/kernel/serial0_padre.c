/*
 * linux/drivers/char/serial.c, (replacing the default serial.c by PADRE)
 *
 * Driver for the serial port on the PADRE chip.
 *
 * Based on drivers/char/serial.c
 */

//#define DO_RX_INTR
//#define DEBUG_RS

#include <linux/config.h>
#include <linux/module.h>
#include <linux/errno.h>
#include <linux/signal.h>
#include <linux/sched.h>
#include <linux/interrupt.h>
#include <linux/tty.h>
#include <linux/tty_flip.h>
#include <linux/serial.h>
#include <linux/major.h>
#include <linux/ptrace.h>
#include <linux/ioport.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/init.h>
#include <linux/console.h>

#include <asm/io.h>
#include <asm/irq.h>
#include <asm/uaccess.h>

#define BAUD_BASE		(9600)

#define	IRQ_CONTX		8
#define	IRQ_CONRX		8

#define SERIAL_PADRE_NAME	"ttyS0"
#define SERIAL_PADRE_MAJOR	4
#define SERIAL_PADRE_MINOR	64

#define SERIAL_PADRE_AUXNAME	"cua0"
#define SERIAL_PADRE_AUXMAJOR	5
#define SERIAL_PADRE_AUXMINOR	64

static struct tty_driver rsPADRE_driver, callout_driver;
static int rsPADRE_refcount;
static struct tty_struct *rsPADRE_table[1];

static struct termios *rsPADRE_termios[1];
static struct termios *rsPADRE_termios_locked[1];

static char wbuf[1000], *putp = wbuf, *getp = wbuf, x_char;
static struct tty_struct *rsPADRE_tty;
static int rsPADRE_use_count;

static int rsPADRE_write_room(struct tty_struct *tty)
{
	return putp >= getp ? (sizeof(wbuf) - (long) putp + (long) getp) : ((long) getp - (long) putp - 1);
}

static void rsPADRE_rx_int(int irq, void *dev_id, struct pt_regs *regs)
{
	if (!rsPADRE_tty) {
#ifdef DEBUG_RS
	printk("rsPADRE_rx_int, !rsPADRE_tty, disable irq and return\n");
#endif

#ifdef DO_RX_INTR
#ifdef OLD_CODE
		disable_irq(IRQ_CONRX);
#else
	writel((readl(PADRE_UART1_CTRL)  & !PADRE_UART1_CTRL_RI), 
		PADRE_UART1_CTRL);
#endif
#endif
		return;
	}
#ifdef OLD_CODE
	while (!(*CSR_UARTFLG & 0x10)) {
		int ch, flag;
		ch = *CSR_UARTDR;
		flag = *CSR_RXSTAT;
		if (flag & 4)
			tty_insert_flip_char(rsPADRE_tty, 0, TTY_OVERRUN);
		if (flag & 2)
			flag = TTY_PARITY;
		else if (flag & 1)
			flag = TTY_FRAME;
		tty_insert_flip_char(rsPADRE_tty, ch, flag);
	}
#else
{
	int ch, flag;
	while (((flag = readl(PADRE_UART1_STAT)) & 0x1)) {
		ch = readl(PADRE_UART1_DATA);
#ifdef DEBUG_RS
	printk("2rsPADRE_rx_int flag=%x, data=%c\n", flag, ch);
#endif
		if (flag & PADRE_UART1_STAT_OV) {
			tty_insert_flip_char(rsPADRE_tty, 0, TTY_OVERRUN);
			ch = readl(PADRE_UART1_DATA);
			writel(0x0, PADRE_UART1_STAT);
		}
		if (flag & PADRE_UART1_STAT_PE)
			flag = TTY_PARITY;
		else if (flag & PADRE_UART1_STAT_FE)
			flag = TTY_FRAME;
		else if (flag & PADRE_UART1_STAT_BR) 
			flag = TTY_BREAK;
		else flag = TTY_NORMAL;
		if (flag != TTY_NORMAL)
			writel(0x0, PADRE_UART1_STAT);
		tty_insert_flip_char(rsPADRE_tty, ch, flag);
	}
}
#endif
	tty_flip_buffer_push(rsPADRE_tty);
}

static void rsPADRE_send_xchar(struct tty_struct *tty, char ch)
{
#ifdef DEBUG_RS
	printk("rsPADRE_send_xchar=\n",ch);
#endif

	x_char = ch;

#ifdef DO_RX_INTR
#ifdef OLD_CODE
	enable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL)  | PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
}

static void rsPADRE_throttle(struct tty_struct *tty)
{
	if (I_IXOFF(tty))
		rsPADRE_send_xchar(tty, STOP_CHAR(tty));
}

static void rsPADRE_unthrottle(struct tty_struct *tty)
{
	if (I_IXOFF(tty)) {
		if (x_char)
			x_char = 0;
		else
			rsPADRE_send_xchar(tty, START_CHAR(tty));
	}
}

static void rsPADRE_tx_int(int irq, void *dev_id, struct pt_regs *regs)
{
#ifdef OLD_CODE
	while (!(*CSR_UARTFLG & 0x20)) {
		if (x_char) {
			*CSR_UARTDR = x_char;
			x_char = 0;
			continue;
		}
		if (putp == getp) {
			disable_irq(IRQ_CONTX);
			break;
		}
		*CSR_UARTDR = *getp;
		if (++getp >= wbuf + sizeof(wbuf))
			getp = wbuf;
	}
#else
{
#ifdef DEBUG_RS
	printk("tx_int:\n");
#endif
while (!(readl(PADRE_UART1_STAT) & 0x4));
if (x_char) writel(x_char, PADRE_UART1_DATA);
else {
		if (putp == getp) {
#ifdef DO_RX_INTR
#ifdef OLD_CODE
			disable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL)  & !PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
		}
		else {
		writel(*getp, PADRE_UART1_DATA);
		if (++getp >= wbuf + sizeof(wbuf))
			getp = wbuf;
		}
}
}
#endif
	if (rsPADRE_tty)
		wake_up_interruptible(&rsPADRE_tty->write_wait);
}

static void rsPADRE_rx_tx_int(int irq, void *dev_id, struct pt_regs *regs)
{
	unsigned long status = readl(PADRE_UART1_STAT);
#ifdef DEBUG_RS
	printk("From IRQ: rsPADRE_rx_tx_int irq=%d\n",irq);
#endif

#ifdef DO_RX_INTR
	if (status & PADRE_UART1_STAT_DR)
		rsPADRE_rx_int(irq, dev_id, regs);
	else if (status & PADRE_UART1_STAT_TH)
		rsPADRE_tx_int(irq, dev_id, regs);
#else
	rsPADRE_rx_int(irq, dev_id, regs);
#endif

}

static inline int rsPADRE_xmit(int ch)
{
	if (putp + 1 == getp || (putp + 1 == wbuf + sizeof(wbuf) && getp == wbuf))
		return 0;
	*putp = ch;
	if (++putp >= wbuf + sizeof(wbuf))
		putp = wbuf;
#ifdef DO_RX_INTR
#ifdef OLD_CODE
	enable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL)  | PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#else
	rsPADRE_tx_int(0, NULL, NULL);
#endif
	return 1;
}

static int rsPADRE_write(struct tty_struct *tty, int from_user,
		       const u_char * buf, int count)
{
	int i;

#ifdef DEBUG_RS
	printk("rsPADRE_write from_user=%d, buf=%s, count=%d\n",from_user, buf, count);
#endif

	if (from_user && verify_area(VERIFY_READ, buf, count))
		return -EINVAL;

	for (i = 0; i < count; i++) {
		char ch;
		if (from_user)
			__get_user(ch, buf + i);
		else
			ch = buf[i];
		if (!rsPADRE_xmit(ch))
			break;
	}
	return i;
}

static void rsPADRE_put_char(struct tty_struct *tty, u_char ch)
{
#ifdef DEBUG_RS
	printk("rsPADRE_put_char\n");
#endif

	rsPADRE_xmit(ch);
}

static int rsPADRE_chars_in_buffer(struct tty_struct *tty)
{
#ifdef DEBUG_RS
	printk("rsPADRE_chars_in_buffer\n");
#endif

	return sizeof(wbuf) - rsPADRE_write_room(tty);
}

static void rsPADRE_flush_buffer(struct tty_struct *tty)
{
#ifdef DO_RX_INTR
#ifdef OLD_CODE
	disable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL) & !PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
	putp = getp = wbuf;
	if (x_char) {
#ifdef DO_RX_INTR
#ifdef OLD_CODE
		enable_irq(IRQ_CONTX);
#else
		writel((readl(PADRE_UART1_CTRL)  | PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
	}
}

static inline void rsPADRE_set_cflag(int cflag)
{
	int h_lcr, baud, quot;

	switch (cflag & CSIZE) {
	case CS5:
		h_lcr = 0x10;
		break;
	case CS6:
		h_lcr = 0x30;
		break;
	case CS7:
		h_lcr = 0x50;
		break;
	default: /* CS8 */
		h_lcr = 0x70;
		break;

	}
	if (cflag & CSTOPB)
		h_lcr |= 0x08;
	if (cflag & PARENB)
		h_lcr |= 0x02;
	if (!(cflag & PARODD))
		h_lcr |= 0x04;

	switch (cflag & CBAUD) {
	case B200:	baud = 200;		break;
	case B300:	baud = 300;		break;
	case B1200:	baud = 1200;		break;
	case B1800:	baud = 1800;		break;
	case B2400:	baud = 2400;		break;
	case B4800:	baud = 4800;		break;
	default:
	case B9600:	baud = 9600;		break;
	case B19200:	baud = 19200;		break;
	case B38400:	baud = 38400;		break;
	case B57600:	baud = 57600;		break;
	case B115200:	baud = 115200;		break;
	}

	/*
	 * The documented expression for selecting the divisor is:
	 *  BAUD_BASE / baud - 1
	 * However, typically BAUD_BASE is not divisible by baud, so
	 * we want to select the divisor that gives us the minimum
	 * error.  Therefore, we want:
	 *  int(BAUD_BASE / baud - 0.5) ->
	 *  int(BAUD_BASE / baud - (baud >> 1) / baud) ->
	 *  int((BAUD_BASE - (baud >> 1)) / baud)
	 */
	quot = (BAUD_BASE - (baud >> 1)) / baud;

/*
	*CSR_UARTCON = 0;
	*CSR_L_UBRLCR = quot & 0xff;
	*CSR_M_UBRLCR = (quot >> 8) & 0x0f;
	*CSR_H_UBRLCR = h_lcr;
	*CSR_UARTCON = 1;
*/
}

static void rsPADRE_set_termios(struct tty_struct *tty, struct termios *old)
{
	if (old && tty->termios->c_cflag == old->c_cflag)
		return;
	rsPADRE_set_cflag(tty->termios->c_cflag);
}


static void rsPADRE_stop(struct tty_struct *tty)
{
#ifdef DEBUG_RS
	printk("rsPADRE_stop\n");
#endif

#ifdef DO_RX_INTR
#ifdef OLD_CODE
	disable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL) & !PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
}

static void rsPADRE_start(struct tty_struct *tty)
{
#ifdef DEBUG_RS
	printk("rsPADRE_start\n");
#endif

#ifdef DO_RX_INTR
#ifdef OLD_CODE
	enable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL) | PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
}

static void rsPADRE_wait_until_sent(struct tty_struct *tty, int timeout)
{
	int orig_jiffies = jiffies;
#ifdef DEBUG_RS
	printk("wait_until_sent\n");
#endif
//	while (*CSR_UARTFLG & 8) {
	while (!(readl(PADRE_UART1_STAT) & 0x4)) {
		current->state = TASK_INTERRUPTIBLE;
		schedule_timeout(1);
		if (signal_pending(current))
			break;
		if (timeout && time_after(jiffies, orig_jiffies + timeout))
			break;
	}
	current->state = TASK_RUNNING;
}

static int rsPADRE_open(struct tty_struct *tty, struct file *filp)
{
	int line;
#ifdef DEBUG_RS
	printk("rsPADRE_open\n");
#endif

	MOD_INC_USE_COUNT;
	line = MINOR(tty->device) - tty->driver.minor_start;
	if (line) {
		MOD_DEC_USE_COUNT;
		return -ENODEV;
	}

	tty->driver_data = NULL;
	if (!rsPADRE_tty)
		rsPADRE_tty = tty;

#ifdef DO_RX_INTR
#ifdef OLD_CODE
	enable_irq(IRQ_CONRX);
#else
	writel((readl(PADRE_UART1_CTRL) | PADRE_UART1_CTRL_RI), 
		PADRE_UART1_CTRL);
#endif
#endif
	rsPADRE_use_count++;
	return 0;
}

static void rsPADRE_close(struct tty_struct *tty, struct file *filp)
{
	if (!--rsPADRE_use_count) {
		rsPADRE_wait_until_sent(tty, 0);
#ifdef DO_RX_INTR
#ifdef OLD_CODE
		disable_irq(IRQ_CONRX);
		disable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL) & !PADRE_UART1_CTRL_TI &
		!PADRE_UART1_CTRL_RI), PADRE_UART1_CTRL);
#endif
#endif
		rsPADRE_tty = NULL;
	}
	MOD_DEC_USE_COUNT;
}

static int __init rsPADRE_init(void)
{
	int baud = B9600;

/*
	if (machine_is_personal_server())
		baud = B57600;
*/

#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
	printk("rsPADRE_init\n");
#endif // CONFIG_PADRE_DEBUG_LEVEL_3
	rsPADRE_driver.magic = TTY_DRIVER_MAGIC;
	rsPADRE_driver.driver_name = "serial_PADRE";
	rsPADRE_driver.name = SERIAL_PADRE_NAME;
	rsPADRE_driver.major = SERIAL_PADRE_MAJOR;
	rsPADRE_driver.minor_start = SERIAL_PADRE_MINOR;
	rsPADRE_driver.num = 1;
	rsPADRE_driver.type = TTY_DRIVER_TYPE_SERIAL;
	rsPADRE_driver.subtype = SERIAL_TYPE_NORMAL;
	rsPADRE_driver.init_termios = tty_std_termios;
	rsPADRE_driver.init_termios.c_cflag = baud | CS8 | CREAD | HUPCL | CLOCAL;
	rsPADRE_driver.flags = TTY_DRIVER_REAL_RAW;
	rsPADRE_driver.refcount = &rsPADRE_refcount;
	rsPADRE_driver.table = rsPADRE_table;
	rsPADRE_driver.termios = rsPADRE_termios;
	rsPADRE_driver.termios_locked = rsPADRE_termios_locked;

	rsPADRE_driver.open = rsPADRE_open;
	rsPADRE_driver.close = rsPADRE_close;
	rsPADRE_driver.write = rsPADRE_write;
	rsPADRE_driver.put_char = rsPADRE_put_char;
	rsPADRE_driver.write_room = rsPADRE_write_room;
	rsPADRE_driver.chars_in_buffer = rsPADRE_chars_in_buffer;
	rsPADRE_driver.flush_buffer = rsPADRE_flush_buffer;
	rsPADRE_driver.throttle = rsPADRE_throttle;
	rsPADRE_driver.unthrottle = rsPADRE_unthrottle;
	rsPADRE_driver.send_xchar = rsPADRE_send_xchar;
	rsPADRE_driver.set_termios = rsPADRE_set_termios;
	rsPADRE_driver.stop = rsPADRE_stop;
	rsPADRE_driver.start = rsPADRE_start;
	rsPADRE_driver.wait_until_sent = rsPADRE_wait_until_sent;

	callout_driver = rsPADRE_driver;
	callout_driver.name = SERIAL_PADRE_AUXNAME;
	callout_driver.major = SERIAL_PADRE_AUXMAJOR;
	callout_driver.subtype = SERIAL_TYPE_CALLOUT;

	if (request_irq(IRQ_CONRX, rsPADRE_rx_tx_int, 0 /*SA_INTERRUPT*/, 
		"rsPADRE", NULL))
		panic("Couldn't get rx irq for rsPADRE");
/*
	if (request_irq(IRQ_CONTX, rsPADRE_tx_int, 0, "rsPADRE", NULL))
		panic("Couldn't get tx irq for rsPADRE");
*/
/*	
        writel(0xaa00, PADRE_GPIO_DIR); // set gpio pin for uart tx and rx
		if( readl(X2_SWITCH) & 0x1)
        	writel(PADRE_UART_9600_F, PADRE_UART1_SCAL); // set baud rate to 9600
		else
        	writel(PADRE_UART_9600, PADRE_UART1_SCAL); // set baud rate to 9600
*/

        writel(0x3, PADRE_UART1_CTRL);  // enable transmitter
        writel(0x07, PADRE_UART1_CTRL);  // enable transmitter, and RI
        writel(0x0, PADRE_UART1_STAT);  // clear error
	    writel((readl(PADRE_UART1_CTRL) | PADRE_UART1_CTRL_TI |
		PADRE_UART1_CTRL_RI), PADRE_UART1_CTRL);
 //       writel(0x7, PADRE_UART1_CTRL);  // enable transmitter, and RI
  //      writel(0x0, PADRE_UART1_STAT);  // clear error

#ifdef DEBUG_RS
	printk("rsPADRE_init U1_st=%x, U1_ct=%x\n", 
	(unsigned int)readl(PADRE_UART1_STAT),
	(unsigned int)readl(PADRE_UART1_CTRL));
#endif


	if (tty_register_driver(&rsPADRE_driver))
		printk(KERN_ERR "Couldn't register PADRE serial driver\n");
	if (tty_register_driver(&callout_driver))
		printk(KERN_ERR "Couldn't register PADRE callout driver\n");

	return 0;
}

static void __exit rsPADRE_fini(void)
{
	unsigned long flags;
	int ret;

	save_flags(flags);
	cli();
	ret = tty_unregister_driver(&callout_driver);
	if (ret)
		printk(KERN_ERR "Unable to unregister PADRE callout driver "
			"(%d)\n", ret);
	ret = tty_unregister_driver(&rsPADRE_driver);
	if (ret)
		printk(KERN_ERR "Unable to unregister PADRE driver (%d)\n",
			ret);

	free_irq(IRQ_CONTX, NULL);
//	free_irq(IRQ_CONRX, NULL);
	restore_flags(flags);
}

module_init(rsPADRE_init);
module_exit(rsPADRE_fini);

#ifndef CONFIG_SERIAL_PADRE_CONSOLE
/************** console driver *****************/

static void rsPADRE_console_write(struct console *co, const char *s, u_int count)
{
	int i;

#ifdef DEBUG_RS
	printk("rsPADRE_console_write *s=%s\n", s);
#endif

#ifdef DO_RX_INTR
#ifdef OLD_CODE
	disable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL) & !PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
	for (i = 0; i < count; i++) {
#ifdef OLD_CODE
		while (*CSR_UARTFLG & 0x20);
		*CSR_UARTDR = s[i];
		if (s[i] == '\n') {
			while (*CSR_UARTFLG & 0x20);
			*CSR_UARTDR = '\r';
		}
#else
		while (!(readl(PADRE_UART1_STAT) & PADRE_UART1_STAT_TH));
		writel(s[i], PADRE_UART1_DATA);
		if (s[i] == '\n') {
			while (!(readl(PADRE_UART1_STAT)&PADRE_UART1_STAT_TH));
			writel('\r', PADRE_UART1_DATA);
		}
#endif
	}
#ifdef DO_RX_INTR
#ifdef OLD_CODE
	enable_irq(IRQ_CONTX);
#else
	writel((readl(PADRE_UART1_CTRL) | PADRE_UART1_CTRL_TI), 
		PADRE_UART1_CTRL);
#endif
#endif
}

static int rsPADRE_console_wait_key(struct console *co)
{
	int c;

#ifdef DO_RX_INTR
#ifdef OLD_CODE
	disable_irq(IRQ_CONRX);
#else
	writel((readl(PADRE_UART1_CTRL) & !PADRE_UART1_CTRL_RI), 
		PADRE_UART1_CTRL);
#endif
#endif
	while (!(readl(PADRE_UART1_STAT) & PADRE_UART1_STAT_DR));
	c = readl(PADRE_UART1_DATA);
#ifdef DO_RX_INTR
#ifdef OLD_CODE
	enable_irq(IRQ_CONRX);
#else
	writel((readl(PADRE_UART1_CTRL) | PADRE_UART1_CTRL_RI), 
		PADRE_UART1_CTRL);
#endif
#endif
	return c;
}

static kdev_t rsPADRE_console_device(struct console *c)
{
	return MKDEV(SERIAL_PADRE_MAJOR, SERIAL_PADRE_MINOR);
}

static int __init rsPADRE_console_setup(struct console *co, char *options)
{
	int baud = 9600;
	int bits = 8;
	int parity = 'n';
	int cflag = CREAD | HUPCL | CLOCAL;

/*
	if (machine_is_personal_server())
		baud = 57600;
*/

	if (options) {
		char *s = options;
		baud = simple_strtoul(options, NULL, 10);
		while (*s >= '0' && *s <= '9')
			s++;
		if (*s)
			parity = *s++;
		if (*s)
			bits = *s - '0';
	}

	/*
	 *    Now construct a cflag setting.
	 */
	switch (baud) {
	case 1200:
		cflag |= B1200;
		break;
	case 2400:
		cflag |= B2400;
		break;
	case 4800:
		cflag |= B4800;
		break;
	case 9600:
		cflag |= B9600;
		break;
	case 19200:
		cflag |= B19200;
		break;
	case 38400:
		cflag |= B38400;
		break;
	case 57600:
		cflag |= B57600;
		break;
	case 115200:
		cflag |= B115200;
		break;
	default:
		cflag |= B9600;
		break;
	}
	switch (bits) {
	case 7:
		cflag |= CS7;
		break;
	default:
		cflag |= CS8;
		break;
	}
	switch (parity) {
	case 'o':
	case 'O':
		cflag |= PARODD;
		break;
	case 'e':
	case 'E':
		cflag |= PARENB;
		break;
	}
	co->cflag = cflag;
	rsPADRE_set_cflag(cflag);
	rsPADRE_console_write(NULL, "\e[2J\e[Hboot ", 12);
	if (options)
		rsPADRE_console_write(NULL, options, strlen(options));
	else
		rsPADRE_console_write(NULL, "no options", 10);
	rsPADRE_console_write(NULL, "\n", 1);

	return 0;
}

static struct console rsPADRE_cons =
{
	name:		SERIAL_PADRE_NAME,
	write:		rsPADRE_console_write,
	device:		rsPADRE_console_device,
	//wait_key:	rsPADRE_console_wait_key,
	setup:		rsPADRE_console_setup,
	flags:		CON_PRINTBUFFER,
	index:		-1,
};

extern void serial_console_init(void);
//void __init rsPADRE_console_init(void)
void __init serial_console_init(void)
{
	register_console(&rsPADRE_cons);
}

#endif	/* CONFIG_SERIAL_PADRE_CONSOLE */
