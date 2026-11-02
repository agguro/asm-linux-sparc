#
# Makefile for drivers/usb/atmel
#
# Note! Dependencies are done automagically by 'make dep', which also
# removes any old dependencies. DON'T put your own dependencies here
# unless it's something special (ie not a .c file).
#

obj-y   :=
obj-n   :=
obj-m   :=
obj-    :=
export-objs := at76c503.o

obj-$(CONFIG_USB_ATMEL76C503) += at76c503.o
obj-$(CONFIG_USB_ATMEL76C503_I3861) += at76c503-i3861.o
obj-$(CONFIG_USB_ATMEL76C503_I3863) += at76c503-i3863.o
obj-$(CONFIG_USB_ATMEL76C503_RFMD) += at76c503-rfmd.o
obj-$(CONFIG_USB_ATMEL76C503_RFMD_ACCTON) += at76c503-rfmd-acc.o
obj-$(CONFIG_USB_ATMEL76C505_RFMD) += at76c505-rfmd.o
obj-$(CONFIG_USB_ATMEL76C505_RFMD2958) += at76c505-rfmd2958.o

O_TARGET := usb-atmel.o

EXTRA_CFLAGS += -DDRIVER_VERSION=\"v0.11\"

include $(TOPDIR)/Rules.make

