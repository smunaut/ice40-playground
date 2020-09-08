CORE := no2ice40

RTL_SRCS_no2ice40 := $(addprefix rtl/, \
	ice40_ebr.v \
	ice40_spram_gen.v \
	ice40_iserdes.v \
	ice40_oserdes.v \
	ice40_serdes_crg.v \
	ice40_serdes_dff.v \
	ice40_serdes_sync.v \
)

TESTBENCHES_no2ice40 := \
	ice40_ebr_tb \
	$(NULL)

include $(NO2BUILD_DIR)/core-magic.mk
