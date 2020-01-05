/* (C) 2019 by Harald Welte <laforge@gnumonks.org>
 * All Rights Reserved
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <string.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <getopt.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

#include "hexdump.h"


static uint8_t g_usb_endpoint = 0x81;

#define E1_CHUNK_HDR_MAGIC	0xe115600d /* E1 is good */
struct e1_chunk_hdr {
	uint32_t magic;
	struct {
		uint64_t sec;
		uint64_t usec;
	} time;
	uint16_t len;		/* length of following payload */
	uint8_t ep;		/* USB endpoint */
} __attribute__((packed));

static int process_file(int fd)
{
	struct e1_chunk_hdr hdr;
	unsigned long offset = 0;
	uint8_t buf[65535];
	int rc;

	while (1) {
		memset(buf, 0, sizeof(buf));
		/* first read header */
		rc = read(fd, &hdr, sizeof(hdr));
		if (rc < 0)
			return rc;
		if (rc != sizeof(hdr)) {
			fprintf(stderr, "%d is less than header size (%zd)\n", rc, sizeof(hdr));
			return -1;
		}
		offset += rc;
		if (hdr.magic != E1_CHUNK_HDR_MAGIC) {
			fprintf(stderr, "offset %lu: Wrong magic 0x%08x\n", offset, hdr.magic);
			return -1;
		}

		/* then read payload */
		rc = read(fd, buf, hdr.len);
		if (rc < 0)
			return rc;
		offset += rc;
		if (rc != hdr.len) {
			fprintf(stderr, "%d is less than payload size (%d)\n", rc, hdr.len);
			return -1;
		}

		/* filter on the endpoint (direction) specified by the user */
		if (hdr.ep != g_usb_endpoint)
			continue;

		if (hdr.len <= 4)
			continue;

		for (int i = 4; i < hdr.len-4; i += 32)
			printf("%s\n", osmo_hexdump(buf+i, 32));
	}
}

static int open_file(const char *fname)
{
	return open(fname, O_RDONLY);
}

int main(int argc, char **argv)
{
	char *fname;
	int rc;

	if (argc < 2) {
		fprintf(stderr, "You must specify the file name of the ICE40-E1 capture\n");
		exit(1);
	}
	fname = argv[1];

	rc = open_file(fname);
	if (rc < 0) {
		fprintf(stderr, "Error opening %s: %s\n", fname, strerror(errno));
		exit(1);
	}
	process_file(rc);
}
