CORE := e1

RTL_SRCS_e1 = $(addprefix rtl/, \
	e1_crc4.v \
	e1_rx_clock_recovery.v \
	e1_rx_deframer.v \
	e1_rx_filter.v \
	e1_rx_phy.v \
	e1_rx.v \
	e1_tx_framer.v \
	e1_tx_phy.v \
	e1_tx.v \
	e1_wb.v \
	hdb3_dec.v \
	hdb3_enc.v \
)

TESTBENCHES_e1 := \
	e1_crc4_tb \
	e1_tb \
	e1_tx_framer_tb \
	hdb3_tb \

include $(ROOT)/build/core-magic.mk
