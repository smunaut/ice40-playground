/*
 * usb_crc.v
 *
 * vim: ts=4 sw=4
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

`default_nettype none

module usb_crc #(
	parameter integer WIDTH = 5,
	parameter POLY  = 5'b00011,
	parameter MATCH = 5'b00000
)(
	// Input
	input  wire in_bit,
	input  wire in_first,
	input  wire in_valid,

	// Output (updated 1 cycle after input)
	output wire [WIDTH-1:0] crc,
	output wire crc_match,

	// Common
	input  wire clk,
	input  wire rst
);

	reg  [WIDTH-1:0] state;
	wire [WIDTH-1:0] state_fb_mux;
	wire [WIDTH-1:0] state_upd_mux;
	wire [WIDTH-1:0] state_nxt;

	assign state_fb_mux  = state & { WIDTH{~in_first} };
	assign state_upd_mux = (state_fb_mux[WIDTH-1] == in_bit) ? POLY : 0;
	assign state_nxt = { state_fb_mux[WIDTH-2:0], 1'b1 } ^ state_upd_mux;

	always @(posedge clk)
		if (in_valid)
			state <= state_nxt;

	assign crc_match = (state == ~MATCH);

	genvar i;
	generate
		for (i=0; i<WIDTH; i=i+1)
			assign crc[i] = state[WIDTH-1-i];
	endgenerate

endmodule // usb_crc
