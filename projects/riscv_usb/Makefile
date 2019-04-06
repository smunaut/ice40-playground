# Project config
PROJ = riscv_usb

PROJ_DEPS := usb misc ice40
PROJ_RTL_SRCS := $(addprefix rtl/, \
	bridge.v \
	dfu_helper.v \
	iobuf.v \
	picorv32.v \
	soc_bram.v \
	soc_spram.v \
	sysmgr.v \
	wb_arbiter.v \
	wb_dma.v \
	wb_e1data.v \
	wb_epbuf.v \
	wb_spram.v \
)
PROJ_SIM_SRCS := $(addprefix sim/, \
	spiflash.v \
)
PROJ_SIM_SRCS += rtl/top.v
PROJ_TESTBENCHES := \
	dfu_helper_tb \
	top_tb
PROJ_PREREQ = \
	$(BUILD_TMP)/boot.hex
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOOT_CODE ?= app
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --pre-pack data/clocks.py --seed 2

# Include default rules
include ../../build/project-rules.mk

# Custom rules
ifeq ($(BOOT_CODE),dfu)
YOSYS_READ_ARGS += -DDFU=1
endif

fw/boot_$(BOOT_CODE).hex:
	make -C fw boot_$(BOOT_CODE).hex

$(BUILD_TMP)/boot.hex: fw/boot_$(BOOT_CODE).hex
	cp $< $@
