CORE := spi_slave

RTL_SRCS_spi_slave := $(addprefix rtl/, \
	spi_fast_core.v \
	spi_fast.v \
	spi_reg.v \
	spi_simple.v \
)

TESTBENCHES_spi_slave := \
	spi_fast_core_tb \
	spi_tb

include $(ROOT)/build/core-magic.mk
