/*
 * Padre Performance Statistics.
 *
 * Infrant Technologies, Inc. Proprietary and Confidential
 *         Copyright (c) 2001, INFRANT
 *         All Rights Reserved
 *
 * (C) Copyright Infrant Technologies, Inc.  2003
 *
 */
#ifndef PADRE_PERF_INCLUDED
#define PADRE_PERF_INCLUDED


#ifdef CONFIG_PADRE_PERFSTATS

static unsigned __inline__ perf_clock(void) {
	// Read Event Counter 0
	writel(0x00,PADRE_GPIO_EVC_CMD);
	// The highest bit is an overflow bit.
	return readl(PADRE_GPIO_EVC_VALUE) & 0x7FFFFFFF;
}

struct perf_stats {
	u32 time;
	u32 counter;
	u32 mintime;
	u32 maxtime;
	u64 sumtime;
	u32 minsize;
	u32 maxsize;
	u64 sumsize;
};

// Initialize the performance module
void perf_init(struct perf_stats *p);

void perf_measurement(struct perf_stats *p,u32 m,u32 t);

// static void __inline__ perf_clock_start(struct perf_stats *p) {
//	p->time=perf_clock();
//}

#define perf_clock_start(x) pperf.x.time=perf_clock()

// Ignore the topmost two bits which might be there because of timer wraparound
#define TIME_DIFF(x1,x2) (((x1)-(x2)))

// static void __inline__ perf_clock_stop(struct perf_stats *p,unsigned size) {
//	perf_measurement(p,size,TIME_DIFF(perf_clock(),p->time));	
//}

#define perf_clock_stop(x,size) perf_measurement(&pperf.x,size,TIME_DIFF(perf_clock(),pperf.x.time))

#define perf_size(x,size) perf_measurement(&pperf.x,size,0)

// List of supported statistics counters by the perf.c module. Add new counters
// here and then add the necessary lines to display the contents in perf.c
struct pstats {
  struct perf_stats cacheflush;
  struct perf_stats dcache_clean_range;
  struct perf_stats icache;
  struct perf_stats icache_page;
  unsigned dflush_pci_map_single;
  unsigned dflush_pci_sync_single;
  unsigned dflush_des3_decrypt;
  unsigned dflush_des3_encrypt;
  unsigned dflush_memdma;
  unsigned dflush_ide;
  unsigned dflush_gmac_skb_alloc;
  unsigned dflush_gmac_tx_m4;
  unsigned dflush_gmac_xmit;
  unsigned dflush_gmac_smart;
  struct perf_stats gmac_xmit_start;
  struct perf_stats gmac_receive;
  struct perf_stats gmac_receive_sizes;
  struct perf_stats gmac_tx_cleanup;
  struct perf_stats gmac_xmit_totproc;
#ifdef CONFIG_PADRE_GMAC_M4_BURST
  struct perf_stats gmac_xmit_burst;
  unsigned gmac_tx_cleanup_overdue;
  unsigned gmac_burst_empty;
  unsigned gmac_xmit_noburst;
  unsigned gmac_opport_burst;
#endif
  struct perf_stats raid_make_request;
  struct perf_stats ide_start_request;
  struct perf_stats raid_handle_stripe;
  struct perf_stats skb_copy_bits;
  struct perf_stats skb_checksum;
  struct perf_stats skb_copy_csum;
  struct perf_stats memcpy_toiovec;
  struct perf_stats memcpy_tokerneliovec;
  struct perf_stats memcpy_fromiovec;
  struct perf_stats memcpy_fromiovecend;
  struct perf_stats copy_to_user;
  struct perf_stats copy_from_user;
  struct perf_stats csum_pcf;
  struct perf_stats sys_sendfile;
  struct perf_stats sys_read;
  struct perf_stats sys_write;
  struct perf_stats read_readpage;
  struct perf_stats read_actor;
  struct perf_stats sys_sendto;
  struct perf_stats sys_pread;
  struct perf_stats sys_pwrite;
  struct perf_stats sock_sendmsg;
  struct perf_stats sock_recvmsg;
  unsigned bad_event_data;
};

extern struct pstats pperf;

void perfstat_init(void);

#define perf_count(x) pperf.x++

#else
#define perf_init(x)
#define perf_measurement(x,y,z)
#define perf_clock_start(x)
#define perf_clock_stop(x,y)
#define perf_count(x)
#define perf_size(x,y)
#endif

#endif
