#!/usr/bin/env python3

import sys

"""
0		0x000000	Multiboot header
16k     0x004000	Boot stub FPGA Image
128k    0x020000	Boot stub Software image (not used)

256k    0x040000	DFU FPGA Image
384k    0x060000	DFU Software Image

512k    0x080000	App 1 FPGA Image
640k    0x0a0000	App 1 Software Image

768k    0x0c0000	App 2 FPGA Image
896k    0x0e0000	App 2 Software Image
"""


def hdr(mode, offset):
	return bytes([
		# Sync header
		0x7e, 0xaa, 0x99, 0x7e,

		# Boot mode
		0x92, 0x00, (0x01 if mode else 0x00),

		# Boot address
		0x44, 0x03,
			(offset >> 16) & 0xff,
			(offset >>  8) & 0xff,
			(offset >>  0) & 0xff,

		# Bank offset
		0x82, 0x00, 0x00,

		# Reboot
		0x01, 0x08,

		# Padding
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	])


offset_map = [
	(True,  0x004000, 0x020000),
	(False, 0x004000, 0x020000),
	(False, 0x040000, 0x060000),
	(False, 0x080000, 0x0a0000),
	(False, 0x0c0000, 0x0e0000),
]


def load_image(img_name):
	# Solit filename
	if ':' in img_name:
		bs_name, fw_name = img_name.split(':', 2)	
		bs_name = bs_name or None
		fw_name = fw_name or None
	else:
		bs_name = img_name
		fw_name = None

	# Read
	bs = open(bs_name, 'rb').read() if (bs_name is not None) else b''
	fw = open(fw_name, 'rb').read() if (fw_name is not None) else b''

	return bs, fw

	
def main(argv0, out, *images):
	# Build the header
	mb_hdr = b''.join([hdr(m, o0) for m,o0,o1 in offset_map])

	# Load images (if any)
	images = [load_image(i) for i in images]

	# Build final image
	data = bytearray(mb_hdr)

	for (_, o_bs, o_fw), (d_bs, d_fw) in zip(offset_map[1:], images):
		for o, d in [(o_bs, d_bs), (o_fw, d_fw)]:
			if len(d):
				data[len(data):] = bytearray(o + len(d) - len(data))
				data[o:o+len(d)] = d

	# Write final image
	with open(out, 'wb') as fh:
		fh.write( data )


if __name__ == '__main__':
	main(*sys.argv)

