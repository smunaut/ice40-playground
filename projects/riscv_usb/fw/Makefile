BOARD ?= icebreaker
CROSS ?= riscv-none-elf-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
ICEPROG = iceprog
DFU_UTIL = dfu-util

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs -D$(BOARD_DEFINE) -I.

NO2USB_FW_VERSION=0
include ../../../cores/no2usb/fw/fw.mk
CFLAGS += $(INC_no2usb)

HEADERS_common=\
	config.h \
	console.h \
	led.h \
	mini-printf.h \
	spi.h \
	utils.h \
	$(HEADERS_no2usb)

SOURCES_common=\
	start.S \
	console.c \
	led.c \
	mini-printf.c  \
	spi.c \
	utils.c \
	$(SOURCES_no2usb)

HEADERS_app=\
	usb_str_app.gen.h \
	$(NULL)

SOURCES_app=\
	fw_app.c \
	usb_desc_app.c \
	$(NULL)


all: boot.hex fw_app.bin


boot.elf: lnk-boot.lds boot.S
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-boot.lds,--strip-debug -DFLASH_APP_ADDR=0x000a0000 -o $@ boot.S

fw_app.elf: lnk-app.lds $(HEADERS_app) $(SOURCES_app) $(HEADERS_common) $(SOURCES_common)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES_common) $(SOURCES_app)


%.hex: %.bin
	./bin2hex.py $< $@

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

.PHONY: prog_app clean
