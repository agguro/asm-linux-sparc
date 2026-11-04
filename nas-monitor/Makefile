
# ============================================================
# agguro NAS Web Monitor
#
# Target: Netgear ReadyNAS / Infrant Neon
# Architecture: SPARC V8, 32-bit, big-endian
# Kernel: Linux 2.6.17.14ReadyNAS
# Build host: Debian x86-64
#
# No libc, no dynamic linker.
# Direct Linux syscalls.
# ============================================================

# Cross-compilation tools
CROSS   := sparc64-linux-gnu-
CC      := $(CROSS)gcc
READELF := $(CROSS)readelf
OBJDUMP := $(CROSS)objdump
STRIP   := $(CROSS)strip

# Compiler flags
CFLAGS := -m32 -mcpu=v8 \
          -O2 -Wall -Wextra \
          -ffreestanding \
          -fno-builtin \
          -fno-stack-protector \
          -fno-pie \
          -Iinclude

# Linker flags
LDFLAGS := -m32 -mcpu=v8 \
           -nostdlib -no-pie \
           -Wl,-e,_start

# Application
TARGET := nasmon

# Current development source
SOURCES := src/main.c \
           src/http.c \
           src/hardware.c \
           arch/sparc/syscall.S

# ReadyNAS connection
NAS_USER := agguro
NAS_HOST := 192.168.0.198

# Installation directory on NAS
NAS_DIR := /c/home/agguro/projects/webmonitor
NAS_BIN := $(NAS_DIR)/bin

# Legacy SSH compatibility
SSH_OPTS := -oKexAlgorithms=diffie-hellman-group14-sha1 \
            -oHostKeyAlgorithms=+ssh-rsa

# Default target
.DEFAULT_GOAL := all

.PHONY: all clean check disasm deploy remote-test strip

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) \
	    -o $@ $^

# ------------------------------------------------------------
# ELF verification
# ------------------------------------------------------------

check: $(TARGET)
	file $(TARGET)
	$(READELF) -h $(TARGET)
	$(READELF) -l $(TARGET)
	$(READELF) -d $(TARGET)

# ------------------------------------------------------------
# Disassembly
# ------------------------------------------------------------

disasm: $(TARGET)
	$(OBJDUMP) -dr $(TARGET)

# ------------------------------------------------------------
# Deployment
# ------------------------------------------------------------

deploy: $(TARGET)
	scp -O $(SSH_OPTS) $(TARGET) \
	    $(NAS_USER)@$(NAS_HOST):$(NAS_BIN)/

# ------------------------------------------------------------
# Remote execution
# ------------------------------------------------------------

remote-test: deploy
	ssh $(SSH_OPTS) \
	    $(NAS_USER)@$(NAS_HOST) \
	    'chmod 755 $(NAS_BIN)/$(TARGET) && \
	     $(NAS_BIN)/$(TARGET)'

# ------------------------------------------------------------
# Utilities
# ------------------------------------------------------------

strip: $(TARGET)
	$(STRIP) $(TARGET)

clean:
	rm -f $(TARGET)
