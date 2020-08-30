CORE := spi_flash

RTL_SRCS_spi_flash := $(addprefix rtl/, \
	spi_flash_reader.v \
)

TESTBENCHES_spi_flash := \
	spi_flash_reader_tb

include $(NO2BUILD_DIR)/core-magic.mk
