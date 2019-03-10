/*
 * fifo_sync_shift.v
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

module fifo_sync_shift #(
	parameter integer DEPTH =  4,
	parameter integer WIDTH = 16
)(
	input  wire [WIDTH-1:0] wr_data,
	input  wire wr_ena,
	output wire wr_full,

	output wire [WIDTH-1:0] rd_data,
	input  wire rd_ena,
	output wire rd_empty,

	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	wire  [DEPTH+1:0] ce;
	wire  [DEPTH+1:0] valid;
	wire  [WIDTH-1:0] data [DEPTH+1:0];


	// Stages
	// ------

	// Generate loop
	genvar i;

	generate
		for (i=1; i<=DEPTH; i=i+1)
		begin : stage
			// Local signals
			reg [WIDTH-1:0] l_data;
			reg l_valid;

			// Data register
			always @(posedge clk)
				if (ce[i])
					l_data <= valid[i+1] ? data[i+1] : wr_data;

			// Valid flag
			always @(posedge clk or posedge rst)
				if (rst)
					l_valid <= 1'b0;
				else if (ce[i])
					l_valid <= ~rd_ena | valid[i+1] | (wr_ena & valid[i]);

			// CE for this stage
			assign ce[i] = rd_ena | (wr_ena & ~valid[i] & valid[i-1]);

			// Map
			assign data[i]  = l_data;
			assign valid[i] = l_valid;
		end
	endgenerate

	// Boundary conditions
	assign data[DEPTH+1] = wr_data;
	assign data[0] = { WIDTH{1'bx} };

	assign valid[DEPTH+1] = 1'b0;
	assign valid[0] = 1'b1;

	assign ce[DEPTH+1] = 1'bx;
	assign ce[0] = 1'bx;


	// User IF
	// -------

	assign wr_full = valid[DEPTH];

	assign rd_empty = ~valid[1];
	assign rd_data  = data[1];

endmodule // fifo_sync_shift
