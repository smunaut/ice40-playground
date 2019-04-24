/*
 * hdb3_tb.v
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

module hdb3_tb;

	// Signals
	reg rst = 1;
	reg clk = 0;

	reg  in_data;
	reg  in_valid;
	wire hdb3_pos;
	wire hdb3_neg;
	wire hdb3_valid;
	wire out_data;
	wire out_valid;

	reg  [31:0] data;
	wire out_data_ref;
	wire out_data_err;

	// Setup recording
	initial begin
		$dumpfile("hdb3_tb.vcd");
		$dumpvars(0,hdb3_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 10000 $finish;
	end

	// Clocks
	always #5 clk = !clk;

	// DUT
	hdb3_enc dut_enc_I (
		.in_data(in_data),
		.in_valid(in_valid),
		.out_pos(hdb3_pos),
		.out_neg(hdb3_neg),
		.out_valid(hdb3_valid),
		.clk(clk),
		.rst(rst)
	);

	hdb3_dec dut_dec_I (
		.in_pos(hdb3_pos),
		.in_neg(hdb3_neg),
		.in_valid(hdb3_valid),
		.out_data(out_data),
		.out_valid(out_valid),
		.clk(clk),
		.rst(rst)
	);

	// Data feed
	always @(posedge clk)
	begin
		if (rst) begin
			in_data  <= 1'b0;
			in_valid <= 1'b0;
			data     <= 32'h6ac0c305;
		end else begin
			in_data  <= data[0];
			in_valid <= 1'b1;
			data     <= { data[0], data[31:1] };
		end
	end

	assign out_data_ref = data[23];
	assign out_data_err = out_data_ref != out_data;

endmodule // hdb3_tb
