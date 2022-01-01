BOARD ?= icebreaker
CROSS ?= riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
ICEPROG = iceprog
DFU_UTIL = dfu-util

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
CFLAGS=-Wall -Wextra -Wno-unused-parameter -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs -D$(BOARD_DEFINE) -I.


# Common / Shared
COMMON_PATH=../../riscv_usb/fw/
CFLAGS += -I$(COMMON_PATH)

HEADERS_common=$(addprefix $(COMMON_PATH), \
	console.h \
	led.h \
	mini-printf.h \
	spi.h \
	utils.h \
)

SOURCES_common=$(addprefix $(COMMON_PATH), \
	start.S \
	console.c \
	led.c \
	mini-printf.c  \
	spi.c \
	utils.c \
)


# USB
NO2USB_FW_VERSION=0
include ../../../cores/no2usb/fw/fw.mk
CFLAGS += $(INC_no2usb)

SOURCES_common += $(SOURCES_no2usb)
HEADERS_common += $(HEADERS_no2usb)


# Local
HEADERS_app=\
	config.h \
	audio.h \
	cdc-dlm.h \
	mc97.h \
	usb_str_app.gen.h \
	$(NULL)

SOURCES_app=\
	audio.c \
	cdc-dlm.c \
	mc97.c \
	fw_app.c \
	usb_desc_app.c \
	$(NULL)


all: boot.hex fw_app.bin


boot.elf: $(COMMON_PATH)/lnk-boot.lds $(COMMON_PATH)/boot.S
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,$(COMMON_PATH)/lnk-boot.lds,--strip-debug -DFLASH_APP_ADDR=0x000a0000 -o $@ $(COMMON_PATH)/boot.S

fw_app.elf: $(COMMON_PATH)/lnk-app.lds $(HEADERS_app) $(SOURCES_app) $(HEADERS_common) $(SOURCES_common)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,$(COMMON_PATH)/lnk-app.lds,--strip-debug -o $@ $(SOURCES_common) $(SOURCES_app)


%.hex: %.bin
	$(COMMON_PATH)/bin2hex.py $< $@

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
