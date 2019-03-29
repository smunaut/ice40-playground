/*
 * hub75_colormap.v
 *
 * vim: ts=4 sw=4
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

module hub75_colormap #(
	parameter integer N_CHANS  = 3,
	parameter integer N_PLANES = 8,
	parameter integer BITDEPTH = 24,
	parameter integer USER_WIDTH = 1
)(
	// Input pixel
	input  wire [BITDEPTH-1:0] in_data,
	input  wire [USER_WIDTH-1:0] in_user,
	input  wire in_valid,
	output reg  in_ready,

	// Output pixel
	output wire [(N_CHANS*N_PLANES)-1:0] out_data,
	output wire [USER_WIDTH-1:0] out_user,
	output reg  out_valid,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Signals
	// -------

	wire [7:0] c0;
	wire [7:0] c1;
	wire [7:0] c2;
	reg  [7:0] cmux;

	reg  [1:0] cnt;

	wire [N_PLANES-1:0] do;
	reg  [N_PLANES-1:0] do_r[0:1];


	// Control
	// -------

		// Little note: Technically we need only 3 cycles to lookup the
		// 3 colors. But to avoid having some registers to pipeline the 'user'
		// data, we take 4 cycles. It doesn't matter anyway since we'll have
		// to wait to pipe the data to the LCD anyway, so 'wasting' a cycle
		// here has no consequence.

	// Cycle counter
	always @(posedge clk)
		cnt <= in_valid ? (cnt + 1) : 2'b00;


	// Input stage
	// -----------

	// Map color channels
	generate
		if (BITDEPTH == 24) begin
			assign c2 = in_data[23:16];
			assign c1 = in_data[15: 8];
			assign c0 = in_data[ 7: 0];
		end else if (BITDEPTH == 16) begin
			assign c2 = { in_data[15:11], in_data[15:13] };
			assign c1 = { in_data[10: 5], in_data[10: 9] };
			assign c0 = { in_data[ 4: 0], in_data[ 4: 2] };
		end else if (BITDEPTH == 8) begin
			assign c2 = { {2{in_data[7:5]}}, in_data[7:6] };
			assign c1 = { {2{in_data[4:2]}}, in_data[4:3] };
			assign c0 = { {4{in_data[1:0]}} };
		end
	endgenerate

	// Mux
	always @(*)
		case (cnt)
			2'b00: cmux = c0;
			2'b01: cmux = c1;
			2'b10: cmux = c2;
			default: cmux = 8'hx;
		endcase

	// When are we ready
	always @(posedge clk)
		in_ready <= (cnt == 2'b10);


	// Gamma LUT
	// ---------

	hub75_gamma #(
		.IW(8),
		.OW(N_PLANES)
	) gamma_lut_I (
		.in(cmux),
		.out(do),
		.enable(1'b1),
		.clk(clk)
	);


	// Output stage
	// ------------

	// Data
	always @(posedge clk)
	begin
		do_r[1] <= do;
		do_r[0] <= do_r[1];
	end

	assign out_data = { do, do_r[1], do_r[0] };

	// User infos
	assign out_user = in_user;

	// Valid signal
	always @(posedge clk)
		out_valid <= (cnt == 2'b10);

endmodule // hub75_colormap
