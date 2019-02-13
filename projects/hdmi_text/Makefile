# Project config
PROJ = hdmi_text

PROJ_DEPS := video spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
	sysmgr.v \
)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --freq 75 --no-promote-globals

# Include default rules
include ../../build/project-rules.mk

# Custom rules

	# SPI core selection
SPI ?= fast
ifeq ($(SPI),fast)
YOSYS_READ_ARGS += -DSPI_FAST=1
endif
