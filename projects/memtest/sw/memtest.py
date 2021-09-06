#!/usr/bin/env python3

#
# memtest.py
#
# Base utiity/driver classes for the various control software variants
#
# Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: MIT
#

import binascii
import random
import serial
import sys


# ----------------------------------------------------------------------------
# Serial commands
# ----------------------------------------------------------------------------

class WishboneInterface(object):

	COMMANDS = {
		'SYNC' : 0,
		'REG_ACCESS' : 1,
		'DATA_SET' : 2,
		'DATA_GET' : 3,
		'AUX_CSR' : 4,
	}

	def __init__(self, port):
		self.ser = ser = serial.Serial()
		ser.port = port
		ser.baudrate = 2000000
		ser.stopbits = 2
		ser.timeout = 0.1
		ser.open()

		if not self.sync():
			raise RuntimeError("Unable to sync")

	def sync(self):
		for i in range(10):
			self.ser.write(b'\x00')
			d = self.ser.read(4)
			if (len(d) == 4) and (d == b'\xca\xfe\xba\xbe'):
				return True
		return False

	def write(self, addr, data):
		cmd_a = ((self.COMMANDS['DATA_SET']   << 36) | data).to_bytes(5, 'big')
		cmd_b = ((self.COMMANDS['REG_ACCESS'] << 36) | addr).to_bytes(5, 'big')
		self.ser.write(cmd_a + cmd_b)

	def read(self, addr):
		cmd_a = ((self.COMMANDS['REG_ACCESS'] << 36) | (1<<20) | addr).to_bytes(5, 'big')
		cmd_b = ((self.COMMANDS['DATA_GET']   << 36)).to_bytes(5, 'big')
		self.ser.write(cmd_a + cmd_b)
		d = self.ser.read(4)
		if len(d) != 4:
			raise RuntimeError('Comm error')
		return int.from_bytes(d, 'big')

	def aux_csr(self, value):
		cmd = ((self.COMMANDS['AUX_CSR'] << 36) | value).to_bytes(5, 'big')
		self.ser.write(cmd)


# ----------------------------------------------------------------------------
# QSPI controller
# ----------------------------------------------------------------------------

class QSPIController(object):

	CORE_REGS = {
		'csr': 0,
		'rf': 3,
	}

	def __init__(self, intf, base, cs=0):
		self.intf = intf
		self.base = base
		self.cs = cs
		self._end()

	def _write(self, reg, val):
		self.intf.write(self.base + self.CORE_REGS.get(reg, reg), val)

	def _read(self, reg):
		return self.intf.read(self.base + self.CORE_REGS.get(reg, reg))

	def _begin(self):
		# Request external control
		self._write('csr', 0x00000004 | (self.cs << 4))
		self._write('csr', 0x00000002 | (self.cs << 4))

	def _end(self):
		# Release external control
		self._write('csr', 0x00000004)

	def spi_xfer(self, tx_data, dummy_len=0, rx_len=0):
		# Start transaction
		self._begin()

		# Total length
		l = len(tx_data) + rx_len + dummy_len

		# Prep buffers
		tx_data = tx_data + bytes( ((l + 3) & ~3) - len(tx_data) )
		rx_data = b''

		# Run
		while l > 0:
			# Word and command
			w = int.from_bytes(tx_data[0:4], 'big')
			c = 0x13 if l >= 4 else (0x10 + l - 1)
			s = 0 if l >= 4 else 8*(4-l)

			# Issue
			self._write(c, w);
			w = self._read('rf')

			# Get RX
			rx_data = rx_data + ((w << s) & 0xffffffff).to_bytes(4, 'big')

			# Next
			l = l - 4
			tx_data = tx_data[4:]

		# End transaction
		self._end()

		# Return interesting part
		return rx_data[-rx_len:]


	def _qpi_tx(self, data, command=False):
		while len(data):
			# Base command
			cmd = 0x1c if command else 0x18

			# Grab chunk
			word = data[0:4]
			data = data[4:]

			cmd |= len(word) - 1
			word = word + bytes(-len(word) & 3)

			# Transmit
			self._write(cmd, int.from_bytes(word, 'big'));

	def _qpi_rx(self, l):
		data = b''

		while l > 0:
			# Issue read
			wl = 4 if l >= 4 else l
			cmd = 0x14 | (wl-1)
			self._write(cmd, 0)
			word = self._read('rf')

			# Accumulate
			data = data + (word & (0xffffffff >> (8*(4-wl)))).to_bytes(wl, 'big')

			# Next
			l = l - 4

		return data

	def qpi_xfer(self, cmd=b'', payload=b'', dummy_len=0, rx_len=0):
		# Start transaction
		self._begin()

		# TX command
		if cmd:
			self._qpi_tx(cmd, True)

		# TX payload
		if payload:
			self._qpi_tx(payload, False)

		# Dummy
		if dummy_len:
			self._qpi_rx(dummy_len)

		# RX payload
		if rx_len:
			rv = self._qpi_rx(rx_len)
		else:
			rv = None

		# End transaction
		self._end()

		return rv


# ----------------------------------------------------------------------------
# HyperRAM controller
# ----------------------------------------------------------------------------

class HyperRAMController(object):

	CORE_REGS = {
		'csr': 0,
		'cmd': 1,
		'wq0': 2,
		'wq1': 3,
	}

	CSR_RUN			= (1 << 0)
	CSR_RESET		= (1 << 1)
	CSR_IDLE_CFG	= (1 << 2)
	CSR_IDLE_RUN	= (1 << 3)
	CSR_CMD_LAT		= lambda self, x: ((x-1) & 15) <<  8
	CSR_CAP_LAT 	= lambda self, x: ((x-1) & 15) << 12
	CSR_PHY_DELAY	= lambda self, x: (x & 15) <<  16
	CSR_PHY_PHASE	= lambda self, x: (x &  3) <<  20
	CSR_PHY_EDGE    = lambda self, x: (x &  1) <<  22

	CMD_LEN			= lambda self, x: ((x-1) & 15) << 8
	CMD_LAT			= lambda self, x: ((x-1) & 15) << 4
	CMD_CS			= lambda self, x: (x &  3) << 2
	CMD_REG			= (1 << 1)
	CMD_MEM			= (0 << 1)
	CMD_READ		= (1 << 0)
	CMD_WRITE		= (0 << 0)

		# Selected so:
		#  - each byte is unique
		#  - ORing  all bytes in a single word == 255
		#  - ANDing all bytes in a single word == 0
	CAL_WORDS = [ 0x600dbabe, 0xb16b00b5 ]

		# Register addresses
	HYPERRAM_REGS = {
		'id0': 0,
		'id1': 1,
		'cr0': 0 | (1 << 11),
		'cr1': 1 | (1 << 11),
	}

	def __init__(self, intf, base, latency=3, csm=0xf, burst_len=128):
		self.intf = intf
		self.base = base

		self.latency = latency
		self.csm = csm
		self.burst_len = burst_len

		# We're always in 2x latency mode, also the location where
		# latency start and the 1 cycle added by the core because it works
		# 32 bit at a time means we can remove 2 cycles of the latency
		self._cmd_latency = (2 * latency - 2) // 2

	def _write(self, reg, val):
		self.intf.write(self.base + self.CORE_REGS[reg], val)

	def _read(self, reg):
		return self.intf.read(self.base + self.CORE_REGS[reg])

	def _cr0(self, dpd=False, drive_strength=None, latency=6, fixed_latency=True, hybrid_burst=True, burst_len=32):
		DRIVE = {
			None: 0,
			115: 1,
			67: 2,
			46: 3,
			34: 4,
			27: 5,
			22: 6,
			19: 7,
		}
		LATENCY = {
			3: 14,
			4: 15,
			5: 0,
			6: 1,
		}
		BURST_LEN = {
			128: 0,
			 64: 1,
			 32: 3,
			 16: 2,
		}
		return (
			((dpd ^ 1) << 15) |
			(DRIVE[drive_strength] << 12) |
			(0xf << 8) |
			(LATENCY[latency] << 4) |
			(fixed_latency << 3) |
			(hybrid_burst << 2) |
			(BURST_LEN[burst_len] << 0)
		)

	def _cr1(self, dri=None):
		DRI = {
			None: 2,
			"1x": 2 ,
			"1.5x": 3,
			"2x": 0,
			"4x": 1,
		}
		return DRI[dri]

	def _ca(self, addr, rwn=0, reg=0, linear=0):
		return (
			(rwn << 47) |
			(reg << 46) |
			((linear | reg) << 45) |
			((addr >> 3) << 16) |
			((addr & 7) << 0)
		)

	def _wait_idle(self):
		# Wait until it's in IDLE Config mode
		for i in range(10):
			if self._read('csr') & self.CSR_IDLE_CFG:
				break
		else:
			raise RuntimeError('HyperRAM controller timeout')

	def _reg_write(self, cs, reg, val):
		ca = self._ca(self.HYPERRAM_REGS[reg], rwn=0, reg=1)

		self._write('wq1', 0x30)
		self._write('wq0', ca >> 16)
		self._write('wq0', ((ca & 0xffff) << 16) | val)
		self._write('wq0', 0)

		self._write('cmd',
			self.CMD_CS(cs) |
			self.CMD_REG |
			self.CMD_WRITE
		)

		self._wait_idle()

	def _reg_read(self, cs, reg):
		ca = self._ca(self.HYPERRAM_REGS[reg], rwn=1, reg=1)

		self._write('wq1', 0x30)
		self._write('wq0', ca >> 16)

		self._write('wq1', 0x20)
		self._write('wq0', (ca & 0xffff) << 16)

		self._write('wq1', 0x00)
		self._write('wq0', 0)

		self._write('cmd',
			self.CMD_LAT(self._cmd_latency) |
			self.CMD_CS(cs) |
			self.CMD_REG |
			self.CMD_READ
		)

		self._wait_idle()

		rv = []
		for i in range(3):
			w1 = self._read('wq1')
			w0 = self._read('wq0')
			rv.append( (w0, w1) )

		return rv[-1][0] >> 16

	def _mem_write(self, cs, addr, val, count=1, mask=0x0):
		ca = self._ca(addr, rwn=0, reg=0)

		self._write('wq1', 0x30)
		self._write('wq0', ca >> 16)

		self._write('wq1', 0x20)
		self._write('wq0', (ca & 0xffff) << 16)

		self._write('wq1', 0x30 | mask)
		self._write('wq0', val)

		self._write('cmd',
			self.CMD_LEN(count) |
			self.CMD_LAT(self._cmd_latency) |
			self.CMD_CS(cs) |
			self.CMD_MEM |
			self.CMD_WRITE
		)

		self._wait_idle()

	def _mem_read(self, cs, addr, count=3):
		if count > 3:
			raise ValueError('Unable to read more than 3 words at a time')

		ca = self._ca(addr, rwn=1, reg=0)

		self._write('wq1', 0x30)
		self._write('wq0', ca >> 16)

		self._write('wq1', 0x20)
		self._write('wq0', (ca & 0xffff) << 16)

		self._write('wq1', 0x00)
		self._write('wq0', 0)

		self._write('cmd',
			self.CMD_LEN(count) |
			self.CMD_LAT(self._cmd_latency) |
			self.CMD_CS(cs) |
			self.CMD_MEM |
			self.CMD_READ
		)

		self._wait_idle()

		rv = []
		for i in range(3):
			w1 = self._read('wq1')
			w0 = self._read('wq0')
			rv.append( (w0, w1) )

		return rv[-count:]

	def _train_check_edge_delay(self, cs, edge, delay):
		# Configure for base capture latency and phase
		self._write('csr',
			self.CSR_PHY_EDGE(edge) |
			self.CSR_PHY_PHASE(0) |
			self.CSR_PHY_DELAY(delay) |
			self.CSR_CMD_LAT(self._cmd_latency) |
			self.CSR_CAP_LAT(3)
		)

		# Find the capture latency and phase
		data = self._mem_read(cs, 0, count=3)

		for w,a in data:
			print(f"{bin(a)} {w:08x}")

		for i in range(3):
			if (data[i][1] & 0xf):
				break
		else:
			return None

		for j in range(4):
			if data[i][1] & (8 >> j):
				break

		cap_latency = 3 + i + (j > 0)
		phase = (4 - j) % 4

		# Re-configure core
		self._write('csr',
			self.CSR_PHY_EDGE(edge) |
			self.CSR_PHY_PHASE(phase) |
			self.CSR_PHY_DELAY(delay) |
			self.CSR_CMD_LAT(self._cmd_latency) |
			self.CSR_CAP_LAT(cap_latency)
		)

		# Confirm data
		data = self._mem_read(cs, 0, count=3)

		ref = [
			(self.CAL_WORDS[0], 0x3a),
			(self.CAL_WORDS[1], 0x3a),
			(self.CAL_WORDS[0], 0x3a),
		]

		if data != ref:
			return None

		return (cap_latency, phase)

	def _train_consolidate(self, train):
		# Checks combination valid for all chips
		rv = {}

		for delay, results in train.items():
			r = [v for k,v in results.items() if self.csm & (1 << k)]
			for x in r:
				if (x is None) or (x != r[0]):
					print("[.]  delay=%2d -> Invalid" % delay)
					rv[delay] = None
					break
			else:
				print("[.]  delay=%2d -> cap_latency=%d, phase=%d" % (delay, *r[0]))
				rv[delay] = r[0]

		return rv

	def _train_group(self, train):
		groups = []

		c_v = None
		c_d = []
		c_first = False
		c_last = False

		for idx, (delay, result) in enumerate(sorted(train.items())):
			# First / Last checks
			is_first = idx == 0
			is_last  = idx == (len(train) - 1)

			# Continue ?
			if result and (c_v == result):
				c_d.append(delay)
				c_first |= is_first
				c_last  |= is_last

			# Or not ...
			else:
				# Flush current
				if c_v is not None:
					groups.append( (c_v, c_d, c_first, c_last) )

				# New item
				c_v     = result
				c_d     = [ delay ]
				c_first = is_first
				c_last  = is_last

		if c_v is not None:
			groups.append( (c_v, c_d, c_first, c_last) )

		return groups

	def _train_pick_params(self, best):
		# Pick delay
		if best[2] and best[3]:
			d = (best[1][0] + best[1][-1]) // 2
		elif best[2]:
			d = min(best[1])
		elif best[3]:
			d = max(best[1])
		else:
			d = int(round(sum(best[1]) / len(best[1])))

		# If the group is only a single value 'wide', print warning it might be marginal
		if len(best[1]) == 1:
			print("[w] Training results might be marginal. Consider switching capture clock phase by 90 deg")

		# Return delay and params
		return d, best[0][0], best[0][1]

	def init(self):
		# Reset HyperRAM and controller
		self._write('csr', self.CSR_RESET)
		self._wait_idle()
		self._write('csr', 0)
		self._wait_idle()

		# Chip config
		self.cr0 = self._cr0(latency=self.latency, burst_len=self.burst_len)
		self.cr1 = self._cr1()

		# DEBUG
		if False:
			cs = 0

			for i in range(5):
				print(hex(self.cr0))
				self._reg_write(cs, 'cr0', self.cr0)
				self._mem_write(cs, 0, self.CAL_WORDS[0], count=3)
				self._mem_write(cs, 2, self.CAL_WORDS[1], count=1)

				self._write('csr',
					self.CSR_PHY_EDGE(1) |
					self.CSR_PHY_PHASE(0) |
					self.CSR_PHY_DELAY(0) |
					self.CSR_CMD_LAT(self._cmd_latency) |
					self.CSR_CAP_LAT(3)
				)
				print(f"{self._read('csr'):08x}")

				for w,a in self._mem_read(cs, 0, count=3):
					print(f"{bin(a)} {w:08x}")

			return False

		# Execute configuration and training on all chips
		edge = 1
		train = {}

		for cs in range(4):
			if not self.csm & (1 << cs):
				continue

			# Debug
			print("[+] Training CS=%d" % cs)

			# CR write
			self._reg_write(cs, 'cr0', self.cr0)
			self._reg_write(cs, 'cr1', self.cr1)

			# Write the calibration words
			self._mem_write(cs, 0, self.CAL_WORDS[0], count=3)
			self._mem_write(cs, 2, self.CAL_WORDS[1], count=1)

			# Scan delays
			any_valid = False

			for delay in [0, 5, 10, 15]:
				d = self._train_check_edge_delay(cs, edge, delay)
				print("[.]  delay=%2d -> %s" % (delay, "Failed" if (d is None) else ("cap_latency=%d, phase=%d" % d)))
				train.setdefault(delay, {})[cs] = d
				any_valid |= d is not None

			# If nothing valid found, assume chip is missing
			if not any_valid:
				print("[w]  No working delay found, assuming chip is missing: disabling it !")
				self.csm &= ~(1 << cs)

		# Are any chips still enabled ?
		if not self.csm:
			print("[!] All chips disabled, somethins is wrong ...")
			return False

		# Find the best combination
		print("[+] Compiling training results")

			# Check what works for all chips
		train = self._train_consolidate(train)

		if not any(train.values()):
			print("[!] Unable to find single valid combination for all chips :(")
			return False

			# Group them
		groups = self._train_group(train)

			# Pick best group
		best = sorted(groups, key=lambda x: len(x[1]) + 2 * (x[2] + x[3]), reverse=True)[0]

			# Select delay
		self._delay, self._cap_latency, self._phase = self._train_pick_params(best)

		# Load final configuration
		print("[+] Core configured for cmd_latency=%d, capture_latency=%d, phase=%d, delay=%d" % (
			self._cmd_latency, self._cap_latency, self._phase, self._delay
		))

		self._csr = (
			self.CSR_PHY_EDGE(edge) |
			self.CSR_PHY_PHASE(self._phase) |
			self.CSR_PHY_DELAY(self._delay) |
			self.CSR_CMD_LAT(self._cmd_latency) |
			self.CSR_CAP_LAT(self._cap_latency)
		)
		self._write('csr', self._csr)

		# Success
		return True

	def set_runtime(self, runtime):
		self._write('csr', self._csr | (self.CSR_RUN if runtime else 0))


# ----------------------------------------------------------------------------
# Memory tester
# ----------------------------------------------------------------------------

class MemoryTester(object):

	CORE_REGS = {
		'cmd': 0,
		'addr': 1,
	}

	CMD_DUAL		= 1 << 18
	CMD_CHECK_RST	= 1 << 17
	CMD_READ		= 1 << 16
	CMD_WRITE		= 0 << 16
	CMD_BUF_ADDR	= lambda self, addr: addr << 8
	CMD_LEN			= lambda self, l: (l-1) << 0

	def __init__(self, intf, base):
		self.intf = intf
		self.base = base

	def _write(self, reg, val):
		self.intf.write(self.base + self.CORE_REGS[reg], val)

	def _read(self, reg):
		return self.intf.read(self.base + self.CORE_REGS[reg])

	def ram_write(self, addr, val):
		self.intf.write(self.base + 0x100 + addr, val)

	def ram_read(self, addr):
		return self.intf.read(self.base + 0x100 + addr)

	def cmd_write(self, ram_addr, buf_addr, xfer_len):
		self._write('addr', ram_addr)
		self._write('cmd',
			self.CMD_WRITE |
			self.CMD_BUF_ADDR(buf_addr) |
			self.CMD_LEN(xfer_len)
		)

	def cmd_read(self, ram_addr, buf_addr, xfer_len, check_reset=False, dual=False):
		self._write('addr', ram_addr)
		self._write('cmd',
			(self.CMD_DUAL if dual else 0) |
			(self.CMD_CHECK_RST if check_reset else 0) |
			self.CMD_READ |
			self.CMD_BUF_ADDR(buf_addr) |
			self.CMD_LEN(xfer_len)
		)

	def load_data(self, addr, data):
		for base in range(0, len(data), 128):
			# Upload chunk to RAM (128 bytes = max burst len)
			for j in range(0, 128, 4):
				b = (data[base+j:base+j+4] + b'\x00\x00\x00\x00')[0:4]
				w = int.from_bytes(b, 'big')
				self.ram_write(j // 4, w)

			# Issue command to write chunk to RAM
			self.cmd_write(addr + (base // 4), 0, 32)

	def run(self, base, size):
		# Check alignement
		if (base & 31) or (size & 31):
			raise ValueError('Base Address and Size argument for memory testing must be aligned on 32-words')

		# Load random block of data
		ref_data = [
			random.randint(0, (1<<32)-1)
				for i in range(256)
		]

		for i in range(256):
			self.ram_write(i, ref_data[i])

		# Fill memory
		for addr in range(base, base+size, 32):
			print(" . Writing block @ %08x\r" % (addr,), end='')
			self.cmd_write(addr, addr & 0xff, 32)

		# Validate all blocks
		all_good = True

		for addr in range(base, base+size, 32):
			blk_first = (addr & 0xfff) == 0x000
			blk_last  = (addr & 0xfff) == 0xfe0

			print(" . Reading block @ %08x\r" % (addr,), end='')
			self.cmd_read(addr, addr & 0xff, 32, check_reset=blk_first)

			if blk_last:
				if not (self._read('cmd') & 2):
					print(" ! Failed at block %08x" % (addr,))
					all_good = False

		print("                                    \r", end='')

		return all_good


# ----------------------------------------------------------------------------
# HDMI Output
# ----------------------------------------------------------------------------

class HDMIOutput(object):

	def __init__(self, intf, base):
		self.intf = intf
		self.base = base

	def _write(self, reg, val):
		self.intf.write(self.base + self.CORE_REGS[reg], val)

	def _read(self, reg):
		return self.intf.read(self.base + self.CORE_REGS[reg])

	def pal_write(self, addr, val):
		self.intf.write(self.base + (1<<6) + addr, val)

	def enable(self, fb_addr, burst_len):
		# Frame Buffer address
		self.intf.write(self.base + 1, fb_addr)

		# Burst Config
		bn_cnt = ((1920 // 8) - 1) // burst_len
		bn_len = burst_len - 1
		bl_len = (1920 // 8) - (burst_len * bn_cnt) - 1
		bl_inc = bl_len

		self.intf.write(self.base + 0,
			(1 << 31) |
			(bn_cnt << 24) |
			(bn_len << 16) |
			(bl_len <<  8) |
			(bl_inc <<  0)
		)

	def disable(self):
		self.intf.write(self.base + 0, 0)
