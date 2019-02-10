#!/usr/bin/env python3

import argparse
import struct
import time

from pycrc.algorithms import Crc

import control


# ---------------------------------------------------------------------------
# DSI utilities
# ---------------------------------------------------------------------------

EOTP = bytearray([ 0x08, 0x0f, 0x0f, 0x01 ])

DSI_CRC = Crc(width=16, poly=0x1021, xor_in=0xffff, xor_out=0x0000, reflect_in=True, reflect_out=True)


def parity(x):
	p = 0
	while x:
		p ^= x & 1
		x >>= 1
	return p

def dsi_header(*data):
	cmd = (data[2] << 16) | (data[1] << 8) | data[0]
	ecc = 0
	if parity(cmd & 0b111100010010110010110111): ecc |= 0x01;
	if parity(cmd & 0b111100100101010101011011): ecc |= 0x02;
	if parity(cmd & 0b011101001001101001101101): ecc |= 0x04;
	if parity(cmd & 0b101110001110001110001110): ecc |= 0x08;
	if parity(cmd & 0b110111110000001111110000): ecc |= 0x10;
	if parity(cmd & 0b111011111111110000000000): ecc |= 0x20;
	return bytearray(data) + bytearray([ecc])


def dsi_crc(payload):
	crc = DSI_CRC.bit_by_bit(bytes(payload))
	return bytearray([ crc & 0xff, (crc >> 8) & 0xff ])


def dcs_short_write(cmd, val=None):
	if val is None:
		return dsi_header(0x05, cmd, 0x00)
	else:
		return dsi_header(0x15, cmd, val)

def dcs_long_write(cmd, data):
	pl = bytearray([ cmd ]) + data
	l = len(pl)
	return dsi_header(0x39, l & 0xff, l >> 8) + pl + dsi_crc(pl)

def generic_short_write(cmd, val=None):
	if val is None:
		return dsi_header(0x13, cmd, 0x00)
	else:
		return dsi_header(0x23, cmd, val)

def generic_long_write(cmd, data):
	pl = bytearray([ cmd ]) + data
	l = len(pl)
	return dsi_header(0x29, l & 0xff, l >> 8) + pl + dsi_crc(pl)



# ---------------------------------------------------------------------------
# nanoPMOD Board control
# ---------------------------------------------------------------------------

class DSIControl(control.BoardControlBase):

	REG_LCD_CTRL = 0x00
	REG_DSI_HS_PREP = 0x10
	REG_DSI_HS_ZERO = 0x11
	REG_DSI_HS_TRAIL = 0x12
	REG_PKT_WR_DATA_RAW = 0x20
	REG_PKT_WR_DATA_U8 = 0x21

	TRANSPOSE_NONE   = 0
	TRANSPOSE_DCS    = 1
	TRANSPOSE_MANUAL = 2

	def __init__(self, n_col=240, n_page=240, flip_col=False, flip_page=False, transpose=TRANSPOSE_NONE, **kwargs):
		# Super call
		super().__init__(**kwargs)

		# Save params
		self.n_col  = n_col
		self.n_page = n_page
		self.flip_col  = flip_col
		self.flip_page = flip_page
		self.transpose = transpose

		# Init the LCD
		self.init()

	def init(self):
		# Default values
		self.backlight = 0x100

		# Turn off Back Light / HS clock and assert reset
		self.reg_w16(self.REG_LCD_CTRL, 0x8000)

		# Wait a bit
		time.sleep(0.1)

		# Configure backlight and release reset
		self.reg_w16(self.REG_LCD_CTRL, self.backlight)

		# Configure DSI timings
		self.reg_w8(self.REG_DSI_HS_PREP,  0x10)
		self.reg_w8(self.REG_DSI_HS_ZERO,  0x18)
		self.reg_w8(self.REG_DSI_HS_TRAIL, 0x18)

		# Enable HS clock
		self.reg_w16(self.REG_LCD_CTRL, 0x4000 | self.backlight)

		# Wait a bit
		time.sleep(0.1)

		# Send DSI packets
		self.send_dsi_pkt(
			dcs_short_write(0x11) +			# Exist sleep
			EOTP							# EoTp
		)

		self.send_dsi_pkt(
			dcs_short_write(0x29) +			# Exist sleep
			EOTP							# EoTp
		)

		mode = (
			(0x80 if self.flip_page else 0) |
			(0x40 if self.flip_col  else 0) |
			(0x20 if self.transpose == DSIControl.TRANSPOSE_DCS else 0)
		)

		# Note. According to the DCS spec, mode.B3=0 should be RGB ... but
		#       the nano display driver IC has an errata and it's actually
		#       BGR order.

		self.send_dsi_pkt(
			dcs_short_write(0x11) +			# Exist sleep
			dcs_short_write(0x29) +			# Display on
			dcs_short_write(0x36, mode) +	# Set address mode
			dcs_short_write(0x3a, 0x55) +	# Set pixel format
			EOTP							# EoTp
		)

	def set_backlight(self, backlight):
		self.backlight = backlight
		self.reg_w16(self.REG_LCD_CTRL, 0x4000 | self.backlight)

	def send_dsi_pkt(self, data):
		self.reg_burst(self.REG_PKT_WR_DATA_RAW, data)

	def set_column_address(self, sc, ec):
		self.send_dsi_pkt(dcs_long_write(0x2a, struct.pack('>HH', sc, ec)))

	def set_page_address(self, sp, ep):
		self.send_dsi_pkt(dcs_long_write(0x2b, struct.pack('>HH', sp, ep)))

	def _send_frame_normal(self, frame, bpp):
		# Max packet size
		mtu = 1024 - 4 - 1 - 2
		psz = (mtu // (2 * self.n_col)) * (2 * self.n_col)
		pcnt = (self.n_col * self.n_page * 2 + psz - 1) // psz

		if bpp == 16:
			for i in range(pcnt):
				self.send_dsi_pkt(
					dsi_header(0x39, (psz + 1) & 0xff, (psz + 1) >> 8) +
					(b'\x2c' if i == 0 else b'\x3c') +
					frame[i*psz:(i+1)*psz] +
					b'\x00\x00'
				)

		else:
			for i in range(pcnt):
				self.reg_burst(self.REG_PKT_WR_DATA_U8,
					dsi_header(0x39, (psz + 1) & 0xff, (psz + 1) >> 8) +
					(b'\x2c' if i == 0 else b'\x3c') +
					frame[i*(psz//2):(i+1)*(psz//2)] +
					b'\x00'
				)

	def _send_frame_transpose_16b(self, frame):
		# Packet size for each line
		mtu = 1024
		psz  = len(self._line_sel_cmd[0]) + 4 + 1 + self.n_page * 2 + 2
		ppb  = mtu // psz

		# Scan each line
		lsz = self.n_page * 2
		burst = []
		bpc = 0

		for y in range(self.n_col):
			burst.append(self._line_sel_cmd[y])
			burst.append(dsi_header(0x39, (lsz + 1) & 0xff, (lsz + 1) >> 8))
			burst.append(b'\x2c')
			burst.append(frame[y*lsz:(y+1)*lsz])
			burst.append(b'\x00\x00')

			bpc += 1
			if (bpc == ppb) or (y == (self.n_col-1)):
				self.send_dsi_pkt(b''.join(burst))
				bpc = 0
				burst = []

	def _send_frame_transpose_8b(self, frame):
		# No choice but to scan each line independently
		for y in range(self.n_col):
			# Select line
			self.send_dsi_pkt(self._line_sel_cmd[y])

			# Send data with special 8bit expand command
			lsz = self.n_page

			self.reg_burst(self.REG_PKT_WR_DATA_U8,
				dsi_header(0x39, (lsz*2 + 1) & 0xff, (lsz*2 + 1) >> 8) +
				b'\x2c' +
				frame[y*lsz:(y+1)*lsz] +
				b'\x00'
			)

	def send_frame(self, frame, bpp=16):
		# Delegate depending on config
		if self.transpose == DSIControl.TRANSPOSE_MANUAL:
			# Init the command tables
			if not hasattr(self, '_line_sel_cmd'):
				self._line_sel_cmd = []
				for y in range(self.n_col):
					self._line_sel_cmd.append(
						dcs_long_write(0x2a, struct.pack('>HH', y, y))
					)

			# In 8 bit mode, we can't combine packets, so do it all the slow way
			if bpp == 8:
				self._send_frame_transpose_8b(frame)
			else:
				self._send_frame_transpose_16b(frame)

		else:
			self._send_frame_normal(frame, bpp)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def load_bgr888_as_bgr565(filename):
	img = open(filename,'rb').read()
	dat = []

	for i in range(len(img) // 4):
		b = img[4*i + 0]
		g = img[4*i + 1]
		r = img[4*i + 2]

		c  = ((r >> 3) & 0x1f) << 11;
		c |= ((g >> 2) & 0x3f) <<  5;
		c |= ((b >> 3) & 0x1f) <<  0;

		dat.append( ((c >> 0) & 0xff) )
		dat.append( ((c >> 8) & 0xff) )

	return bytearray(dat)


def main():
	# Parse options
	parser = argparse.ArgumentParser(
			formatter_class=argparse.ArgumentDefaultsHelpFormatter
	)
	g_input   = parser.add_argument_group('input',   'Input options')
	g_display = parser.add_argument_group('display', 'Display configuation options')
	g_brd     = parser.add_argument_group('board',   'Board configuration options')

	g_input.add_argument('--input', type=argparse.FileType('rb'), metavar='FILE', help='Input file', required=True)
	g_input.add_argument('--fps',   type=float, help='Target FPS to regulate to (None=no regulation)')
	g_input.add_argument('--loop',  help='Play in a loop', action='store_true', default=False)
	g_input.add_argument('--bgr8',  help='Input is BGR8 instead of BGR565', action='store_true', default=False)

	g_display.add_argument('--n_col',     type=int, metavar='N', help='Number of columns', default=240)
	g_display.add_argument('--n_page',    type=int, metavar='N', help='Number of pages',   default=240)
	g_display.add_argument('--flip_col',  help='Flip column order', action='store_true', default=False)
	g_display.add_argument('--flip_page', help='Flip page order',   action='store_true', default=False)
	g_display.add_argument('--transpose', help='Transpose mode', choices=['none', 'dcs', 'manual'], default='none')

	control.arg_group_setup(g_brd)

	args = parser.parse_args()

	# Build the actual panel control object with those params
	kwargs = control.arg_to_kwargs(args)
	kwargs['n_col']     = args.n_col
	kwargs['n_page']    = args.n_page
	kwargs['flip_col']  = args.flip_col
	kwargs['flip_page'] = args.flip_page
	kwargs['transpose'] = {
		'none'   : DSIControl.TRANSPOSE_NONE,
		'dcs'    : DSIControl.TRANSPOSE_DCS,
		'manual' : DSIControl.TRANSPOSE_MANUAL,
	}[args.transpose]

	ctrl = DSIControl(**kwargs)

	# Streaming loop
	if args.fps:
		tpf = 1.0 / args.fps
		tt  = time.time() + tpf

	fsize = args.n_col * args.n_page * (1 if args.bgr8 else 2)

	while True:
		# Send one frame
		data = args.input.read(fsize)
		if len(data) == fsize:
			ctrl.send_frame(data, bpp=(8 if args.bgr8 else 16))

		# Loop ?
		else:
			if args.loop:
				args.input.seek(0)
				continue
			else:
				break

		# FPS regulation
		if args.fps:
			w = tt - time.time()
			if w > 0:
				time.sleep(w)
			tt += tpf


if __name__ == '__main__':
	main()
