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
#define DNT_UNMOUNT	11

struct block
{
	size_t size;
	char data[512-sizeof(size_t)];
};


/*
 * this is the "base class". The type field determines the type. This can be
 * used for all types that require no further data, such as 
 * -deleting a file
 * -removing a dentry from the dcache
 */
struct changeinfo /* :block*/ {
	size_t size;
	unsigned long type;
	pid_t pid;
	unsigned long id;
};

/* 
 * This is used for name creation. It is the only type of type 
 * that has a variable length. That is why the constructor is a bit more
 * complicated for this one.
 */
struct registerinfo /* :changeinfo*/ {
	size_t size;
	unsigned long type;
	pid_t pid;
	unsigned long id;
	unsigned long parentid;
	char text[sizeof(struct block)-sizeof(unsigned long)*3-sizeof(size_t)];
};
/*
 * this is used for file creations
 */
struct createinfo {
	size_t size;
	unsigned long type;
	pid_t pid;
	unsigned long id;
	int mode;
	dev_t dev;
};
/* 
 * this is used for attribute changes.
 * I could copy the whole iattr struct into this?
 */
struct attribinfo {
	size_t size;
	unsigned long type;
	pid_t pid;
	unsigned long id;
	unsigned int ia_valid;
};

/*
 * this is used for read and write access.
 */
struct rwinfo {
	size_t size;
	unsigned long type;
	pid_t pid;
	unsigned long id;
	loff_t foff;
	size_t fsize;
};

/*
 * Changeinfo structs are created in kernel space and consumed in user space.
 * So we do not need the constructors in user space.
 */
#ifdef __KERNEL__
static inline int block_copy(struct block *dst,struct block *src) 
{
	if(dst->size>=src->size) {
		memcpy(dst,src,src->size);
		return 0;
	} else {
		memcpy(dst,src,dst->size);
		return -1;
	}
}

static inline struct block *block_next(struct block *block) 
{
	char *temp=(char*)block;
	//sanity check
	if(block->size<4 || block->size>sizeof(struct block))
		BUG();
	temp+=block->size;
	return (struct block*)temp;
}

/*
 * this is how we create a unique id for a dentry.
 * Currently we just return the address of the dentry.
 * We might also use something more sophisticated like a lossless hash.
 * Is it a security risk to let the userspace know the dentry adresses?
 * I don't think so. 
 */
static inline unsigned long getid(struct dentry *dentry) {
	return (unsigned long)dentry;
}

static inline void changeinfo_init(struct changeinfo *info,struct dentry *dentry,unsigned long type) {
	info->size=sizeof(*info);
	info->type=type;
	info->pid=current->pid;
	info->id=getid(dentry);
}

static inline void registerinfo_init(
		struct registerinfo *info,
		struct dentry *dentry)
{
	const int min=offsetof(struct registerinfo,text);
	const int max=sizeof(struct registerinfo);
	int n=dentry->d_name.len;
	if(n>max-min)
		n=max-min;
	info->size=min;
	info->type=DNT_REGISTER;
	info->pid=current->pid;
	info->id=getid(dentry);
	info->parentid=getid(dentry->d_parent);
	memcpy(info->text,dentry->d_name.name,n);
	info->size+=n;
}

static inline void attribinfo_init(struct attribinfo *info,struct dentry *dentry,struct iattr *attr)
{
	info->size=sizeof(struct attribinfo);
	info->type=DNT_ATTRIB;
	info->pid=current->pid;
	info->id=getid(dentry);
	info->ia_valid=attr->ia_valid;
}

static inline void rwinfo_init(struct rwinfo *info,struct dentry *dentry,unsigned long type,loff_t foff,size_t fsize)
{
	info->size=sizeof(struct rwinfo);
	info->type=type;
	info->pid=current->pid;
	info->id=getid(dentry);
	info->foff=foff;
	info->fsize=fsize;
}
#endif
