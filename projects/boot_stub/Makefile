# Project config
PROJ = boot_stub

PROJ_DEPS := misc
PROJ_RTL_SRCS := $(addprefix rtl/, \
)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icebreaker
DEVICE = up5k
PACKAGE = sg48

NEXTPNR_ARGS = --freq 48 --no-promote-globals

# Include default rules
include ../../build/project-rules.mk

# Custom rules
$(BUILD_TMP)/boot_mb.bin: $(BUILD_TMP)/$(PROJ).bin
	./utils/mkmultiboot.py $@ $<

build-mb: $(BUILD_TMP)/boot_mb.bin

prog-mb: $(BUILD_TMP)/boot_mb.bin
	$(ICEPROG) $<

sudo-prog-mb: $(BUILD_TMP)/boot_mb.bin
	@echo 'Executing prog as root!!!'
	sudo $(ICEPROG) $<

.PHONY: build-mb prog-mb sudo-prog-mb
