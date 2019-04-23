/*
 * pdm_tb.v
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
`timescale 1ns / 100ps

module pdm_tb;

	// Signals
	reg rst = 1;
	reg clk = 1;

	reg [7:0] data;
	wire pdm;

	// Setup recording
	initial begin
		$dumpfile("pdm_tb.vcd");
		$dumpvars(0,pdm_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 20000 $finish;
	end

	// Clocks
	always #5 clk = !clk;

	// DUT
	pdm #(
		.WIDTH(12),
		.PHY("ICE40"),
		.DITHER("ON")
	) dut_I (
		.in({data[7:4],data}),
		.pdm(pdm),
		.oe(1'b1),
		.clk(clk),
		.rst(rst)
	);

	initial begin
		#0		data <= 8'hc1;
		#5000	data <= 8'h10;
		#5000	data <= 8'hf0;
		#5000	data <= 8'h80;
	end

endmodule // pdm_tb
