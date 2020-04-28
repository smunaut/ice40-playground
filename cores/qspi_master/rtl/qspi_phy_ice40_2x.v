/*
 * qspi_phy_ice40_2x.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`default_nettype none

module qspi_phy_ice40_2x #(
	parameter integer N_CS = 2,					/* CS count */
	parameter integer WITH_CLK = 1,

	// auto
	parameter integer CL = N_CS ? (N_CS-1) : 0
)(
	// Pads
	inout  wire [ 3:0] pad_io,
	output wire        pad_clk,
	output wire [CL:0] pad_cs_n,

	// PHY interface
	output reg  [ 7:0] phy_io_i,
	input  wire [ 7:0] phy_io_o,
	input  wire [ 3:0] phy_io_oe,
	input  wire [ 1:0] phy_clk_o,
	input  wire [CL:0] phy_cs_o,

	// Clock
	input  wire clk_1x,
	input  wire clk_2x
);

	// IOs
	reg  [3:0] phy_io_o_fe;
	wire [3:0] phy_io_o_re;

	wire [3:0] phy_io_i_pe;
	wire [3:0] phy_io_i_ne;
	reg  [3:0] phy_io_i_ne_r;

		// Output edge dispatch
	assign phy_io_o_re = { phy_io_o[7], phy_io_o[5], phy_io_o[3], phy_io_o[1] };

	always @(posedge clk_1x)
		phy_io_o_fe <= { phy_io_o[6], phy_io_o[4], phy_io_o[2], phy_io_o[0] };

		// IOB
	SB_IO #(
		.PIN_TYPE(6'b1100_00),
		.PULLUP(1'b1),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_io_I[3:0] (
		.PACKAGE_PIN(pad_io),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(clk_1x),
		.OUTPUT_CLK(clk_1x),
		.OUTPUT_ENABLE(phy_io_oe),
		.D_OUT_0(phy_io_o_re),
		.D_OUT_1(phy_io_o_fe),
		.D_IN_0(phy_io_i_pe),
		.D_IN_1(phy_io_i_ne)
	);

		// Input edge resync
	always @(posedge clk_1x)
		phy_io_i_ne_r <= phy_io_i_ne;

	always @(posedge clk_1x)
		phy_io_i <= {
			phy_io_i_ne_r[3], phy_io_i_pe[3],
			phy_io_i_ne_r[2], phy_io_i_pe[2],
			phy_io_i_ne_r[1], phy_io_i_pe[1],
			phy_io_i_ne_r[0], phy_io_i_pe[0]
		};

	// Clock
	generate
		if (WITH_CLK) begin
			reg [1:0] clk_active;
			reg       clk_toggle;
			reg       clk_toggle_r;
			wire      clk_out;

			// Data is sent by 8 bits always, so we only use
			// one of the two signals ...
			always @(posedge clk_1x)
			begin
				clk_active <= phy_clk_o;
				clk_toggle <= ~clk_toggle;
			end

			always @(posedge clk_2x)
				clk_toggle_r <= clk_toggle;

			assign clk_out = (clk_toggle == clk_toggle_r) ? clk_active[0] : clk_active[1];

			SB_IO #(
				.PIN_TYPE(6'b110011),
				.PULLUP(1'b1),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_clk_I (
				.PACKAGE_PIN(pad_clk),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk_2x),
				.OUTPUT_ENABLE(1'b1),
				.D_OUT_0(clk_out),
				.D_OUT_1(1'b0)
			);
		end
	endgenerate

	// Chip select
	generate
		// FIXME register CS config ?
		// Because the default CS (for the config flash) shares an IO site
		// with CLK, we can't use clk_1x here. So instead we don't register
		// the signal at all and count of the fact it's held low a bit longer
		// than needed by the controller ...
		if (N_CS)
			SB_IO #(
				.PIN_TYPE(6'b101011),
				.PULLUP(1'b1),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_cs_I[N_CS-1:0] (
				.PACKAGE_PIN(pad_cs_n),
				.OUTPUT_ENABLE(~phy_cs_o),
				.D_OUT_0(1'b0)
			);
	endgenerate

endmodule
