# Export core directory
CORE_$(CORE)_DIR := $(abspath $(ROOT)/cores/$(CORE)/)

# Make the sources path absolute
RTL_SRCS_$(CORE) := $(addprefix $(CORE_$(CORE)_DIR)/,$(RTL_SRCS_$(CORE)))
SIM_SRCS_$(CORE) := $(addprefix $(CORE_$(CORE)_DIR)/,$(SIM_SRCS_$(CORE)))

# Dependency collection target
$(BUILD_TMP)/deps-core-$(CORE): $(CORE_$(CORE)_DIR)/core.mk $(addprefix $(BUILD_TMP)/deps-core-,$(DEPS_$(CORE)))
	$(eval CORE := $(subst $(BUILD_TMP)/deps-core-,,$@))
	@echo "DEPS_SOLVE_TMP += $(CORE)" > $@
	@echo "RTL_SRCS_SOLVE_TMP += $(RTL_SRCS_$(CORE))" >> $@
	@echo "SIM_SRCS_SOLVE_TMP += $(SIM_SRCS_$(CORE))" >> $@
	@echo "PREREQ_SOLVE_TMP +=  $(PREREQ_$(CORE))" >> $@
