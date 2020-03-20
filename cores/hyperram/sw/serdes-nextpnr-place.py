#!/usr/bin/env python

from collections import namedtuple
import re

BEL = namedtuple('BEL', 'x y z')

def to_int(s):
	return int(re.sub(r'[^\d-]+', '', s))

def split_bel(b):
	return BEL(*[to_int(x) for x in b.split('/', 3)])

def find_io_site(lc):
	# Check in/out ports
	for pn in [ 'I0', 'I1', 'I2', 'I3', 'O' ]:
		n = lc.ports[pn].net
		if (n is None) or n.name.startswith('$PACKER_'):
			continue
		pl = [ n.driver ] + list(n.users)
		for p in pl:
			if (p.cell.type == 'SB_IO') and ('BEL' in p.cell.attrs):
				return split_bel(p.cell.attrs['BEL'])
	return None


# Find all groups and all LCs
serdes_lcs = {}
serdes_site = {}

for n,c in ctx.cells:
	if 'SERDES_GRP' in c.attrs:
		# Get group ID
		grp = int(c.attrs['SERDES_GRP'],2)

		# Append to LCs list and IO site list
		serdes_lcs.setdefault(grp, []).append(c)

		io_site = find_io_site(c)
		if io_site is not None:
			if (grp in serdes_site) and (serdes_site[grp] != io_site):
				raise RuntimeError('IO site conflict for SERDES group %d (%s vs %s)' % (grp, io_site, serdes_site[grp]))
			serdes_site[grp] = io_site

# Split into top / bottmon IO banks
serdes_top = {}
serdes_bot = {}

for grp, site in serdes_site.items():
	if site.y == 31:
		serdes_top[grp] = site
	else:
		serdes_bot[grp] = site

# Place them
# (super dumb algo ...)
def place(sites):
	# Init set
	toplace = sorted(sites.items(), key=lambda x:-x[1].x)
	placed  = {}

	# Scan each possible site in order and place ASAP
	for x in range(1,26):
		# Skip invalid (SPRAM columns)
		if x in [6, 19]:
			continue

		# Place next one ?
		if x >= (toplace[-1][1].x - 1):
			placed[toplace.pop()[0]] = x

		# Done ?
		if not toplace:
			break

	# Cleanup pass
	while True:
		# Find a group that could be moved to its preferred X
		used = set(placed.values())
		for grp, pos in placed.items():
			px = sites[grp].x
			if (pos != px) and (px not in used) and (px not in [6, 19]):
				placed[grp] = sites[grp].x
				break
		else:
			break

	# Done
	return placed

serdes_top_place = place(serdes_top)
serdes_bot_place = place(serdes_bot)

# Merge results
serdes_place = dict()
serdes_place.update(serdes_top_place)
serdes_place.update(serdes_bot_place)

# Add the final BEL attribute to all LCs
for grp in serdes_place.keys():
	x = serdes_place[grp]
	for lc in serdes_lcs[grp]:
		# Grab attributes
		yofs = int(lc.attrs['SERDES_YOFS'], 2)
		y = (30-yofs) if serdes_site[grp].y == 31 else (1+yofs)
		z = int(lc.attrs['SERDES_Z'], 2)

		# Set attribute
		lc.setAttr('BEL', 'X%d/Y%d/lc%d' % (x, y, z))

		# Clear out
		lc.unsetAttr('SERDES_GRP')
		lc.unsetAttr('SERDES_YOFS')
		lc.unsetAttr('SERDES_Z')
