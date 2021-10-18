BOARD ?= bitsy-v1
CROSS ?= riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
ICEPROG = iceprog
DFU_UTIL = dfu-util

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs -D$(BOARD_DEFINE) -I.

NO2USB_FW_VERSION=0
include ../../../cores/no2usb/fw/fw.mk
CFLAGS += $(INC_no2usb)

HEADERS=\
	config.h \
	console.h \
	framegrab.h \
	i2c.h \
	led.h \
	mini-printf.h \
	usb_str_app.gen.h \
	$(HEADERS_no2usb)

SOURCES=\
	start.S \
	fw_app.c \
	console.c \
	framegrab.c \
	i2c.c \
	led.c \
	mini-printf.c \
	usb_desc_app.c \
	$(SOURCES_no2usb)

all: fw_app.bin


fw_app.elf: lnk-app.lds $(HEADERS) $(SOURCES)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES)

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@


prog: fw_app.bin
	$(ICEPROG) -o 640k $<

dfuprog: fw_app.bin
ifeq ($(DFU_SERIAL),)
	$(DFU_UTIL) -R -a 1 -D $<
else
	$(DFU_UTIL) -R -S $(DFU_SERIAL) -a 1 -D $<
endif


clean:
	rm -f *.bin *.hex *.elf *.o *.gen.h

.PHONY: prog dfuprog clean
