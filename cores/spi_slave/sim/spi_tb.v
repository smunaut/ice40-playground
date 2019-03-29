/*
 * spi_tb.v
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
 *
 * vim: ts=4 sw=4
 */

`default_nettype none
`timescale 1ns / 100ps

module spi_tb;

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;

	wire spi_mosi;
	wire spi_miso;
	wire spi_cs_n;
	wire spi_clk;

	wire [7:0] sb_addr;
	wire [7:0] sb_data;
	wire sb_first;
	wire sb_last;
	wire sb_strobe;

	wire [15:0] reg_val;
	wire reg_stb;

	// Setup recording
	initial begin
		$dumpfile("spi_tb.vcd");
		$dumpvars(0,spi_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk = !clk;

	// DUT
	spi_simple spi_I (
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.spi_cs_n(spi_cs_n),
		.spi_clk(spi_clk),
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.last(sb_last),
		.strobe(sb_strobe),
		.out(8'hba),
		.clk(clk),
		.rst(rst)
	);

	spi_reg #(
		.ADDR(8'hA5),
		.BYTES(2)
	) reg_I (
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.strobe(sb_strobe),
		.rst_val(16'hbabe),
		.out_val(reg_val),
		.out_stb(reg_stb),
		.clk(clk),
		.rst(rst)
	);

	// SPI data generation
	reg [71:0] spi_csn_data = 72'b11110000000000000000000000000000000000000000000000000001111;
	reg [71:0] spi_clk_data = 72'b00000010101010101010101010101010101010101010101010101000000;
	reg [71:0] spi_dat_data = 72'b00000110011000011001111110000000000111111000000001100000000;

	reg [4:0] div;

	always @(posedge clk)
		if (rst)
			div <= 0;
		else
			div <= div + 1;

	always @(posedge clk)
		if (div == 4'hf) begin
			spi_csn_data <= { spi_csn_data[70:0], 1'b0 & spi_csn_data[71] };
			spi_clk_data <= { spi_clk_data[70:0], spi_clk_data[71] };
			spi_dat_data <= { spi_dat_data[70:0], spi_dat_data[71] };
		end

	assign spi_mosi = spi_dat_data[70];
	assign spi_cs_n = spi_csn_data[70];
	assign spi_clk  = spi_clk_data[70];

endmodule // spi_tb
