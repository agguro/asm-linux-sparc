O_TARGET := prism2_usb.o

#obj-y	:= p80211types.o p80211metamsg.o p80211metamib.o p80211meta.o \
#	   mkmetastruct.o p80211mod.o p80211conv.o p80211req.o p80211frm.o \
#	   p80211wext.o p80211wep.o p80211netdev.o prism2sta.o prism2mgmt.o \
#	   prism2mib.o hfa384x_usb.o
export-objs := prism2sta.o prism2mgmt.o prism2mib.o hfa384x_usb.o

obj-y	:= prism2sta.o prism2mgmt.o prism2mib.o hfa384x_usb.o
obj-m	:= $(O_TARGET)

include $(TOPDIR)/Rules.make
