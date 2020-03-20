/*
 * pkt_fifo_tb.v
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

module pkt_fifo_tb;

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;

	wire [7:0] wr_data;
	wire wr_last;
	wire wr_ena;
	wire full;

	wire [7:0] rd_data;
	wire rd_last;
	wire rd_ena;
	wire empty;

	// Setup recording
	initial begin
		$dumpfile("pkt_fifo_tb.vcd");
		$dumpvars(0,pkt_fifo_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk = !clk;

	// DUT
	pkt_fifo #(
		.AWIDTH(5)
	) dut_I (
		.wr_data(wr_data),
		.wr_last(wr_last),
		.wr_ena(wr_ena),
		.full(full),
		.rd_data(rd_data),
		.rd_last(rd_last),
		.rd_ena(rd_ena),
		.empty(empty),
		.clk(clk),
		.rst(rst)
	);

	// Feed some data
	assign rd_ena = r & ~empty;

	reg [7:0] cnt;
	reg r;

	always @(posedge clk)
		if (rst)
			r <= 1'b0;
		else
			r <= $random & $random;

	always @(posedge clk)
		if (rst)
			cnt <= 0;
		else
			cnt <= cnt + 1;

	assign wr_data = cnt;
	assign wr_last = (cnt[2:0] == 3'b111);
	assign wr_ena  = ~full & (cnt[7:6] == 2'b01);

endmodule // pkt_fifo_tb
