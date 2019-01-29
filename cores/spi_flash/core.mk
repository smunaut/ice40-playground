CORE := spi_flash

RTL_SRCS_spi_flash := $(addprefix rtl/, \
	spi_flash_reader.v \
)

TESTBENCHES_spi_flash := \
	spi_flash_reader_tb

include $(ROOT)/build/core-magic.mk
