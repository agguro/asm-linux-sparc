# SPARC V8 Linux assembly build
# Target: 32-bit SPARC ELF

AS      := sparc64-linux-gnu-as
LD      := sparc64-linux-gnu-ld

ASFLAGS := -32 -Av8
LDFLAGS := -m elf32_sparc

TARGET  := build/hello
OBJECT  := build/main.o
SOURCE  := main.s

.PHONY: all clean info

all: $(TARGET)

build:
	mkdir -p build

$(OBJECT): $(SOURCE) | build
	$(AS) $(ASFLAGS) -o $@ $<

$(TARGET): $(OBJECT)
	$(LD) $(LDFLAGS) -o $@ $<

info: $(TARGET)
	file $(TARGET)
	readelf -h $(TARGET)

clean:
	rm -rf build
