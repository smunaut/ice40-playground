/*
 * usb_tb.v
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

module usb_tb;

	// Signals
	reg rst = 1;
	reg clk_48m  = 0;	// USB clock
	reg clk_samp = 0;	// Capture samplerate

	reg  [7:0] in_file_data;
	reg  in_file_valid;
	reg  in_file_done;

	wire usb_dp;
	wire usb_dn;
	wire usb_pu;

	wire [ 8:0] ep_tx_addr_0;
	wire [31:0] ep_tx_data_0;
	wire ep_tx_we_0;
	wire [ 8:0] ep_rx_addr_0;
	wire [31:0] ep_rx_data_1;
	wire ep_rx_re_0;

	wire [11:0] bus_addr;
	wire [15:0] bus_din;
	wire [15:0] bus_dout;
	wire bus_cyc;
	wire bus_we;
	wire bus_ack;

	// Setup recording
	initial begin
		$dumpfile("usb_tb.vcd");
		$dumpvars(0,usb_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10.416 clk_48m  = !clk_48m;
	always #3.247  clk_samp = !clk_samp;

	// DUT
	usb #(
		.TARGET("ICE40"),
		.EPDW(32)
	) dut_I (
		.pad_dp(usb_dp),
		.pad_dn(usb_dn),
		.pad_pu(usb_pu),
		.ep_tx_addr_0(ep_tx_addr_0),
		.ep_tx_data_0(ep_tx_data_0),
		.ep_tx_we_0(ep_tx_we_0),
		.ep_rx_addr_0(ep_rx_addr_0),
		.ep_rx_data_1(ep_rx_data_1),
		.ep_rx_re_0(ep_rx_re_0),
		.ep_clk(clk_48m),
		.bus_addr(bus_addr),
		.bus_din(bus_din),
		.bus_dout(bus_dout),
		.bus_cyc(bus_cyc),
		.bus_we(bus_we),
		.bus_ack(bus_ack),
		.clk(clk_48m),
		.rst(rst)
	);

	reg [7:0] cnt;

	always @(posedge clk_48m)
		if (bus_ack)
			cnt <= 0;
		else if (~cnt[7])
			cnt <= cnt + 1;

	assign bus_addr = 12'h000;
	assign bus_din = 16'h8001;
	assign bus_cyc = cnt[7];
	assign bus_we = 1'b1;

	assign ep_rx_addr_0 = 9'h000;
	assign ep_rx_re_0 = 1'b1;
	assign ep_tx_addr_0 = 9'h000;
	assign ep_tx_data_0 = 32'h02000112;
	assign ep_tx_we_0 = 1'b1;

	// Read file
	integer fh_in, rv;

	initial
		fh_in = $fopen("../data/capture_usb_raw_short.bin", "rb");

	always @(posedge clk_samp)
	begin
		if (rst) begin
			in_file_data  <= 8'h00;
			in_file_valid <= 1'b0;
			in_file_done  <= 1'b0;
		end else begin
			if (!in_file_done) begin
				rv = $fread(in_file_data, fh_in);
				in_file_valid <= (rv == 1);
				in_file_done  <= (rv != 1);
			end else begin
				in_file_data  <= 8'h00;
				in_file_valid <= 1'b0;
				in_file_done  <= 1'b1;
			end
		end
	end

	// Input
	assign usb_dp = in_file_data[1] & in_file_valid;
	assign usb_dn = in_file_data[0] & in_file_valid;

endmodule // usb_tb
