/*
 * Directory notification for Linux
 *
 * Copyright (C) 2003,2004 Rüdiger Klaehn
 * Copyright (C) 2000,2002 Stephen Rothwell
 */
/*
 * Types of directory notifications that may be requested.
 */
#define DNT_ACCESS	0
#define DNT_MODIFY	1
#define DNT_CREATE	2
#define DNT_DELETE	3
#define DNT_RENAME	4
#define DNT_ATTRIB	5
#define DNT_REGISTER	6
#define DNT_UNREGISTER	7
#define DNT_MMAP	8
#define DNT_MUNMAP	9
#define DNT_MOUNT	10
#define DNT_UMOUNT	11

#define DN_ACCESS	0x00000001	/* File accessed */
#define DN_MODIFY	0x00000002	/* File modified */
#define DN_CREATE	0x00000004	/* File created */
#define DN_DELETE	0x00000008	/* File removed */
#define DN_RENAME	0x00000010	/* File renamed */
#define DN_ATTRIB	0x00000020	/* File changed attibutes */

#define DN_REGISTER	0x00000040	/* Positive dentry is registered */
#define DN_UNREGISTER	0x00000080	/* Name destruction */

//#define DN_MMAP		(1<<DNT_MMAP)
//#define DN_MUNMAP	(1<<DNT_MUNMAP)
//#define DN_MOUNT	(1<<DNT_MOUNT)
#define DN_UMOUNT	(1<<DNT_UMOUNT)

#define DN_EXTENDED	0x20000000	/* Extended notification */
#define DN_RECURSIVE	0x40000000	/* Recursive notification */
#define DN_MULTISHOT	0x80000000	/* Don't remove notifier */

#define BUFFER_SIZE 4096*10
