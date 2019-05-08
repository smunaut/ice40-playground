/*
 * usb_dfu_proto.h
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

#define USB_REQ_DFU_DETACH	(0)
#define USB_REQ_DFU_DNLOAD	(1)
#define USB_REQ_DFU_UPLOAD	(2)
#define USB_REQ_DFU_GETSTATUS	(3)
#define USB_REQ_DFU_CLRSTATUS	(4)
#define USB_REQ_DFU_GETSTATE	(5)
#define USB_REQ_DFU_ABORT	(6)

#define USB_RT_DFU_DETACH	((0 << 8) | 0x21)
#define USB_RT_DFU_DNLOAD	((1 << 8) | 0x21)
#define USB_RT_DFU_UPLOAD	((2 << 8) | 0xa1)
#define USB_RT_DFU_GETSTATUS	((3 << 8) | 0xa1)
#define USB_RT_DFU_CLRSTATUS	((4 << 8) | 0x21)
#define USB_RT_DFU_GETSTATE	((5 << 8) | 0xa1)
#define USB_RT_DFU_ABORT	((6 << 8) | 0x21)


enum dfu_state {
	appIDLE = 0,
	appDETACH,
	dfuIDLE,
	dfuDNLOAD_SYNC,
	dfuDNBUSY,
	dfuDNLOAD_IDLE,
	dfuMANIFEST_SYNC,
	dfuMANIFEST,
	dfuMANIFEST_WAIT_RESET,
	dfuUPLOAD_IDLE,
	dfuERROR,
	_DFU_MAX_STATE
};

enum dfu_status {
	OK = 0,
	errTARGET,
	errFILE,
	errWRITE,
	errERASE,
	errCHECK_ERASED,
	errPROG,
	errVERIFY,
	errADDRESS,
	errNOTDONE,
	errFIRMWARE,
	errVENDOR,
	errUSBR,
	errPOR,
	errUNKNOWN,
	errSTALLEDPKT,
	_DFU_MAX_STATUS
};
