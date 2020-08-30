CORE := no2misc

RTL_SRCS_no2misc = $(addprefix rtl/, \
	delay.v \
	fifo_sync_ram.v \
	fifo_sync_shift.v \
	glitch_filter.v \
	ram_sdp.v \
	prims.v \
	pdm.v \
	pwm.v \
	uart_rx.v \
	uart_tx.v \
	uart_wb.v \
	xclk_strobe.v \
	xclk_wb.v \
)

TESTBENCHES_no2misc := \
	fifo_tb \
	pdm_tb \
	uart_tb \

include $(NO2BUILD_DIR)/core-magic.mk
