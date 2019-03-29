/*
 * spi_reg.v
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

module spi_reg #(
	parameter ADDR = 8'h00,
	parameter integer BYTES = 1
)(
	// Bus interface
	input wire  [7:0] addr,
	input wire  [7:0] data,
	input wire  first,
	input wire  strobe,

	// Reset
	input wire  [(8*BYTES)-1:0] rst_val,

	// Output
	output wire [(8*BYTES)-1:0] out_val,
	output wire out_stb,

	// Clock / Reset
	input wire  clk,
	input wire  rst
);

	localparam integer WIDTH = 8*BYTES;

	// Signals
	wire [WIDTH-1:0] nxt_val;
	reg  [WIDTH-1:0] cur_val;
	wire [BYTES-1:0] hit_delay;
	wire hit;
	reg  out_stb_i;

	// History
	generate
		if (BYTES > 1) begin
			reg [WIDTH-9:0] history;
			reg [BYTES-2:0] bc;

			always @(posedge clk or posedge rst)
				if (rst) begin
					history <= 0;
					bc <= 0;
				end else if (strobe) begin
					history <= nxt_val[WIDTH-9: 0];
					bc <= hit_delay[BYTES-2:0];
				end

			assign nxt_val = { history, data };
			assign hit_delay = { bc, first };
		end else begin
			assign nxt_val = data;
			assign hit_delay = { first };
		end
	endgenerate

	// Address match
	assign hit = hit_delay[BYTES-1] & strobe & (addr == ADDR);

	// Value register
	always @(posedge clk or posedge rst)
		if (rst)
			cur_val <= rst_val;
		else if (hit)
			cur_val <= nxt_val;

	always @(posedge clk)
		out_stb_i <= hit;

	assign out_val = cur_val;
	assign out_stb = out_stb_i;

endmodule // spi_reg
