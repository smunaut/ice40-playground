/*
 * ice40_oserdes.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
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

module ice40_oserdes #(
	parameter MODE = "DATA",	// "DATA" / "CLK90_2X" / "CLK90_4X"
	parameter integer SERDES_GRP = 0
)(
	input  wire [3:0] d,
	output wire [1:0] q,
	input  wire       sync,
	input  wire       clk_1x,
	input  wire       clk_4x
);

	genvar i;


	// Signals
	// -------

	wire [3:0] cap_in;
	wire [3:0] cap_out;

	wire [3:0] shift_in;
	wire [3:0] shift_out;

	wire       delay_out;


	// Capture
	// -------

	assign cap_in = (MODE == "CLK90_2X") ? { d[1], 1'b0, d[0], 1'b0 } : d;

	generate
		for (i=0; i<4; i=i+1)
			ice40_serdes_dff #(
				.SERDES_GRP( (SERDES_GRP << 8) | 'h00 | i )
			) dff_cap_I (
				.d(cap_in[i]),
				.q(cap_out[i]),
				.c(clk_1x)
			);
	endgenerate


	// Shifter
	// -------

	assign shift_in = sync ? cap_out : { shift_out[2:0], 1'b0 };

	generate
		for (i=0; i<4; i=i+1)
			ice40_serdes_dff #(
				.SERDES_GRP( (SERDES_GRP << 8) | 'h10 | i )
			) dff_shift_I (
				.d(shift_in[i]),
				.q(shift_out[i]),
				.c(clk_4x)
			);
	endgenerate


	// Output
	// ------

	generate
		if ((MODE == "CLK90_2X") || (MODE == "CLK90_4X")) begin
			// Delay FF for falling edge
			ice40_serdes_dff #(
				.SERDES_GRP( (SERDES_GRP << 8) | 'h20 )
			) dff_out_I (
				.d(shift_out[3]),
				.q(delay_out),
				.c(clk_4x)
			);

			// Output depends on clock mode
			assign q[0] = (MODE == "CLK90_2X") ? delay_out : 1'b0;
			assign q[1] = delay_out;
		end else begin
			// Simple data map, fall edge output un-used
			assign q[0] = shift_out[3];
			assign q[1] = 1'b0;
		end
	endgenerate

endmodule
