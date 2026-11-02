# $Id: Makefile,v 1.38 2000/12/15 00:41:22 davem Exp $
# Makefile for the linux Sparc-specific parts of the memory manager.
#
# Note! Dependencies are done automagically by 'make dep', which also
# removes any old dependencies. DON'T put your own dependencies here
# unless it's something special (ie not a .c file).
#
# Note 2! The CFLAGS definition is now in the main makefile...

.S.o:
	$(CC) $(AFLAGS) -ansi -c -o $*.o $<

O_TARGET := mm.o
obj-y    := fault.o init.o extable.o

include $(TOPDIR)/Rules.make
