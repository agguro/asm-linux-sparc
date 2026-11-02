/* $Id: cache.h,v 1.9 1999/08/14 03:51:58 anton Exp $
 * cache.h:  Cache specific code for the Sparc.  These include flushing
 *           and direct tag/data line access.
 *
 * Copyright (C) 1995 David S. Miller (davem@caip.rutgers.edu)
 */

#ifndef _SPARC_CACHE_H
#define _SPARC_CACHE_H

#define L1_CACHE_BYTES 32

#ifdef CONFIG_PADRE_DC3
/* Lock down cache define */
#define __dc3data  __attribute__ ((__section__ (".dc3.init"))) 
#define __DC3DATA   .section    ".dc3.init","aw"  
#else
#define __dc3data
#define __DC3DATA
#endif

#ifdef CONFIG_PADRE_IC3
#define __ic3call  __attribute__ ((__section__ (".ic3.init"))) 
#define __IC3CALL	.section	".ic3.init","ax"
#else
#define __ic3call
#define __IC3CALL
#endif

#ifndef __ASSEMBLY__
extern unsigned long icmu_ctrl,dcmu_ctrl; 
#endif

#endif /* !(_SPARC_CACHE_H) */
