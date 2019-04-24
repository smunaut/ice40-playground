/*
 * e1_crc4.v
 *
 * vim: ts=4 sw=4
 *
 * E1 CRC4 computation
 *
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
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

module e1_crc4 #(
	parameter INIT = 4'h0,
	parameter POLY = 4'h3
)(
	// Input
	input  wire in_bit,
	input  wire in_first,
	input  wire in_valid,

	// Output (updated 1 cycle after input)
	output wire [3:0] out_crc4,

	// Common
	input  wire clk,
	input  wire rst
);

	reg  [3:0] state;
	wire [3:0] state_fb_mux;
	wire [3:0] state_upd_mux;

	assign state_fb_mux  = in_first ? INIT : state;
	assign state_upd_mux = (state_fb_mux[3] != in_bit) ? POLY : 0;

	always @(posedge clk)
		if (in_valid)
			state <= { state_fb_mux[2:0], 1'b0 } ^ state_upd_mux;

	assign out_crc4 = state;

endmodule // e1_crc4
