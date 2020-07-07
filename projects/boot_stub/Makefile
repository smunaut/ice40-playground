# Project config
PROJ = boot_stub

PROJ_DEPS := misc
PROJ_RTL_SRCS := $(addprefix rtl/, \
)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --freq 48 --no-promote-globals

# Include default rules
include ../../build/project-rules.mk

# Custom rules
	# Just bootstub in multi-boot image
$(BUILD_TMP)/boot_mb.bin: $(BUILD_TMP)/$(PROJ).bin
	./utils/mkmultiboot.py $@ $<

build-mb: $(BUILD_TMP)/boot_mb.bin

prog-mb: $(BUILD_TMP)/boot_mb.bin
	$(ICEPROG) $<

sudo-prog-mb: $(BUILD_TMP)/boot_mb.bin
	@echo 'Executing prog as root!!!'
	sudo $(ICEPROG) $<

	# Full DFU bootloader image
DFU_PROJ_BASE=$(realpath $(BUILD_TMP)/../../riscv_usb)

$(BUILD_TMP)/bootloader.bin: $(BUILD_TMP)/$(PROJ).bin $(DFU_PROJ_BASE)/build-tmp/riscv_usb.bin $(DFU_PROJ_BASE)/fw/fw_dfu.bin
	./utils/mkmultiboot.py $@ $(BUILD_TMP)/$(PROJ).bin $(DFU_PROJ_BASE)/build-tmp/riscv_usb.bin:$(DFU_PROJ_BASE)/fw/fw_dfu.bin

$(DFU_PROJ_BASE)/build-tmp/riscv_usb.bin:
	make -C $(DFU_PROJ_BASE) BOOT_CODE=dfu

$(DFU_PROJ_BASE)/fw/fw_dfu.bin:
	make -C $(DFU_PROJ_BASE)/fw fw_dfu.bin

bootloader-clean:
	if [ "$(PRE_CLEAN)" == "1" ]; then \
		make clean; \
		make -C $(DFU_PROJ_BASE) clean; \
		make -C $(DFU_PROJ_BASE)/fw clean; \
	fi

bootloader: bootloader-clean $(BUILD_TMP)/bootloader.bin

prog-bootloader: bootloader
	$(ICEPROG) $(BUILD_TMP)/bootloader.bin

sudo-prog-bootloader: bootloader
	@echo 'Executing prog as root!!!'
	sudo $(ICEPROG) $(BUILD_TMP)/bootloader.bin


.PHONY: build-mb prog-mb sudo-prog-mb bootloader-clean bootloader prog-bootloader sudo-prog-bootloader
