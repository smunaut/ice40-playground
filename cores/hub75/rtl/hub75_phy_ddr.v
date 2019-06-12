/*
 * hub75_phy_ddr.v
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

module hub75_phy_ddr #(
	parameter integer N_BANKS  = 2,
	parameter integer N_ROWS   = 32,
	parameter integer N_CHANS  = 3,
	parameter integer PHY_N    = 1,		// # of PHY in //
	parameter integer PHY_AIR  = 0,		// PHY Address Inc/Reset
	parameter integer PHY_DDR  = 1,		// PHY DDR Phase

	// Auto-set
	parameter integer SDW         = N_BANKS * N_CHANS,
	parameter integer ESDW        = SDW / 2,
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS)
)(
	// Hub75 interface pads
	output wire [PHY_N-1:0] hub75_addr_inc,
	output wire [PHY_N-1:0] hub75_addr_rst,
	output wire [(PHY_N*LOG_N_ROWS)-1:0] hub75_addr,
	output wire [ESDW-1 :0] hub75_data,
	output wire [PHY_N-1:0] hub75_clk,
	output wire [PHY_N-1:0] hub75_le,
	output wire [PHY_N-1:0] hub75_blank,

	// PHY interface signals
	input wire phy_addr_inc,
	input wire phy_addr_rst,
	input wire [LOG_N_ROWS-1:0] phy_addr,
	input wire [SDW-1:0] phy_data,
	input wire phy_clk,
	input wire phy_le,
	input wire phy_blank,

	// Clock / Reset
	input  wire clk,
	input  wire clk_2x,
	input  wire rst
);
	// Signals
	// -------

	// Sync
	reg sync_toggle;
	reg sync_done;
	reg [1:0] sync_cap;
	reg [1:0] sync;			// [0] in phase with clk, [1] is clk_n

	// Cross-clock
	reg  cc_addr_inc;
	reg  cc_addr_rst;
	reg  [LOG_N_ROWS-1:0] cc_addr;
	reg  [(N_BANKS*N_CHANS)-1:0] cc_data;
	reg  cc_clk;
	reg  cc_le;
	reg  cc_blank;

	// Data Mux
	wire [ESDW-1:0] mux_data;

	// External Shift clock
	reg clk_sig;


	// Capture signals in 2x domain
	// ----------------------------

	// Sync signals
	always @(posedge clk or posedge rst)
		if (rst)
			sync_toggle <= 1'b0;
		else
			sync_toggle <= ~sync_toggle;

	always @(posedge clk_2x or posedge rst)
	begin
		if (rst) begin
			sync_done <= 1'b0;
			sync_cap  <= 2'b00;
			sync      <= 2'b00;
		end else begin
			sync_done <= sync_done | (sync_cap[0] ^ sync_cap[1]);
			sync_cap  <= { sync_cap[0], sync_toggle };
			sync[0]   <= sync_done ? ~sync[0] : (sync_cap[0] ^ sync_cap[1]);
			sync[1]   <= sync[0];
		end
	end

	// Capture
	always @(posedge clk_2x or posedge rst)
	begin
		if (rst) begin
			cc_addr_inc <= 1'b0;
			cc_addr_rst <= 1'b0;
			cc_addr     <= 0;
			cc_data     <= 0;
			cc_clk      <= 1'b0;
			cc_le       <= 1'b0;
			cc_blank    <= 1'b0;
		end else if (sync[0]) begin
			cc_addr_inc <= phy_addr_inc ^ PHY_AIR[1];
			cc_addr_rst <= phy_addr_rst ^ PHY_AIR[2];
			cc_addr     <= phy_addr;
			cc_data     <= phy_data;
			cc_clk      <= phy_clk;
			cc_le       <= phy_le;
			cc_blank    <= phy_blank;
		end
	end


	// IOB
	// ---

	// Address
	genvar i;
	generate
		if (PHY_AIR == 0) begin
			for (i=0; i<PHY_N; i=i+1)
				SB_IO #(
					.PIN_TYPE(6'b010100),
					.PULLUP(1'b0),
					.NEG_TRIGGER(1'b0),
					.IO_STANDARD("SB_LVCMOS")
				) iob_addr_I[LOG_N_ROWS-1:0] (
					.PACKAGE_PIN(hub75_addr[i*LOG_N_ROWS+:LOG_N_ROWS]),
					.CLOCK_ENABLE(1'b1),
					.OUTPUT_CLK(clk_2x),
					.D_OUT_0(cc_addr)
				);
		end else begin
			SB_IO #(
				.PIN_TYPE(6'b010100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_addr_inc_I[PHY_N-1:0] (
				.PACKAGE_PIN(hub75_addr_inc),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk_2x),
				.D_OUT_0(cc_addr_inc)
			);

			SB_IO #(
				.PIN_TYPE(6'b010100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_addr_rst_I[PHY_N-1:0] (
				.PACKAGE_PIN(hub75_addr_rst),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk_2x),
				.D_OUT_0(cc_addr_rst)
			);
		end
	endgenerate

	// Data lines
	for (i=0; i<ESDW; i=i+N_CHANS)
		assign mux_data[i+:N_CHANS] = cc_clk ? (sync[0] ? cc_data[2*i+:N_CHANS] : cc_data[2*i+N_CHANS+:N_CHANS]) : 0;

	SB_IO #(
		.PIN_TYPE(6'b010100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_data_I[ESDW-1:0] (
		.PACKAGE_PIN(hub75_data),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk_2x),
		.D_OUT_0(mux_data)
	);

	// Clock DDR register
	always @(posedge clk_2x)
		clk_sig <= cc_clk ? sync[0] : 1'b1;

	SB_IO #(
		.PIN_TYPE(6'b010000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_I[PHY_N-1:0] (
		.PACKAGE_PIN(hub75_clk),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk_2x),
		.D_OUT_0(clk_sig | (PHY_DDR == 2)),
		.D_OUT_1(clk_sig)
	);

	// Latch
	SB_IO #(
		.PIN_TYPE(6'b010100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_le_I[PHY_N-1:0] (
		.PACKAGE_PIN(hub75_le),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk_2x),
		.D_OUT_0(cc_le)
	);

	// Blanking
	SB_IO #(
		.PIN_TYPE(6'b010100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_blank_I[PHY_N-1:0] (
		.PACKAGE_PIN(hub75_blank),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk_2x),
		.D_OUT_0(cc_blank)
	);

endmodule
