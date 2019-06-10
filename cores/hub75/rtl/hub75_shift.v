/*
 * hub75_shift.v
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

module hub75_shift #(
	parameter integer N_BANKS  = 2,
	parameter integer N_COLS   = 64,
	parameter integer N_CHANS  = 3,
	parameter integer N_PLANES = 8,

	// Auto-set
	parameter integer SDW         = N_BANKS * N_CHANS,
	parameter integer LOG_N_COLS  = $clog2(N_COLS)
)(
	// PHY
	output wire [SDW-1:0] phy_data,
	output wire phy_clk,

	// RAM interface
	input  wire [(N_BANKS*N_CHANS*N_PLANES)-1:0] ram_data,
	output wire [LOG_N_COLS-1:0] ram_col_addr,
	output wire ram_rden,

	// Control
	input  wire [N_PLANES-1:0] ctrl_plane,
	input  wire ctrl_go,
	output wire ctrl_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	genvar i;

	// Signals
	// -------

	reg active_0;
	reg active_1;
	reg active_2;
	reg [LOG_N_COLS:0] cnt_0;
	reg cnt_last_0;

	wire [SDW-1:0] ram_data_bit;
	reg  [SDW-1:0] data_2;


	// Control logic
	// -------------

	// Active / Valid flag
	always @(posedge clk or posedge rst)
		if (rst) begin
			active_0 <= 1'b0;
			active_1 <= 1'b0;
			active_2 <= 1'b0;
		end else begin
			active_0 <= (active_0 & ~cnt_last_0) | ctrl_go;
			active_1 <= active_0;
			active_2 <= active_1;
		end

	// Counter
	always @(posedge clk)
		if (ctrl_go) begin
			cnt_0 <= 0;
			cnt_last_0 <= 1'b0;
		end else if (active_0) begin
			cnt_0 <= cnt_0 + 1;
			cnt_last_0 <= (cnt_0 == (N_COLS - 2));
		end

	// Ready ?
	assign ctrl_rdy = ~active_0;


	// Data path
	// ---------

	// RAM access
	assign ram_rden = active_0;
	assign ram_col_addr = cnt_0[LOG_N_COLS-1:0];

	// Data plane mux
	generate
		for (i=0; i<SDW; i=i+1)
			assign ram_data_bit[i] = |(ram_data[((i+1)*N_PLANES)-1:i*N_PLANES] & ctrl_plane);
	endgenerate

	// Mux register
	always @(posedge clk)
		data_2 <= ram_data_bit;


	// PHY
	// ---

	assign phy_data = data_2;
	assign phy_clk = active_2;

endmodule // hub75_shift
