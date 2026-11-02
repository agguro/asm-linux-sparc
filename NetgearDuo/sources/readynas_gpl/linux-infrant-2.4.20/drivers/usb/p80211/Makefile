O_TARGET := p80211.o

##CFLAGS_p80211conv.o = -include /usr/src/linux-2.4.20/include/linux/modversions.h

export-objs := p80211mod.o p80211conv.o p80211req.o p80211frm.o p80211wext.o \
           p80211wep.o p80211netdev.o


obj-y	:= p80211mod.o p80211conv.o p80211req.o p80211frm.o p80211wext.o \
           p80211wep.o p80211netdev.o

obj-m	:= $(O_TARGET)

include $(TOPDIR)/Rules.make
