#!/usr/bin/env python3

from collections import namedtuple
import re


# SerDes group numbers:
#  [15:12] Group
#  [11: 8] SubGroup
#  [ 7: 4] Type
#  [    3] n/a
#  [ 2: 0] LC number
#
# SubGroups:
#
#  0 Data Out path 0
#  1 Data Out path 1
#  2 Data Out Enable
#
#  4 Data In  path 0
#  5 Data In  path 1
#  6 Data In  common
#
#
# Types:
#
# 0 OSERDES Capture
# 1 OSERDES Shift
# 2 OSERDES NegEdge Delay
#
# 8 ISERDES Slow Capture
# 9 ISERDES Fast Capture
# a ISERDES Shift
# b ISERDES PreMux
#
#
# Placement priority
#
#        type    near
#        2       io      Output Neg Edge delay
#        b       io      Input Pre mux
#        a       io      Input Shift
#        9       'a'     Input Fast Capture
#        1       io      Output Shift
#        0       '1'     Output Capture
#        8       '9's    Input Slow Capture
#


class BEL(namedtuple('BEL', 'x y z')):

	@classmethod
	def from_json_attr(kls, v):
		def to_int(s):
			return int(re.sub(r'[^\d-]+', '', s))
		return kls(*[to_int(x) for x in v.split('/', 3)])


class ControlGroup(namedtuple('ControlGroup', 'clk rst ena neg')):

	@classmethod
	def from_lc(kls, lc):
		netname = lambda lc, p: lc.ports[p].net.name if (lc.ports[p].net is not None) else None
		return kls(
			netname(lc, 'CLK'),
			netname(lc, 'SR'),
			netname(lc, 'CEN'),
			lc.params['NEG_CLK'] == '1'
		)


class FullCellId(namedtuple('SDGId', 'gid sid typ lc')):

	@classmethod
	def from_json_attr(kls, v):
		return kls(
			v >> 12,
			(v >> 8) & 0xf,
			(v >> 4) & 0xf,
			(v >> 0) & 0x7
		)


class SerDesGroup:

	def __init__(self, gid):
		self.gid = gid
		self.blocks = {}
		self.io = None

	def add_lc(self, lc, fcid=None):
		# Get Full Cell ID if not provided
		if fcid is None:
			grp = int(lc.attrs['SERDES_GRP'], 2)
			fcid = FullCellId.from_json_attr(grp)

		# Add to the cell list
		if (fcid.sid, fcid.typ) not in self.blocks:
			self.blocks[(fcid.sid, fcid.typ)] = SerDesBlock(self, fcid.sid, fcid.typ)

		self.blocks[(fcid.sid, fcid.typ)].add_lc(lc, fcid=fcid)

	def analyze(self):
		# Process all blocks
		for blk in self.blocks.values():
			# Analyze
			blk.analyze()

			# Check IO
			if blk.io is not None:
				if (self.io is not None) and (self.io != blk.io):
					raise RuntimeError(f'Incompatible IO sites found in SerDes group {self.gid}: {self.io} vs {blk.io}')
				self.io = blk.io


class SerDesBlock:

	NAMES = {
		0x0: 'OSERDES Capture',
		0x1: 'OSERDES Shift',
		0x2: 'OSERDES NegEdge Delay',
		0x8: 'ISERDES Slow Capture',
		0x9: 'ISERDES Fast Capture',
		0xa: 'ISERDES Shift',
		0xb: 'ISERDES PreMux',
	}

	def __init__(self, group, sid, typ):
		# Identity
		self.group = group
		self.sid = sid
		self.typ = typ

		# Container
		self.lcs = 8 * [None]
		self.io = None
		self.cg = None

	def __str__(self):
		return f'SerDesBlock({self.sid:x}/{self.typ:x} {self.NAMES[self.typ]})'

	def _find_io_site_for_lc(self, lc):
		# Check in/out ports
		for pn in [ 'I0', 'I1', 'I2', 'I3', 'O' ]:
			n = lc.ports[pn].net
			if (n is None) or n.name.startswith('$PACKER_'):
				continue
			pl = [ n.driver ] + list(n.users)
			for p in pl:
				if (p.cell.type == 'SB_IO') and ('BEL' in p.cell.attrs):
					return BEL.from_json_attr(p.cell.attrs['BEL'])
		return None

	def add_lc(self, lc, fcid=None):
		# Get Full Cell ID if not provided
		if fcid is None:
			grp = int(lc.attrs['SERDES_GRP'], 2)
			fcid = FullCellId.from_json_attr(grp)

		# Add to LCs
		if self.lcs[fcid.lc] is not None:
			raise RuntimeError(f'Duplicate LC for FullCellId {fcid}')

		self.lcs[fcid.lc] = lc

	def find_io_site(self):
		for lc in self.lcs:
			if lc is None:
				continue
			s = self._find_io_site_for_lc(lc)
			if s is not None:
				return s
		return None

	def analyze(self):
		# Check and truncate LC array
		l = len(self)
		if not all([x is not None for x in self.lcs[0:l]]):
			raise RuntimeError(f'Invalid group in block {self.group.gid}/{self.sid}/{self.typ}')

		self.lcs = self.lcs[0:l]

		# Identify IO site connection if there is one
		self.io = self.find_io_site()

		# Identify the control group
		self.cg = ControlGroup.from_lc(self.lcs[0])

	def assign_bel(self, base_bel, zofs=0):
		for i, lc in enumerate(self.lcs):
			lc.setAttr('BEL', 'X%d/Y%d/lc%d' % (base_bel.x, base_bel.y, base_bel.z + zofs + i))

	def __len__(self):
		return sum([x is not None for x in self.lcs])


class PlacerSite:

	def __init__(self, pos):
		self.pos = pos
		self.free = 8
		self.blocks = []
		self.cg = None

	def valid_for_block(self, blk):
		return (self.free >= len(blk)) and (
			(self.cg is None) or
			(blk.cg is None) or
			(self.cg == blk.cg)
		)

	def add_block(self, blk):
		# Assign the block into position
		pos = BEL(self.pos.x, self.pos.y, 8-self.free)
		blk.assign_bel(pos)

		# Add to blocks here
		self.blocks.append(blk)

		# Update constrainsts
		self.cg = blk.cg
		self.free -= len(blk)

		return pos


class Placer:

	PRIORITY = [
		# Type	Place Target
		(0x2,	lambda p, b: b.group.io),
		(0xb,	lambda p, b: b.group.io),
		(0xa,	lambda p, b: b.group.io),
		(0x9,	lambda p, b: p.pos_of( b.group.blocks[(4|(b.sid & 1), 0xa)] ) ),
		(0x1,	lambda p, b: b.group.io),
		(0x0,	lambda p, b: p.pos_of( b.group.blocks[(b.sid, 0x1)]  ) ),
		(0x8,	lambda p, b: p.pos_of( b.group.blocks[(4, 0xa)], b.group.blocks.get((5, 0xa)) ) ),
	]

	PLACE_PREF = [
		# Xofs Yofs
		( 0,  1),
		(-1,  1),
		( 1,  1),
		(-1,  0),
		( 1,  0),
		( 0, -1),
		(-1, -1),
		( 1, -1),
		( 0,  1),
		( 0,  2),
		( 0,  3),
		( 0,  4),
		(-1,  1),
		( 1,  1),
		(-1,  2),
		( 1,  2),
		(-1,  3),
		( 1,  3),
		(-1,  4),
		( 1,  4),
	]

	def __init__(self, groups, top=False):
		# Save groups to place
		self.groups = groups

		# Generate site grid
		self.top = top
		self.m_fwd  = {}
		self.m_back = {}

		for y in (range(26,31) if self.top else range(1,6)):
			for x in range(1,25):
				# Invalid, used by SPRAM
				if x in [6,19]:
					continue
				self.m_fwd[BEL(x,y,0)] = PlacerSite(BEL(x,y, 0))

	def _blocks_by_type(self, typ):
		r = []
		for grp in self.groups:
			for blk in grp.blocks.values():
				if blk.typ == typ:
					r.append(blk)
		return sorted(r, key=lambda b: (b.group.gid, b.sid))

	def place(self):
		# Scan by priority order
		for typ, fn in self.PRIORITY:
			# Collect all blocks per type and sorted by gid,sid
			blocks = self._blocks_by_type(typ)

			# Place each block
			for blk in blocks:
				# Get target location
				tgt = fn(self, blk)

				if type(tgt) == list:
					x = int(round(sum([b.x for b in tgt]) / len(tgt)))
					y = int(round(sum([b.y for b in tgt]) / len(tgt)))
					tgt = BEL(x, y, 0)

				# Scan placement preference and try to place
				for xofs, yofs in self.PLACE_PREF:
					# Flip for top
					if self.top:
						yofs = -yofs

					p = BEL(tgt.x + xofs, tgt.y + yofs, 0)

					if (p in self.m_fwd) and (self.m_fwd[p].valid_for_block(blk)):
						self.place_block(blk, p)
						break

				else:
					raise RuntimeError(f'Unable to place {blk}')

		# Debug
		if debug:
			for g in self.groups:
				print(f"Group {g.gid} for IO {g.io}")
				for b in g.blocks.values():
					print(f"\t{str(b):40s}: {len(b)} LCs placed @ {self.pos_of(b)}")
				print()

	def place_block(self, blk, pos):
		self.m_back[blk] = self.m_fwd[pos].add_block(blk)

	def pos_of(self, *blocks):
		if len(blocks) > 1:
			return [ self.m_back.get(b) for b in blocks if b is not None ]
		else:
			return self.m_back.get(blocks[0])



# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

debug = True


# Collect
# -------

groups = {}
sync_lbuf_net_map = {}
sync_lbuf_top = {}
sync_lbuf_bot = {}

for n,c in ctx.cells:
	# Filter out dummy 'BEL' attributes
	if 'BEL' in c.attrs:
		if not c.attrs['BEL'].strip():
			c.unsetAttr('BEL')

	# Special processing
	if 'SERDES_ATTR' in c.attrs:
		attr = c.attrs['SERDES_ATTR']
		c.unsetAttr('SERDES_ATTR')

		# Local sync buffer
		if attr.startswith('sync_lbuf'):
			# Position
			if attr.endswith('top'):
				d = sync_lbuf_top
			elif attr.endswith('bot'):
				d = sync_lbuf_bot

			# Sync source
			src_net = c.ports['I0'].net
			src_plb = BEL.from_json_attr(src_net.driver.cell.attrs['BEL'])[0:2]
			dst_net = c.ports['O'].net

			# Collect
			sync_lbuf_net_map.setdefault(src_plb, []).append(src_net.name)
			d[src_plb] = dst_net.name

	# Does the cell need grouping ?
	if 'SERDES_GRP' in c.attrs:
		# Get group
		grp = int(c.attrs['SERDES_GRP'], 2)
		c.unsetAttr('SERDES_GRP')

		# Skip invalid/dummy
		if grp == 0xffffffff:
			continue

		# Add LC to our list
		fcid = FullCellId.from_json_attr(grp)

		if fcid.gid not in groups:
			groups[fcid.gid] = SerDesGroup(fcid.gid)

		groups[fcid.gid].add_lc(c, fcid=fcid)


# Analyze and split into top/bottom
# ---------------------------------

groups_top = []
groups_bot = []

for g in groups.values():
	# Analyze
	g.analyze()

	# Sort
	if g.io.y == 0:
		groups_bot.append(g)
	else:
		groups_top.append(g)


# Process local buffers
# ---------------------

def lbuf_build_map(src_net_map, dst_net_map):
	rv = {}
	for k, v in dst_net_map.items():
		for n in src_net_map[k]:
			rv[n] = v
	return rv

def lbuf_reconnect(net_map, cells):
	# Scan all cells
	for lc in cells:
		# Scan all ports
		for pn in ['I0', 'I1', 'I2', 'I3', 'CEN']:
			n = lc.ports[pn].net
			if (n is not None) and (n.name in net_map):
				# Reconnect
				ctx.disconnectPort(lc.name, pn)
				ctx.connectPort(net_map[n.name], lc.name, pn)


sync_lbuf_top = lbuf_build_map(sync_lbuf_net_map, sync_lbuf_top)
sync_lbuf_bot = lbuf_build_map(sync_lbuf_net_map, sync_lbuf_bot)

for g in groups_top:
	for blk in g.blocks.values():
		lbuf_reconnect(sync_lbuf_top, blk.lcs)

for g in groups_bot:
	for blk in g.blocks.values():
		lbuf_reconnect(sync_lbuf_bot, blk.lcs)


# Execute placer
# --------------

if groups_top:
	p_top = Placer(groups_top, top=True)
	p_top.place()

if groups_bot:
	p_bot = Placer(groups_bot, top=False)
	p_bot.place()
