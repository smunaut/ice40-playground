#!/usr/bin/env python3

import json
import sys

def main(argv0, fn_in, fn_out, board=''):

	with open(fn_in, 'r') as fh_in, open(fn_out, 'w') as fh_out:
		# Arrays
		str_d = []

		# String 0
		str_d.append("""static const struct usb_str_desc _str0_desc = {
	.bLength		= 4,
	.bDescriptorType	= USB_DT_STR,
	.wString		= { 0x0409 },
};
""")

		# String 1..n
		def sep(i, l):
			if i == l-1:
				return ''
			elif ((i & 7) == 7):
				return '\n\t\t'
			else:
				return ' '

		for i, ld in enumerate(fh_in.readlines()):
			ld = ld.strip()
			if ld.startswith('!{'):
				ld = json.loads(ld[1:])
				ld = ld[board] if board in ld else ld['']
			ll = len(ld)
			d = ''.join(['0x%04x,%s' % (ord(c), sep(j, ll)) for j,c in enumerate(ld)])
			str_d.append("""static const struct usb_str_desc _str%d_desc = {
	.bLength		= %d,
	.bDescriptorType	= USB_DT_STR,
	.wString		= {
		%s
	},
};
""" % (i+1, ll*2+2, d))

		fh_out.write('\n'.join(str_d))

		# Array
		fh_out.write("\n")
		fh_out.write("static const struct usb_str_desc * const _str_desc_array[] = {\n")
		for i in range(len(str_d)):
			fh_out.write("\t& _str%d_desc,\n" % i)
		fh_out.write("};\n")

if __name__ == '__main__':
	main(*sys.argv)
