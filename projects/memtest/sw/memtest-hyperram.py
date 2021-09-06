#!/usr/bin/env python3

#
# memtest-hyperram.py
#
# Control software for testing the HyperRAM
#
# Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: MIT
#

import sys

from memtest import WishboneInterface, MemoryTester, HDMIOutput
from memtest import HyperRAMController


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def RAM_ADDR_CS(cs, addr):
	return (cs << 30) | addr


def main(argv0, port='/dev/ttyUSB1', filename=None):
	# Connect to board
	wb = WishboneInterface(port)

	# Devices on the bus
	hyperram = HyperRAMController(wb, 0x00000)
	memtest  = MemoryTester(wb, 0x10000)
	hdmi     = HDMIOutput(wb, 0x20000)

	# Make sure to disable DMA
	hdmi.disable()
	wb.aux_csr(0)

	# Initialize HyperRAM core
	if hyperram.init() is False:
		print("[!] Init failed")
		return -1

	hyperram.set_runtime(True)

	# What mode ?
	if filename is None:
		# Run memtest
		for cs in range(4):
			if not (hyperram.csm & (1 << cs)):
				continue

			print("[+] Testing CS=%d" % cs)
			good = memtest.run(RAM_ADDR_CS(cs, 0), 1<<21)
			if good:
				print("[.]  All good !")
			else:
				print("[!]  Errors found !")

	else:
		# Load data file
		print("[+] Uploading image data")

		img = open(filename, 'rb').read()
		img = bytearray([(a << 4) | b for a, b in zip(img[0::2], img[1::2])])
		memtest.load_data(RAM_ADDR_CS(3, 0), img)

		# Palette (1:1)
		print("[+] Uploading palette")
		for i in range(4*16):
			hdmi.pal_write(i, i&15)

		# Start DMA
		print("[+] Starting DMA")
		wb.aux_csr(1)
		hdmi.enable(RAM_ADDR_CS(3, 0), 16)

	# Done
	return 0


if __name__ == '__main__':
	sys.exit(main(*sys.argv) or 0)
