# Project config
PROJ = rgb_panel

PROJ_DEPS := hub75 spi_flash spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
	pgen.v \
	sysmgr.v \
	vgen.v \
	vstream.v \
)
PROJ_TESTBENCHES := \
	hub75_top_tb
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker-double
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --pre-pack data/clocks.py

# Include default rules
include ../../build/project-rules.mk

# Custom rules

	# SPI core selection
SPI ?= fast
ifeq ($(SPI),fast)
YOSYS_READ_ARGS += -DSPI_FAST=1
endif

	# Panel frequency
PANEL ?= fast
ifeq ($(PANEL),fast)
YOSYS_READ_ARGS += -DPANEL_FAST=1
endif

	# Custom data program
$(BUILD_TMP)/$(PROJ)-video.bin: $(BUILD_TMP)/$(PROJ).bin data/nyan_glitch_64x64x16.raw
	cp $< $@
	dd if=data/nyan_glitch_64x64x16.raw of=$@ seek=256 bs=1024

data-prog: $(BUILD_TMP)/$(PROJ)-video.bin
	$(ICEPROG) $<

