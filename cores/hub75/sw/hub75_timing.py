#!/usr/bin/env python3

import argparse

OVERHEAD = 5	# Guesstimated

class PanelConfig(object):


	def __init__(self, **kwargs):
		params = [
			'freq',				# Clock frequency in Hz
			'n_banks',			# Number of banks
			'n_rows',			# Number of rows
			'n_cols',			# Number of columns
			'n_planes',			# Number of bitplanes in BCM modulation
			'bcm_lsb_len',		# Duration of the LSB of BCM modulation (in clk cycles)
		]

		for x in params:
			setattr(self, x, kwargs.pop(x))

		self._sim()

	def _sim(self):
		# Init
		cyc_tot = 0
		cyc_on  = 0

		# Scan all place
		for plane in range(self.n_planes):
			# Length of the plane in clock cycle
			len_show = self.bcm_lsb_len << plane

			# Length required to do data shift for the next plane
			len_shift = self.n_cols

			# Length of this cycle is the max
			len_plane = max(len_show, len_shift) + OVERHEAD

			# Accumulate
			cyc_tot += len_plane
			cyc_on  += len_show

		# Compute results
		self._light_efficiency = 1.0 * cyc_on / cyc_tot
		self._refresh_rate = self.freq / (self.n_rows * cyc_tot)

	@property
	def light_efficiency(self):
		return self._light_efficiency

	@property
	def refresh_rate(self):
		return self._refresh_rate


def main():
	# Parse options
	parser = argparse.ArgumentParser()
	parser.add_argument('--freq',		type=float, help='Clock frequency in Hz', default=30e6)
	parser.add_argument('--n_banks',	type=int, required=True, metavar='N', help='Number of banks')
	parser.add_argument('--n_rows',		type=int, required=True, metavar='N', help='Number of rows')
	parser.add_argument('--n_cols',		type=int, required=True, metavar='N', help='Number of columns')
	parser.add_argument('--n_planes',	type=int, required=True, metavar='N', help='Number of bitplanes in BCM modulation')
	parser.add_argument('--bcm_min_len',type=int, metavar='CYCLES', help='Min duration of the LSB of BCM modulation (in clk cycles, default=1)', default=1)
	parser.add_argument('--bcm_max_len',type=int, metavar='CYCLES', help='Max duration of the LSB of BCM modulation (in clk cycles, default=20)', default=20)
	args = parser.parse_args()

	# Scan various bcm_lsb_len
	print("bcm_lsb_len\tlight_efficiency\trefresh_rate")
	for i in range(args.bcm_min_len, args.bcm_max_len+1):
		pc = PanelConfig(
			freq     = args.freq,
			n_banks  = args.n_banks,
			n_rows   = args.n_rows,
			n_cols   = args.n_cols,
			n_planes = args.n_planes,
			bcm_lsb_len = i,
		)
		print("%2d\t\t%4.1f\t\t\t%5.1f" % (
			i,
			pc.light_efficiency * 100.0,
			pc.refresh_rate
		))


if __name__ == '__main__':
	main()
