/*
 * e1_crc4_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

`default_nettype none
`timescale 1ns / 100ps

module e1_crc4_tb;

	// Signals
	reg rst = 1;
	reg clk = 1;

	reg [31:0] data;

	wire in_bit;
	reg  in_valid;
	reg  in_first;

	wire [3:0] crc;

	// Setup recording
	initial begin
		$dumpfile("e1_crc4_tb.vcd");
		$dumpvars(0,e1_crc4_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 20000 $finish;
	end

	// Clocks
	always #5 clk = !clk;

	// DUT
	e1_crc4 dut_I (
		.in_bit(in_bit),
		.in_first(in_first),
		.in_valid(in_valid),
		.out_crc4(crc),
		.clk(clk),
		.rst(rst)
	);

	// Data feed
	always @(posedge clk)
		if (rst)
			in_valid <= 1'b0;
		else
			in_valid <= 1'b1;

	always @(posedge clk)
		if (rst)
			in_first <= 1'b1;
		else if (in_valid)
			in_first <= 1'b0;

	always @(posedge clk)
		if (rst)
			//data <= 32'h600dbabe;
			data <= 32'h0badbabe;
		else if (in_valid)
			data <= { data[31:0], 1'b0 };

	assign in_bit = data[31];

endmodule // e1_crc4_tb
