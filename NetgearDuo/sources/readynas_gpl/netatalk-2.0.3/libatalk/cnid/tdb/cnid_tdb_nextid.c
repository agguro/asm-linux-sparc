/*
 * $Id: cnid_tdb_nextid.c,v 1.1.1.1 2005/05/19 22:39:34 jmaggard Exp $
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif 

#ifdef CNID_BACKEND_TDB

#include "cnid_tdb.h"

cnid_t cnid_tdb_nextid(struct _cnid_db *cdb)
{
    return CNID_INVALID;
}

#endif 
