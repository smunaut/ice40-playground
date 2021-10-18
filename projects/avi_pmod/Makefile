# Project config
PROJ = avi_pmod

PROJ_DEPS=no2ice40 no2misc no2usb no2qpimem
PROJ_RTL_SRCS := $(addprefix rtl/, \
	dfu_helper.v \
	hdmi_phy_ddr_1x.v \
	picorv32_ice40_regs.v \
	picorv32.v \
	memif_arb.v \
	soc_bram.v \
	soc_dma.v \
	soc_picorv32_base.v \
	soc_picorv32_bridge.v \
	soc_spram.v \
	soc_usb_buf_bridge.v \
	sysmgr.v \
	vid_frame_grab.v \
	vid_in_phy.v \
	vid_in_sync.v \
	vid_line_mem.v \
	vid_pix_fifo.v \
	vid_render.v \
	vid_ycbcr2rgb.v \
)
PROJ_TESTBENCHES := \
	vid_in_tb \
	vid_pix_fifo_tb \
	$(NULL)
PROJ_PREREQ = \
	$(BUILD_TMP)/boot.hex
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= bitsy-v1
DEVICE = up5k
PACKAGE = sg48
SEED ?= 7

NEXTPNR_ARGS = --no-promote-globals --pre-pack data/clocks.py --pre-place $(CORE_no2ice40_DIR)/sw/serdes-nextpnr-place.py --seed $(SEED)

# Include default rules
include ../../build/project-rules.mk

# Custom rules
fw_boot/boot.hex: fw_boot
	make -C fw_boot boot.hex

$(BUILD_TMP)/boot.hex: fw_boot/boot.hex
	cp $< $@
