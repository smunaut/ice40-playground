/*
 * hub75_phy.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * Copyright (C) 2019  Piotr Esden-Tempski <piotr@esden.net>
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

module hub75_phy #(
	parameter integer N_BANKS  = 2,
	parameter integer N_ROWS   = 32,
	parameter integer N_CHANS  = 3,
	parameter integer PHY_AIR  = 0,		// PHY Address Inc/Reset

	// Auto-set
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS)
)(
	// Hub75 interface pads
	output wire hub75_addr_inc,
	output wire hub75_addr_rst,
	output wire [LOG_N_ROWS-1:0] hub75_addr,
	output wire [(N_BANKS*N_CHANS)-1:0] hub75_data,
	output wire hub75_clk,
	output wire hub75_le,
	output wire hub75_blank,

	// PHY interface signals
	input wire phy_addr_inc,
	input wire phy_addr_rst,
	input wire [LOG_N_ROWS-1:0] phy_addr,
	input wire [(N_BANKS*N_CHANS)-1:0] phy_data,
	input wire phy_clk,
	input wire phy_le,
	input wire phy_blank,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	genvar i;

	// Signals
	reg phy_clk_f;

	// Address
	generate
		if (PHY_AIR == 0) begin
			SB_IO #(
				.PIN_TYPE(6'b010100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_addr_I[LOG_N_ROWS-1:0] (
				.PACKAGE_PIN(hub75_addr),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk),
				.D_OUT_0(phy_addr)
			);
		end else begin
			SB_IO #(
				.PIN_TYPE(6'b010100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_addr_inc_I (
				.PACKAGE_PIN(hub75_addr_inc),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk),
				.D_OUT_0(phy_addr_inc ^ PHY_AIR[1])
			);

			SB_IO #(
				.PIN_TYPE(6'b010100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_addr_rst_I (
				.PACKAGE_PIN(hub75_addr_rst),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk),
				.D_OUT_0(phy_addr_rst ^ PHY_AIR[2])
			);
		end
	endgenerate

	// Data lines
	generate
		for (i=0; i<(N_BANKS*N_CHANS); i=i+1)
			SB_IO #(
				.PIN_TYPE(6'b010100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_data_I (
				.PACKAGE_PIN(hub75_data[i]),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk),
				.D_OUT_0(phy_data[i])
			);
	endgenerate

	// Falling edge clock, so we need one more delay so it's not too early !
	always @(posedge clk or posedge rst)
		if (rst) begin
			phy_clk_f <= 1'b0;
		end else begin
			phy_clk_f <= phy_clk;
		end

	// Clock DDR register
	SB_IO #(
		.PIN_TYPE(6'b010000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_I (
		.PACKAGE_PIN(hub75_clk),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk),
		.D_OUT_0(1'b0),
		.D_OUT_1(phy_clk_f)
	);

	// Latch
	SB_IO #(
		.PIN_TYPE(6'b010100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_le_I (
		.PACKAGE_PIN(hub75_le),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk),
		.D_OUT_0(phy_le)
	);

	// Blanking
	SB_IO #(
		.PIN_TYPE(6'b010100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_blank_I (
		.PACKAGE_PIN(hub75_blank),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk),
		.D_OUT_0(phy_blank)
	);

endmodule
