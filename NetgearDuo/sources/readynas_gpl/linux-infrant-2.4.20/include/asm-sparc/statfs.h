/* $Id: statfs.h,v 1.4 1996/06/07 00:41:05 ecd Exp $ */
#ifndef _SPARC_STATFS_H
#define _SPARC_STATFS_H

#ifndef __KERNEL_STRICT_NAMES

#include <linux/types.h>

typedef __kernel_fsid_t	fsid_t;

#endif

struct statfs {
	long f_type;
	long f_bsize;
	long f_blocks;
	long f_bfree;
	long f_bavail;
	long f_files;
	long f_ffree;
	__kernel_fsid_t f_fsid;
	long f_namelen;  /* SunOS ignores this field. */
//        long f_frsize;
	long f_spare[6];
};

/*
struct statfs64 {
        long f_type;
        long f_bsize;
        long f_blocks;
        long f_bfree;
        long f_bavail;
        long f_files;
        long f_ffree;
        __kernel_fsid_t f_fsid;
        long f_namelen;
        long f_frsize;
        long f_spare[5];
};
*/

struct statfs64 {
        __u32 f_type;
        __u32 f_bsize;
        __u64 f_blocks;
        __u64 f_bfree;
        __u64 f_bavail;
        __u64 f_files;
        __u64 f_ffree;
        __kernel_fsid_t f_fsid;
        __u32 f_namelen;
        __u32 f_frsize;
        __u32 f_spare[5];
};

#endif
