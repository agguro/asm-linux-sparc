
# agguro NAS Monitor
# Target: Netgear ReadyNAS Duo / Linux SPARC V8 (32-bit)
# Build host: Debian x86-64
# Runtime dependencies: None (direct Linux syscalls)

# ReadyNAS deployment
NAS_USER := agguro
NAS_HOST := 192.168.0.198
NAS_DIR  := /c/home/agguro/projects/

SSH_OPTS := -oKexAlgorithms=diffie-hellman-group14-sha1 \
            -oHostKeyAlgorithms=+ssh-rsa

CROSS   := sparc64-linux-gnu-
CC      := $(CROSS)gcc
READELF := $(CROSS)readelf
OBJDUMP := $(CROSS)objdump
STRIP   := $(CROSS)strip

TARGET  := hello-sparc
SRCS    := $(TARGET).c
OBJS    := $(SRCS:.c=.o)

CFLAGS  := -m32 -mcpu=v8 \
           -O2 -Wall -Wextra \
           -ffreestanding \
           -fno-builtin \
           -fno-stack-protector \
           -fno-pie

LDFLAGS := -m32 -mcpu=v8 \
           -nostdlib -no-pie \
           -Wl,-e,_start

.PHONY: all clean check disasm strip deploy

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

check: $(TARGET)
	file $(TARGET)
	$(READELF) -h $(TARGET)
	$(READELF) -l $(TARGET)
	$(READELF) -d $(TARGET)

disasm: $(TARGET)
	$(OBJDUMP) -dr $(TARGET)

strip: $(TARGET)
	$(STRIP) $(TARGET)

deploy: $(TARGET)
	scp -O $(SSH_OPTS) $(TARGET) \
	    $(NAS_USER)@$(NAS_HOST):$(NAS_DIR)/

clean:
	rm -f $(TARGET) $(OBJS)
