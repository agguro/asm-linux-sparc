/*
 * Directory notifications for Linux.
 *
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
#ifndef CONFIG_PADRE_DNOTIFY
#include <linux/fs.h>
#include <linux/sched.h>
#endif
#include <linux/dnotify.h>
#include <linux/init.h>
#include <linux/spinlock.h>
#include <linux/slab.h>
#ifdef CONFIG_PADRE_DNOTIFY
#include <linux/changeinfo.h>
#endif // CONFIG_PADRE_DNOTIFY

#ifndef CONFIG_PADRE_DNOTIFY
extern void send_sigio(struct fown_struct *fown, int fd, int band);

int dir_notify_enable = 1;

static rwlock_t dn_lock = RW_LOCK_UNLOCKED;
static kmem_cache_t *dn_cache;

static void redo_inode_mask(struct inode *inode)
{
	unsigned long new_mask;
	struct dnotify_struct *dn;

	new_mask = 0;
	for (dn = inode->i_dnotify; dn != NULL; dn = dn->dn_next)
		new_mask |= dn->dn_mask & ~DN_MULTISHOT;
	inode->i_dnotify_mask = new_mask;
}

void dnotify_flush(struct file *filp, fl_owner_t id)
{
	struct dnotify_struct *dn;
	struct dnotify_struct **prev;
	struct inode *inode;

	inode = filp->f_dentry->d_inode;
	if (!S_ISDIR(inode->i_mode))
		return;
	write_lock(&dn_lock);
	prev = &inode->i_dnotify;
	while ((dn = *prev) != NULL) {
		if ((dn->dn_owner == id) && (dn->dn_filp == filp)) {
			*prev = dn->dn_next;
			redo_inode_mask(inode);
			kmem_cache_free(dn_cache, dn);
			break;
		}
		prev = &dn->dn_next;
	}
	write_unlock(&dn_lock);
}

int fcntl_dirnotify(int fd, struct file *filp, unsigned long arg)
{
	struct dnotify_struct *dn;
	struct dnotify_struct *odn;
	struct dnotify_struct **prev;
	struct inode *inode;
	fl_owner_t id = current->files;

	if ((arg & ~DN_MULTISHOT) == 0) {
		dnotify_flush(filp, id);
		return 0;
	}
	if (!dir_notify_enable)
		return -EINVAL;
	inode = filp->f_dentry->d_inode;
	if (!S_ISDIR(inode->i_mode))
		return -ENOTDIR;
	dn = kmem_cache_alloc(dn_cache, SLAB_KERNEL);
	if (dn == NULL)
		return -ENOMEM;
	write_lock(&dn_lock);
	prev = &inode->i_dnotify;
	while ((odn = *prev) != NULL) {
		if ((odn->dn_owner == id) && (odn->dn_filp == filp)) {
			odn->dn_fd = fd;
			odn->dn_mask |= arg;
			inode->i_dnotify_mask |= arg & ~DN_MULTISHOT;
			kmem_cache_free(dn_cache, dn);
			goto out;
		}
		prev = &odn->dn_next;
	}
	filp->f_owner.pid = current->pid;
	filp->f_owner.uid = current->uid;
	filp->f_owner.euid = current->euid;
	dn->dn_mask = arg;
	dn->dn_fd = fd;
	dn->dn_filp = filp;
	dn->dn_owner = id;
	inode->i_dnotify_mask |= arg & ~DN_MULTISHOT;
	dn->dn_next = inode->i_dnotify;
	inode->i_dnotify = dn;
out:
	write_unlock(&dn_lock);
	return 0;
}

void __inode_dir_notify(struct inode *inode, unsigned long event)
{
	struct dnotify_struct *	dn;
	struct dnotify_struct **prev;
	struct fown_struct *	fown;
	int			changed = 0;

	write_lock(&dn_lock);
	prev = &inode->i_dnotify;
	while ((dn = *prev) != NULL) {
		if ((dn->dn_mask & event) == 0) {
			prev = &dn->dn_next;
			continue;
		}
		fown = &dn->dn_filp->f_owner;
		if (fown->pid)
		        send_sigio(fown, dn->dn_fd, POLL_MSG);
		if (dn->dn_mask & DN_MULTISHOT)
			prev = &dn->dn_next;
		else {
			*prev = dn->dn_next;
			changed = 1;
			kmem_cache_free(dn_cache, dn);
		}
	}
	if (changed)
		redo_inode_mask(inode);
	write_unlock(&dn_lock);
}

static int __init dnotify_init(void)
{
	printk("DD: create cache - dnotify_cache\n");
	dn_cache = kmem_cache_create("dnotify_cache",
		sizeof(struct dnotify_struct), 0, 0, NULL, NULL);
	if (!dn_cache)
		panic("cannot create dnotify slab cache");
	return 0;
}

module_init(dnotify_init)

#else  // CONFIG_PADRE_DNOTIFY

int dir_notify_enable = 1;

struct dnotify_ops {
        void (*dnotify_flush)(struct file *,fl_owner_t);
        int (*fcntl_dirnotify)(int,struct file *,unsigned long);
        int (*fcntl_getdirnotify)(int,struct file *,unsigned long);
        void (*dnotify_init_dentry)(struct dentry *dentry);
        void (*dnotify_move_dentry)(struct dentry *dentry);
        void (*dnotify_dispose_dentry)(struct dentry *dentry);
        void (*dnotify_parent)(struct dentry *dentry,unsigned long event,void *args,int nargs);
};

struct dnotify_ops *dnotify_ops;
EXPORT_SYMBOL(dnotify_ops);
extern void send_sigio(struct fown_struct *fown,int fd,int band);
EXPORT_SYMBOL(send_sigio);
static inline int check(struct dentry *dentry,unsigned long mask) {
        return (dentry->d_dn_mask|dentry->d_dn_rmask)&mask;
}

void dnotify_flush(struct file *file,fl_owner_t owner)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)ops->dnotify_flush(file,owner);
}
int fcntl_dirnotify(int cmd,struct file *file,unsigned long arg)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)return ops->fcntl_dirnotify(cmd,file,arg);
        else return -EFAULT;
}
int fcntl_getdirnotify(int cmd,struct file *file,unsigned long arg)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)return ops->fcntl_getdirnotify(cmd,file,arg);
        else return -EFAULT;
}
void dnotify_init_dentry(struct dentry *dentry)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)ops->dnotify_init_dentry(dentry);
}
void dnotify_move_dentry(struct dentry *dentry)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)ops->dnotify_move_dentry(dentry);
}
void dnotify_dispose_dentry(struct dentry *dentry)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)ops->dnotify_dispose_dentry(dentry);
}
void dnotify_parent(struct dentry *dentry,unsigned long event,void *args,int nargs)
{
        struct dnotify_ops *ops=dnotify_ops;
        if(ops!=NULL)ops->dnotify_parent(dentry,event,args,nargs);
}
void dnotify_create(struct dentry *dentry)
{
        if(!check(dentry,DN_CREATE))
                return;
        dnotify_parent(dentry,DN_CREATE,NULL,0);
}
void dnotify_delete(struct dentry *dentry)
{
        if(!check(dentry,DN_DELETE))
                return;
        dnotify_parent(dentry,DN_DELETE,NULL,0);
}
void dnotify_access(struct dentry *dentry,loff_t off,size_t size)
{
	struct rwinfo rwinfo;
        if(!check(dentry,DN_ACCESS))
                return;
        rwinfo_init(&rwinfo,dentry,DNT_ACCESS,off,size);
        dnotify_parent(dentry,DN_ACCESS,&rwinfo,1);
}
void dnotify_modify(struct dentry *dentry,loff_t off,size_t size)
{
	struct rwinfo rwinfo;
        if(!check(dentry,DN_MODIFY))
                return;
        rwinfo_init(&rwinfo,dentry,DNT_MODIFY,off,size);
        dnotify_parent(dentry,DN_MODIFY,&rwinfo,1);
}
void dnotify_attrib(struct dentry *dentry,struct iattr *attr)
{
	struct attribinfo attribinfo;
        if(!check(dentry,DN_ATTRIB))
                return;
        attribinfo_init(&attribinfo,dentry,attr);
        dnotify_parent(dentry,DN_ATTRIB,&attribinfo,1);
}
void dnotify_mmap(struct dentry *dentry,unsigned long ofs,unsigned long len)
{
	struct changeinfo info;
        if(!check(dentry,DN_MMAP))
                return;
        changeinfo_init(&info,dentry,DNT_MMAP);
        dnotify_parent(dentry,DN_MMAP,&info,1);
}
void dnotify_munmap(struct dentry *dentry)
{
	struct changeinfo info;
        if(!check(dentry,DN_MUNMAP))
                return;
        changeinfo_init(&info,dentry,DNT_MUNMAP);
        dnotify_parent(dentry,DN_MUNMAP,&info,1);
}
void dnotify_mount(struct dentry *dentry)
{
	struct changeinfo info;
        if(!check(dentry,DN_MOUNT))
                return;
        changeinfo_init(&info,dentry,DNT_MOUNT);
        dnotify_parent(dentry,DN_MOUNT,&info,1);
}
void dnotify_unmount(struct dentry *dentry)
{
	struct changeinfo info;
        if(!check(dentry,DN_UNMOUNT))
                return;
        changeinfo_init(&info,dentry,DNT_UNMOUNT);
        dnotify_parent(dentry,DN_UNMOUNT,&info,1);
}
#endif // CONFIG_PADRE_DNOTIFY
