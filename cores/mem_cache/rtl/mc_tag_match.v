/*
 * mc_tag_match.v
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

module mc_tag_match #(
	parameter integer TAG_WIDTH = 12
)(
	input  wire [TAG_WIDTH-1:0] ref,
	input  wire [TAG_WIDTH-1:0] tag,
	input  wire valid,
	output wire match
);

	genvar i;

	// Constants
	// ---------

	localparam integer CW = (TAG_WIDTH + 1) / 2;
	localparam integer AW = ((CW + 1)  + 3) / 4;


	// Signals
	// -------

	wire [(2*CW)-1:0] cmp_in0;
	wire [(2*CW)-1:0] cmp_in1;
	wire [   CW -1:0] cmp_out;

	wire [(4*AW)-1:0] agg_in;
	wire [   AW -1:0] agg_out;


	// Comparator stage
	// ----------------

	// Map input to even number, pad with 0
	assign cmp_in0 = { {(TAG_WIDTH & 1){1'b0}}, ref };
	assign cmp_in1 = { {(TAG_WIDTH & 1){1'b0}}, tag };

	// Comparator, 2 bits at a time
	generate
		for (i=0; i<CW; i=i+1)
			SB_LUT4 #(
				.LUT_INIT(16'h9009)
			) lut_cmp_I (
				.I0(cmp_in0[2*i+0]),
				.I1(cmp_in1[2*i+0]),
				.I2(cmp_in0[2*i+1]),
				.I3(cmp_in1[2*i+1]),
				.O(cmp_out[i])
			);
	endgenerate


	// Aggregation stage
	// -----------------

	// Map aggregator input
	assign agg_in = { {((4*AW)-CW-1){1'b1}}, valid, cmp_out };

	// Aggregate 4 bits at a time
	generate
		for (i=0; i<AW; i=i+1)
			SB_LUT4 #(
				.LUT_INIT(16'h8000)
			) lut_cmp_I (
				.I0(agg_in[4*i+3]),
				.I1(agg_in[4*i+2]),
				.I2(agg_in[4*i+1]),
				.I3(agg_in[4*i+0]),
				.O(agg_out[i])
			);
	endgenerate

	// Final OR
		// This is not manually done because we want the optimizer to merge it
		// with other logic
	assign match = &agg_out;

endmodule
