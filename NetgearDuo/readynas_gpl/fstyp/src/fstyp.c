/*
 * fstyp.c
 *
 * Copyright (C) 2000, 2001 Martin K. Petersen <mkp@mkp.net>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version
 * 2 as published by the Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 * GNU General Public License for more details. 
 * 
 * You should have received a copy of the GNU General Public License 
 * along with this program; if not, write to the Free Software 
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
 */ 

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <getopt.h>

#include <config.h>
#include "mount_guess_fstype.h"

static char const rcsid[] = "$Id: fstyp.c,v 1.2 2005/06/02 22:43:09 jmaggard Exp $";

void usage (void);


void
usage (void)
{
	fprintf (stderr, "Usage: fstyp [-hV]\n       fstyp <device>\n");
	exit (EXIT_FAILURE);
}


int
main (int argc, char **argv) 
{
	char opt, *type = NULL;

	while ((opt = getopt(argc, argv, "hV")) != EOF) {
		switch (opt) {
		case 'V':
			fprintf (stderr, 
				 "fstyp version %s by Martin K. Petersen <mkp@mkp.net>\n", 
				 VERSION);
			exit (EXIT_FAILURE);
		default:
			usage();
		}
	}

	if (argc != 2) 
		usage();
	
	type = fstype (argv[1]);

	if (type) {
		fprintf (stdout, "%s", type);
		exit (EXIT_SUCCESS);
	}
		
	exit (EXIT_FAILURE);
}

