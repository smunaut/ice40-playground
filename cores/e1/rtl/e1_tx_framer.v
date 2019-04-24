/*
 * e1_tx_framer.v
 *
 * vim: ts=4 sw=4
 *
 * E1 Frame generation as described G.704
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

module e1_tx_framer (
	// Fetch interface
	input  wire [7:0] in_data,
	input  wire [1:0] in_crc_e,	// CRC error bits to use in this multiframe
	output wire [3:0] in_frame,
	output wire [4:0] in_ts,
	output reg  in_mf_first,	// First request for this multiframe
	output reg  in_mf_last,		// Last  request for this multiframe
	output reg  in_req,
	input  wire in_rdy,

	// Output
	output reg  out_bit,
	output reg  out_valid,

	// Loopback Input
	input  wire lb_bit,
	input  wire lb_valid,

	// Control
	input  wire ctrl_time_src,	// 0=internal, 1=external
	input  wire ctrl_do_framing,
	input  wire ctrl_do_crc4,
	input  wire ctrl_loopback,
	input  wire alarm,

	// Timing sources
	input  wire ext_tick,
	output wire int_tick,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Tick source
	reg  [5:0] tick_cnt;
	reg  strobe;

	// Fetch unit
	reg  [3:0] fetch_frame;
	reg  [4:0] fetch_ts;
	reg  fetch_ts_is0;
	reg  fetch_ts_is31;
	reg  fetch_first;
	reg  fetch_last;
	reg  fetch_done;

	wire [7:0] fetch_data;
	wire [1:0] fetch_crc_e;
	wire fetch_valid;

	wire fetch_ack;

	// TS0 generation
	reg  [7:0] shift_data_nxt;
	wire [7:0] odd_bit0;

	// Shift register
	reg  [7:0] shift_data;
	reg  shift_at_first;
	reg  shift_at_last;
	reg  shift_at_crc;

	// CRC4
	wire crc_in_bit;
	wire crc_in_first;
	wire crc_in_valid;
	reg  crc_capture;

	wire [3:0] crc_out;
	reg  [3:0] crc_smf;


	// Tick source
	// -----------

	always @(posedge clk or posedge rst)
		if (rst)
			tick_cnt <= 5'b00000;
		else
			tick_cnt <= strobe ? 5'b01100 : (tick_cnt - 1);

	always @(posedge clk)
		strobe <= (ctrl_time_src ? ext_tick : tick_cnt[4]) & ~strobe;

	assign int_tick = strobe;


	// Fetch control
	// -------------

	// Frame
	always @(posedge clk or posedge rst)
		if (rst)
			fetch_frame <= 4'hf;
		else if (fetch_ack)
			fetch_frame <= fetch_frame + fetch_ts_is31;

	// Time Slot
	always @(posedge clk or posedge rst)
		if (rst) begin
			fetch_ts   <= 5'h1f;
			fetch_ts_is0  <= 1'b0;
			fetch_ts_is31 <= 1'b1;
		end else if (fetch_ack) begin
			fetch_ts   <= fetch_ts + 1;
			fetch_ts_is0  <= fetch_ts_is31;
			fetch_ts_is31 <= (fetch_ts == 5'h1e);
		end

	// External request
	assign in_frame = fetch_frame;
	assign in_ts = fetch_ts;

	always @(posedge clk or posedge rst)
		if (rst) begin
			in_mf_first <= 1'b0;
			in_mf_last  <= 1'b1;
		end else if (fetch_ack) begin
			in_mf_first <= in_mf_last;
			in_mf_last  <= (fetch_frame == 4'hf) && (fetch_ts == 5'h1e) ;
		end

	always @(posedge clk)
		in_req <= fetch_ack;

	// Track the first ever request (hence first valid data ...)
	always @(posedge clk or posedge rst)
		if (rst)
			fetch_done <= 1'b0;
		else if (in_req)
			fetch_done <= 1'b1;

	// Data output to next stage
	assign fetch_data  = in_data;
	assign fetch_crc_e = in_crc_e;
	assign fetch_valid = in_rdy & fetch_done;


	// TS0 generation
	// --------------
		// After fetch_ack we have plenty of time to generate the next data
		// from the response

	assign odd_bit0 = { fetch_crc_e[1:0], 6'b110100 };

	always @(posedge clk)
		if (fetch_valid) begin
			if (fetch_ts_is0 & ctrl_do_framing) begin
				// TS0 with auto-framing
				if (fetch_frame[0])
					// Odd frame number
					shift_data_nxt <= { odd_bit0[fetch_frame[3:1]], 1'b1, alarm, 5'b11111 };
				else
					// Even frame number
					shift_data_nxt <= 8'h1b;	// CRC bits are set later
			end else begin
				// Either auto-frame is disabled, or this is not TS0
				shift_data_nxt <= fetch_data;
			end
		end else begin
			// No data from fetch unit, fill with 0xff
			shift_data_nxt <= 8'hff;
		end


	// Shift register
	// --------------

	reg [3:0] bit_cnt;
	reg bit_first;

	// Bit counter
	always @(posedge clk or posedge rst)
		if (rst)
			bit_cnt <= 4'b1000;
		else if (strobe)
			bit_cnt <= bit_cnt[3] ? 4'b0110 : (bit_cnt - 1);

	// Shift register
	always @(posedge clk or posedge rst)
		if (rst)
			shift_data <= 8'hff;
		else if (strobe)
			shift_data <= bit_cnt[3] ? shift_data_nxt : { shift_data[6:0], 1'b1 };

	// Ack to upstream
	assign fetch_ack = strobe & bit_cnt[3];

	// Track special positions
	always @(posedge clk or posedge rst)
		if (rst) begin
			shift_at_first <= 1'b1;
			shift_at_last  <= 1'b0;
			shift_at_crc   <= 1'b0;
		end else if (strobe) begin
			shift_at_first <= (fetch_frame[2:0] == 3'b000) & fetch_ts_is0 &  bit_cnt[3];
			shift_at_last  <= (fetch_frame[2:0] == 3'b000) & fetch_ts_is0 & (bit_cnt[2:0] == 3'b000);
			shift_at_crc   <= ~fetch_frame[0]              & fetch_ts_is0 & bit_cnt[3];
		end


	// CRC4
	// ----

	// CRC4 computation
	assign crc_in_bit   = shift_at_crc ? 1'b0 : shift_data[7];
	assign crc_in_first = shift_at_first;
	assign crc_in_valid = strobe;

	always @(posedge clk)
		crc_capture <= shift_at_last;

	e1_crc4 crc_I (
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.out_crc4(crc_out),
		.clk(clk),
		.rst(rst)
	);

	always @(posedge clk or posedge rst)
		if (rst)
			crc_smf <= 4'b1111;
		else if (crc_capture)
			crc_smf <= crc_out;
		else if (shift_at_crc & strobe)
			crc_smf <= { crc_smf[2:0], 1'b1 };


	// Output
	// ------

	always @(posedge clk or posedge rst)
		if (rst) begin
			out_bit   <= 1'b1;
			out_valid <= 1'b0;
		end else begin
			out_bit   <= ctrl_loopback ? lb_bit   : ((ctrl_do_crc4 & shift_at_crc) ? crc_smf[3] : shift_data[7]);
			out_valid <= ctrl_loopback ? lb_valid : strobe;
		end

endmodule // e1_tx_framer
