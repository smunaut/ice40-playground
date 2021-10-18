/*
 * fw_app.c
 *
 * Copyright (C) 2021 Sylvain Munaut
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include <no2usb/usb.h>
#include <no2usb/usb_priv.h>
#include <no2usb/usb_hw.h>
#include <no2usb/usb_dfu_rt.h>

#include "i2c.h"
#include "led.h"
#include "console.h"
#include "framegrab.h"

#include "config.h"

struct misc {
	uint32_t csr;
} __attribute__((packed,aligned(4)));

#define MISC_BOOT		(1 << 31)
#define MISC_BTN		(1 << 16)
#define MISC_GET_TIMER(v)	((v) & 0xffff)

static volatile struct misc * const misc_regs = (void*)(MISC_BASE);



extern const struct usb_stack_descriptors app_stack_desc;




static void
wait_ms(int delay)
{
	uint16_t t = MISC_GET_TIMER(misc_regs->csr) + delay;

        while (MISC_GET_TIMER(misc_regs->csr) != t)
        {
                for (int i=0; i<100; i++)
                        asm("nop");
        }
}

void
adv_init(void)
{
	i2c_write_reg(0x40, 0x0f, 0x80);	// Reset

	wait_ms(10);

	i2c_write_reg(0x40, 0x0f, 0x00);	// Exit Power Down Mode
	i2c_write_reg(0x40, 0x52, 0xcd);	// AFE IBIAS

#if 0
	i2c_write_reg(0x40, 0x00, 0x05);	// ADI Required Write [INSEL set to unconnected input]
	i2c_write_reg(0x40, 0x0c, 0x37);	// Force Free run mode
	i2c_write_reg(0x40, 0x02, 0x84);	// Force standard to PAL
	i2c_write_reg(0x40, 0x14, 0x11);	// Set Free-run pattern to 100% color bars
#else
	i2c_write_reg(0x40, 0x53, 0xce);	// ADI Required Write [Ibias]
	i2c_write_reg(0x40, 0x00, 0x08);	// INSEL = YC, Y - Ain1, C - Ain2
	i2c_write_reg(0x40, 0x0e, 0x80);	// ADI Required Write
	i2c_write_reg(0x40, 0x9c, 0x00);	// Reset Coarse Clamp Circuitry [step1]
	i2c_write_reg(0x40, 0x9c, 0xff);	// Reset Coarse Clamp Circuitry [step2]
	i2c_write_reg(0x40, 0x0e, 0x00);	// Enter User Sub Map
#endif

	i2c_write_reg(0x40, 0x80, 0x51);	// ADI Required Write
	i2c_write_reg(0x40, 0x81, 0x51);	// ADI Required Write
	i2c_write_reg(0x40, 0x82, 0x68);	// ADI Required Write
	i2c_write_reg(0x40, 0x17, 0x41);	// Enable SH1
	i2c_write_reg(0x40, 0x03, 0x0c);	// Enable Pixel & Sync output drivers
	i2c_write_reg(0x40, 0x04, 0x07);	// Power-up INTRQ, HS & VS pads
	i2c_write_reg(0x40, 0x13, 0x00);	// Enable ADV7282A for 28_63636MHz crystal
	i2c_write_reg(0x40, 0x1d, 0x40);	// Enable LLC output driver
}


// ----------------------------------------------------------------------------------------------------

#include <no2usb/usb_vc_proto.h>

static struct {
	bool init_done;
	bool active;
	int  bdi;

	uint8_t uvc_frame_id;
	uint8_t cap_frame;
	bool    dma_pending;
	struct dma_state ds;
} g_video;


static struct usb_vc_probe_commit infos = {
	.bmHint			= 0x0001,
	.bFormatIndex		= 1,
	.bFrameIndex		= 1,
	.dwFrameInterval	= 4320000,
	.wKeyFrameRate		= 0,
	.wPFrameRate		= 0,
	.wCompQuality		= 0,
	.wCompWindowSize	= 0,
	.wDelay			= 0,
	.dwMaxVideoFrameSize	= 720 * 288 * 2,
	.dwMaxPayloadTransferSize = 960,
	.dwClockFrequency	= 1000000,
	.bmFramingInfo		= 3,
	.bPreferedVersion	= 0,
	.bMinVersion		= 0,
	.bMaxVersion		= 0,
};

static bool
_set_cur(struct usb_xfer *xfer)
{
	memcpy(&infos, xfer->data, sizeof(infos));
	return true;
}

static enum usb_fnd_resp
video_usb_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	const struct usb_intf_desc *intf;

	/* Check it's a class request to an interface */
	if ((USB_REQ_TYPE(req) | USB_REQ_RCPT(req)) != (USB_REQ_TYPE_CLASS | USB_REQ_RCPT_INTF))
		return USB_FND_CONTINUE;

	/* Check it's audio class / control interface */
	intf = usb_desc_find_intf(NULL, (req->wIndex & 0xff), 0, NULL);
	if ((intf == NULL) || (intf->bInterfaceClass != USB_CLS_VIDEO))
		return USB_FND_CONTINUE;

	/* Check unit ID */
	//printf("VCtrl: %04x %04x %04x %d %d\n", req->wRequestAndType, req->wIndex, req->wValue, req->wLength, sizeof(infos));

	/* */
	switch (req->wRequestAndType)
	{
	case USB_RT_VC_SET_CUR_INTF:
		xfer->cb_done = _set_cur;
		return USB_FND_SUCCESS;

	case USB_RT_VC_GET_MIN_INTF:
	case USB_RT_VC_GET_MAX_INTF:
	case USB_RT_VC_GET_CUR_INTF:
	case USB_RT_VC_GET_DEF_INTF:
		memcpy(xfer->data, &infos, sizeof(infos));
		xfer->len = sizeof(infos);
		return USB_FND_SUCCESS;

	default:
		return USB_FND_ERROR;
	}
}

static enum usb_fnd_resp
video_usb_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	/* Check it's audio class */
	if (base->bInterfaceClass != USB_CLS_VIDEO)
		return USB_FND_CONTINUE;

	/* Sub class */
	switch (base->bInterfaceSubClass)
	{
		case USB_VC_SCLS_VIDEOCONTROL:
		case USB_VC_SCLS_COLLECTION:
			return USB_FND_SUCCESS;

		case USB_VC_SCLS_VIDEOSTREAMING:
			/* EP config */
			if (!g_video.init_done) {
				usb_ep_boot(base, 0x84, true);
				g_video.init_done = true;
			}

			usb_ep_reconf(sel, 0x84);

			g_video.bdi = 0;

			/* Set state */
			g_video.active = (sel->bAlternateSetting != 0);
			printf("Set : %d\n", sel->bAlternateSetting);

			if (g_video.active) {
				printf("Activate\n");
				g_video.uvc_frame_id = 0;
				g_video.cap_frame    = 0xff;
				g_video.dma_pending  = false;
			}

			/* LED update */
			if (g_video.active)
				led_color(0, 48, 0);
			else
				led_color(48, 0, 0);

			return USB_FND_SUCCESS;

		default:
			return USB_FND_ERROR;
	}
}

static enum usb_fnd_resp
video_usb_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	/* Check it's video class */
	if (base->bInterfaceClass != USB_CLS_VIDEO)
		return USB_FND_CONTINUE;

	/* Sub class */
	switch (base->bInterfaceSubClass)
	{
	case USB_VC_SCLS_VIDEOCONTROL:
	case USB_VC_SCLS_COLLECTION:
		*alt = 0;
		return USB_FND_SUCCESS;

	case USB_VC_SCLS_VIDEOSTREAMING:
		*alt = g_video.active ? 1 : 0;
		return USB_FND_SUCCESS;

	default:
		return USB_FND_ERROR;
	}
}

static struct usb_fn_drv _video_drv = {
	.ctrl_req = video_usb_ctrl_req,
	.set_intf = video_usb_set_intf,
	.get_intf = video_usb_get_intf,
};


static volatile struct usb_ep *
_usb_hw_get_ep(uint8_t ep_addr)
{
        return (ep_addr & 0x80) ?
                &usb_ep_regs[ep_addr & 0xf].in :
                &usb_ep_regs[ep_addr & 0xf].out;
}



static void
video_poll(void)
{
	volatile struct usb_ep *ep_regs;

	/* Only while active */
	if (!g_video.active)
		return;

	/* Fill buffer */
	ep_regs = _usb_hw_get_ep(0x84);

	while (1)
	{
		/* All caught up */
		if ((ep_regs->bd[g_video.bdi].csr & USB_BD_STATE_MSK) == USB_BD_STATE_RDY_DATA)
			break;

		/* Was DMA already commanded ? */
		if (!g_video.dma_pending)
		{
			uint8_t hdr[4];
			int len;
			bool eoi;

			/* Do we have a frame ? If not, grab one and prep for DMA */
			if (g_video.cap_frame == 0xff) {
				if ((g_video.cap_frame = framegrab_get_latest()) == 0xff)
					break;

				dma_start(&g_video.ds, g_video.cap_frame);
			}

			/* No, so we queue DMA commands */
			len = 960;
			eoi = dma_fill_pkt(&g_video.ds, ep_regs->bd[g_video.bdi].ptr + 4, &len);
			g_video.dma_pending = true;

			/* Prepare header */
			hdr[0] = 4;
			hdr[1] = (eoi ? 2 : 0) | g_video.uvc_frame_id | (1 << 7);
			hdr[2] = 0; /* fill */
			hdr[3] = 0; /* fill */

			usb_data_write(ep_regs->bd[g_video.bdi].ptr, hdr, 4);

			/* And the descriptor */
			ep_regs->bd[g_video.bdi].csr = USB_BD_LEN(len + 4);

			/* If that was the end, we need to clean up */
			if (eoi) {
				/* FIXME: In theory we should release only when DMA is done */
				framegrab_release(g_video.cap_frame);
				g_video.uvc_frame_id ^= 1;
				g_video.cap_frame = 0xff;
			}

			/* Have to wait now */
			break;
		}
		else
		{
			/* DMA is pending. If not over, nothing to do */
			if (!dma_done())
				break;

			/* DMA is over data has been filled. */
			g_video.dma_pending = false;

			/* Submit */
			ep_regs->bd[g_video.bdi].csr = USB_BD_LEN(964) | USB_BD_STATE_RDY_DATA;

			/* Next buffer */
			g_video.bdi ^= 1;
		}
	}
}


// ----------------------------------------------------------------------------------------------------



void
usb_dfu_rt_cb_reboot(void)
{
	/* Disable USB */
	usb_disconnect();

	/* Reboot */
	misc_regs->csr = MISC_BOOT;
}

void main()
{
	int cmd = -1;
	uint8_t frame;

	/* LED */
	led_init();
	led_color(48, 96, 5);
	led_breathe(true, 500, 500);
	led_state(true);
	led_color(48, 0, 0);

//	adv_init();
//	framegrab_init();

	/* Enable USB directly */
	//serial_no_init();
	usb_init(&app_stack_desc);
	usb_dfu_rt_init();
	console_init();
	usb_register_function_driver(&_video_drv);
	usb_connect();

	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			printf("Command> ");

		/* Poll for command */
		cmd = getchar_nowait();

		if (cmd >= 0) {
			if (cmd > 32 && cmd < 127)
				putchar(cmd);
			putchar('\r');
			putchar('\n');

			switch (cmd)
			{
			case 'c':
				for (int i=0; i<16; i++) {
					((volatile uint32_t *)(USB_DATA_BASE + 0x10000))[i] = 0xaaaaaaaa;
				}
				break;

			case 'a':
				adv_init();
				break;

			case 'A':
				printf("ADV ident: %02x\n", i2c_read_reg(0x40, 0x11));
				printf("ADV ident: %02x\n", i2c_read_reg(0x40, 0x12));
				break;

			case 'f':
				framegrab_init();
				break;

			case 's':
				framegrab_start();
				break;

			case 'S':
				framegrab_stop();
				break;

			case 'd':
				framegrab_debug();
				break;

			case 'g':
				frame = framegrab_get_latest();
				printf("Grabbed %d\n", frame);
				break;

			case 'r':
				framegrab_release(frame);
				break;

			case 'm':
				printf("%08x\n", misc_regs->csr);
				break;

			default:
				break;
			}
		}

		/* Poll */
		usb_poll();
		video_poll();
		console_poll();
		framegrab_poll();
	}
}
