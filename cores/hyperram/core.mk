CORE := hyperram

RTL_SRCS_hyperram := $(addprefix rtl/, \
	hram_dline.v \
	hram_phy_ice40.v \
	hram_top.v \
)

TESTBENCHES_hyperram := \
	hram_top_tb \
	$(NULL)

include $(ROOT)/build/core-magic.mk
