#
# core-rules.mk
#

# Save value
THIS_CORE := $(CORE)

# Default tools
IVERILOG ?= iverilog

ICE40_LIBS ?= $(shell yosys-config --datdir/ice40/cells_sim.v)


# Must be first rule and call it 'all' by convention
all: sim

# Base directories
ifeq ($(origin NO2BUILD_DIR), undefined)
NO2BUILD_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
endif

ifeq ($(origin NO2CORES_DIR), undefined)
NO2CORES_DIR := $(abspath $(NO2BUILD_DIR)/../cores)
endif

# Temporary build-directory
BUILD_TMP := $(abspath build-tmp)

$(BUILD_TMP):
	mkdir -p $(BUILD_TMP)

# Discover all cores
$(foreach core_def, $(wildcard $(NO2CORES_DIR)/*/no2core.mk), $(eval include $(core_def)))

# Resolve dependency tree for project and collect sources
$(BUILD_TMP)/core-deps.mk: Makefile $(BUILD_TMP) $(BUILD_TMP)/deps-core-$(THIS_CORE)
	@echo "SELF_DIR := \$$(dir \$$(lastword \$$(MAKEFILE_LIST)))" > $@
	@echo "include \$$(SELF_DIR)deps-core-*" >> $@
	@echo "CORE_ALL_DEPS := \$$(DEPS_SOLVE_TMP)" >> $@
	@echo "CORE_ALL_RTL_SRCS := \$$(RTL_SRCS_SOLVE_TMP)" >> $@
	@echo "CORE_ALL_SIM_SRCS := \$$(SIM_SRCS_SOLVE_TMP)" >> $@
	@echo "CORE_ALL_PREREQ := \$$(PREREQ_SOLVE_TMP)" >> $@

include $(BUILD_TMP)/core-deps.mk

# Include path
CORE_SYNTH_INCLUDES := $(addsuffix /rtl/, $(addprefix -I$(NO2CORES_DIR)/, $(CORE_ALL_DEPS)))
CORE_SIM_INCLUDES   := $(addsuffix /sim/, $(addprefix -I$(NO2CORES_DIR)/, $(CORE_ALL_DEPS)))


# Simulation
$(BUILD_TMP)/%_tb: sim/%_tb.v $(ICE40_LIBS) $(CORE_ALL_PREREQ) $(CORE_ALL_RTL_SRCS) $(CORE_ALL_SIM_SRCS)
	iverilog -Wall -Wno-portbind -Wno-timescale -DSIM=1 -o $@ \
		$(CORE_SYNTH_INCLUDES) $(CORE_SIM_INCLUDES) \
		$(addprefix -l, $(ICE40_LIBS) $(CORE_ALL_RTL_SRCS) $(CORE_ALL_SIM_SRCS)) \
		$<


# Action targets
sim: $(addprefix $(BUILD_TMP)/, $(TESTBENCHES_$(THIS_CORE)))

clean:
	@rm -Rf $(BUILD_TMP)


.PHONY: all sim clean
