/*
 * pkt_spi_write_tb.v
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

module pkt_spi_write_tb;

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;

	wire [7:0] sb_addr;
	wire [7:0] sb_data;
	wire sb_first;
	wire sb_last;
	wire sb_strobe;

	wire [7:0] spf_wr_data;
	wire spf_wr_last;
	wire spf_wr_ena;
	wire spf_full = 1'b0;

	// Setup recording
	initial begin
		$dumpfile("pkt_spi_write_tb.vcd");
		$dumpvars(0,pkt_spi_write_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk = !clk;

	// DUT
	pkt_spi_write #(
		.BASE(8'hA4)
	) pkt_I (
		.sb_addr(sb_addr),
		.sb_data(sb_data),
		.sb_first(sb_first),
		.sb_last(sb_last),
		.sb_strobe(sb_strobe),
		.fifo_data(spf_wr_data),
		.fifo_last(spf_wr_last),
		.fifo_wren(spf_wr_ena),
		.fifo_full(spf_full),
		.clk(clk),
		.rst(rst)
	);

	// SPI data generation
	reg [7:0] cnt;

	always @(posedge clk)
		if (rst)
			cnt <= 0;
		else
			cnt <= cnt + 1;


	assign sb_addr   = sb_strobe ? 8'ha5 : 8'hxx;
	assign sb_data   = sb_strobe ? cnt : 8'hxx;
	assign sb_first  = sb_strobe ? cnt[7:4] == 4'h0 : 1'bx;
	assign sb_last   = sb_strobe ? cnt[7:4] == 4'hf : 1'bx;
	assign sb_strobe = cnt[3:0] == 4'hf;

endmodule // pkt_spi_write_tb
