/*
 * $Id: gate.h,v 1.1.1.1 2005/05/19 22:39:34 jmaggard Exp $
 *
 * Copyright (c) 1990,1993 Regents of The University of Michigan.
 * All Rights Reserved. See COPYRIGHT.
 */

struct gate {
    struct gate		*g_next,
			*g_prev;
    int			g_state;
    struct interface	*g_iface;
    struct rtmptab	*g_rt;
    struct sockaddr_at	g_sat;
};
