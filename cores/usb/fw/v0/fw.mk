CORE_no2usb_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

INC_no2usb := -I$(CORE_no2usb_DIR)/fw/v0/include

HEADERS_no2usb=$(addprefix $(CORE_no2usb_DIR)/fw/v0/include/, \
	no2usb/usb.h \
	no2usb/usb_dfu.h \
	no2usb/usb_dfu_proto.h \
	no2usb/usb_dfu_rt.h \
	no2usb/usb_hw.h \
	no2usb/usb_priv.h \
	no2usb/usb_proto.h \
)

SOURCES_no2usb=$(addprefix $(CORE_no2usb_DIR)/fw/v0/src/, \
	usb.c \
	usb_ctrl_ep0.c \
	usb_ctrl_std.c \
	usb_dfu.c \
	usb_dfu_rt.c \
	usb_dfu_vendor.c \
)

usb_str_%.gen.h: usb_str_%.txt
	$(CORE_no2usb_DIR)/fw/usb_gen_strings.py $< $@ $(BOARD)
