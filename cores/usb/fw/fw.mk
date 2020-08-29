SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

ifeq ($(NO2USB_FW_VERSION),0)
include $(SELF_DIR)v0/fw.mk
endif
