CORE := hub75

DEPS_hub75 := misc

RTL_SRCS_hub75 := $(addprefix rtl/, \
	hub75_bcm.v \
	hub75_blanking.v \
	hub75_colormap.v \
	hub75_fb_readout.v \
	hub75_fb_writein.v \
	hub75_framebuffer.v \
	hub75_gamma.v \
	hub75_init_inject.v \
	hub75_linebuffer.v \
	hub75_phy.v \
	hub75_phy_ddr.v \
	hub75_scan.v \
	hub75_shift.v \
	hub75_top.v \
)

TESTBENCHES_hub75 := \
	hub75_init_inject_tb \

PREREQ_hub75 := \
	$(BUILD_TMP)/gamma_table.hex

include $(ROOT)/build/core-magic.mk

$(BUILD_TMP)/gamma_table.hex: $(CORE_hub75_DIR)/sw/mkgamma.py
	$(CORE_hub75_DIR)/sw/mkgamma.py > $@
