#!/usr/bin/env python3

import binascii
import random
import serial
import sys
import time


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
		ser.baudrate = 4000000
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

	def read_burst(self, addr, burst_len, adv=4):
		req_addr = addr
		ofs  = 0
		resp = []

		while len(resp) < burst_len:
			# Anything left to request ?
			if ofs < burst_len:
				# Issue commands
				cmd_a = ((self.COMMANDS['REG_ACCESS'] << 36) | (1<<20) | (addr + ofs)).to_bytes(5, 'big')
				cmd_b = ((self.COMMANDS['DATA_GET']   << 36)).to_bytes(5, 'big')
				self.ser.write(cmd_a + cmd_b)

				# Next
				ofs += 1

			# If we're in advance, read back
			if ofs > adv:
				d = self.ser.read(4)
				if len(d) != 4:
					raise RuntimeError('Comm error')
				resp.append( int.from_bytes(d, 'big') )

		return resp

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
# I2C master
# ----------------------------------------------------------------------------

class I2CMaster(object):

	CMD_START = 0 << 12
	CMD_STOP  = 1 << 12
	CMD_WRITE = 2 << 12
	CMD_READ  = 3 << 12

	def __init__(self, intf, base=0):
		self.intf = intf
		self.base = base

	def _wait(self):
		while True:
			v = self.intf.read(self.base)
			if v & (1 << 31):
				break
		return v & 0x1ff;

	def start(self):
		self.intf.write(self.base, self.CMD_START)
		self._wait()

	def stop(self):
		self.intf.write(self.base, self.CMD_STOP)
		self._wait()

	def write(self, data):
		self.intf.write(self.base, self.CMD_WRITE | (data & 0xff))
		return bool(self._wait() & (1 << 8))

	def read(self, ack):
		self.intf.write(self.base, self.CMD_READ | ((1 << 8) if ack else 0))
		return self._wait() & 0xff

	def write_reg(self, dev, reg, val):
		self.start()
		self.write(dev)
		self.write(reg)
		self.write(val)
		self.stop()

	def read_reg(self, reg):
		self.start()
		self.write(dev)
		self.write(reg)
		self.start()
		self.write(dev|1)
		v = self.read(False)
		self.stop()
		return v



# --------------------------------------------------------------------------------

def hexdump(x):
	return binascii.b2a_hex(x).decode('utf-8')

def adv_init(i2c, test_mode=None, port='cvbs'):
	# Reset
	i2c.write_reg(0x40, 0x0f, 0x80)
	time.sleep(10e-3)

	i2c.write_reg(0x40, 0x0f, 0x00) # Exit Power Down Mode
	i2c.write_reg(0x40, 0x52, 0xcd) # AFE IBIAS

	if test_mode is not None:
		# Free-Run
		i2c.write_reg(0x40, 0x00, 0x05) # ADI Required Write [INSEL set to unconnected input]
		i2c.write_reg(0x40, 0x0c, 0x37) # Force Free run mode

		if test_mode == 'pal':
			i2c.write_reg(0x40, 0x02, 0x84) # Force standard to PAL
		elif test_mode == 'ntsc':
			i2c.write_reg(0x40, 0x02, 0x54) # Force standard to NTSC-M
		else:
			raise ValueError('Invalid test mode')

		i2c.write_reg(0x40, 0x14, 0x11) # Set Free-run pattern to 100% color bars

	elif port == 'cvbs':
		# CVBS
		i2c.write_reg(0x40, 0x00, 0x00) # CVBS in on AIN1
		i2c.write_reg(0x40, 0x0e, 0x80) # ADI Required Write
		i2c.write_reg(0x40, 0x9c, 0x00) # Reset Current Clamp Circuitry [step1]
		i2c.write_reg(0x40, 0x9c, 0xff) # Reset Current Clamp Circuitry [step2]
		i2c.write_reg(0x40, 0x0e, 0x00) # Enter User Sub Map

	elif port == 'svideo':
		i2c.write_reg(0x40, 0x53, 0xce) # ADI Required Write [Ibias]
		i2c.write_reg(0x40, 0x00, 0x08) # INSEL = YC, Y - Ain1, C - Ain2
		i2c.write_reg(0x40, 0x0e, 0x80) # ADI Required Write
		i2c.write_reg(0x40, 0x9c, 0x00) # Reset Coarse Clamp Circuitry [step1]
		i2c.write_reg(0x40, 0x9c, 0xff) # Reset Coarse Clamp Circuitry [step2]
		i2c.write_reg(0x40, 0x0e, 0x00) # Enter User Sub Map

	i2c.write_reg(0x40, 0x80, 0x51) # ADI Required Write
	i2c.write_reg(0x40, 0x81, 0x51) # ADI Required Write
	i2c.write_reg(0x40, 0x82, 0x68) # ADI Required Write
	i2c.write_reg(0x40, 0x17, 0x41) # Enable SH1
	i2c.write_reg(0x40, 0x03, 0x0c) # Enable Pixel & Sync output drivers
	i2c.write_reg(0x40, 0x04, 0x07) # Power-up INTRQ, HS & VS pads
	i2c.write_reg(0x40, 0x13, 0x00) # Enable ADV7282A for 28_63636MHz crystal
	i2c.write_reg(0x40, 0x1d, 0x40) # Enable LLC output driver

	#i2c.write_reg(0x40, 0xFD, 0x84) # Set VPP map address
	#i2c.write_reg(0x84, 0xA3, 0x00) # ADI Required Write [ADV7282A VPP writes begin]
	#i2c.write_reg(0x84, 0x5B, 0x00) # Enable Advanced Timing Mode
	#i2c.write_reg(0x84, 0x55, 0x80) # Enable the Deinterlacer for I2P [All ADV7282A Writes Finished]


def main(argv0, action, port='/dev/ttyACM0'):
	wbi   = WishboneInterface(port=port)
	i2c   = I2CMaster(wbi, 0x00000)
	psram = QSPIController(wbi, 0x10000, cs=1)

	if action == 'init_cvbs':
		wbi.aux_csr(1)
		adv_init(i2c, port='cvbs')

	elif action == 'init_svideo':
		wbi.aux_csr(1)
		adv_init(i2c, port='svideo')

	elif action == 'capture':
		# Info debug
		#print("[+] ID read")
		#print(" PSRAM: " + hexdump(psram.spi_xfer(b'\x9f', dummy_len=3, rx_len=8)))

		# QPI enable
		psram.spi_xfer(b'\x35')

		# Issue capture command
		wbi.write(0x20000, (1<<31))
		time.sleep(1);

		# Issue read command of 1 block
		N = 0x60000
		for addr in range(0, N, 128):
			wbi.write(0x20000, (1<<30) | addr)
			for d in wbi.read_burst(0x20000, 128, 32):
				print("%08x" % d)

		# QPI disable
		psram.qpi_xfer(b'\xf5')


if __name__ == '__main__':
	main(*sys.argv)
