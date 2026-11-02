/* -*- c-file-style: "linux" -*-
   Copyright (C) Andrew Tridgell 1996
   Copyright (C) Paul Mackerras 1996

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

/* handle passing ACLs between systems */

#include "rsync.h"
#include "lib/sysacls.h"

#if SUPPORT_ACLS

extern int preserve_acls;
extern int am_root;
extern int dry_run;

typedef struct {
	id_t id;
	uchar access;
	SMB_ACL_TAG_T tag_type;
} rsync_ace;

typedef struct {
	size_t count;
	size_t malloced;
	rsync_ace *races;
} rsync_acl;

static const rsync_acl rsync_acl_initializer = { 0, 0, NULL };

static void expand_rsync_acl(rsync_acl *racl)
{
	/* first time through, 0 <= 0, so list is expanded:
	 * diabolical, rsync guys! */
	if (racl->malloced <= racl->count) {
		rsync_ace *new_ptr;
		size_t new_size = racl->malloced + 10;
		new_ptr = realloc_array(racl->races, rsync_ace, new_size);
		if (verbose >= 4) {
			rprintf(FINFO, "expand rsync_acl to %.0f bytes, did%s move\n",
				(double) new_size * sizeof racl->races[0],
				racl->races ? "" : " not");
		}

		racl->races = new_ptr;
		racl->malloced = new_size;

		if (!racl->races)
			out_of_memory("expand_rsync_acl");
	}
}

static void rsync_acl_free(rsync_acl *racl)
{
	free(racl->races);
	racl->races = NULL;
	racl->count = 0;
	racl->malloced = 0;
}

static int rsync_ace_sorter(const void *r1, const void *r2)
{
	rsync_ace *race1 = (rsync_ace *)r1;
	SMB_ACL_TAG_T rtag1 = race1->tag_type;
	id_t rid1 = race1->id;
	rsync_ace *race2 = (rsync_ace *)r2;
	SMB_ACL_TAG_T rtag2 = race2->tag_type;
	id_t rid2 = race2->id;
	/* start at the extrema */
	if (rtag1 == SMB_ACL_USER_OBJ || rtag2 == SMB_ACL_MASK)
		return -1;
	if (rtag2 == SMB_ACL_USER_OBJ || rtag1 == SMB_ACL_MASK)
		return 1;
	/* work inwards */
	if (rtag1 == SMB_ACL_OTHER)
		return 1;
	if (rtag2 == SMB_ACL_OTHER)
		return -1;
	/* only SMB_ACL_USERs and SMB_ACL_GROUP*s left */
	if (rtag1 == SMB_ACL_USER) {
		switch (rtag2) {
		case SMB_ACL_GROUP:
		case SMB_ACL_GROUP_OBJ:
		case SMB_ACL_OTHER:
			return -1;
		}
		/* both USER */
		return rid1 == rid2 ? 0 : rid1 < rid2 ? -1 : 1;
	}
	if (rtag2 == SMB_ACL_USER)
		return 1;
	/* only SMB_ACL_GROUP*s to worry about; kick out GROUP_OBJs first */
	if (rtag1 == SMB_ACL_GROUP_OBJ)
		return -1;
	if (rtag2 == SMB_ACL_GROUP_OBJ)
		return 1;
	/* only SMB_ACL_GROUPs left */
	return rid1 == rid2 ? 0 : rid1 < rid2 ? -1 : 1;
}

static void sort_rsync_acl(rsync_acl *racl)
{
	if (!racl->count)
		return;
	qsort((void **)racl->races, racl->count, sizeof racl->races[0],
	      &rsync_ace_sorter);
}

static BOOL unpack_smb_acl(rsync_acl *racl, SMB_ACL_T sacl)
{
	SMB_ACL_ENTRY_T entry;
	int rc;
	const char *errfun;
	*racl = rsync_acl_initializer;
	errfun = "sys_acl_get_entry";
	for (rc = sys_acl_get_entry(sacl, SMB_ACL_FIRST_ENTRY, &entry);
	     rc == 1;
	     rc = sys_acl_get_entry(sacl, SMB_ACL_NEXT_ENTRY, &entry)) {
		SMB_ACL_PERMSET_T permset;
		void *qualifier;
		rsync_ace *race;
		expand_rsync_acl(racl);
		race = &racl->races[racl->count++];
		if ((rc = sys_acl_get_tag_type(entry, &race->tag_type))) {
			errfun = "sys_acl_get_tag_type";
			break;
		}
		if ((rc = sys_acl_get_permset(entry, &permset))) {
			errfun = "sys_acl_get_tag_type";
			break;
		}
		race->access = (sys_acl_get_perm(permset, SMB_ACL_READ) ? 4 : 0)
			     | (sys_acl_get_perm(permset, SMB_ACL_WRITE) ? 2 : 0)
			     | (sys_acl_get_perm(permset, SMB_ACL_EXECUTE) ? 1 : 0);
		switch (race->tag_type) {
		case SMB_ACL_USER:
		case SMB_ACL_GROUP:
			break;
		default:
			continue;
		}
		if (!(qualifier = sys_acl_get_qualifier(entry))) {
			errfun = "sys_acl_get_tag_type";
			rc = EINVAL;
			break;
		}
		race->id = *((id_t *)qualifier);
		sys_acl_free_qualifier(qualifier, race->tag_type);
	}
	if (rc) {
		rprintf(FERROR, "unpack_smb_acl: %s(): %s\n",
			errfun, strerror(errno));
		rsync_acl_free(racl);
		return False;
	}
	sort_rsync_acl(racl);
	return True;
}

static BOOL rsync_acls_equal(const rsync_acl *racl1, const rsync_acl *racl2)
{
	rsync_ace *race1, *race2;
	size_t count = racl1->count;
	if (count != racl2->count)
		return False;
	race1 = racl1->races;
	race2 = racl2->races;
	for (; count--; race1++, race2++) {
		if (race1->tag_type != race2->tag_type
		 || race1->access != race2->access
		 || ((race1->tag_type == SMB_ACL_USER
		   || race1->tag_type == SMB_ACL_GROUP)
		  && race1->id != race2->id))
			return False;
	}
	return True;
}

typedef struct {
	size_t count;
	size_t malloced;
	rsync_acl *racls;
} rsync_acl_list;

static rsync_acl_list _rsync_acl_lists[] = {
	{ 0, 0, NULL }, /* SMB_ACL_TYPE_ACCESS */
	{ 0, 0, NULL }  /* SMB_ACL_TYPE_DEFAULT */
};

static inline rsync_acl_list *rsync_acl_lists(SMB_ACL_TYPE_T type)
{
	return type == SMB_ACL_TYPE_ACCESS ? &_rsync_acl_lists[0]
	    : &_rsync_acl_lists[1];
}

static void expand_rsync_acl_list(rsync_acl_list *racl_list)
{
	/* first time through, 0 <= 0, so list is expanded:
	 * diabolical, rsync guys! */
	if (racl_list->malloced <= racl_list->count) {
		rsync_acl *new_ptr;
		size_t new_size;
		if (racl_list->malloced < 1000)
			new_size = racl_list->malloced + 1000;
		else
			new_size = racl_list->malloced * 2;
		new_ptr = realloc_array(racl_list->racls, rsync_acl, new_size);
		if (verbose >= 3) {
			rprintf(FINFO, "expand_rsync_acl_list to %.0f bytes, did%s move\n",
				(double) new_size * sizeof racl_list->racls[0],
				racl_list->racls ? "" : " not");
		}

		racl_list->racls = new_ptr;
		racl_list->malloced = new_size;

		if (!racl_list->racls)
			out_of_memory("expand_rsync_acl_list");
	}
}

#if 0
static void free_rsync_acl_list(rsync_acl_list *racl_list)
{
	/* run this in reverse, so references are freed before referents, */
	/* although not currently necessary */
	while (racl_list->count--) {
		rsync_acl *racl = &racl_list->racls[racl_list->count];
		if (racl)
			rsync_acl_free(racl);
	}
	free(racl_list->racls);
	racl_list->racls = NULL;
	racl_list->malloced = 0;
}
#endif

static int find_matching_rsync_acl(SMB_ACL_TYPE_T type,
				   const rsync_acl_list *racl_list,
				   const rsync_acl *racl)
{
	static int access_match = -1, default_match = -1;
	int *match = (type == SMB_ACL_TYPE_ACCESS) ?
			&access_match : &default_match;
	size_t count = racl_list->count;
	/* if this is the first time through or we didn't match the last
	 * time, then start at the end of the list, which should be the
	 * best place to start hunting */
	if (*match == -1)
		*match = racl_list->count - 1;
	while (count--) {
		if (rsync_acls_equal(&racl_list->racls[*match], racl))
			return *match;
		if (!(*match)--)
			*match = racl_list->count - 1;
	}
	*match = -1;
	return *match;
}

/* the general strategy with the tag_type <-> character mapping is that
 * lowercase implies that no qualifier follows, where uppercase does.
 * same sorta thing for the acl type (access or default) itself, but
 * lowercase in this instance means there's no ACL following, so the
 * ACL is a repeat, so the receiver should reuse the last of the same
 * type ACL */

static void send_rsync_acl(int f, const rsync_acl *racl)
{
	rsync_ace *race;
	size_t count = racl->count;
	write_int(f, count);
	for (race = racl->races; count--; race++) {
		char ch;
		switch (race->tag_type) {
		case SMB_ACL_USER_OBJ:
			ch = 'u';
			break;
		case SMB_ACL_USER:
			ch = 'U';
			break;
		case SMB_ACL_GROUP_OBJ:
			ch = 'g';
			break;
		case SMB_ACL_GROUP:
			ch = 'G';
			break;
		case SMB_ACL_OTHER:
			ch = 'o';
			break;
		case SMB_ACL_MASK:
			ch = 'm';
			break;
		default:
			rprintf(FERROR,
				"send_rsync_acl: unknown tag_type (%0x) on ACE; disregarding\n",
				race->tag_type);
			continue;
		}
		write_byte(f, ch);
		write_byte(f, race->access);
		if (isupper((int)ch)) {
			write_int(f, race->id);
			/* FIXME: sorta wasteful. we should maybe buffer as
			 * many ids as max(ACL_USER + ACL_GROUP) objects to
			 * keep from making so many calls */
			if (ch == 'U')
				add_uid(race->id);
			else
				add_gid(race->id);
		}
	}
}

static rsync_acl _curr_rsync_acls[2];


static const char *str_acl_type(SMB_ACL_TYPE_T type)
{
	return type == SMB_ACL_TYPE_ACCESS ? "SMB_ACL_TYPE_ACCESS" :
		type == SMB_ACL_TYPE_DEFAULT ? "SMB_ACL_TYPE_DEFAULT" :
		"unknown SMB_ACL_TYPE_T";
}

/* generate the ACL(s) for this flist entry;
 * ACL(s) are either sent or cleaned-up by send_acl() below */

BOOL make_acl(const struct file_struct *file, const char *fname)
{
	SMB_ACL_TYPE_T *type,
		types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
	rsync_acl *curr_racl;
	if (!preserve_acls || S_ISLNK(file->mode))
		return True;
	for (type = &types[0], curr_racl = &_curr_rsync_acls[0];
	     type < &types[0] + sizeof types / sizeof types[0]
		&& (*type == SMB_ACL_TYPE_ACCESS || S_ISDIR(file->mode));
	     type++, curr_racl++) {
		SMB_ACL_T sacl;
		BOOL ok;
		*curr_racl = rsync_acl_initializer;
		if (!(sacl = sys_acl_get_file(fname, *type))) {
			rprintf(FERROR, "send_acl: sys_acl_get_file(%s, %s): %s\n",
				fname, str_acl_type(*type), strerror(errno));
			return False;
		}
		ok = unpack_smb_acl(curr_racl, sacl);
		sys_acl_free_acl(sacl);
		if (!ok)
			return False;
	}
	return True;
}

/* send the make_acl()-generated ACLs for this flist entry,
 * or clean up after an flist entry that's not being sent (f == -1) */

void send_acl(const struct file_struct *file, int f)
{
	SMB_ACL_TYPE_T *type,
		types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
	rsync_acl *curr_racl;
	if (!preserve_acls || S_ISLNK(file->mode))
		return;
	for (type = &types[0], curr_racl = &_curr_rsync_acls[0];
	     type < &types[0] + sizeof types / sizeof types[0]
		&& (*type == SMB_ACL_TYPE_ACCESS || S_ISDIR(file->mode));
	     type++, curr_racl++) {
		int index;
		rsync_acl_list *racl_list = rsync_acl_lists(*type);
		if (f == -1) {
			rsync_acl_free(curr_racl);
			continue;
		}
		if ((index = find_matching_rsync_acl(*type, racl_list, curr_racl))
		    != -1) {
			write_byte(f, *type == SMB_ACL_TYPE_ACCESS ? 'a' : 'd');
			write_int(f, index);
			rsync_acl_free(curr_racl);
		} else {
			write_byte(f, *type == SMB_ACL_TYPE_ACCESS ? 'A' : 'D');
			send_rsync_acl(f, curr_racl);
			expand_rsync_acl_list(racl_list);
			racl_list->racls[racl_list->count++] = *curr_racl;
		}
	}
}

/* the below stuff is only used by the receiver */

/* structure to hold index to rsync_acl_list member corresponding to
 * flist->files[i] */

typedef struct {
	const struct file_struct *file;
	int aclidx;
} file_acl_index;

typedef struct {
	size_t count;
	size_t malloced;
	file_acl_index *fileaclidxs;
} file_acl_index_list;

static file_acl_index_list _file_acl_index_lists[] = {
	{0, 0, NULL },/* SMB_ACL_TYPE_ACCESS */
	{0, 0, NULL } /* SMB_ACL_TYPE_DEFAULT */
};

static inline file_acl_index_list *file_acl_index_lists(SMB_ACL_TYPE_T type)
{
	return type == SMB_ACL_TYPE_ACCESS ?
		&_file_acl_index_lists[0] : &_file_acl_index_lists[1];
}

static void expand_file_acl_index_list(file_acl_index_list *fileaclidx_list)
{
	/* first time through, 0 <= 0, so list is expanded:
	 * diabolical, rsync guys! */
	if (fileaclidx_list->malloced <= fileaclidx_list->count) {
		file_acl_index *new_ptr;
		size_t new_size;
		if (fileaclidx_list->malloced < 1000)
			new_size = fileaclidx_list->malloced + 1000;
		else
			new_size = fileaclidx_list->malloced * 2;
		new_ptr = realloc_array(fileaclidx_list->fileaclidxs, file_acl_index, new_size);
		if (verbose >= 3) {
			rprintf(FINFO, "expand_file_acl_index_list to %.0f bytes, did%s move\n",
				(double) new_size * sizeof fileaclidx_list->fileaclidxs[0],
				fileaclidx_list->fileaclidxs ? "" : " not");
		}

		fileaclidx_list->fileaclidxs = new_ptr;
		fileaclidx_list->malloced = new_size;

		if (!fileaclidx_list->fileaclidxs)
			out_of_memory("expand_file_acl_index_list");
	}
}

#if 0
static void free_file_acl_index_list(file_acl_index_list *fileaclidx_list)
{
	free(fileaclidx_list->fileaclidxs);
	fileaclidx_list->fileaclidxs = NULL;
	fileaclidx_list->malloced = 0;
}
#endif

/* lists to hold the SMB_ACL_Ts corresponding to the rsync_acl_list entries */

typedef struct {
	size_t count;
	size_t malloced;
	SMB_ACL_T *sacls;
} smb_acl_list;

static smb_acl_list _smb_acl_lists[] = {
	{ 0, 0, NULL }, /* SMB_ACL_TYPE_ACCESS */
	{ 0, 0, NULL }  /* SMB_ACL_TYPE_DEFAULT */
};

static inline smb_acl_list *smb_acl_lists(SMB_ACL_TYPE_T type)
{
	return type == SMB_ACL_TYPE_ACCESS ? &_smb_acl_lists[0] :
		&_smb_acl_lists[1];
}

static void expand_smb_acl_list(smb_acl_list *sacl_list)
{
	/* first time through, 0 <= 0, so list is expanded:
	 * diabolical, rsync guys! */
	if (sacl_list->malloced <= sacl_list->count) {
		SMB_ACL_T *new_ptr;
		size_t new_size;
		if (sacl_list->malloced < 1000)
			new_size = sacl_list->malloced + 1000;
		else
			new_size = sacl_list->malloced * 2;
		new_ptr = realloc_array(sacl_list->sacls, SMB_ACL_T, new_size);
		if (verbose >= 3) {
			rprintf(FINFO, "expand_smb_acl_list to %.0f bytes, did%s move\n",
				(double) new_size * sizeof sacl_list->sacls[0],
				sacl_list->sacls ? "" : " not");
		}

		sacl_list->sacls = new_ptr;
		sacl_list->malloced = new_size;

		if (!sacl_list->sacls)
			out_of_memory("expand_smb_acl_list");
	}
}

#if 0
static void free_smb_acl_list(SMB_ACL_TYPE_T type)
{
	smb_acl_list *sacl_list = smb_acl_lists(type);
	SMB_ACL_T *sacl = sacl_list->sacls;
	while (sacl_list->count--) {
		if (*sacl)
			sys_acl_free_acl(*sacl++);
	}
	free(sacl_list->sacls);
	sacl_list->sacls = NULL;
	sacl_list->malloced = 0;
}
#endif

/* build an SMB_ACL_T corresponding to an rsync_acl */
static BOOL pack_smb_acl(SMB_ACL_T *smb_acl, const rsync_acl *racl)
{
	size_t count = racl->count;
	rsync_ace *race = racl->races;
	const char *errfun = NULL;
	*smb_acl = sys_acl_init(count);
	if (!*smb_acl) {
		rprintf(FERROR, "pack_smb_acl: sys_acl_int(): %s\n",
			strerror(errno));
		return False;
	}
	for (; count--; race++) {
		SMB_ACL_ENTRY_T entry;
		SMB_ACL_PERMSET_T permset;
		if (sys_acl_create_entry(smb_acl, &entry)) {
			errfun = "sys_acl_create)";
			break;
		}
		if (sys_acl_set_tag_type(entry, race->tag_type)) {
			errfun = "sys_acl_set_tag";
			break;
		}
		if (race->tag_type == SMB_ACL_USER ||
		    race->tag_type == SMB_ACL_GROUP)
			if (sys_acl_set_qualifier(entry, (void*)&race->id)) {
				errfun = "sys_acl_set_qualfier";
				break;
			}
		if (sys_acl_get_permset(entry, &permset)) {
			errfun = "sys_acl_get_permset";
			break;
		}
		if (sys_acl_clear_perms(permset)) {
			errfun = "sys_acl_clear_perms";
			break;
		}
		if (race->access & 4)
			if (sys_acl_add_perm(permset, SMB_ACL_READ)) {
				errfun = "sys_acl_add_perm";
				break;
			}
		if (race->access & 2)
			if (sys_acl_add_perm(permset, SMB_ACL_WRITE)) {
				errfun = "sys_acl_add_perm";
				break;
			}
		if (race->access & 1)
			if (sys_acl_add_perm(permset, SMB_ACL_EXECUTE)) {
				errfun = "sys_acl_add_perm";
				break;
			}
		if (sys_acl_set_permset(entry, permset)) {
			errfun = "sys_acl_set_permset";
			break;
		}
	}
	if (errfun) {
		sys_acl_free_acl(*smb_acl);
		rprintf(FERROR, "pack_smb_acl %s(): %s\n", errfun,
			strerror(errno));
		return False;
	}
	return True;
}

static void receive_rsync_acl(rsync_acl *racl, int f)
{
#if ACLS_NEED_MASK
	uchar required_mask_perm = 0;
#endif
	BOOL saw_mask = False;
	BOOL saw_user_obj = False, saw_group_obj = False,
		saw_other = False;
	size_t count = read_int(f);
	rsync_ace *race;
	if (!count)
		return;
	while (count--) {
		uchar tag = read_byte(f);
		expand_rsync_acl(racl);
		race = &racl->races[racl->count++];
		switch (tag) {
		case 'u':
			race->tag_type = SMB_ACL_USER_OBJ;
			saw_user_obj = True;
			break;
		case 'U':
			race->tag_type = SMB_ACL_USER;
			break;
		case 'g':
			race->tag_type = SMB_ACL_GROUP_OBJ;
			saw_group_obj = True;
			break;
		case 'G':
			race->tag_type = SMB_ACL_GROUP;
			break;
		case 'o':
			race->tag_type = SMB_ACL_OTHER;
			saw_other = True;
			break;
		case 'm':
			race->tag_type = SMB_ACL_MASK;
			saw_mask = True;
			break;
		default:
			rprintf(FERROR, "receive_rsync_acl: unknown tag %c\n",
				tag);
			exit_cleanup(RERR_STREAMIO);
		}
		race->access = read_byte(f);
		if (race->access & ~ (4 | 2 | 1)) {
			rprintf(FERROR, "receive_rsync_acl: bogus permset %o\n",
				race->access);
			exit_cleanup(RERR_STREAMIO);
		}
		if (race->tag_type == SMB_ACL_USER ||
		    race->tag_type == SMB_ACL_GROUP) {
			race->id = read_int(f);
#if ACLS_NEED_MASK
			required_mask_perm |= race->access;
#endif
		}
#if ACLS_NEED_MASK
		else if (race->tag_type == SMB_ACL_GROUP_OBJ)
			required_mask_perm |= race->access;
#endif

	}
	if (!saw_user_obj) {
		expand_rsync_acl(racl);
		race = &racl->races[racl->count++];
		race->tag_type = SMB_ACL_USER_OBJ;
		race->access = 7;
	}
	if (!saw_group_obj) {
		expand_rsync_acl(racl);
		race = &racl->races[racl->count++];
		race->tag_type = SMB_ACL_GROUP_OBJ;
		race->access = 0;
	}
	if (!saw_other) {
		expand_rsync_acl(racl);
		race = &racl->races[racl->count++];
		race->tag_type = SMB_ACL_OTHER;
		race->access = 0;
	}
#if ACLS_NEED_MASK
	if (!saw_mask) {
		expand_rsync_acl(racl);
		race = &racl->races[racl->count++];
		race->tag_type = SMB_ACL_MASK;
		race->access = required_mask_perm;
	}
#else
	/* If we, a system without ACLS_NEED_MASK, received data from a
	 * system that has masks, throw away the extraneous CLASS_OBJs. */
	if (saw_mask && racl->count == 4) {
		rsync_ace *group_obj_race = NULL, *mask_race = NULL;
		rsync_ace *p;
		size_t i;
		for (i = 0, p = racl->races; i < racl->count; i++, p++) {
			if (p->tag_type == SMB_ACL_MASK)
				mask_race = p;
			else if (p->tag_type == SMB_ACL_GROUP_OBJ)
				group_obj_race = p;
		}
		if (mask_race == NULL || group_obj_race == NULL) {
			rprintf(FERROR, "receive_rsync_acl: have four ACES "
					"and one's ACL_MASK but missing "
					"either it or ACL_GROUP_OBJ, "
					"when pruning ACL\n");
		} else {
			/* mask off group perms with it first */
			group_obj_race->access &= mask_race->access;
			/* dump mask_race; re-slot any followers-on */
			racl->count--;
			if (mask_race != &racl->races[racl->count]) {
				*mask_race = racl->races[racl->count];
				saw_user_obj = False; /* force re-sort */
			}
		}
	}
#endif
#if ACLS_NEED_MASK
	if (!(saw_user_obj && saw_group_obj && saw_other && saw_mask))
#else
	if (!(saw_user_obj && saw_group_obj && saw_other))
#endif
		sort_rsync_acl(racl);
}

/* receive and build the rsync_acl_lists */

void receive_acl(struct file_struct *file, int f)
{
	SMB_ACL_TYPE_T *type,
		types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
	char *fname;
	if (!preserve_acls || S_ISLNK(file->mode))
		return;
	fname = f_name(file);
	for (type = &types[0];
	     type < &types[0] + sizeof types / sizeof types[0]
		&& (*type == SMB_ACL_TYPE_ACCESS || S_ISDIR(file->mode));
	     type++) {
		file_acl_index_list *fileaclidx_list =
			file_acl_index_lists(*type);
		uchar tag;
		expand_file_acl_index_list(fileaclidx_list);

		tag = read_byte(f);
		if (tag == 'A' || tag == 'a') {
			if (*type != SMB_ACL_TYPE_ACCESS) {
				rprintf(FERROR, "receive_acl %s: duplicate access ACL\n",
					fname);
				exit_cleanup(RERR_STREAMIO);
			}
		} else if (tag == 'D' || tag == 'd') {
			if (*type == SMB_ACL_TYPE_ACCESS) {
				rprintf(FERROR, "receive_acl %s: expecting access ACL; got default\n",
					fname);
				exit_cleanup(RERR_STREAMIO);
			}
		} else {
			rprintf(FERROR, "receive_acl %s: unknown ACL type tag: %c\n",
				fname, tag);
			exit_cleanup(RERR_STREAMIO);
		}
		if (tag == 'A' || tag == 'D') {
			rsync_acl racl = rsync_acl_initializer;
			rsync_acl_list *racl_list = rsync_acl_lists(*type);
			smb_acl_list *sacl_list = smb_acl_lists(*type);
			fileaclidx_list->fileaclidxs[fileaclidx_list->count].
				aclidx = racl_list->count;
			fileaclidx_list->fileaclidxs[fileaclidx_list->count++].
				file = file;
			receive_rsync_acl(&racl, f);
			expand_rsync_acl_list(racl_list);
			racl_list->racls[racl_list->count++] = racl;
			expand_smb_acl_list(sacl_list);
			sacl_list->sacls[sacl_list->count++] = NULL;
		} else {
			int index = read_int(f);
			rsync_acl_list *racl_list = rsync_acl_lists(*type);
			if ((size_t) index >= racl_list->count) {
				rprintf(FERROR, "receive_acl %s: %s ACL index %d out of range\n",
					fname,
					str_acl_type(*type),
					index);
				exit_cleanup(RERR_STREAMIO);
			}
			fileaclidx_list->fileaclidxs[fileaclidx_list->count].
				aclidx = index;
			fileaclidx_list->fileaclidxs[fileaclidx_list->count++].
				file = file;
		}
	}
}

static int file_acl_index_list_sorter(const void *f1, const void *f2)
{
	const file_acl_index *fileaclidx1 = (const file_acl_index *)f1;
	const file_acl_index *fileaclidx2 = (const file_acl_index *)f2;
	return fileaclidx1->file == fileaclidx2->file ? 0 :
		fileaclidx1->file < fileaclidx2->file ? -1 : 1;
}

void sort_file_acl_index_lists()
{
	SMB_ACL_TYPE_T *type,
		types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
	if (!preserve_acls)
		return;
	for (type = &types[0];
	     type < &types[0] + sizeof types / sizeof types[0];
	     type++)
	{
		file_acl_index_list *fileaclidx_list =
			file_acl_index_lists(*type);
		if (!fileaclidx_list->count)
			continue;
		qsort(fileaclidx_list->fileaclidxs, fileaclidx_list->count,
		      sizeof fileaclidx_list->fileaclidxs[0],
		      &file_acl_index_list_sorter);
	}
}

static int find_file_acl_index(const file_acl_index_list *fileaclidx_list,
			       const struct file_struct *file) {
	int low = 0, high = fileaclidx_list->count;
	const struct file_struct *file_mid;
	if (!high--)
		return -1;
	do {
		int mid = (high + low) / 2;
		file_mid = fileaclidx_list->fileaclidxs[mid].file;
		if (file_mid == file)
			return fileaclidx_list->fileaclidxs[mid].aclidx;
		if (file_mid > file)
			high = mid - 1;
		else
			low = mid + 1;
	} while (low < high);
	if (low == high) {
		file_mid = fileaclidx_list->fileaclidxs[low].file;
		if (file_mid == file)
			return fileaclidx_list->fileaclidxs[low].aclidx;
	}
	rprintf(FERROR,
		"find_file_acl_index: can't find entry for file in list\n");
	exit_cleanup(RERR_STREAMIO);
	return -1;
}

/* for duplicating ACLs on backups when using backup_dir */

int dup_acl(const char *orig, const char *bak, mode_t mode)
{
	SMB_ACL_TYPE_T *type,
		types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
	int ret = 0;
	if (!preserve_acls)
		return 0;
	for (type = &types[0];
	     type < &types[0] + sizeof types / sizeof types[0]
		 && (*type == SMB_ACL_TYPE_ACCESS || S_ISDIR(mode));
	     type++) {
		SMB_ACL_T sacl_orig, sacl_bak;
		rsync_acl racl_orig, racl_bak;
		if (!(sacl_orig = sys_acl_get_file(orig, *type))) {
			rprintf(FERROR, "dup_acl: sys_acl_get_file(%s, %s): %s\n",
				orig, str_acl_type(*type), strerror(errno));
			ret = -1;
			continue;
		}
		if (!(sacl_bak = sys_acl_get_file(orig, *type))) {
			rprintf(FERROR, "dup_acl: sys_acl_get_file(%s, %s): %s. ignoring\n",
				bak, str_acl_type(*type), strerror(errno));
			ret = -1;
			/* try to forge on through */
		}
		if (!unpack_smb_acl(&racl_orig, sacl_orig)) {
			ret = -1;
			goto out_with_sacls;
		}
		if (sacl_bak) {
			if (!unpack_smb_acl(&racl_bak, sacl_bak)) {
				ret = -1;
				goto out_with_one_racl;
			}
			if (rsync_acls_equal(&racl_orig, &racl_bak))
				goto out_with_all;
		} else {
			; /* presume they're unequal */
		}
		if (*type == SMB_ACL_TYPE_DEFAULT && !racl_orig.count) {
			if (-1 == sys_acl_delete_def_file(bak)) {
				rprintf(FERROR, "dup_acl: sys_acl_delete_def_file(%s): %s\n",
					bak, strerror(errno));
				ret = -1;
			}
		} else if (-1 == sys_acl_set_file(bak, *type, sacl_bak)) {
			rprintf(FERROR, "dup_acl: sys_acl_set_file(%s, %s): %s\n",
				bak, str_acl_type(*type), strerror(errno));
			ret = -1;
		}
		out_with_all:
			if (sacl_bak)
				rsync_acl_free(&racl_bak);
		out_with_one_racl:
			rsync_acl_free(&racl_orig);
		out_with_sacls:
			if (sacl_bak)
				sys_acl_free_acl(sacl_bak);
		/* out_with_one_sacl: */
			if (sacl_orig)
				sys_acl_free_acl(sacl_orig);
	}
	return ret;
}

/* stuff for redirecting calls to set_acl() from set_perms()
 * for keep_backup() */
static const struct file_struct *backup_orig_file = NULL;
static const char null_string[] = "";
static const char *backup_orig_fname = null_string;
static const char *backup_dest_fname = null_string;
static SMB_ACL_T _backup_sacl[] = { NULL, NULL };

void push_keep_backup_acl(const struct file_struct *file,
			  const char *orig, const char *dest)
{
	if (preserve_acls) {
		SMB_ACL_TYPE_T *type,
			types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
		SMB_ACL_T *sacl;
		backup_orig_file = file;
		backup_orig_fname = orig;
		backup_dest_fname = dest;
		for (type = &types[0], sacl = &_backup_sacl[0];
		     type < &types[0] + sizeof types / sizeof types[0];
		     type++) {
			if (*type == SMB_ACL_TYPE_DEFAULT && !S_ISDIR(file->mode))
				*sacl = NULL;
			else {
				if (!(*sacl = sys_acl_get_file(orig, *type))) {
					rprintf(FERROR, "push_keep_backup_acl: sys_acl_get_file(%s, %s): %s\n",
						orig, str_acl_type(*type),
						strerror(errno));
				}
			}
		}
	}
}

static int set_keep_backup_acl()
{
	if (preserve_acls) {
		SMB_ACL_TYPE_T *type,
			types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
		SMB_ACL_T *sacl;
		int ret = 0;
		for (type = &types[0], sacl = &_backup_sacl[0];
		     type < &types[0] + sizeof types / sizeof types[0];
		     type++) {
			if (*sacl) {
				if (-1 == sys_acl_set_file(backup_dest_fname,
							   *type, *sacl))
				{
					rprintf(FERROR, "push_keep_backup_acl: sys_acl_get_file(%s, %s): %s\n",
						backup_dest_fname,
						str_acl_type(*type),
						strerror(errno));
					ret = -1;
				}
			}
		}
		return ret;
	}
	return 0;
}

void cleanup_keep_backup_acl()
{
	if (preserve_acls) {
		SMB_ACL_TYPE_T *type,
			types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
		SMB_ACL_T *sacl;
		backup_orig_file = NULL;
		backup_orig_fname = null_string;
		backup_dest_fname = null_string;
		for (type = &types[0], sacl = &_backup_sacl[0];
		     type < &types[0] + sizeof types / sizeof types[0];
		     type++) {
			if (*sacl)
				sys_acl_free_acl(*sacl);
			*sacl = NULL;
		}
	}
}

/* set ACL on rsync-ed or keep_backup-ed file */

int set_acl(const char *fname, const struct file_struct *file)
{
	int updated = 0;
	SMB_ACL_TYPE_T *type,
		types[] = {SMB_ACL_TYPE_ACCESS, SMB_ACL_TYPE_DEFAULT};
	if (dry_run || !preserve_acls || S_ISLNK(file->mode))
		return 0;
	if (file == backup_orig_file) {
		if (!strcmp(fname, backup_dest_fname))
			return set_keep_backup_acl();
	}
	for (type = &types[0];
	     type < &types[0] + sizeof  types / sizeof types[0]
		&& (*type == SMB_ACL_TYPE_ACCESS || S_ISDIR(file->mode));
	     type++) {
		SMB_ACL_T sacl_orig, *sacl_new;
		rsync_acl racl_orig, *racl_new;
		int aclidx = find_file_acl_index(file_acl_index_lists(*type),
						 file);
		BOOL ok;
		racl_new = &(rsync_acl_lists(*type)->racls[aclidx]);
		sacl_new = &(smb_acl_lists(*type)->sacls[aclidx]);
		sacl_orig = sys_acl_get_file(fname, *type);
		if (!sacl_orig) {
			rprintf(FERROR, "set_acl: sys_acl_get_file(%s, %s): %s\n",
				fname, str_acl_type(*type), strerror(errno));
			updated = -1;
			continue;
		}
		ok = unpack_smb_acl(&racl_orig, sacl_orig);
		sys_acl_free_acl(sacl_orig);
		if (!ok) {
			updated = -1;
			continue;
		}
		ok = rsync_acls_equal(&racl_orig, racl_new);
		rsync_acl_free(&racl_orig);
		if (ok)
			continue;
		if (*type == SMB_ACL_TYPE_DEFAULT && !racl_new->count) {
			if (-1 == sys_acl_delete_def_file(fname)) {
				rprintf(FERROR, "set_acl: sys_acl_delete_def_file(%s): %s\n",
					fname, strerror(errno));
				updated = -1;
				continue;
			}
		} else {
			if (!*sacl_new)
				if (!pack_smb_acl(sacl_new, racl_new)) {
					updated = -1;
					continue;
				}
			if (-1 == sys_acl_set_file(fname, *type, *sacl_new)) {
				rprintf(FERROR, "set_acl: sys_acl_set_file(%s, %s): %s\n",
					fname, str_acl_type(*type),
					strerror(errno));
				updated = -1;
				continue;
			}
		}
		if (!updated)
			updated = 1;
	}
	return updated;
}

/* enumeration functions for uid mapping */

/* context -- one and only one. should be cycled through once on uid mapping
 * and once on gid mapping */
static rsync_acl_list *_enum_racl_lists[] = {
	&_rsync_acl_lists[0], &_rsync_acl_lists[1], NULL
};

static rsync_acl_list **enum_racl_list = &_enum_racl_lists[0];
static size_t enum_racl_index = 0;
static size_t enum_race_index = 0;

/* this returns the next tag_type id from the given acl for the next entry,
 * or it returns 0 if there are no more tag_type ids in the acl */

static id_t next_ace_id(SMB_ACL_TAG_T tag_type, const rsync_acl *racl)
{
	for (; enum_race_index < racl->count; enum_race_index++) {
		rsync_ace *race = &racl->races[enum_race_index];
		if (race->tag_type == tag_type)
			return race->id;
	}
	enum_race_index = 0;
	return 0;
}

static id_t next_acl_id(SMB_ACL_TAG_T tag_type, const rsync_acl_list *racl_list)
{
	for (; enum_racl_index < racl_list->count; enum_racl_index++) {
		rsync_acl *racl = &racl_list->racls[enum_racl_index];
		id_t id = next_ace_id(tag_type, racl);
		if (id)
			return id;
	}
	enum_racl_index = 0;
	return 0;
}

static id_t next_acl_list_id(SMB_ACL_TAG_T tag_type)
{
	for (; *enum_racl_list; enum_racl_list++) {
		id_t id = next_acl_id(tag_type, *enum_racl_list);
		if (id)
			return id;
	}
	enum_racl_list = &_enum_racl_lists[0];
	return 0;
}

id_t next_acl_uid()
{
	return next_acl_list_id(SMB_ACL_USER);
}

id_t next_acl_gid()
{
	return next_acl_list_id(SMB_ACL_GROUP);
}

/* referring to the global context enum_entry, sets the entry's id */
static void set_acl_id(id_t id)
{
	(*enum_racl_list)->racls[enum_racl_index].races[enum_race_index++].id = id;
}

void acl_uid_map(id_t uid)
{
	set_acl_id(uid);
}

void acl_gid_map(id_t gid)
{
	set_acl_id(gid);
}

#endif /* SUPPORT_ACLS */
