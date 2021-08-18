# Project config
PROJ = memtest

PROJ_DEPS := no2misc no2ice40
PROJ_RTL_SRCS := $(addprefix rtl/, \
	memtest.v \
	uart2wb.v \
	sys_mgr.v \
)
PROJ_TESTBENCHES := \
	$(NULL)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

PIN_DEF = $(BUILD_TMP)/$(PROJ_TOP_MOD).pcf
NEXTPNR_ARGS = --no-promote-globals --timing-allow-fail --pre-pack data/clocks.py --pre-place $(CORE_no2ice40_DIR)/sw/serdes-nextpnr-place.py

PCFS = $(abspath data/$(PROJ_TOP_MOD)-$(BOARD).pcf) $(abspath data/$(PROJ_TOP_MOD)-$(BOARD)-$(MEM).pcf)

# Build options
	# spi / hyperram
MEM ?= spi
	# none / 4bpp / 12bpp
VIDEO ?= none

YOSYS_READ_ARGS += -DMEM_$(MEM)=1 -DVIDEO_$(VIDEO)=1

ifeq ($(MEM),spi)
	PROJ_DEPS += no2qpimem
endif
ifeq ($(MEM),hyperram)
	PROJ_DEPS += no2hyperbus
endif

ifneq ($(VIDEO),none)
	PROJ_DEPS += video
	PROJ_RTL_SRCS += $(addprefix rtl/, \
		hdmi_buf.v \
		hdmi_out.v \
	)
	PCFS += $(abspath data/$(PROJ_TOP_MOD)-$(BOARD)-hdmi-$(VIDEO).pcf)
endif

# Include default rules
include ../../build/project-rules.mk

# Custom rules
$(PIN_DEF): $(PCFS)
	cat $^ > $@
