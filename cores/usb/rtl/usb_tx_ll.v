/*
 * usb_tx_ll.v
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

module usb_tx_ll (
	// PHY
	output wire phy_tx_dp,
	output wire phy_tx_dn,
	output wire phy_tx_en,

	// Low-Level
	input  wire ll_start,
	input  wire ll_bit,
	input  wire ll_last,
	output reg  ll_ack,

	// Common
	input  wire clk,
	input  wire rst
);

	`include "usb_defs.vh"

	// Signals
	// -------

	// State
	reg [2:0] state;
	wire active;

	reg  [2:0] br_cnt;
	wire br_now;

	// Bit stuffing
	reg  [2:0] bs_cnt;
	reg  bs_now;
	wire bs_bit;

	// NRZI
	reg  lvl_prev;

	// Output
	reg  out_active;
	wire [1:0] out_sym_nxt;
	reg  [1:0] out_sym;


	// State
	// -----

	always @(posedge clk or posedge rst)
		if (rst)
			state <= 3'b000;
		else begin
			if (ll_start)
				state <= 3'b100;
			else if (br_now & ~bs_now) begin
				if (ll_last)
					state <= 3'b101;
				else
					case (state[1:0])
						2'b00:   state <= state;
						2'b01:   state <= 3'b110;
						2'b10:   state <= 3'b111;
						default: state <= 3'b000;
					endcase
			end
		end

	assign active = state[2];

	always @(posedge clk)
		br_cnt <= { 1'b0, active ? br_cnt[1:0] : 2'b10 } + 1;

	assign br_now = br_cnt[2];


	// Bit Stuffing
	// ------------

	// Track number of 1s
	always @(posedge clk or posedge ll_start)
		if (ll_start) begin
			bs_cnt <= 3'b000;
			bs_now <= 1'b0;
		end else if (br_now) begin
			bs_cnt <= (ll_bit & ~bs_now) ? (bs_cnt + 1) : 3'b000;
			bs_now <= ll_bit & (bs_cnt == 3'b101);
		end

	// Effective bit
	assign bs_bit = ~bs_now & ll_bit;

	// Track previous level
	always @(posedge clk)
		lvl_prev <= active ? (lvl_prev ^ (~bs_bit & br_now)) : 1'b1;


	// Output stage
	// ------------

	// Ack input
	always @(posedge clk)
		ll_ack <= br_now & ~bs_now & (state[1:0] == 2'b00);

	// Output symbol. Must be forced to 'J' outside of active area to
	// be ready for the next packet start
	assign out_sym_nxt = (bs_bit ^ lvl_prev) ? SYM_K : SYM_J;

	always @(posedge clk or posedge rst)
	begin
		if (rst)
			out_sym <= SYM_J;
		else if (br_now) begin
			case (state[1:0])
				2'b00:   out_sym <= out_sym_nxt;
				2'b01:   out_sym <= bs_now ? out_sym_nxt : SYM_SE0;
				2'b10:   out_sym <= SYM_SE0;
				2'b11:   out_sym <= SYM_J;
				default: out_sym <= 2'bxx;
			endcase
		end
	end

	// The OE is a bit in advance (not aligned with br_now) on purpose
	// so that we output a bit of 'J' at the packet beginning
	always @(posedge clk)
		out_active <= active;

	// PHY control
	assign phy_tx_dp = out_sym[1];
	assign phy_tx_dn = out_sym[0];
	assign phy_tx_en = out_active;

endmodule // usb_tx_ll
