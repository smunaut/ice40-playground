/*
 *  icevideo -- stream video over SPI to a smunaut hub75 driver core
 *
 *  Copyright (C) 2018  Piotr Esden-Tempski <piotr@esden.net>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#define _GNU_SOURCE

#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <getopt.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>

#include "mpsse.h"


// ---------------------------------------------------------
// icebreaker specific gpio functions
// ---------------------------------------------------------

static void set_cs(int cs_b)
{
	uint8_t gpio = 0;
	uint8_t direction = 0x0b;

	/*
	 * XXX
	 * The chip select here is the dedicated SPI chip select.
	 * I am not sure how it is being toggled by hand yet.
	 * Not sure this will work.
	 */
	if (cs_b) {
		gpio |= 0x08;
	}

	mpsse_set_gpio(gpio, direction);
}

static void set_reset(int reset)
{
	uint8_t gpio = 0;
	uint8_t direction = 0x8b;

	/*
	 * XXX
	 * The chip select here is the dedicated SPI chip select.
	 * I am not sure how it is being toggled by hand yet.
	 * Not sure this will work.
	 */
	if (reset) {
		gpio |= 0x80;
	}
	gpio |= 0x08;

	mpsse_set_gpio(gpio, direction);
}

// ---------------------------------------------------------
// icestream implementation
// ---------------------------------------------------------

static void help(const char *progname)
{
	fprintf(stderr, "Simple streaming tool for smunaut hub75 core.\n");
	fprintf(stderr, "Usage: %s <input file>\n", progname);
	fprintf(stderr, "\n");
	fprintf(stderr, "General options:\n");
	fprintf(stderr, "  -d <device string>    use the specified USB device [default: i:0x0403:0x6010 or i:0x0403:0x6014]\n");
	fprintf(stderr, "                          d:<devicenode>               (e.g. d:002/005)\n");
	fprintf(stderr, "                          i:<vendor>:<product>         (e.g. i:0x0403:0x6010)\n");
	fprintf(stderr, "                          i:<vendor>:<product>:<index> (e.g. i:0x0403:0x6010:0)\n");
	fprintf(stderr, "                          s:<vendor>:<product>:<serial-string>\n");
	fprintf(stderr, "  -I [ABCD]             connect to the specified interface on the FTDI chip\n");
	fprintf(stderr, "                          [default: A]\n");
	fprintf(stderr, "  -s                    slow SPI (5 MHz instead of 30 MHz)\n");
	fprintf(stderr, "  -v                    verbose output\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Miscellaneous options:\n");
	fprintf(stderr, "      --help            display this help and exit\n");
	fprintf(stderr, "  --                    treat all remaining arguments as filenames\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Exit status:\n");
	fprintf(stderr, "  0 on success,\n");
	fprintf(stderr, "  1 if a non-hardware error occurred (e.g., failure to read from or\n");
	fprintf(stderr, "    write to a file, or invoked with invalid options),\n");
	fprintf(stderr, "  2 if communication with the hardware failed (e.g., cannot find the\n");
	fprintf(stderr, "    iCE FTDI USB device),\n");
	fprintf(stderr, "  3 if verification of the data failed.\n");
	fprintf(stderr, "\n");
}

static void print_stats(bool verbose)
{
	if (!verbose)
		return;

	static double before, next;
	static int frame_count;

	if (before == 0) {
		struct timeval tv0;
		gettimeofday(&tv0, NULL);
		before = tv0.tv_sec + tv0.tv_usec / 1000000.0;
		next = before + 1.0;
		return;
	}

	frame_count++;

	struct timeval tv1;
	gettimeofday(&tv1, NULL);
	double now = tv1.tv_sec + tv1.tv_usec / 1000000.0;
	if (now < next)
		return;

	double fps = frame_count / (now - before);
	fprintf(stderr, "%d: %g FPS\n", (int)(now - before), fps);
	next += 1.0;
}

int main(int argc, char **argv)
{
	/* used for error reporting */
	const char *my_name = argv[0];
	for (size_t i = 0; argv[0][i]; i++)
		if (argv[0][i] == '/')
			my_name = argv[0] + i + 1;

	bool verbose = false;
	bool slow_clock = false;
	const char *filename = NULL;
	const char *devstr = NULL;
	int ifnum = 0;

	static struct option long_options[] = {
		{"help", no_argument, NULL, -2},
		{NULL, 0, NULL, 0}
	};

	/* Decode command line parameters */
	int opt;
	char *endptr;
	while ((opt = getopt_long(argc, argv, "d:I:vs", long_options, NULL)) != -1) {
		switch (opt) {
		case 'd': /* device string */
			devstr = optarg;
			break;
		case 'I': /* FTDI Chip interface select */
			if (!strcmp(optarg, "A"))
				ifnum = 0;
			else if (!strcmp(optarg, "B"))
				ifnum = 1;
			else if (!strcmp(optarg, "C"))
				ifnum = 2;
			else if (!strcmp(optarg, "D"))
				ifnum = 3;
			else {
				fprintf(stderr, "%s: `%s' is not a valid interface (must be `A', `B', `C', or `D')\n", my_name, optarg);
				return EXIT_FAILURE;
			}
			break;
		case 'v': /* provide verbose output */
			verbose = true;
			break;
		case 's': /* use slow SPI clock */
			slow_clock = true;
			break;
		case -2:
			help(argv[0]);
			return EXIT_SUCCESS;
		default:
			/* error message has already been printed */
			fprintf(stderr, "Try `%s --help' for more information.\n", argv[0]);
			return EXIT_FAILURE;
		}
	}

	/* Get file argument */
	if (optind + 1 == argc) {
		filename = argv[optind];
	} else if (optind != argc) {
		fprintf(stderr, "%s: too many arguments\n", my_name);
		fprintf(stderr, "Try `%s --help' for more information.\n", argv[0]);
		return EXIT_FAILURE;
	} else {
		fprintf(stderr, "%s: missing argument\n", my_name);
		fprintf(stderr, "Try `%s --help' for more information.\n", argv[0]);
		return EXIT_FAILURE;
	}

	// ---------------------------------------------------------
	// Open File
	// ---------------------------------------------------------

	FILE *f = NULL;
	long file_size = -1;

	f = (strcmp(filename, "-") == 0) ? stdin : fopen(filename, "rb");
	if (f == NULL) {
		fprintf(stderr, "%s: can't open '%s' for reading: ", my_name, filename);
		perror(0);
		return EXIT_FAILURE;
	}

	// ---------------------------------------------------------
	// Init USB
	// ---------------------------------------------------------

	fprintf(stderr, "init..\n");

	mpsse_init(ifnum, devstr, slow_clock);
//	set_reset(0);
//	sleep(1);
//	set_reset(1);

#define LINE_AT_A_TIME 0

	int llen = 64*6*2;
	int flen = 64*llen;
	uint8_t *buf = malloc(flen);

	while (1) {
		int cblen = 64 * (llen + 21);
		char cmd_buf[cblen + 256];
#if !LINE_AT_A_TIME
		size_t i = 0;
#endif
		/* Read frame */
		if (fread(buf, flen, 1, f) != 1) {
			fseek(f, 0L, SEEK_SET);
			continue;
		}

		/* Upload all the lines */
		for (int y=0; y<64; y++)
		{
#if 0
			cmd_buf[0] = 0x80;
			memcpy(cmd_buf+1, &buf[y*llen], llen);

			set_cs(0);
			mpsse_send_spi(cmd_buf, llen+1);
			set_cs(1);

			/* Swap line buffer and write it to fb */
			cmd_buf[0] = 0x03;
			cmd_buf[1] = y;
			set_cs(0);
			mpsse_send_spi(cmd_buf, 2);
			set_cs(1);
#else
#if LINE_AT_A_TIME
			int i=0;
#endif

			/* Set CS low */
			cmd_buf[i++] = 0x80; /* MC_SETB_LOW */
			cmd_buf[i++] = 0x00; /* gpio */
			cmd_buf[i++] = 0x0b; /* dir  */

			/* SPI packet header */
			cmd_buf[i++] = 0x11; /* MC_DATA_OUT | MC_DATA_OCN */
			cmd_buf[i++] = (llen+1-1) & 0xff;
			cmd_buf[i++] = (llen+1-1) >> 8;

			/* SPI payload */
			cmd_buf[i++] = 0x80;
			memcpy(cmd_buf+i, &buf[y*llen], llen);
			i += llen;

			/* Set CS high */
			cmd_buf[i++] = 0x80; /* MC_SETB_LOW */
			cmd_buf[i++] = 0x08; /* gpio */
			cmd_buf[i++] = 0x0b; /* dir  */

			/* Set CS low */
			cmd_buf[i++] = 0x80; /* MC_SETB_LOW */
			cmd_buf[i++] = 0x00; /* gpio */
			cmd_buf[i++] = 0x0b; /* dir  */

			/* SPI header */
			cmd_buf[i++] = 0x11; /* MC_DATA_OUT | MC_DATA_OCN */
			cmd_buf[i++] = 2-1;
			cmd_buf[i++] = 0;

			/* SPI payload */
			cmd_buf[i++] = 0x03;
			cmd_buf[i++] = y;

			/* Set CS high */
			cmd_buf[i++] = 0x80; /* MC_SETB_LOW */
			cmd_buf[i++] = 0x08; /* gpio */
			cmd_buf[i++] = 0x0b; /* dir  */

#if LINE_AT_A_TIME
			mpsse_send_raw(cmd_buf, i);
#endif
#endif

		}

#if !LINE_AT_A_TIME
		assert(i <= cblen);
		mpsse_send_raw(cmd_buf, i);
#endif

		/* Swap */
		cmd_buf[0] = 0x04;
		cmd_buf[1] = 0x00;
		set_cs(0);
		mpsse_send_spi(cmd_buf, 2);
		set_cs(1);

		/* VSync */
#if 1
		do {
			cmd_buf[0] = 0x00;
			cmd_buf[1] = 0x00;
			set_cs(0);
			mpsse_xfer_spi(cmd_buf, 2);
			set_cs(1);
			//printf("%d\n", cmd_buf[0] | cmd_buf[1]);
		} while (((cmd_buf[0] | cmd_buf[1]) & 0x02) != 0x02);
#endif
		print_stats(verbose);
	}


	// ---------------------------------------------------------
	// Exit
	// ---------------------------------------------------------

	fprintf(stderr, "Bye.\n");
	mpsse_close();
	return 0;
}
