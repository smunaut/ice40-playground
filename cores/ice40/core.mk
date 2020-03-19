CORE := ice40

RTL_SRCS_ice40 := $(addprefix rtl/, \
	ice40_ebr.v \
	ice40_spram_gen.v \
)

TESTBENCHES_ice40 := \
	ice40_ebr_tb \
	$(NULL)

include $(ROOT)/build/core-magic.mk
