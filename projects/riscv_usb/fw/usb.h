/*
 * usb.h
 *
 * Copyright (C) 2019 Sylvain Munaut
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "usb_proto.h"


/* Types */
/* ----- */

struct usb_xfer;

struct usb_stack_descriptors {
	const struct usb_dev_desc *dev;
	const struct usb_conf_desc * const *conf;
	int n_conf;
	const struct usb_str_desc * const *str;
	int n_str;
};

enum usb_dev_state {
	USB_DS_OFF		= 0,	/* Core is not initialize */
	USB_DS_DISCONNECTED	= 1,	/* Core is not connected  */
	USB_DS_CONNECTED	= 2,	/* Core is connected awaiting reset */
	USB_DS_DEFAULT		= 3,
	USB_DS_ADDRESS		= 4,
	USB_DS_CONFIGURED	= 5,
	USB_DS_SUSPENDED	= 0x80,	/* Bit marking suspend */
	USB_DS_RESUME		= 0x81,	/* Special value for set_state */
};


enum usb_fnd_resp {
        USB_FND_CONTINUE = 0,	/* Not handled, continue to next */
        USB_FND_SUCCESS,	/* Handled: Success */
        USB_FND_ERROR,		/* Handled: Error   */
};

typedef void (*usb_fnd_sof_cb)(void);
typedef void (*usb_fnd_bus_reset_cb)(void);
typedef void (*usb_fnd_state_chg_cb)(enum usb_dev_state state);
typedef enum usb_fnd_resp (*usb_fnd_ctrl_req_cb)(struct usb_ctrl_req *req, struct usb_xfer *xfer);
typedef enum usb_fnd_resp (*usb_fnd_set_conf_cb)(const struct usb_conf_desc *desc);
typedef enum usb_fnd_resp (*usb_fnd_set_intf_cb)(const struct usb_intf_desc *base, const struct usb_intf_desc *sel);
typedef enum usb_fnd_resp (*usb_fnd_get_intf_cb)(const struct usb_intf_desc *base, uint8_t *alt);

struct usb_fn_drv {
	struct usb_fn_drv *next;
        usb_fnd_sof_cb		sof;
        usb_fnd_bus_reset_cb	bus_reset;
        usb_fnd_state_chg_cb	state_chg;
        usb_fnd_ctrl_req_cb	ctrl_req;
        usb_fnd_set_conf_cb	set_conf;
        usb_fnd_set_intf_cb	set_intf;
        usb_fnd_get_intf_cb	get_intf;
};


typedef bool (*usb_xfer_cb)(struct usb_xfer *xfer);

struct usb_xfer {
	/* Data buffer */
	uint8_t *data;
	int ofs;
	int len;

	/* Call backs */
	usb_xfer_cb cb_data;	/* Data call back */
	usb_xfer_cb cb_done;	/* Completion call back */
	void *cb_ctx;
};


/* API */
void usb_init(const struct usb_stack_descriptors *stack_desc);
void usb_poll(void);

void usb_set_state(enum usb_dev_state new_state);
enum usb_dev_state usb_get_state(void);

uint32_t usb_get_tick(void);

void usb_connect(void);
void usb_disconnect(void);

void usb_set_address(uint8_t addr);

void usb_register_function_driver(struct usb_fn_drv *drv);
void usb_unregister_function_driver(struct usb_fn_drv *drv);


	/* EP */
bool usb_ep_is_configured(uint8_t ep);
bool usb_ep_is_halted(uint8_t ep);
bool usb_ep_halt(uint8_t ep);
bool usb_ep_resume(uint8_t ep);

	/* Descriptors */
const struct usb_conf_desc *usb_desc_find_conf(uint8_t cfg_value);
const void *usb_desc_find(const void *sod, const void *eod, uint8_t dt);
const void *usb_desc_next(const void *sod);


/* Debug */
void usb_debug_print_ep(int ep, int dir);
void usb_debug_print_data(int ofs, int len);
void usb_debug_print(void);
