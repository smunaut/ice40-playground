#!/usr/bin/env python3

import sys
import types


#
# OpCodes
#

def NOP():
	return 0x0000

def LD(src):
	srcs = {
		'evt': 0,
		'pkt_pid': 2,
		'pkt_pid_chk': 3,
		'ep_type': 4,
		'bd_state': 6,
	}
	return 0x1000 | srcs[src]

def EP(bd_state=None, bdi_flip=False, dt_flip=False, wb=False, cel_set=False):
	return 0x2000 | \
		((1 << 0) if dt_flip else 0) | \
		((1 << 1) if bdi_flip else 0) | \
		(((bd_state << 3) | (1 << 2)) if bd_state is not None else 0) | \
		((1 << 7) if wb else 0) | \
		((1 << 8) if cel_set else 0)

def ZL():
	return 0x3000

def TX(pid, set_dt=False):
	return 0x4000 | pid | ((1 << 4) if set_dt else 0)

def NOTIFY(code):
	return 0x5000 | code

def EVT_CLR(evts):
	return 0x6000 | evts

def EVT_RTO(timeout):
	return 0x7000 | timeout

def JMP(tgt, cond_val=None, cond_mask=0xf, cond_invert=False):
	if isinstance(tgt, str):
		return lambda resolve: JMP(resolve(tgt), cond_val, cond_mask, cond_invert)
	assert tgt & 3 == 0
	return (
		(1 << 15) |
		(tgt << 6) |
		(0 if (cond_val is None) else ((cond_mask << 4) | cond_val)) |
		((1<<14) if cond_invert else 0)
	)

def JEQ(tgt, cond_val=None, cond_mask=0xf):
	return JMP(tgt, cond_val, cond_mask)

def JNE(tgt, cond_val=None, cond_mask=0xf):
	return JMP(tgt, cond_val, cond_mask, cond_invert=True)

def L(label):
	return label


#
# "Assembler"
#

def assemble(code):
	flat_code = []
	labels    = {}
	for elem in code:
		if isinstance(elem, str):
			assert elem not in labels
			while len(flat_code) & 3:
				flat_code.append(JMP(elem))
			labels[elem] = len(flat_code)
		else:
			flat_code.append(elem)
	for offset, elem in enumerate(flat_code):
		if isinstance(elem, types.LambdaType):
			flat_code[offset] = elem(lambda label: labels[label])
	return flat_code, labels


#
# Constants
#

EVT_ALL     = 0xf
EVT_RX_OK   = (1 << 0)
EVT_RX_ERR  = (1 << 1)
EVT_TX_DONE = (1 << 2)
EVT_TIMEOUT = (1 << 3)

PID_OUT   = 0b0001
PID_IN    = 0b1001
PID_SETUP = 0b1101
PID_DATA0 = 0b0011
PID_DATA1 = 0b1011
PID_ACK   = 0b0010
PID_NAK   = 0b1010
PID_STALL = 0b1110

PID_DATA_MSK = 0b0111
PID_DATA_VAL = 0b0011

EP_TYPE_NONE  = 0b0000
EP_TYPE_ISOC  = 0b0001
EP_TYPE_INT   = 0b0010
EP_TYPE_BULK  = 0b0100
EP_TYPE_CTRL  = 0b0110

EP_TYPE_MSK1  = 0b0111
EP_TYPE_MSK2  = 0b0110
EP_TYPE_HALT  = 0b0001
EP_TYPE_CEL   = 0b1000

BD_NONE      = 0b000
BD_RDY_DATA  = 0b010
BD_RDY_STALL = 0b011
BD_RDY_MSK   = 0b110
BD_RDY_VAL   = 0b010
BD_DONE_OK   = 0b100
BD_DONE_ERR  = 0b101

NOTIFY_SUCCESS = 0x00
NOTIFY_TX_FAIL = 0x08
NOTIFY_RX_FAIL = 0x09

TIMEOUT = 70	# Default timeout value for waiting for a packet from the host


#
# Microcode
#


mc = [
	# Main loop
	# ---------

	L('IDLE'),
		# Wait for an event we care about
		LD('evt'),
		JEQ('IDLE', 0),
		EVT_CLR(EVT_ALL),
		JEQ('IDLE', 0, EVT_RX_OK),

		# Dispatch to handler
		LD('pkt_pid'),
		JEQ('DO_IN', PID_IN),
		JEQ('DO_OUT', PID_OUT),
		JEQ('DO_SETUP', PID_SETUP),
		JMP('IDLE'),						# invalid PID / not token, ignore packet


	# IN Transactions
	# ---------------

	L('DO_IN'),
		# Check endpoint type
		LD('ep_type'),
		JEQ('DO_IN_ISOC', EP_TYPE_ISOC, EP_TYPE_MSK1),	# isochronous is special
		JEQ('IDLE', EP_TYPE_NONE, EP_TYPE_MSK1),		# endpoint doesn't exist, ignore packet


		# Bulk/Control/Interrupt
		# - - - - - - - - - - - -

		# Is EP halted ?
		JEQ('TX_STALL_HALT', EP_TYPE_HALT, EP_TYPE_HALT),

		# If it's a Control endpoint and Lock is active, NAK
		JEQ('TX_NAK', EP_TYPE_CEL | EP_TYPE_CTRL, EP_TYPE_CEL | EP_TYPE_MSK2),

		# Anything valid in the active BD ?
		LD('bd_state'),
		JEQ('TX_STALL_BD', BD_RDY_STALL),
		JNE('TX_NAK', BD_RDY_DATA),

		# TX packet from BD
		TX(PID_DATA0, set_dt=True),

		# Wait for TX to complete
	L('_DO_IN_BCI_WAIT_TX'),
		LD('evt'),
		JEQ('_DO_IN_BCI_WAIT_TX', 0, EVT_TX_DONE),
		EVT_CLR(EVT_TX_DONE),

		# Wait for ACK
		EVT_RTO(TIMEOUT),

	L('_DO_IN_BCI_WAIT_ACK'),
		LD('evt'),
		JEQ('_DO_IN_BCI_WAIT_ACK', 0, EVT_TIMEOUT | EVT_RX_ERR | EVT_RX_OK),

		# If it's not a good packet and a ACK, we failed
		JEQ('_DO_IN_BCI_FAIL', 0, EVT_RX_OK),
		LD('pkt_pid'),
		JNE('_DO_IN_BCI_FAIL', PID_ACK),

		# Success !
		EP(bd_state=BD_DONE_OK, bdi_flip=True, dt_flip=True, wb=True),
		NOTIFY(NOTIFY_SUCCESS),
		JMP('IDLE'),

		# TX Fail handler, notify the host
	L('_DO_IN_BCI_FAIL'),
		NOTIFY(NOTIFY_TX_FAIL),
		JMP('IDLE'),


		# Isochronous
		# - - - - - -

	L('DO_IN_ISOC'),
		# Anything to TX ?
		LD('bd_state'),
		JNE('_DO_IN_ISOC_NO_DATA', BD_RDY_DATA),

		# Transmit packet (with DATA0, always)
		TX(PID_DATA0),

		# Wait for TX to complete
	L('_DO_IN_ISOC_WAIT_TX'),
		LD('evt'),
		JEQ('_DO_IN_ISOC_WAIT_TX', 0, EVT_TX_DONE),
		EVT_CLR(EVT_TX_DONE),

		# "Assume" success
		EP(bd_state=BD_DONE_OK, bdi_flip=True, dt_flip=False, wb=True),
		NOTIFY(NOTIFY_SUCCESS),
		JMP('IDLE'),

		# Transmit empty packet
	L('_DO_IN_ISOC_NO_DATA'),
		ZL(),
		TX(PID_DATA0),
		JMP('IDLE'),


	# SETUP Transactions
	# ------------------

	L('DO_SETUP'),
		# Check the endpoint is 'control' and CEL is not asserted
		LD('ep_type'),
		JNE('RX_DISCARD_NEXT', EP_TYPE_CTRL, EP_TYPE_MSK2 | EP_TYPE_CEL),

		# For Setup, if no-space, don't NAK, just ignore
		LD('bd_state'),
		JNE('RX_DISCARD_NEXT', BD_RDY_DATA),

		# Wait for packet
		EVT_RTO(TIMEOUT),

	L('_DO_SETUP_WAIT_DATA'),
		LD('evt'),
		JEQ('_DO_SETUP_WAIT_DATA', 0, EVT_TIMEOUT | EVT_RX_ERR | EVT_RX_OK),

		# Did it work ?
		JEQ('_DO_SETUP_FAIL', 0, EVT_RX_OK),
		LD('pkt_pid'),
		JNE('_DO_SETUP_FAIL', PID_DATA0),

		# Success !
		EP(bd_state=BD_DONE_OK, bdi_flip=True, dt_flip=True, wb=True, cel_set=True),
		NOTIFY(NOTIFY_SUCCESS),
		JMP('TX_ACK'),

		# Setup RX handler
	L('_DO_SETUP_FAIL'),
		EP(bd_state=BD_DONE_ERR, bdi_flip=True, dt_flip=False, wb=True),
		NOTIFY(NOTIFY_RX_FAIL),
		JMP('IDLE'),


	# OUT Transactions
	# ----------------

	L('DO_OUT'),
		# Check endpoint type
		LD('ep_type'),
		JEQ('DO_OUT_ISOC', EP_TYPE_ISOC, EP_TYPE_MSK1),	# isochronous is special
		JEQ('IDLE', EP_TYPE_NONE, EP_TYPE_MSK1),		# endpoint doesn't exist, ignore packet


		# Bulk/Control/Interrupt
		# - - - - - - - - - - - -

		# If EP is halted, we drop the packet and respond with STALL
		JEQ('_DO_OUT_BCI_DROP_DATA', EP_TYPE_HALT, EP_TYPE_HALT),

		# If it's a Control endpoint and Lock is active, NAK
		JEQ('_DO_OUT_BCI_DROP_DATA', EP_TYPE_CEL | EP_TYPE_CTRL, EP_TYPE_CEL | EP_TYPE_MSK2),

		# Check we have space, if not prevent data writes
		LD('bd_state'),
		JNE('_DO_OUT_BCI_DROP_DATA', BD_RDY_DATA),

		# Wait for packet
		EVT_RTO(TIMEOUT),

	L('_DO_OUT_BCI_WAIT_DATA'),
		LD('evt'),
		JEQ('_DO_OUT_BCI_WAIT_DATA', 0, EVT_TIMEOUT | EVT_RX_ERR | EVT_RX_OK),

		# We got a packet (and possibly stored the data), now we need to respond !
			# Not a valid packet at all, or timeout, or not DATAx -> No response
		JEQ('_DO_OUT_BCI_FAIL', 0, EVT_RX_OK),
		LD('pkt_pid_chk'),
		JNE('_DO_OUT_BCI_FAIL', PID_DATA_VAL, PID_DATA_MSK),	# Accept DATA0/DATA1 only

			# If EP is halted, TX STALL
		LD('ep_type'),
		JEQ('TX_STALL_HALT', EP_TYPE_HALT, EP_TYPE_HALT),

			# If it's a Control endpoint and Lock is active, NAK
		JEQ('TX_NAK', EP_TYPE_CEL | EP_TYPE_CTRL, EP_TYPE_CEL | EP_TYPE_MSK2),

			# Wrong Data Toggle -> Ignore new data, just re-tx a ACK
		LD('pkt_pid_chk'),
		JEQ('TX_ACK', PID_DATA1),								# With pid_chk, DATA1 means wrong DT

			# We didn't have space -> NAK
		LD('bd_state'),
		JNE('TX_NAK', BD_RDY_VAL, BD_RDY_MSK),

			# Explicitely asked for stall ?
		JEQ('TX_STALL_BD', BD_RDY_STALL),

		# We're all good !
		EP(bd_state=BD_DONE_OK, bdi_flip=True, dt_flip=True, wb=True),
		NOTIFY(NOTIFY_SUCCESS),
		JMP('TX_ACK'),

		# Fail handler: Prepare to drop data
	L('_DO_OUT_BCI_DROP_DATA'),
		ZL(),
		JMP('_DO_OUT_BCI_WAIT_DATA'),

		# Fail hander: Packet reception failed
	L('_DO_OUT_BCI_FAIL'),
			# Check we actually had a BD at all
		LD('bd_state'),
		JNE('IDLE', BD_RDY_VAL, BD_RDY_MSK),

			# We had a BD, so report the error
		EP(bd_state=BD_DONE_ERR, bdi_flip=True, dt_flip=False, wb=True),
		NOTIFY(NOTIFY_RX_FAIL),
		JMP('IDLE'),


		# Isochronous
		# - - - - - -

	L('DO_OUT_ISOC'),
		# Do we have space to RX ?
		LD('bd_state'),
		JNE('_DO_OUT_ISOC_NO_SPACE', BD_RDY_DATA),

		# Wait for packet RX
		EVT_RTO(TIMEOUT),

	L('_DO_OUT_ISOC_WAIT_DATA'),
		LD('evt'),
		JEQ('_DO_OUT_ISOC_WAIT_DATA', 0, EVT_TIMEOUT | EVT_RX_ERR | EVT_RX_OK),

		# Did it work ?
		JEQ('_DO_OUT_ISOC_FAIL', 0, EVT_RX_OK),
		LD('pkt_pid'),
		JNE('_DO_OUT_ISOC_FAIL', PID_DATA_VAL, PID_DATA_MSK),	# Accept DATA0/DATA1

		# Success !
		EP(bd_state=BD_DONE_OK, bdi_flip=True, dt_flip=False, wb=True),
		NOTIFY(NOTIFY_SUCCESS),
		JMP('IDLE'),

		# RX fail handler, mark error in the BD, notify host
	L('_DO_OUT_ISOC_FAIL'),
		EP(bd_state=BD_DONE_ERR, bdi_flip=True, dt_flip=False, wb=True),
		NOTIFY(NOTIFY_RX_FAIL),
		JMP('IDLE'),

		# RX no-space handler, just discard packet :(
	L('_DO_OUT_ISOC_NO_SPACE'),
		# Notify host ?
		# Discard
		JMP('RX_DISCARD_NEXT'),


	# Common shared utility
	# ---------------------

	# Transmit STALL as asked in a Buffer Descriptor
	L('TX_STALL_BD'),
		EP(bd_state=BD_DONE_OK, bdi_flip=True, dt_flip=False, wb=True),
		NOTIFY(NOTIFY_SUCCESS),
		# fall-thru

	# Transmit STALL because of halted End Point
	L('TX_STALL_HALT'),
		ZL(),
		TX(PID_STALL),
		JMP('IDLE'),

	# Transmit NAK handshake
	L('TX_NAK'),
		ZL(),
		TX(PID_NAK),
		JMP('IDLE'),

	# Transmit ACK handshake
	L('TX_ACK'),
		ZL(),
		TX(PID_ACK),
		JMP('IDLE'),

	# Discard the next packet (if any)
	L('RX_DISCARD_NEXT'),
		# Zero-length to prevent store of data
		ZL(),

		# Wait for a packet
		EVT_RTO(TIMEOUT),

	L('_RX_DISCARD_WAIT'),
		LD('evt'),
		JEQ('_RX_DISCARD_WAIT', 0, EVT_TIMEOUT | EVT_RX_ERR | EVT_RX_OK),

		# Done
		JMP('IDLE'),
]


if __name__ == '__main__':
	code, labels = assemble(mc)
	ilabel = dict([(v,k) for k,v in labels.items()])
	for i, v in enumerate(code):
		if (len(sys.argv) > 1) and (sys.argv[1] == 'debug'):
			print("%02x %04x\t%s" % (i, v,ilabel.get(i,'')))
		else:
			print("%04x" % (v,))
