# Project config
PROJ = nano-pmod-up5k

PROJ_DEPS := no2misc spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
	nano_dsi_clk.v \
	nano_dsi_data.v \
	pkt_fifo.v \
	pkt_spi_write.v \
	sysmgr.v \
)
PROJ_TESTBENCHES := \
	dsi_tb  \
	pkt_fifo_tb  \
	pkt_spi_write_tb

PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --freq 55

# Include default rules
include ../../build/project-rules.mk

# Custom rules

	# SPI core selection
SPI ?= fast
ifeq ($(SPI),fast)
YOSYS_READ_ARGS += -DSPI_FAST=1
endif
