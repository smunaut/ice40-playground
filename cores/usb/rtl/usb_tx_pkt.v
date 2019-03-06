/*
 * usb_tx_pkt.v
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

module usb_tx_pkt (
	// Low-Level
	output reg  ll_start,
	output wire ll_bit,
	output wire ll_last,
	input  wire ll_ack,

	// Packet interface
	input  wire pkt_start,
	output reg  pkt_done,

	input  wire [3:0] pkt_pid,
	input  wire [9:0] pkt_len,

	input  wire [7:0] pkt_data,
	output reg  pkt_data_ack,

	// Common
	input  wire clk,
	input  wire rst
);

	`include "usb_defs.vh"

	// FSM
	// ---

	localparam
		ST_IDLE      = 0,
		ST_SYNC      = 1,
		ST_PID       = 2,
		ST_DATA      = 3,
		ST_CRC_LSB   = 4,
		ST_CRC_MSB   = 5;


	// Signals
	// -------

	// FSM
	reg  [3:0] state_nxt;
	reg  [3:0] state;

	// Helper
	reg  pid_is_handshake;
	wire next;

	// Shift register
	reg  [3:0] shift_bit;
	reg  [7:0] shift_load;
	reg  [7:0] shift_data;
	reg  shift_data_crc;
	wire shift_last_bit;
	reg  shift_last_byte;
	wire shift_do_load;
	wire shift_now;
	reg  shift_new_bit;

	// Packet length
	reg [10:0] len;
	wire len_last;
	wire len_dec;

	// CRC
	wire crc_in_bit;
	reg  crc_in_first;
	wire crc_in_valid;
	wire [15:0] crc;


	// Main FSM
	// --------

	// Next state logic
	always @(*)
	begin
		// Default is to stay put
		state_nxt = state;

		// Main case
		case (state)
			ST_IDLE:
				if (pkt_start)
					state_nxt = ST_SYNC;

			ST_SYNC:
				state_nxt = ST_PID;

			ST_PID:
				if (next)
				begin
					if (pid_is_handshake)
						state_nxt = ST_IDLE;
					else if (len_last)
						state_nxt = ST_CRC_LSB;
					else
						state_nxt = ST_DATA;
				end

			ST_DATA:
				if (next && len_last)
					state_nxt = ST_CRC_LSB;

			ST_CRC_LSB:
				if (next)
					state_nxt = ST_CRC_MSB;

			ST_CRC_MSB:
				if (next)
					state_nxt = ST_IDLE;
		endcase
	end

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;


	// Helper
	// ------

	always @(posedge clk)
		pid_is_handshake <= (pkt_pid == PID_ACK) || (pkt_pid == PID_NAK) || (pkt_pid == PID_STALL);

	assign next = shift_last_bit & ll_ack;


	// Shift register
	// --------------

	// When to load a new byte
	assign shift_do_load = (state == ST_SYNC) | (shift_last_bit & ll_ack);

	// When to shift
	assign shift_now = (state == ST_SYNC) | ll_ack;

	// Bit counter
	always @(posedge clk)
		if (shift_now)
			shift_bit <= (shift_do_load ? 4'b0111 : shift_bit) - 1;

	assign shift_last_bit = shift_bit[3];

	// Load mux
	always @(*)
		case (state)
			ST_SYNC:    shift_load <= 8'h80;
			ST_PID:     shift_load <= { ~pkt_pid, pkt_pid };
			ST_DATA:    shift_load <= pkt_data;
			ST_CRC_LSB: shift_load <= crc_in_first ? 8'h00 : crc[ 7:0];
			ST_CRC_MSB: shift_load <= crc_in_first ? 8'h00 : crc[15:8];
			default:    shift_load <= 8'hxx;
		endcase

	// Shift data
	always @(posedge clk)
		if (shift_now)
			shift_data <= shift_do_load ? shift_load : {1'b0, shift_data[7:1]};

	// Some flags about the data
	always @(posedge clk)
		if (shift_now & shift_do_load) begin
			shift_data_crc  <= (state == ST_DATA);
			shift_last_byte <= (state == ST_CRC_MSB) | ((state == ST_PID) & pid_is_handshake);
		end

	// When a fresh new bit is available
	always @(posedge clk)
		shift_new_bit <= shift_now;


	// Packet length
	// -------------

	assign len_dec = pkt_start || (shift_do_load && ((state == ST_DATA) || (state == ST_PID)));

	always @(posedge clk)
		if (len_dec)
			len <= (pkt_start ? { 1'b0, pkt_len } : len) - 1;

	assign len_last = len[10];


	// CRC generation
	// --------------

	// Keep track of first bit
	always @(posedge clk)
		crc_in_first <= (crc_in_first & ~crc_in_valid) | (state == ST_IDLE);

	// Input all bits once acked
	assign crc_in_bit   = shift_data[0];
	assign crc_in_valid = shift_data_crc & shift_new_bit;

	// CRC16 core
	usb_crc #(
		.WIDTH(16),
		.POLY(16'h8005),
		.MATCH(16'h800D)
	) crc_16_I (
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.crc(crc),
		.crc_match(),
		.clk(clk),
		.rst(rst)
	);


	// Low-level control
	// -----------------

	// Start right after the load of SYNC
	always @(posedge clk)
		ll_start <= state == ST_SYNC;

	// Bit
	assign ll_bit  = shift_data[0];
	assign ll_last = shift_last_bit & shift_last_byte;


	// Packet interface feedback
	// -------------------------

	// We don't care about the delay, better register
	always @(posedge clk)
	begin
		pkt_done <= ll_ack && ll_last;
		pkt_data_ack <= (state == ST_DATA) && next;
	end

endmodule // usb_tx_pkt
