#
# Makefile for RT2500
#

O_TARGET	:= rt2500.o

obj-y := \
	rtmp_main.o mlme.o connect.o sync.o assoc.o auth.o \
	auth_rsp.o rtmp_data.o rtmp_init.o sanity.o rtmp_wep.o \
	rtmp_info.o eeprom.o rtmp_tkip.o wpa.o md5.o

obj-$(CONFIG_NET_RT2500)	+= $(O_TARGET)

ifeq ($(CONFIG_PADRE),y)
	EXTRA_CFLAGS += -DBIG_ENDIAN
	EXTRA_CFLAGS += -DLinux
endif

# For Debug RT2500 module
#EXTRA_CFLAGS += -DRT2500_DBG

include $(TOPDIR)/Rules.make
