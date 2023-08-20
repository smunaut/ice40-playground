# Project config
PROJ = usb_amr

PROJ_DEPS := no2usb no2misc no2ice40
PROJ_RTL_SRCS := $(addprefix rtl/, \
	mc97.v \
	mc97_fifo.v \
	mc97_rfi.v \
	mc97_wb.v \
	dfu_helper.v \
	picorv32.v \
	picorv32_ice40_regs.v \
	soc_bram.v \
	soc_picorv32_base.v \
	soc_picorv32_bridge.v \
	soc_spram.v \
	soc_usb.v \
	sysmgr.v \
)
PROJ_TESTBENCHES := \
	mc97_tb \
	mc97_rfi_tb \
	$(NULL)
PROJ_PREREQ = \
	$(BUILD_TMP)/boot.hex
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

YOSYS_SYNTH_ARGS = -dffe_min_ce_use 4
NEXTPNR_ARGS = --pre-pack data/clocks.py --seed 2

# Include default rules
include ../../build/project-rules.mk

# Custom rules
fw/boot.hex:
	make -C fw boot.hex

$(BUILD_TMP)/boot.hex: fw/boot.hex
	cp $< $@
