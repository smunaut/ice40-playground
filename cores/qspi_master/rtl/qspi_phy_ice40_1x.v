/*
 * qspi_phy_ice40_1x.v
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

module qspi_phy_ice40_1x #(
	parameter integer N_CS = 2,				/* CS count */
	parameter integer WITH_CLK = 1,
	parameter integer NEG_IN = 0,			/* Sample on negative edge */

	// auto
	parameter integer CL = N_CS ? (N_CS-1) : 0
)(
	// Pads
	inout  wire [ 3:0] pad_io,
	output wire        pad_clk,
	output wire [CL:0] pad_cs_n,

	// PHY interface
	output wire [ 3:0] phy_io_i,
	input  wire [ 3:0] phy_io_o,
	input  wire [ 3:0] phy_io_oe,
	input  wire        phy_clk_o,
	input  wire [CL:0] phy_cs_o,

	// Clock
	input  wire clk
);

	// IOs
	wire [3:0] phy_io_i_pe;
	wire [3:0] phy_io_i_ne;

	SB_IO #(
		.PIN_TYPE(6'b1101_00),
		.PULLUP(1'b1),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_io_I[3:0] (
		.PACKAGE_PIN(pad_io),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(clk),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(phy_io_oe),
		.D_OUT_0(phy_io_o),
		.D_IN_0(phy_io_i_pe),
		.D_IN_1(phy_io_i_ne)
	);

	assign phy_io_i = NEG_IN ? phy_io_i_ne : phy_io_i_pe;

	// Clock
	generate
		if (WITH_CLK) begin
			reg clk_active;

			always @(posedge clk)
				clk_active <= phy_clk_o;

			SB_IO #(
				.PIN_TYPE(6'b110011),
				.PULLUP(1'b1),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_clk_I (
				.PACKAGE_PIN(pad_clk),
				.CLOCK_ENABLE(1'b1),
				.OUTPUT_CLK(clk),
				.OUTPUT_ENABLE(1'b1),
				.D_OUT_0(1'b0),
				.D_OUT_1(clk_active)
			);
		end
	endgenerate

	// Chip select
	generate
		if (N_CS)
			SB_IO #(
				.PIN_TYPE(6'b0101_11),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) iob_cs_I[N_CS-1:0] (
				.PACKAGE_PIN(pad_cs_n),
				.OUTPUT_CLK(clk),
				.D_OUT_0(phy_cs_o)
			);
	endgenerate

endmodule
