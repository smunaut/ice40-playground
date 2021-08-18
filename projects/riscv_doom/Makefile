# Project config
PROJ = riscv_doom

PROJ_DEPS := no2usb no2misc no2ice40 no2qpimem no2memcache video
PROJ_RTL_SRCS := $(addprefix rtl/, \
	vid_top.v \
	vid_palette.v \
	vid_framebuf.v \
	soc_bram.v \
	sysmgr.v \
	VexRiscv.v \
)
PROJ_SIM_SRCS := $(addprefix sim/, \
	spiflash.v \
)
PROJ_SIM_SRCS += rtl/top.v
PROJ_TESTBENCHES := \
	top_tb
PROJ_PREREQ = \
	$(BUILD_TMP)/boot.hex
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

SEED ?= 4

YOSYS_SYNTH_ARGS = -dffe_min_ce_use 4 -abc9 -device u -dsp
NEXTPNR_ARGS = --pre-pack data/clocks.py --pre-place $(CORE_no2ice40_DIR)/sw/serdes-nextpnr-place.py --seed $(SEED)
NEXTPNR_ARGS += --timing-allow-fail

# Include default rules
include ../../build/project-rules.mk

# Custom rules
fw_boot/boot.hex:
	make -C fw_boot boot.hex

$(BUILD_TMP)/boot.hex: fw_boot/boot.hex
	cp $< $@
