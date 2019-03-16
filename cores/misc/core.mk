CORE := misc

RTL_SRCS_misc = $(addprefix rtl/, \
	delay.v \
	fifo_sync_ram.v \
	fifo_sync_shift.v \
	glitch_filter.v \
	ram_sdp.v \
	prims.v \
	pwm.v \
	uart_rx.v \
	uart_tx.v \
)

TESTBENCHES_misc := \
	fifo_tb \
	uart_tb \

include $(ROOT)/build/core-magic.mk
