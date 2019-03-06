CORE := usb

DEPS_usb := misc

RTL_SRCS_usb := $(addprefix rtl/, \
	usb.v \
	usb_crc.v \
	usb_ep_buf.v \
	usb_ep_status.v \
	usb_phy.v \
	usb_rx_ll.v \
	usb_rx_pkt.v \
	usb_trans.v \
	usb_tx_ll.v \
	usb_tx_pkt.v \
)

PREREQ_usb := \
	$(ROOT)/cores/usb/rtl/usb_defs.vh \
	$(BUILD_TMP)/usb_trans_mc.hex \
	$(BUILD_TMP)/usb_ep_status.hex

TESTBENCHES_usb := \
	usb_ep_buf_tb \
	usb_tb \
	usb_tx_tb

$(BUILD_TMP)/usb_trans_mc.hex: $(ROOT)/cores/usb/utils/microcode.py
	$(ROOT)/cores/usb/utils/microcode.py > $@

$(BUILD_TMP)/usb_ep_status.hex: $(ROOT)/cores/usb/data/usb_ep_status.hex
	cp -a $< $@

include $(ROOT)/build/core-magic.mk
