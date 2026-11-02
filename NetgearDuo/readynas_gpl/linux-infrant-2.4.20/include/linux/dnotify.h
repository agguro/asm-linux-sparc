/*
 * Directory notification for Linux
 *
 * Copyright (C) 2000,2002 Stephen Rothwell
 */
#ifdef CONFIG_PADRE_DNOTIFY
#include <linux/fs.h>
struct blockbuffer;
#endif // CONFIG_PADRE_DNOTIFY
struct dnotify_struct {
	struct dnotify_struct *	dn_next;
	unsigned long		dn_mask;	/* Events to be notified
						   see linux/fcntl.h */
	int			dn_fd;
	struct file *		dn_filp;
	fl_owner_t		dn_owner;
#ifdef CONFIG_PADRE_DNOTIFY
        size_t                  size;
        size_t                  max;
        char *                  buffer;
#endif // CONFIG_PADRE_DNOTIFY
};

#ifdef CONFIG_PADRE_DNOTIFY
int fcntl_dirnotify(int cmd,struct file *file,unsigned long arg);
int fcntl_getdirnotify(int cmd,struct file *file,unsigned long arg);
void dnotify_flush(struct file *file,fl_owner_t owner);
void dnotify_init_dentry(struct dentry *dentry);
void dnotify_dispose_dentry(struct dentry *dentry);
void dnotify_move_dentry(struct dentry *dentry);
void dnotify_access(struct dentry *dentry,loff_t off,size_t size);
void dnotify_modify(struct dentry *dentry,loff_t off,size_t size);
void dnotify_attrib(struct dentry *dentry,struct iattr *attr);
void dnotify_create(struct dentry *dentry);
void dnotify_delete(struct dentry *dentry);
void dnotify_mmap(struct dentry *dentry,unsigned long ofs,unsigned long len);
void dnotify_munmap(struct dentry *dentry);
void dnotify_mount(struct dentry *dentry);
void dnotify_unmount(struct dentry *dentry);
void dnotify_parent(struct dentry *dentry,unsigned long event,void *args,int nargs);
#else // CONFIG_PADRE_DNOTIFY
extern void __inode_dir_notify(struct inode *, unsigned long);
extern void dnotify_flush(struct file *filp, fl_owner_t id);
extern int fcntl_dirnotify(int, struct file *, unsigned long);

static inline void inode_dir_notify(struct inode *inode, unsigned long event)
{
	if ((inode)->i_dnotify_mask & (event))
		__inode_dir_notify(inode, event);
}

/*
 * This is hopelessly wrong, but unfixable without API changes.  At
 * least it doesn't oops the kernel...
 */
static inline void dnotify_parent(struct dentry *dentry, unsigned long event)
{
	struct dentry *parent;
	spin_lock(&dcache_lock);
	parent = dentry->d_parent;
	if (parent->d_inode->i_dnotify_mask & event) {
		dget(parent);
		spin_unlock(&dcache_lock);
		__inode_dir_notify(parent->d_inode, event);
		dput(parent);
	} else
		spin_unlock(&dcache_lock);
}
#endif // CONFIG_PADRE_DNOTIFY
