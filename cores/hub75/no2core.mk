CORE := no2hub75

DEPS_no2hub75 := no2misc

RTL_SRCS_no2hub75 := $(addprefix rtl/, \
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

TESTBENCHES_no2hub75 := \
	hub75_init_inject_tb \

PREREQ_no2hub75 := \
	$(BUILD_TMP)/gamma_table.hex

include $(NO2BUILD_DIR)/core-magic.mk

$(BUILD_TMP)/gamma_table.hex: $(CORE_no2hub75_DIR)/sw/mkgamma.py
	$(CORE_no2hub75_DIR)/sw/mkgamma.py > $@
