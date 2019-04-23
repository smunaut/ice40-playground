/*
 * pdm.v
 *
 * vim: ts=4 sw=4
 *
 * Pulse Density Modulation core (1st order with dither)
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

module pdm #(
	parameter integer WIDTH = 8,
	parameter PHY = "GENERIC",
	parameter DITHER = "NO"
)(
	input  wire [WIDTH-1:0] in,
	output wire pdm,
	input  wire oe,
	input  wire clk,
	input  wire rst
);

	// Signals
	wire [WIDTH:0] in_i;
	reg  [WIDTH:0] acc;

	reg  dither;

	wire pdm_i;

	// Delta Sigma
	assign in_i = { acc[WIDTH], in };

	always @(posedge clk)
	begin
		if (rst)
			acc <= 0;
		else
			acc <= acc + in_i + dither;
	end

	assign pdm_i = acc[WIDTH];

	// Dither generator
	generate
		if (DITHER == "YES") begin
			wire [7:0] lfsr_out;

			pdm_lfsr #(
				.WIDTH(8),
				.POLY(8'h71)
			) lfsr_I (
				.out(lfsr_out),
				.clk(clk),
				.rst(rst)
			);

			always @(posedge clk)
				dither <= lfsr_out[0] ^ lfsr_out[3];

		end else begin
			always @(posedge clk)
				dither <= 1'b0;
		end
	endgenerate

	// PHY (Basically just IO register)
	generate
		if (PHY == "GENERIC") begin
			reg pdm_r;
			always @(posedge clk)
				pdm_r <= oe ? pdm_i : 1'bz;
			assign pdm = pdm_r;
		end else if (PHY == "ICE40") begin
			SB_IO #(
				.PIN_TYPE(6'b110100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) io_reg_I (
				.PACKAGE_PIN(pdm),
				.LATCH_INPUT_VALUE(1'b0),
				.CLOCK_ENABLE(1'b1),
				.INPUT_CLK(1'b0),
				.OUTPUT_CLK(clk),
				.OUTPUT_ENABLE(oe),
				.D_OUT_0(pdm_i),
				.D_OUT_1(1'b0),
				.D_IN_0(),
				.D_IN_1()
			);
		end
	endgenerate

endmodule // pdm


module pdm_lfsr #(
	parameter integer WIDTH = 8,
	parameter POLY = 8'h71
)(
	output reg  [WIDTH-1:0] out,
	input  wire clk,
	input  wire rst
 );

	// Signals
	wire fb;

	// Linear Feedback
	assign fb = ^(out & POLY);

	// Register
	always @(posedge clk)
		if (rst)
			out <= { {(WIDTH-1){1'b0}}, 1'b1 };
		else
			out <= { fb, out[WIDTH-1:1] };

endmodule // pdm_lfsr
