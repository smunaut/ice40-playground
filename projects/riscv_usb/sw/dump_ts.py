#!/usr/bin/env python3

import binascii
import struct
import sys

from collections import namedtuple


fh_out0 = open('/tmp/out0.xlaw', 'wb')
fh_out1 = open('/tmp/out1.xlaw', 'wb')


class Header(namedtuple('Header', 'magic ts_sec ts_usec len ep')):

	sd = struct.Struct('=LQQhB')
	size = sd.size

	@classmethod
	def unpack(kls, data):
		return kls(*kls.sd.unpack(data))


def process_frame(ep, frame):
	#print("%02x %s" % (ep, binascii.b2a_hex(frame).decode('utf-8')))
	if False:
		if ep == 0x81:
			ts = 1
			fh_out0.write(frame[ts:ts+1])
		elif ep == 0x82:
			ts = 1
			fh_out1.write(frame[ts:ts+1])


with open(sys.argv[1], 'rb') as fh_in:

	while True:
		hdr_data = fh_in.read(Header.size)
		if len(hdr_data) != Header.size:
			break

		hdr = Header.unpack(hdr_data)

		if hdr.magic != 0xe115600d:
			print("Bad header %r" % (hdr,))
			break

		if hdr.len < 0:
			print("Error %r" % (hdr,))
			continue

		if hdr.len > 0:
			data = fh_in.read(hdr.len)

			print(hdr.ep, binascii.b2a_hex(data[0:4]).decode('utf-8'), hdr.len)

			nf = (len(data) - 4) // 32
			for i in range(nf):
				process_frame(hdr.ep, data[4+32*i:4+32*(i+1)])

		#print(hdr)
