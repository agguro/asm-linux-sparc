/*
 * $Id: strdup.c,v 1.1.1.1 2005/05/19 22:39:34 jmaggard Exp $
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif /* HAVE_CONFIG_H */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ultrix
char *strdup(const char *string)
{
  char *new;
  
  if (new = (char *) malloc(strlen(string) + 1))
    strcpy(new, string);

  return new;
}
#endif /* ultrix */
