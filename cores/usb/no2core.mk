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

PREREQ_usb = \
	$(CORE_usb_DIR)/rtl/usb_defs.vh \
	$(BUILD_TMP)/usb_trans_mc.hex \
	$(BUILD_TMP)/usb_ep_status.hex

TESTBENCHES_usb := \
	usb_ep_buf_tb \
	usb_tb \
	usb_tx_tb

include $(NO2BUILD_DIR)/core-magic.mk

$(BUILD_TMP)/usb_trans_mc.hex: $(CORE_usb_DIR)/utils/microcode.py
	$(CORE_usb_DIR)/utils/microcode.py > $@

$(BUILD_TMP)/usb_ep_status.hex: $(CORE_usb_DIR)/data/usb_ep_status.hex
	cp -a $< $@
