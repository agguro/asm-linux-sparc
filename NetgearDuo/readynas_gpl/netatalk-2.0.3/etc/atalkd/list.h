/*
 * $Id: list.h,v 1.1.1.1 2005/05/19 22:39:34 jmaggard Exp $
 *
 * Copyright (c) 1990,1992 Regents of The University of Michigan.
 * All Rights Reserved. See COPYRIGHT.
 */

struct list {
    void	*l_data;
    struct list	*l_next,
		*l_prev;
};
