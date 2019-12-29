/*
 * e1_tx_liu.v
 *
 * vim: ts=4 sw=4
 *
 * E1 RX interface to external LIU
 *
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

module e1_tx_liu (
	// Pads
	input  wire pad_tx_data,
	input  wire pad_tx_clk,

	// Intput
	input  wire in_data,
	input  wire in_valid,

	// Common
	input  wire clk,
	input  wire rst
);
	// Signals
	reg [5:0] cnt_cur;
	reg [5:0] cnt_nxt;

	reg  tx_data;
	wire tx_clk;

	// Counters
	always @(posedge clk)
		if (in_valid)
			cnt_nxt <= 0;
		else
			cnt_nxt <= cnt_nxt + 1;

	always @(posedge clk)
		if (in_valid)
			cnt_cur <= { 1'b1, cnt_nxt[5:1] };
		else
			cnt_cur <= cnt_cur - 1;

	// TX
	always @(posedge clk)
		if (in_valid)
			tx_data <= in_data;

	assign tx_clk = cnt_cur[5];

	// IOBs (registered)
	SB_IO #(
		.PIN_TYPE(6'b0101_00),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0)
	) tx_data_iob_I (
		.PACKAGE_PIN(pad_tx_data),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(1'b1),
		.D_OUT_0(tx_data),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);

	SB_IO #(
		.PIN_TYPE(6'b0101_00),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0)
	) tx_clk_iob_I (
		.PACKAGE_PIN(pad_tx_clk),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(1'b1),
		.D_OUT_0(tx_clk),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);

endmodule // e1_tx_liu
