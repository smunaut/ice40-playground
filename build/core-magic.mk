# Export core directory
CORE_$(CORE)_DIR := $(abspath $(ROOT)/cores/$(CORE)/)

# Make the sources path absolute
RTL_SRCS_$(CORE) := $(addprefix $(CORE_$(CORE)_DIR)/,$(RTL_SRCS_$(CORE)))
TB_SRCS_$(CORE)  := $(addprefix $(CORE_$(CORE)_DIR)/,$(TB_SRCS_$(CORE)))

# Dependency collection target
deps-core-$(CORE): $(addprefix deps-core-,$(DEPS_$(CORE)))
	$(eval CORE := $(subst deps-core-,,$@))
	$(eval DEPS_SOLVE_TMP += $(CORE))
	$(eval SRCS_SOLVE_TMP += $(RTL_SRCS_$(CORE)))
	$(eval PREREQ_SOLVE_TMP += $(PREREQ_$(CORE)))

.PHONY: deps-core-$(CORE)
