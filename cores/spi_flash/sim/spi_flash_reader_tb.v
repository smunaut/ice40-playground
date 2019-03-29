/*
 * spi_flash_reader_tb.v
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

module spi_flash_reader_tb;

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;

	wire spi_mosi;
	wire spi_miso;
	wire spi_cs_n;
	wire spi_clk;

	wire [23:0] addr;
	wire [15:0] len;
	wire go;
	wire rdy;

	wire [7:0] data;
	wire valid;

	reg flip;
	reg [23:0] cnt;

	// Setup recording
	initial begin
		$dumpfile("spi_flash_reader_tb.vcd");
		$dumpvars(0,spi_flash_reader_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #33 clk = !clk;	// ~ 30 MHz

	// DUT
	spi_flash_reader dut_I (
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.spi_cs_n(spi_cs_n),
		.spi_clk(spi_clk),
		.addr(addr),
		.len(len),
		.go(go),
		.rdy(rdy),
		.data(data),
		.valid(valid),
		.clk(clk),
		.rst(rst)
	);

	// No real RAM
	assign spi_miso = spi_cs_n ? 1'bz : flip;

	always @(posedge rst, negedge spi_clk)
		if (rst)
			flip <= 1'b0;
		else
			flip <= ~flip;

	// Read commands
	assign addr = cnt;
	assign len = 16'h0000;
	assign go = rdy & ~rst & ~valid;

	always @(posedge clk)
		if (rst)
			cnt <= 24'h00BABE;
		else if (valid)
			cnt <= cnt + 1;

endmodule // spi_flash_reader_tb
