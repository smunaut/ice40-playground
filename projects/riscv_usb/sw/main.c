
#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <sched.h>
#include <errno.h>

#include <sys/time.h>

#include <libusb.h>

#include "idt82v2081.h"
#include "idt82v2081_usb.h"
#include "idt82v2081_regs.h"


static int g_do_exit = 0;

#define USB_VID		0x1d50
#define USB_PID		0x6145
#define EP_DATA_IN0	0x81
#define EP_DATA_IN1	0x82

struct e1_streamer;
struct flow;

typedef int (*xfer_cb_t)(struct e1_streamer *e1s, struct flow *flow, uint8_t *buf, int size);

struct flow_entry {
	uint8_t *buf;
	struct libusb_transfer *xfr;
};

struct flow {
	struct e1_streamer *parent;
	xfer_cb_t cb;

	int ep;
	int count;
	int size;
	int ppx;
	struct flow_entry *entries;
};

struct e1_streamer {
	struct libusb_device_handle *devh;
	struct flow data_in[2];
	struct idt82 liu[2];
	FILE *fh;
};

struct e1_chunk_hdr {
	uint32_t magic;
	struct {
		uint64_t sec;
		uint64_t usec;
	} time;
	int16_t len;
	uint8_t ep;
} __attribute__((packed));


static int
cb_xfr_data_in(struct e1_streamer *e1s, struct flow *flow, uint8_t *buf, int size)
{
	struct e1_chunk_hdr hdr;
	struct timeval tv;
	int rc;

	hdr.magic = 0xe115600d;	/* E1 is good */

	gettimeofday(&tv, NULL);
	hdr.time.sec  = tv.tv_sec;
	hdr.time.usec = tv.tv_usec;

	hdr.ep = flow->ep;
	hdr.len = size;

	if (size < 0) {
		printf("EP %02x - Err %d: %s\n", flow->ep, size, libusb_strerror(size));
		return 0;
	}

	if (!e1s->fh)
		return 0;

	rc = fwrite(&hdr, sizeof(struct e1_chunk_hdr), 1, e1s->fh);
	if (rc != 1) {
		fprintf(stderr, "[!] Short write: %d != %zd", rc, sizeof(struct e1_chunk_hdr));
		if (rc == -1)
			fprintf(stderr, ", %s\n", strerror(errno));
		else
			fprintf(stderr, "\n");
		g_do_exit = 1;
	}

	if (size > 0) {
		rc = fwrite(buf, size, 1, e1s->fh);
		if (rc != 1) {
			fprintf(stderr, "[!] Short write: %d != %zd", rc, sizeof(struct e1_chunk_hdr));
			if (rc == -1)
				fprintf(stderr, ", %s\n", strerror(errno));
			else
				fprintf(stderr, "\n");
			g_do_exit = 1;
		}
	}

	return 0;
}

static void LIBUSB_CALL cb_xfr(struct libusb_transfer *xfr)
{
	struct flow *flow = (struct flow *) xfr->user_data;
	struct e1_streamer *e1s = flow->parent;
	int j, rv, len;

#if 0
	fprintf(stderr, "transfer status (%02x) %d [%d %d] [%d %d]\n", flow->ep, xfr->status,
		xfr->iso_packet_desc[0].status,
		xfr->iso_packet_desc[0].actual_length,
		xfr->iso_packet_desc[1].status,
		xfr->iso_packet_desc[1].actual_length
	);
#endif

	if (xfr->status != LIBUSB_TRANSFER_COMPLETED) {
		fprintf(stderr, "[!] XFR status != completed (%d)\n", xfr->status);
		g_do_exit = 1;
	}

	len = 0;

	if (flow->ep & 0x80) {
		for (j=0; j<flow->ppx; j++) {
			flow->cb(e1s, flow,
				libusb_get_iso_packet_buffer_simple(xfr, j),
				(xfr->iso_packet_desc[j].status == LIBUSB_TRANSFER_COMPLETED) ?
					xfr->iso_packet_desc[j].actual_length : -1
			);
			if (!(xfr->iso_packet_desc[j].status == LIBUSB_TRANSFER_COMPLETED)) {
				fprintf(stderr, "[!] ISO packet status != completed (%d)\n",
					xfr->iso_packet_desc[j].status);
				g_do_exit = 1;
			}

			len += (xfr->iso_packet_desc[j].length = flow->size);
		}
	} else {
		for (j=0; j<flow->ppx; j++)
			len += (xfr->iso_packet_desc[j].length = flow->cb(e1s, flow, &xfr->buffer[len], flow->size));
	}

	libusb_fill_iso_transfer(xfr, e1s->devh, flow->ep,
		xfr->buffer, len, flow->ppx,
		cb_xfr, flow, 0
	);

	rv = libusb_submit_transfer(xfr);
	if (rv) {
		fprintf(stderr, "[!] Error re-submitting buffer (%d): %s\n", rv, libusb_strerror(rv));
		g_do_exit = 1;
	}
}


static void
_e1s_flow_fini(struct flow *flow)
{
	int i;

	for (i=0; i<flow->count; i++)
		free(flow->entries[i].buf);

	free(flow->entries);
}

static void
_e1s_flow_init(struct e1_streamer *e1s, struct flow *flow, xfer_cb_t cb, int ep, int count, int size, int ppx)
{
	int i;

	flow->parent  = e1s;
	flow->cb      = cb;
	flow->ep      = ep;
	flow->count   = count;
	flow->size    = size;
	flow->ppx     = ppx;
	flow->entries = calloc(count, sizeof(struct flow_entry));

	for (i=0; i<count; i++)
		flow->entries[i].buf = malloc(size * ppx);
}

static int
_e1s_flow_start(struct e1_streamer *e1s, struct flow *flow)
{
	struct libusb_transfer *xfr;
	int i, j, rv, len;

	for (i=0; i<flow->count; i++)
	{
		xfr = libusb_alloc_transfer(flow->ppx);
		if (!xfr)
			return -ENOMEM;

		len = 0;

		if (flow->ep & 0x80) {
			for (j=0; j<flow->ppx; j++)
				len += (xfr->iso_packet_desc[j].length = flow->size);
		} else {
			for (j=0; j<flow->ppx; j++)
				len += (xfr->iso_packet_desc[j].length = flow->cb(e1s, flow, &flow->entries[i].buf[len], flow->size));
		}

		libusb_fill_iso_transfer(xfr, e1s->devh, flow->ep,
			flow->entries[i].buf, len, flow->ppx,
			cb_xfr, flow, 0
		);

		rv = libusb_submit_transfer(xfr);
		if (rv) {
			return rv;
		}

		flow->entries[i].xfr = xfr;
	}

	return 0;
}


static void
e1s_release(struct e1_streamer *e1s)
{
	if (!e1s)
		return;

	_e1s_flow_fini(&e1s->data_in[0]);
	_e1s_flow_fini(&e1s->data_in[1]);

	if (e1s->devh) {
		libusb_release_interface(e1s->devh, 0);
		libusb_close(e1s->devh);
	}

	free(e1s);
}

static struct e1_streamer *
e1s_new(bool monitor, const char *out_file, bool append, int nx, int ppx)
{
	struct e1_streamer *e1s = NULL;
	int rv;

	e1s = calloc(1, sizeof(struct e1_streamer));
	if (!e1s)
		return NULL;

	e1s->devh = libusb_open_device_with_vid_pid(NULL, USB_VID, USB_PID);
	if (!e1s->devh) {
		fprintf(stderr, "Error finding USB device\n");
		goto err;
	}

	rv = libusb_claim_interface(e1s->devh, 0);
	if (rv < 0) {
		fprintf(stderr, "Error claiming interface: %s\n", libusb_error_name(rv));
		goto err;
	}

	rv = libusb_set_interface_alt_setting(e1s->devh, 0, 1);
	if (rv < 0) {
		fprintf(stderr, "Error enabling interface: %s\n", libusb_error_name(rv));
		goto err;
	}

	_e1s_flow_init(e1s, &e1s->data_in[0], cb_xfr_data_in, EP_DATA_IN0, nx, 388, ppx);
	_e1s_flow_init(e1s, &e1s->data_in[1], cb_xfr_data_in, EP_DATA_IN1, nx, 388, ppx);

	idt82_usb_init(&e1s->liu[0], e1s->devh, EP_DATA_IN0);
	idt82_usb_init(&e1s->liu[1], e1s->devh, EP_DATA_IN1);
	idt82_init(&e1s->liu[0], monitor);
	idt82_init(&e1s->liu[1], monitor);

	if (out_file) {
		e1s->fh = fopen(out_file, append ? "ab" : "wb");
		if (!e1s->fh)
			fprintf(stderr, "[1] Failed to open recording file\n");
	}

	return e1s;

err:
	e1s_release(e1s);
	return NULL;
}

struct options {
	/* Transfer config */
	int nx;
	int ppx;

	/* Output */
	const char *out_filename;
	bool out_append;

	/* PHY */
	bool monitor;

	/* OS */
	bool realtime;
};

static void
opts_defaults(struct options *opts)
{
	memset(opts, 0x00, sizeof(struct options));

	opts->nx = 2;
	opts->ppx = 4;
}

static void
opts_help(void)
{
	fprintf(stderr, " -a           Output : append mode\n");
	fprintf(stderr, " -o FILE      Output : filename\n");
	fprintf(stderr, " -n NX        Xfer   : Number of queued transfers (default: 2)\n");
	fprintf(stderr, " -p PPX       Xfer   : Number of packets per transfer (default: 4)\n");
	fprintf(stderr, " -m           PHY    : Monitor mode (i.e. high gain)\n");
	fprintf(stderr, " -r           OS     : Set real-time priority on process\n");
	fprintf(stderr, " -h           help\n");
}

static int
opts_parse(struct options *opts, int argc, char *argv[])
{
	const char *opts_short = "ao:n:p:mrh";
	int opt;

	while ((opt = getopt(argc, argv, opts_short)) != -1)
	{
		switch(opt) {
		case 'a':
			opts->out_append = true;
			break;

		case 'o':
			opts->out_filename = optarg;
			break;

		case 'n':
			opts->nx = atoi(optarg);
			if (opts->nx <= 0) {
				fprintf(stderr, "[!] Invalid nx value ignored\n");
				opts->nx = 2;
			}
			break;

		case 'p':
			opts->ppx = atoi(optarg);
			if (opts->ppx <= 0) {
				fprintf(stderr, "[!] Invalid ppx value ignored\n");
				opts->ppx = 4;
			}
			break;

		case 'm':
			opts->monitor = true;
			break;

		case 'r':
			opts->realtime = true;
			break;

		case 'h':
		default:
			opts_help();
			exit(1);
		}
	}

	return 0;
}

int main(int argc, char *argv[])
{
	struct e1_streamer *e1s;
	struct sched_param sp;
	struct options opts;
	int rv;

	opts_defaults(&opts);
	opts_parse(&opts, argc, argv);

	if (opts.realtime) {
		memset(&sp, 0x00, sizeof(sp));
		sp.sched_priority = 50;
		rv = sched_setscheduler(0, SCHED_RR, &sp);
		printf("%d %d\n", rv, errno);
		perror("sched_setscheduler");
	}

	rv = libusb_init(NULL);
	if (rv < 0) {
		fprintf(stderr, "Error initializing libusb: %s\n", libusb_error_name(rv));
		return rv;
	}

	e1s = e1s_new(opts.monitor, opts.out_filename, opts.out_append, opts.nx, opts.ppx);
	if (!e1s)
		goto out;

	_e1s_flow_start(e1s, &e1s->data_in[0]);
	_e1s_flow_start(e1s, &e1s->data_in[1]);

	while (!g_do_exit) {
		rv = libusb_handle_events(NULL);
		if (rv != LIBUSB_SUCCESS)
			break;
	}

out:
	e1s_release(e1s);

	libusb_exit(NULL);

	return 0;
}
