/*
 * usb_defs.vh
 *
 * vim: ts=4 sw=4 syntax=verilog
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

localparam SYM_SE0		= 2'b00;
localparam SYM_SE1		= 2'b11;
localparam SYM_J		= 2'b10;
localparam SYM_K		= 2'b01;


localparam PID_OUT		= 4'b0001;
localparam PID_IN		= 4'b1001;
localparam PID_SOF		= 4'b0101;
localparam PID_SETUP	= 4'b1101;

localparam PID_DATA0	= 4'b0011;
localparam PID_DATA1	= 4'b1011;

localparam PID_ACK		= 4'b0010;
localparam PID_NAK		= 4'b1010;
localparam PID_STALL	= 4'b1110;

localparam PID_INVAL	= 4'b0000;
