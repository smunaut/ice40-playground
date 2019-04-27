/*
 * usb_tx_tb.v
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

module usb_tx_tb;

	// Signals
	reg rst = 1;
	reg clk_48m  = 0;	// USB clock

	wire phy_tx_dp;
	wire phy_tx_dn;
	wire phy_tx_en;

	wire ll_start;
	wire ll_bit;
	wire ll_last;
	wire ll_ack;

	wire pkt_start;
	wire pkt_done;
	wire [3:0] pkt_pid;
	wire [9:0] pkt_len;
	reg  [11:0] pkt_data_addr;
	reg  [7:0] pkt_data;
	wire pkt_data_ack;

	// Setup recording
	initial begin
		$dumpfile("usb_tx_tb.vcd");
		$dumpvars(0,usb_tx_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 400000 $finish;
	end

	// Clocks
	always #10.416 clk_48m  = !clk_48m;

	// DUT
	usb_tx_ll tx_ll_I (
		.phy_tx_dp(phy_tx_dp),
		.phy_tx_dn(phy_tx_dn),
		.phy_tx_en(phy_tx_en),
		.ll_start(ll_start),
		.ll_bit(ll_bit),
		.ll_last(ll_last),
		.ll_ack(ll_ack),
		.clk(clk_48m),
		.rst(rst)
	);

`ifndef NO_PKT
	usb_tx_pkt tx_pkt_I (
		.ll_start(ll_start),
		.ll_bit(ll_bit),
		.ll_last(ll_last),
		.ll_ack(ll_ack),
		.pkt_start(pkt_start),
		.pkt_done(pkt_done),
		.pkt_pid(pkt_pid),
		.pkt_len(pkt_len),
		.pkt_data(pkt_data),
		.pkt_data_ack(pkt_data_ack),
		.clk(clk_48m),
		.rst(rst)
	);

	// Start signal
	reg [7:0] cnt;
	reg ready;

	always @(posedge clk_48m)
		if (rst)
			ready <= 1'b1;
		else
			if (pkt_start)
				ready <= 1'b0;
			else if (pkt_done)
				ready <= 1'b1;

	always @(posedge clk_48m)
		if (rst)
			cnt <= 0;
		else
			cnt <= cnt + 1;

	assign pkt_start = (cnt == 8'hff) & ready;

	// Packet
	assign pkt_len = 10'h100;	// 256 bytes payload
	assign pkt_pid = 4'b0011;	// DATA0
//	assign pkt_pid = 4'b0010;	// ACK

	// Fake data source
	always @(posedge clk_48m)
		if (rst)
			pkt_data_addr <= 8'h00;
		else
			pkt_data_addr <= pkt_data_addr + pkt_data_ack;

	always @(*)
		case (pkt_data_addr)
			12'h000: pkt_data = 8'h8c;
			12'h001: pkt_data = 8'h1a;
			12'h002: pkt_data = 8'hf2;
			12'h003: pkt_data = 8'hf0;

			12'h100: pkt_data = 8'ha0;
			12'h101: pkt_data = 8'h28;
			12'h102: pkt_data = 8'hf2;
			12'h103: pkt_data = 8'hf0;
			default: pkt_data = 8'h00;
		endcase
`endif

`ifdef NO_PKT
	wire [31:0] bit_seq = 32'b00000001_10100101_11111111_11100000;
	reg [7:0] cnt;
	reg started;

	always @(posedge clk_48m)
		if (rst)
			cnt <= 0;
		else if (ll_ack | ~started)
			cnt <= cnt + 1;

	always @(posedge clk_48m)
		if (rst)
			started <= 1'b0;
		else
			if (ll_start)
				started <= 1'b1;
			else if (ll_last & ll_ack)
				started <= 1'b0;

	assign ll_start = (cnt == 8'h1f);
	assign ll_bit   = bit_seq[31 - cnt[4:0]];
	assign ll_last  = cnt[4:0] == 31;
`endif

	wire trig = tx_ll_I.ll_last & tx_ll_I.br_now & tx_ll_I.bs_now;

endmodule // usb_tx_tb
