/*
 * hub75_blanking.v
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

module hub75_blanking #(
	parameter integer N_PLANES = 8
)(
	// PHY
	output wire phy_blank,

	// Control
	input  wire [N_PLANES-1:0] ctrl_plane,
	input  wire ctrl_go,
	output wire ctrl_rdy,

	// Config
	input  wire [7:0] cfg_bcm_bit_len,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	wire active;
	wire plane_cnt_ce;
	reg [N_PLANES:0] plane_cnt;
	reg [7:0] bit_cnt;
	wire bit_cnt_trig;


	// Control
	// -------

	// Active
	assign active = plane_cnt[N_PLANES];

	// Plane length counter
	always @(posedge clk or posedge rst)
		if (rst)
			plane_cnt <= 0;
		else if (plane_cnt_ce)
			plane_cnt <= (ctrl_go ? { 1'b1, ctrl_plane } : plane_cnt) - 1;

	assign plane_cnt_ce = (bit_cnt_trig & active) | ctrl_go;

	// Base len bit counter
	always @(posedge clk)
		if (~active | bit_cnt_trig)
			bit_cnt <= cfg_bcm_bit_len;
		else
			bit_cnt <= bit_cnt - 1;

	assign bit_cnt_trig = bit_cnt[7];

	// Ready
	assign ctrl_rdy = ~active;


	// PHY
	// ---

	assign phy_blank = ~active;

endmodule // hub75_blanking
