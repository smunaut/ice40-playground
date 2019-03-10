CROSS = riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
ICEPROG = iceprog

CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -nostartfiles

HEADERS=\
	mini-printf.h \
	io.h \
	usb_desc.h \
	usb_desc_data.h

SOURCES=\
	start.S \
	firmware.c \
	io.c \
	mini-printf.c  \
	usb_desc.c

firmware.elf: lnk-app.lds $(HEADERS) $(SOURCES)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES)

boot.elf: lnk-boot.lds boot.S
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-boot.lds,--strip-debug -o $@ boot.S

%.hex: %.bin
	./bin2hex.py $< $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

prog_fw: firmware.bin
	$(ICEPROG) -o 1M $<

clean:
	rm -f *.bin *.hex *.elf
