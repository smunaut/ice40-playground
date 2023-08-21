#!/usr/bin/env python3

import struct

import usb.core
import usb.util


class AMRModem:

	USB_RT_CDC_SET_AUX_LINE_STATE = ((0x10 << 8) | 0x21)
	USB_RT_CDC_SET_HOOK_STATE     = ((0x11 << 8) | 0x21)
	USB_RT_CDC_SET_COMM_FEATURE   = ((0x02 << 8) | 0x21)
	USB_RT_CDC_GET_COMM_FEATURE   = ((0x03 << 8) | 0xa1)
	USB_RT_CDC_CLEAR_COMM_FEATURE = ((0x04 << 8) | 0x21)

	ON_HOOK   = 0
	OFF_HOOK  = 1
	CALLED_ID = 2

	def __init__(self):
		# Locate device
		self.dev = usb.core.find(idVendor=0x1d50, idProduct=0x6175)
		if self.dev is None:
			raise ValueError('Device not found')

	def _ctrl(self, rt, wValue=0, data_or_wLength=None, timeout=None):
		return self.dev.ctrl_transfer(
			rt & 0xff,
			rt >> 8,
			wValue,
			4,
			data_or_wLength,
			timeout
		)

	def set_aux_line_state(self, state):
		self._ctrl(self.USB_RT_CDC_SET_AUX_LINE_STATE, 1 if state else 0)

	def set_hook_state(self, state):
		self._ctrl(self.USB_RT_CDC_SET_HOOK_STATE, state)

	def set_country(self, cc):
		self._ctrl(self.USB_RT_CDC_SET_COMM_FEATURE, 2, struct.pack('<H', cc))

	def get_country(self):
		return struct.unpack('<H', self._ctrl(self.USB_RT_CDC_GET_COMM_FEATURE, 2, 2))[0]

	def clear_country(self):
		self._ctrl(self.USB_RT_CDC_CLEAR_COMM_FEATURE, 2)

	def read_notif(self, timeout=None):
		return self.read(0x83, 8, timeout=timeout)
