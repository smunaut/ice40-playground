/*
 * usb_ep_buf_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019 Sylvain Munaut
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
`timescale 1ns/100ps

module usb_ep_buf_tb;

	localparam integer RWIDTH = 16;	// 8/16/32
	localparam integer WWIDTH = 64;	// 8/16/32

	localparam integer ARW = 11 - $clog2(RWIDTH / 8);
	localparam integer AWW = 11 - $clog2(WWIDTH / 8);

	// Signals
	reg rst = 1;
	reg clk  = 0;

	wire [ARW-1:0] rd_addr_0;
	wire [RWIDTH-1:0] rd_data_1;
	wire rd_en_0;
	wire [AWW-1:0] wr_addr_0;
	wire [WWIDTH-1:0] wr_data_0;
	wire wr_en_0;

	// Setup recording
	initial begin
		$dumpfile("usb_ep_buf_tb.vcd");
		$dumpvars(0,usb_ep_buf_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk  = !clk;

	// DUT
	usb_ep_buf #(
		.RWIDTH(RWIDTH),
		.WWIDTH(WWIDTH)
	) dut_I (
		.rd_addr_0(rd_addr_0),
		.rd_data_1(rd_data_1),
		.rd_en_0(rd_en_0),
		.rd_clk(clk),
		.wr_addr_0(wr_addr_0),
		.wr_data_0(wr_data_0),
		.wr_en_0(wr_en_0),
		.wr_clk(clk)
	);

	assign rd_en_0 = 1'b1;
	assign wr_en_0 = 1'b1;
	assign rd_addr_0 = 3;
	assign wr_addr_0 = 0;
	assign wr_data_0 = 64'hab89127bbabecafe;

endmodule // usb_ep_buf_tb
