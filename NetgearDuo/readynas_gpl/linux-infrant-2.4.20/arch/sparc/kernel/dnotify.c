/*
 * Directory notifications for Linux.
 *
 * Copyright (C) 2003,2004 Rüdiger Klaehn
 * Copyright (C) 2000,2001,2002 Stephen Rothwell
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 */
//#include <linux/types.h>
#include <linux/list.h>
#include <linux/fs.h>
#include <linux/module.h>
#include <linux/sched.h>
#include <linux/init.h>
#include <linux/spinlock.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <asm/semaphore.h>
#include <asm/uaccess.h>
#include <linux/dcache.h>
#include "fcntl.h"
#include "changeinfo.h"
#define BUFFER_SIZE (4096*10)

struct dnotify_struct {
	struct dnotify_struct *	dn_next;
	unsigned long		dn_mask;	/* Events to be notified
						   see linux/fcntl.h */
	int			dn_fd;
	struct file *		dn_filp;
	fl_owner_t		dn_owner;
	size_t			size;
	size_t			max;
	char *			buffer;
};

struct dnotify_ops {
	void (*dnotify_flush)(struct file *,fl_owner_t);
	int (*fcntl_dirnotify)(int,struct file *,unsigned long);
	int (*fcntl_getdirnotify)(int,struct file *,unsigned long);
	void (*dnotify_init_dentry)(struct dentry *dentry);
	void (*dnotify_move_dentry)(struct dentry *dentry);
	void (*dnotify_dispose_dentry)(struct dentry *dentry);
	void (*dnotify_parent)(struct dentry *dentry,unsigned long event,void *args,int nargs);
};

static void postevent(struct dentry *dentry,unsigned long mask,void *blocks,int nblocks);

extern int dir_notify_enable;
extern struct dnotify_ops *dnotify_ops;

/* lock for all static dnotify stuff */
static spinlock_t dn_lock = SPIN_LOCK_UNLOCKED;
/* cache for dnotify_structs */
static kmem_cache_t *dn_cache;
/* cache for buffers */
static kmem_cache_t *dn_buffer_cache;

/* appends a block to a buffer */
static void __append(struct dnotify_struct *dn,struct block *block)
{
	if(dn->max+block->size<dn->size)
	{
		memcpy(dn->buffer+dn->max,block,block->size);
		dn->max+=block->size;
	}
}

/* calculates masks for a dentry */ 
static void __getmasks(struct dentry *dentry,unsigned long *mask,unsigned long *rmask)
{
	struct dnotify_struct *list;
	for(list=dentry->d_dnotify;list!=NULL;list=list->dn_next)
		*(list->dn_mask&DN_RECURSIVE?rmask:mask)|=list->dn_mask & ~DN_MULTISHOT;
}

/* initializes masks for a complete subtree in the dcache */
static void __initmasks(struct dentry *dentry,unsigned long pmask,unsigned long rmask)
{
	struct dentry *curr,*next;
	unsigned long temp=0,rtemp=0;
	__getmasks(dentry,&temp,&rtemp);
	dentry->d_dn_mask=temp|rtemp;
	dentry->d_dn_rmask=rmask|pmask;
	rmask|=rtemp;
	pmask=temp;
	list_for_each_entry_safe(curr,next,&dentry->d_subdirs,d_child)
		__initmasks(curr,pmask,rmask);
}

/* initializes masks for a complete subtree */
static void initmasks(struct dentry *dentry) 
{
//	printk("dentry=%p\ndentry->parent=%p\n",dentry,dentry->d_parent);
	unsigned long pmask=0;
	unsigned long rmask=0;
	struct dentry *parent=dentry->d_parent;
	if(parent!=NULL && parent!=dentry) {
		__getmasks(parent,&pmask,&rmask);
		pmask|=rmask;
		rmask|=parent->d_dn_rmask;
	}
	__initmasks(dentry,pmask,rmask);
}

/* registers dentry names for a complete subtree */
static void __registernames(struct dentry *droot,struct dentry *dentry) {
	struct dentry *curr,*next;
	struct dnotify_struct *dn;
	struct registerinfo info;
	spin_lock(&dcache_lock);
	registerinfo_init(&info,dentry);
	for(dn=droot->d_dnotify;dn!=NULL;dn=dn->dn_next)
		__append(dn,(struct block*)&info);
	list_for_each_entry_safe(curr,next,&dentry->d_subdirs,d_child)
		__registernames(droot,curr);
	spin_unlock(&dcache_lock);
}

/* registers dentry names for a complete subtree */
static void registernames(struct dentry *dentry) {
	if(dentry->d_dn_mask&DN_REGISTER)
		__registernames(dentry,dentry);
}

/* cleans up for a file */
void local_dnotify_flush(struct file *filp, fl_owner_t id)
{
//	printk("local_dnotify_flush %p\n",filp->f_dentry->d_dnotify);
	struct dnotify_struct *dn;
	struct dnotify_struct **prev;
	struct dentry *dentry;

	dentry = filp->f_dentry;
	spin_lock(&dn_lock);
	prev = &dentry->d_dnotify;
	while ((dn = *prev) != NULL) {
		if ((dn->dn_owner == id) && (dn->dn_filp == filp)) {
			*prev = dn->dn_next;
			if(dn->buffer!=NULL)
				kmem_cache_free(dn_buffer_cache, dn->buffer);
			kmem_cache_free(dn_cache, dn);
			break;
		}
		prev = &dn->dn_next;
	}
	spin_unlock(&dn_lock);
}

/* ioctl to get the dirnotify event buffer */
int local_fcntl_getdirnotify(int fd, struct file *filp, unsigned long arg)
{
	size_t oldmax;
	struct dnotify_struct *dn;
	struct block *data=(struct block*)arg;
	fl_owner_t id = current->files;
	int nread=0;
	char *tempbuffer=kmem_cache_alloc(dn_buffer_cache,SLAB_KERNEL);
	if(tempbuffer == NULL)
	{
#ifdef CONFIG_PADRE_DEBUG_LEVEL_3
		printk("Warning: can not allocate a buffer from the dn_buffer_cache");
#endif
		return nread;
	}

	spin_lock(&dn_lock);
	for(dn=filp->f_dentry->d_dnotify;dn!=NULL;dn=dn->dn_next)
		if ((dn->dn_owner == id) && (dn->dn_filp == filp))
			break;
	if(dn!=NULL && dn->buffer!=NULL) {
		char *t=dn->buffer;
		dn->buffer=tempbuffer;
		tempbuffer=t;
		oldmax=dn->max;
		dn->max=0;
		spin_unlock(&dn_lock);
		/* the copying to userspace has to happen outside the lock since it might sleep */
		copy_from_user(&nread,data,sizeof(nread));
		if(nread>oldmax)
			nread=oldmax;
		copy_to_user(data,tempbuffer,nread);
	} else spin_unlock(&dn_lock);
	kmem_cache_free(dn_buffer_cache,tempbuffer);
	return nread;
}

extern int f_setown(struct file *filp, unsigned long arg, int force);
extern void send_sigio(struct fown_struct *fown, int fd, int band);

int local_fcntl_dirnotify(int fd, struct file *filp, unsigned long arg)
{
	struct dnotify_struct *dn,*newdn;
	struct dentry *dentry;
	fl_owner_t id = current->files;
	int error = 0;

//	printk("fcnlt_dirnotify pid=%d mask=%lx name=%s\n",current->pid,arg,filp->f_dentry->d_name.name);	

	if ((arg & ~DN_MULTISHOT) == 0) {
		local_dnotify_flush(filp, id);
		return 0;
	}
	if (!dir_notify_enable)
		return -EINVAL;
		
	error = -ENOMEM;
	newdn = kmem_cache_alloc(dn_cache, SLAB_KERNEL);
	if (newdn == NULL)
		goto out;
	newdn->dn_mask = arg;
	newdn->dn_fd = fd;
	newdn->dn_filp = filp;
	newdn->dn_owner = id;
	if((arg&DN_EXTENDED)!=0) {
		newdn->buffer = kmem_cache_alloc(dn_buffer_cache, SLAB_KERNEL);
		if (newdn->buffer == NULL)
			goto out;
		newdn->size=BUFFER_SIZE;
		newdn->max=0;
	} else {
		newdn->buffer = NULL;
		newdn->size=0;
		newdn->max=0;
	}
	
	error=-EINVAL;
	dentry = dget(filp->f_dentry);
	if (dentry==NULL)
		goto out;
	shrink_dcache_parent(dentry);
	spin_lock(&dn_lock);
	
	for(dn=dentry->d_dnotify;dn!=NULL;dn=dn->dn_next)
		if ((dn->dn_owner == id) && (dn->dn_filp == filp)) {
			dn->dn_fd = fd;
			dn->dn_mask |= arg;
			goto unlock;
		}

	error = f_setown(filp, current->pid, 0);
  	if (error)
		goto unlock;

	newdn->dn_next = dentry->d_dnotify;
	dentry->d_dnotify = newdn;
	initmasks(dentry);
	registernames(dentry);
	newdn=NULL;
unlock:
	spin_unlock(&dn_lock);
	dput(dentry);
out:
	if(newdn!=NULL)
	{
		if(newdn->buffer!=NULL)
			kmem_cache_free(dn_buffer_cache,newdn->buffer);
		kmem_cache_free(dn_cache,newdn);
	}
	return error;
}

static void consumeevent(struct dentry *dentry,unsigned long event,void *args,int nargs) {
	struct block *info=args;
	struct dnotify_struct *	dn;
	struct dnotify_struct **prev;
	struct fown_struct *	fown;
	int			changed = 0;

	spin_lock(&dn_lock);
	prev = &dentry->d_dnotify;
	while ((dn = *prev) != NULL) {
		if ((dn->dn_mask & event) == 0) {
			prev = &dn->dn_next;
			continue;
		}
		while(nargs>0) {
			__append(dn,info);
			info=block_next(info);
			nargs--;
		}
		fown = &dn->dn_filp->f_owner;
		send_sigio(fown, dn->dn_fd, POLL_MSG);
		if (dn->dn_mask & DN_MULTISHOT)
			prev = &dn->dn_next;
		else {
			*prev = dn->dn_next;
			changed = 1;
			kmem_cache_free(dn_buffer_cache, dn->buffer);
			kmem_cache_free(dn_cache, dn);
		}
	}
	if (changed)
		initmasks(dentry);
	spin_unlock(&dn_lock);
}

/* this crawls up the dentry tree, delivering the event to all interested parties */
static void postevent(struct dentry *dsource,unsigned long event,void *args,int nargs) {
	struct dentry *dparent;
	struct dentry *dentry=dsource;
	spin_lock(&dcache_lock);
	while(1) {
		//deliver event
		if(dentry->d_dn_mask&event)
			consumeevent(dentry, event, args,nargs);
		//we are at the root
		if(dentry->d_parent==dentry || dentry->d_parent==NULL)
			break;
		//the parent dentry is not interested in this event.
		if((dentry->d_dn_rmask&event)==0) 
			break;
		//move to parent with interlock
		dparent=dentry->d_parent;
//		spin_lock(&dparent->d_lock);
//		spin_unlock(&dentry->d_lock);
		dentry=dparent;
	}
	spin_unlock(&dcache_lock);
}

/* this is the entry point to the dnotify mechanism. */
static void dnotify_parent(struct dentry *dentry,unsigned long event,void *args,int nargs)
{
	struct changeinfo info;
	struct changeinfo *param=(struct changeinfo*)args;
	if(param!=NULL && nargs>0 && param->size>=sizeof(struct changeinfo) && param->size<=sizeof(struct block))
	{
		postevent(dentry,event,args,nargs);
	} else {
		int type;
		for(type=0;type<32;type++)
			if((1<<type)==event)
				break;
		changeinfo_init(&info,dentry,type);
		postevent(dentry,event,&info,1);
	}
}

static void dnotify_init_dentry(struct dentry *dentry)
{
	struct registerinfo info;
	initmasks(dentry);
	registerinfo_init(&info,dentry);
	postevent(dentry,1<<info.type,&info,1);
}

static void dnotify_move_dentry(struct dentry *dentry)
{
	initmasks(dentry);
	registernames(dentry);
}

static void dnotify_dispose_dentry(struct dentry *dentry)
{
	struct changeinfo info;
	changeinfo_init(&info,dentry,DNT_UNREGISTER);
	postevent(dentry,DN_UNREGISTER,&info,1);
}

struct dnotify_ops my_dnotify_ops={
	.dnotify_init_dentry=dnotify_init_dentry,
	.dnotify_parent=dnotify_parent,
	.dnotify_flush=local_dnotify_flush,
	.dnotify_dispose_dentry=dnotify_dispose_dentry,
	.dnotify_move_dentry=dnotify_move_dentry,
	.fcntl_dirnotify=local_fcntl_dirnotify,
	.fcntl_getdirnotify=local_fcntl_getdirnotify
};

static int __init dnotify_init(void)
{
	printk("DDDD: create cache - dnotify_cache\n");
	dn_cache = kmem_cache_create("dnotify_cache",
		sizeof(struct dnotify_struct), 0, 0, NULL, NULL);
	if (!dn_cache)
		panic("cannot create dnotify slab cache");

	printk("DDDD: create cache - dn_buffer_cache (%d)\n", BUFFER_SIZE);
	dn_buffer_cache = kmem_cache_create("dn_buffer_cache",
		BUFFER_SIZE, 0, 0, NULL, NULL);
	if(!dn_buffer_cache)
		panic("cannot create dnotify buffer slab cache");

	dnotify_ops=&my_dnotify_ops;
	return 0;
}

static void __exit dnotify_exit(void)
{
	kmem_cache_destroy(dn_buffer_cache);
	kmem_cache_destroy(dn_cache);
	dnotify_ops=NULL;
}

module_init(dnotify_init);
module_exit(dnotify_exit);
MODULE_LICENSE("GPL");
