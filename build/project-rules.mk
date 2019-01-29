#
# project-rules.mk
#

# Default tools
YOSYS ?= yosys
YOSYS_READ_ARGS ?=
YOSYS_SYNTH_ARGS ?= -dffe_min_ce_use 4 -relut
NEXTPNR ?= nextpnr-ice40
NEXTPNR_ARGS ?= --freq 50
ICEPACK ?= icepack
ICEPROG ?= iceprog
IVERILOG ?= iverilog

ICE40_LIBS ?= $(shell yosys-config --datdir/ice40/cells_sim.v)


# Must be first rule and call it 'all' by convention
all: synth

# Root directory
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# Temporary build-directory
BUILD_TMP := $(abspath build-tmp)

$(BUILD_TMP):
	mkdir -p $(BUILD_TMP)

# Discover all cores
$(foreach core_dir, $(wildcard $(ROOT)/cores/*), $(eval include $(core_dir)/core.mk))

# Resolve dependency tree for project and collect sources
$(BUILD_TMP)/proj-deps.mk: Makefile $(BUILD_TMP) $(addprefix deps-core-,$(PROJ_DEPS))
	@echo "PROJ_ALL_DEPS := $(DEPS_SOLVE_TMP)" > $@
	@echo "PROJ_ALL_SRCS := $(SRCS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_PREREQ := $(PREREQ_SOLVE_TMP)" >> $@

include $(BUILD_TMP)/proj-deps.mk

# Make all sources absolute
PROJ_RTL_SRCS := $(abspath $(PROJ_RTL_SRCS))
PROJ_TOP_SRC  := $(abspath $(PROJ_TOP_SRC))

PIN_DEF ?= $(abspath data/$(PROJ_TOP_MOD)-$(BOARD).pcf)

# Add those to the list
PROJ_ALL_SRCS += $(PROJ_RTL_SRCS)
PROJ_ALL_PREREQ += $(PROJ_PREREQ)


# Synthesis & Place-n-route rules

$(BUILD_TMP)/$(PROJ).ys: $(PROJ_TOP_SRC) $(PROJ_ALL_SRCS)
	@echo "read_verilog $(YOSYS_READ_ARGS) $(PROJ_TOP_SRC) $(PROJ_ALL_SRCS)" > $@
	@echo "synth_ice40 $(YOSYS_SYNTH_ARGS) -top $(PROJ_TOP_MOD) -json $(PROJ).json" >> $@

$(BUILD_TMP)/$(PROJ).synth.rpt $(BUILD_TMP)/$(PROJ).json: $(PROJ_ALL_PREREQ) $(BUILD_TMP)/$(PROJ).ys $(PROJ_ALL_SRCS)
	cd $(BUILD_TMP) && \
		$(YOSYS) -s $(BUILD_TMP)/$(PROJ).ys \
			 -l $(BUILD_TMP)/$(PROJ).synth.rpt

$(BUILD_TMP)/$(PROJ).pnr.rpt $(BUILD_TMP)/$(PROJ).asc: $(BUILD_TMP)/$(PROJ).json $(PIN_DEF)
	$(NEXTPNR) $(NEXTPNR_ARGS) \
		--$(DEVICE) --package $(PACKAGE)  \
		-l $(BUILD_TMP)/$(PROJ).pnr.rpt \
		--json $(BUILD_TMP)/$(PROJ).json \
		--pcf $(PIN_DEF) \
		--asc $@ 

%.bin: %.asc
	$(ICEPACK) -s $< $@


# Simulation
$(BUILD_TMP)/%_tb: sim/%_tb.v $(ICE40_LIBS) $(PROJ_ALL_PREREQ) $(PROJ_ALL_SRCS)
	iverilog -Wall -DSIM=1 -o $@ $(ICE40_LIBS) $(PROJ_ALL_SRCS) $<


# Action targets

synth: $(BUILD_TMP)/$(PROJ).bin

sim: $(addprefix $(BUILD_TMP)/, $(PROJ_TESTBENCHES))

prog: $(BUILD_TMP)/$(PROJ).bin
	$(ICEPROG) $<

sudo-prog: $(BUILD_TMP)/$(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo $(ICEPROG) $<

clean:
	@rm -Rf $(BUILD_TMP)


.PHONY: all synth sim prog sudo-prog clean
