/*
 * pwm.v
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

module pwm #(
	parameter integer WIDTH = 10
)(
	// PWM out
	output wire pwm,

	// Config
	input wire [WIDTH-1:0] cfg_val,

	// Clock / Reset
	input wire  clk,
	input wire  rst
);
	wire [WIDTH:0] cnt_cycle_rst;
	reg [WIDTH:0] cnt_cycle;
	reg [WIDTH:0] cnt_on;

	assign cnt_cycle_rst = { { (WIDTH-1){1'b0} }, 2'b10 };

	always @(posedge clk or posedge rst)
		if (rst)
			cnt_cycle <= cnt_cycle_rst;
		else
			cnt_cycle <= cnt_cycle[WIDTH] ? cnt_cycle_rst : (cnt_cycle + 1);

	always @(posedge clk or posedge rst)
		if (rst)
			cnt_on <= 0;
		else
			cnt_on <= (cnt_cycle[WIDTH] ? { 1'b1, cfg_val } : cnt_on) - 1;

	assign pwm = cnt_on[WIDTH];

endmodule // pwm
