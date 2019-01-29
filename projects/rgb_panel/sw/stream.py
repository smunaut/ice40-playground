#!/usr/bin/env python3

import argparse
import time

import control


class PanelControl(control.BoardControlBase):

	def __init__(self, n_banks=2, n_rows=32, n_cols=64, colordepth=16, **kwargs):
		# Super call
		super().__init__(**kwargs)

		# Save panel description
		self.n_banks = n_banks
		self.n_rows  = n_rows
		self.n_cols  = n_cols
		self.colordepth = colordepth

		# Pre-create buffers
		self.line_bytes = n_cols * (colordepth // 8)
		self.send_buf = bytearray(1 + self.line_bytes)
		self.send_buf_view = memoryview(self.send_buf)

	def send_line_file(self, fh):
		self.send_buf_view[0] = 0x80
		rb = fh.readinto(self.send_buf_view[1:])
		if rb != self.line_bytes:
			return False
		self.slave.exchange(self.send_buf)
		return True

	def send_line_data(self, data):
		self.send_buf_view[0] = 0x80
		self.send_buf_view[1:] = data
		self.slave.exchange(self.send_buf)

	def send_frame_file(self, fh):
		# Scan all line
		for y in range(self.n_banks * self.n_rows):
			# Send write command to line buffer
			if not self.send_line_file(fh):
				return False

			# Swap line buffer & Write it to line y of back frame buffer
			self.reg_w8(0x03, y)

		# Send frame swap command
		self.reg_w8(0x04, 0x00)

		# Wait for the frame swap to occur
		while (self.read_status() & 0x02 == 0):
			pass

		return True

	def send_frame_data(self, frame):
		# View on the data
		frame_view = memoryview(frame)

		# Scan all line
		for y in range(self.n_banks * self.n_rows):
			# Send write command to line buffer
			self.send_line_data(frame_view[y*self.line_bytes:(y+1)*self.line_bytes])

			# Swap line buffer & Write it to line y of back frame buffer
			self.reg_w8(0x03, y)

		# Send frame swap command
		self.reg_w8(0x04, 0x00)

		# Wait for the frame swap to occur
		while (self.read_status() & 0x02 == 0):
			pass


def main():
	# Parse options
	parser = argparse.ArgumentParser(
			formatter_class=argparse.ArgumentDefaultsHelpFormatter
	)
	g_input = parser.add_argument_group('input', 'Input options')
	g_panel = parser.add_argument_group('panel', 'Panel configuation options')
	g_brd   = parser.add_argument_group('board', 'Board configuration options')

	g_input.add_argument('--input', type=argparse.FileType('rb'), metavar='FILE', help='Input file', required=True)
	g_input.add_argument('--fps',   type=float, help='Target FPS to regulate to (None=no regulation)')
	g_input.add_argument('--loop',  help='Play in a loop', action='store_true', default=False)

	g_panel.add_argument('--n_banks',    type=int, metavar='N', help='Number of banks',   default=2)
	g_panel.add_argument('--n_rows',     type=int, metavar='N', help='Number of rows',    default=32)
	g_panel.add_argument('--n_cols',     type=int, metavar='N', help='Number of columns', default=64)
	g_panel.add_argument('--colordepth', type=int, metavar='DEPTH', help='Bit per color',     default=16)

	control.arg_group_setup(g_brd)

	args = parser.parse_args()

	# Build the actual panel control object with those params
	kwargs = control.arg_to_kwargs(args)
	kwargs['n_banks']    = args.n_banks
	kwargs['n_rows']     = args.n_rows
	kwargs['n_cols']     = args.n_cols
	kwargs['colordepth'] = args.colordepth

	panel = PanelControl(**kwargs)

	# Streaming loop
	if args.fps:
		tpf = 1.0 / args.fps
		tt  = time.time() + tpf

	while True:
		# Send one frame
		rv = panel.send_frame_file(args.input)

		# Loop ?
		if not rv:
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
