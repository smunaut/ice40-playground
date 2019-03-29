/*
 * glitch_filter.v
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

module glitch_filter #(
	parameter integer L = 2
)(
	input wire  pin_iob_reg,
	input wire  cond,

	output wire val,
	output reg  rise,
	output reg  fall,

	input  wire clk,
	input  wire rst
);
	// Signals
	wire [L-1:0] all_zero;
	wire [L-1:0] all_one;

	reg [1:0] sync;
	reg state;
	reg [L-1:0] cnt;

	// Constants
	assign all_zero = { L{1'b0} };
	assign all_one  = { L{1'b1} };

	// Synchronizer
	always @(posedge clk)
		sync <= { sync[0], pin_iob_reg };

	// Filter
	always @(posedge clk)
		if (rst)
			cnt <= all_one;
		else begin
			if (sync[1] & (cnt != all_one))
				cnt <= cnt + 1;
			else if (~sync[1] & (cnt != all_zero))
				cnt <= cnt - 1;
			else
				cnt <= cnt;
		end

	// State
	always @(posedge clk)
		if (rst)
			state <= 1'b1;
		else begin
			if (state & cnt == all_zero)
				state <= 1'b0;
			else if (~state & cnt == all_one)
				state <= 1'b1;
			else
				state <= state;
		end

	assign val = state;

	// Rise / Fall detection
	always @(posedge clk)
	begin
		if (~cond) begin
			rise <= 1'b0;
			fall <= 1'b0;
		end else begin
			rise <= ~state & (cnt == all_one);
			fall <=  state & (cnt == all_zero);
		end
	end

endmodule // glitch_filter
