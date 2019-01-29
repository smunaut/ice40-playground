#!/usr/bin/env python3

import struct

from pyftdi.spi import SpiController


class BoardControlBase(object):

	def __init__(self, addr='ftdi://ftdi:2232h/1', spi_frequency=30e6, spi_cs=None):
		# SPI link
		self.spi_frequency = spi_frequency
		self.spi = SpiController(cs_count=3)
		self.spi.configure(addr)

		if spi_cs is not None:
			self.slave = self.spi.get_port(cs=spi_cs, freq=self.spi_frequency, mode=0)
		else:
			self.slave = self._spi_probe()

	def _spi_probe(self):
		for cs in [0, 2]:
			port = self.spi.get_port(cs=cs, freq=self.spi_frequency, mode=0)
			r = port.exchange(b'\x00', duplex=True)[0]
			if r != 0xff:
				return port
		raise RunttimeError('Automatic SPI CS probe failed')

	def reg_w16(self, reg, v):
		self.slave.exchange(struct.pack('>BH', reg, v))

	def reg_w8(self, reg, v):
		self.slave.exchange(struct.pack('>BB', reg, v))

	def reg_burst(self, reg, data):
		self.slave.exchange(bytearray([reg]) + data)

	def read_status(self):
		rv = self.slave.exchange(bytearray(2), duplex=True)
		return rv[0] | rv[1]


def arg_group_setup(group):
	group.add_argument('--spi-freq',  type=float, help='SPI frequency in MHz', default=30.0)
	group.add_argument('--spi-cs',    type=int,   help='SPI slave select id (-1 = probe)', default=-1)
	group.add_argument('--ftdi-addr', type=str,   help='FTDI address', default='ftdi://ftdi:2232h/1')


def arg_to_kwargs(args):
	return {
		'spi_frequency': args.spi_freq * 1e6,
		'spi_cs': args.spi_cs if (args.spi_cs >= 0) else None,
		'addr': args.ftdi_addr,
	}
