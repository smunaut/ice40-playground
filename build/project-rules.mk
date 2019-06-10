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

ifeq ($(PLACER),heap)
NEXTPNR_SYS_ARGS += --placer heap
endif

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
$(BUILD_TMP)/proj-deps.mk: Makefile $(BUILD_TMP) $(addprefix $(BUILD_TMP)/deps-core-,$(PROJ_DEPS))
	@echo "include $(BUILD_TMP)/deps-core-*" > $@
	@echo "PROJ_ALL_DEPS := \$$(DEPS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_RTL_SRCS := \$$(RTL_SRCS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_SIM_SRCS := \$$(SIM_SRCS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_PREREQ := \$$(PREREQ_SOLVE_TMP)" >> $@

include $(BUILD_TMP)/proj-deps.mk

# Make all sources absolute
PROJ_RTL_SRCS := $(abspath $(PROJ_RTL_SRCS))
PROJ_TOP_SRC  := $(abspath $(PROJ_TOP_SRC))

# Board config
PIN_DEF ?= $(abspath data/$(PROJ_TOP_MOD)-$(BOARD).pcf)

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
YOSYS_READ_ARGS += -D$(BOARD_DEFINE)=1

# Add those to the list
PROJ_ALL_RTL_SRCS += $(PROJ_RTL_SRCS)
PROJ_ALL_SIM_SRCS += $(PROJ_SIM_SRCS)
PROJ_ALL_PREREQ += $(PROJ_PREREQ)

# Include path
PROJ_SYNTH_INCLUDES := -I$(abspath rtl/) $(addsuffix /rtl/, $(addprefix -I$(ROOT)/cores/, $(PROJ_ALL_DEPS)))
PROJ_SIM_INCLUDES   := -I$(abspath sim/) $(addsuffix /sim/, $(addprefix -I$(ROOT)/cores/, $(PROJ_ALL_DEPS)))


# Synthesis & Place-n-route rules

$(BUILD_TMP)/$(PROJ).ys: $(PROJ_TOP_SRC) $(PROJ_ALL_RTL_SRCS)
	@echo "read_verilog $(YOSYS_READ_ARGS) $(PROJ_SYNTH_INCLUDES) $(PROJ_TOP_SRC) $(PROJ_ALL_RTL_SRCS)" > $@
	@echo "synth_ice40 $(YOSYS_SYNTH_ARGS) -top $(PROJ_TOP_MOD) -json $(PROJ).json" >> $@

$(BUILD_TMP)/$(PROJ).synth.rpt $(BUILD_TMP)/$(PROJ).json: $(PROJ_ALL_PREREQ) $(BUILD_TMP)/$(PROJ).ys $(PROJ_ALL_RTL_SRCS)
	cd $(BUILD_TMP) && \
		$(YOSYS) -s $(BUILD_TMP)/$(PROJ).ys \
			 -l $(BUILD_TMP)/$(PROJ).synth.rpt

$(BUILD_TMP)/$(PROJ).pnr.rpt $(BUILD_TMP)/$(PROJ).asc: $(BUILD_TMP)/$(PROJ).json $(PIN_DEF)
	$(NEXTPNR) $(NEXTPNR_ARGS) $(NEXTPNR_SYS_ARGS) \
		--$(DEVICE) --package $(PACKAGE)  \
		-l $(BUILD_TMP)/$(PROJ).pnr.rpt \
		--json $(BUILD_TMP)/$(PROJ).json \
		--pcf $(PIN_DEF) \
		--asc $@ 

%.bin: %.asc
	$(ICEPACK) -s $< $@


# Simulation
$(BUILD_TMP)/%_tb: sim/%_tb.v $(ICE40_LIBS) $(PROJ_ALL_PREREQ) $(PROJ_ALL_RTL_SRCS) $(PROJ_ALL_SIM_SRCS)
	$(IVERILOG) -Wall -DSIM=1 -D$(BOARD_DEFINE)=1 -o $@ \
		$(PROJ_SYNTH_INCLUDES) $(PROJ_SIM_INCLUDES) \
		$(addprefix -l, $(ICE40_LIBS) $(PROJ_ALL_RTL_SRCS) $(PROJ_ALL_SIM_SRCS)) \
		$<


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
