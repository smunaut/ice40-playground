#!/usr/bin/env python3

import struct
import sys


def main(argv0, in_name, out_name):
	with open(in_name, 'rb') as in_fh, open(out_name, 'w') as out_fh:
		while True:
			b = in_fh.read(4)
			if len(b) < 4:
				break
			out_fh.write('%08x\n' % struct.unpack('<I', b))

if __name__ == '__main__':
	main(*sys.argv)
