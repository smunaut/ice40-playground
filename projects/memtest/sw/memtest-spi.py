#!/usr/bin/python3

import binascii
import random
import sys

from memtest import WishboneInterface, MemoryTester, HDMIOutput
from memtest import QSPIController


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def hexdump(x):
	return binascii.b2a_hex(x).decode('utf-8')

def RAM_ADDR_CS(cs, addr):
	return (cs << 30) | addr


def main(argv0, port='/dev/ttyUSB1', filename=None):
	# Connect to board
	wb = WishboneInterface(port)

	# Devices on the bus
	flash    = QSPIController(wb, 0x00000, cs=0)
	psram    = QSPIController(wb, 0x00000, cs=1)
	memtest  = MemoryTester(wb, 0x10000)
	hdmi     = HDMIOutput(wb, 0x20000)

	# Make sure to disable DMA
	hdmi.disable()
	wb.aux_csr(0)

	# Read chip IDs
	print("[+] ID read")
	print(" Flash: " + hexdump(flash.spi_xfer(b'\x9f', rx_len=3)))
	print(" PSRAM: " + hexdump(psram.spi_xfer(b'\x9f', dummy_len=3, rx_len=8)))

	# Enable PSRAM QPI
	psram.spi_xfer(b'\x35')

	# Manual page read/write test
	if True:
		print("[+] Manual page read/write test")

		# Write a random page
		data = bytes([random.randint(0,255) for i in range(256)])
		psram.qpi_xfer(b'\x02\x01\x00\x00', data)

		# Read it back
		rdata = psram.qpi_xfer(b'\xeb\x01\x00\x00', dummy_len=3, rx_len=256)

		# Results
		if data != rdata:
			print("[!] Failed")
			print(" Orig: " + hexdump(data))
			print(" Read: " + hexdump(rdata))
			print(" Diff: " + hexdump(bytes([a^b for a,b in zip(data,rdata) ])))
		else:
			print("[.] OK")

	# What mode ?
	if filename is None:
		# Run memtest on PSRAM
		print("[+] Testing PSRAM")
		good = memtest.run(RAM_ADDR_CS(1, 0), 1<<21)
		if good:
			print("[.]  All good !")
		else:
			print("[!]  Errors found !")

		# Disable QPI
		psram.qpi_xfer(b'\xf5')

	else:
		# Load data file
		print("[+] Uploading image data")

		img = open(filename, 'rb').read()
		img = bytearray([(a << 4) | b for a, b in zip(img[0::2], img[1::2])])
		memtest.load_data(RAM_ADDR_CS(1, 0), img)

		print("[+] Uploading palette")
		try:
			# Palette data from file
			def to_col(d):
				return (
					(((d[2] + 0x08) >> 4) << 8) |
					(((d[1] + 0x08) >> 4) << 4) |
					(((d[0] + 0x08) >> 4) << 0) |
					0
				)
			with open(filename + '.pal', 'rb') as fh:
				pal = [to_col(fh.read(3)) for i in range(16)]
			for i in range(4*16):
				hdmi.pal_write(i, pal[i&15])
		except:
			# 1:1 palette
			for i in range(4*16):
				hdmi.pal_write(i, i&15)

		# Start DMA
		print("[+] Starting DMA")
		wb.aux_csr(1)
		hdmi.enable(RAM_ADDR_CS(1, 0), 64)

	# Done
	return 0


if __name__ == '__main__':
	sys.exit(main(*sys.argv) or 0)
