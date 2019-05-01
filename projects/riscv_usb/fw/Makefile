BOARD ?= icebreaker
CROSS ?= riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
ICEPROG = iceprog

CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs -DBOARD_$(BOARD)


HEADERS_common=\
	config.h \
	console.h \
	led.h \
	mini-printf.h \
	spi.h \
	usb_hw.h \
	usb_priv.h \
	usb_proto.h \
	utils.h

SOURCES_common=\
	start.S \
	console.c \
	led.c \
	mini-printf.c  \
	spi.c \
	usb.c \
	usb_ctrl_ep0.c \
	usb_ctrl_std.c \
	utils.c

HEADERS_app=\
	usb_str_app.gen.h

SOURCES_app=\
	fw_app.c \
	usb_desc_app.c


all: boot_app.hex fw_app.bin


boot_app.elf: lnk-boot.lds boot.S
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-boot.lds,--strip-debug -DFLASH_APP_ADDR=0x000a0000 -o $@ boot.S

fw_app.elf: lnk-app.lds $(HEADERS_app) $(SOURCES_app) $(HEADERS_common) $(SOURCES_common)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES_common) $(SOURCES_app)


%.hex: %.bin
	./bin2hex.py $< $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

usb_str_%.gen.h: usb_str_%.txt
	./usb_gen_strings.py $< $@ $(BOARD)


prog_app: fw_app.bin
	$(ICEPROG) -o 640k $<


clean:
	rm -f *.bin *.hex *.elf *.o *.gen.h

.PHONY: prog_app clean
