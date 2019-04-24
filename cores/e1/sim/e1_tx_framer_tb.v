/*
 * e1_tx_framer_tb.v
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

module e1_tx_framer_tb;

	// Signals
	reg rst = 1;
	reg clk_30m72 = 0;

	wire [7:0] in_data;
	wire [1:0] in_crc_e;
	wire [3:0] in_frame;
	wire [4:0] in_ts;
	wire in_mf_first;
	wire in_mf_last;
	wire in_req;
	wire in_rdy;

	wire out_bit;
	wire out_valid;

	// Setup recording
	initial begin
		$dumpfile("e1_tx_framer_tb.vcd");
		$dumpvars(0,e1_tx_framer_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 10000000 $finish;
	end

	// Clocks
	always #16.276 clk_30m72 = !clk_30m72;

	// DUT
	e1_tx_framer framer_I (
		.in_data(in_data),
		.in_crc_e(in_crc_e),
		.in_frame(in_frame),
		.in_ts(in_ts),
		.in_mf_first(in_mf_first),
		.in_mf_last(in_mf_last),
		.in_req(in_req),
		.in_rdy(in_rdy),
		.lb_bit(1'b0),
		.lb_valid(1'b0),
		.out_bit(out_bit),
		.out_valid(out_valid),
		.ctrl_time_src(1'b0),
		.ctrl_do_framing(1'b1),
		.ctrl_do_crc4(1'b1),
		.ctrl_loopback(1'b0),
		.alarm(1'b0),
		.ext_tick(1'b0),
		.clk(clk_30m72),
		.rst(rst)
	);

	reg [7:0] cnt = 8'h00;

	always @(posedge clk_30m72)
		if (in_req)
			cnt <= cnt + 1;

	assign in_data  = in_ts == 5'h10 ? 8'hf9 : cnt;
	assign in_crc_e = 2'b11;
	assign in_rdy   = 1'b1;

	e1_rx_deframer rx_deframer_I (
		.in_bit(out_bit),
		.in_valid(out_valid),
		.out_data(),
		.out_valid(),
		.out_ts(),
		.clk(clk_30m72),
		.rst(rst)
	);

endmodule // e1_tx_framer_tb
