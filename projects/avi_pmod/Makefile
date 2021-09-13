# Project config
PROJ = avi_pmod

PROJ_DEPS=no2ice40 no2misc no2muacm no2qpimem
PROJ_RTL_SRCS := $(addprefix rtl/, \
	hdmi_phy_ddr_1x.v \
	vid_cap.v \
	vid_in_phy.v \
	vid_in_sync.v \
	vid_line_mem.v \
	vid_render.v \
	vid_ycbcr2rgb.v \
	sysmgr.v \
)
PROJ_TESTBENCHES := \
	vid_in_tb \
	$(NULL)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= bitsy-v1
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --no-promote-globals --pre-pack data/clocks.py --pre-place $(CORE_no2ice40_DIR)/sw/serdes-nextpnr-place.py

# Include default rules
include ../../build/project-rules.mk
