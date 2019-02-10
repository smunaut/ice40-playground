#!/usr/bin/env python3

import argparse
import struct
from PIL import Image

import control


class TextControl(control.BoardControlBase):

	COLOR_BASE  = 0x6000
	SCREEN_BASE = 0x8000
	GLYPH_BASE  = 0xc000

	def __init__(self, **kwargs):
		# Super call
		super().__init__(**kwargs)

	def bus_write(self, addr, data):
		self.slave.exchange(struct.pack('>BHH', 0, addr, data))

	def upload_font(self, fn, s=0):
		img = Image.open(fn)

		for i in range(0x0000, 0x2000):
			c = (i >> 5)
			fx = (c & 0xf) * 9
			fy = ((c >> 4) & 0xf) * 17
			cx = (i & 0x01) * 4
			cy = (i & 0x1e) >> 1

			data = (
				((img.getpixel( (fx+cx+0, fy+cy) )[0] >> 7) << 12) |
				((img.getpixel( (fx+cx+1, fy+cy) )[0] >> 7) <<  8) |
				((img.getpixel( (fx+cx+2, fy+cy) )[0] >> 7) <<  4) |
				((img.getpixel( (fx+cx+3, fy+cy) )[0] >> 7) <<  0)
			)

			self.bus_write(self.GLYPH_BASE + s*0x2000 + i, data)


def default_config(text):
	# Colors
		# FG
	for i in range(0x6000, 0x6008):
		text.bus_write(i, (i & 0x7) | ((i & 0x7) << 4))

		# BG
	for i in range(0x6008, 0x6010):
		text.bus_write(i, (i & 0x7) | ((i & 0x7) << 4) | 0x88)

		# Custom RGBI
	for i in range(0x6020, 0x6030):
		text.bus_write(i, (i & 0xf) | ((i & 0xf) << 4))

	# Font
	text.upload_font('../data/VGA-8x16.png')


def show_font(text):
	# Char matrix
	for i in range(0x0000, 0x4000):
		text.bus_write(text.SCREEN_BASE + i,
			(i & 0xff) |
			(((i >> 8) & 0x3f) << 10) |
			(1 << 9)
		)


def show_bars(text):
	# Create a font
	for i in range(16):
		d = (i << 0) | (i << 4) | (i << 8) | (i << 12)
		for w in range(32):
			text.bus_write(text.GLYPH_BASE + 0x2000 + i*32 + w, d)

	# Bands on the screen
	for y in range(64):
		for x in range(256):
			addr = text.SCREEN_BASE | (y << 8) | x

			text.bus_write(addr,
				((x >> 3) & 0xf) |
				(1 <<  8) |
				(2 << 12)
			)


def main():
	# Parse options
	parser = argparse.ArgumentParser(
		formatter_class=argparse.ArgumentDefaultsHelpFormatter
	)
	g_text  = parser.add_argument_group('test',  'Text core options')
	g_brd   = parser.add_argument_group('board', 'Board configuration options')

	g_text.add_argument('--show-font', help='Show font over FG/BG palette', action='store_true', default=False)
	g_text.add_argument('--show-bars', help='Show color bars', action='store_true', default=False)

	control.arg_group_setup(g_brd)

	args = parser.parse_args()

	# Build control object with those params
	kwargs = control.arg_to_kwargs(args)

	text = TextControl(**kwargs)

	# Commands
	default_config(text)

	if args.show_font:
		show_font(text)

	if args.show_bars:
		show_bars(text)


if __name__ == '__main__':
	main()
