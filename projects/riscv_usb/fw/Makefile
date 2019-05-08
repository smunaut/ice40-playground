BOARD ?= icebreaker
CROSS = riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
ICEPROG = iceprog

CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section -DBOARD_$(BOARD)

HEADERS=\
	config.h \
	console.h \
	led.h \
	mini-printf.h \
	spi.h \
	usb_priv.h \
	usb_desc_data.h

SOURCES=\
	start.S \
	console.c \
	firmware.c \
	led.c \
	mini-printf.c  \
	spi.c \
	usb.c \
	usb_ep0.c \
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
