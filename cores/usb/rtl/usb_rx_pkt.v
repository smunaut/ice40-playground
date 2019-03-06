/*
 * usb_rx_pkt.v
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

module usb_rx_pkt (
	// Low-Level
	input  wire [1:0] ll_sym,
	input  wire ll_bit,
	input  wire ll_valid,
	input  wire ll_eop,
	input  wire ll_sync,
	input  wire ll_bs_skip,
	input  wire ll_bs_err,

	// Packet interface
	output reg  pkt_start,
	output reg  pkt_done_ok,
	output reg  pkt_done_err,

	output wire [ 3:0] pkt_pid,
	output wire pkt_is_sof,
	output wire pkt_is_token,
	output wire pkt_is_data,
	output wire pkt_is_handshake,

	output wire [10:0] pkt_frameno,
	output wire [ 6:0] pkt_addr,
	output wire [ 3:0] pkt_endp,

	output wire [ 7:0] pkt_data,
	output reg  pkt_data_stb,

	// Control
	input  wire inhibit,

	// Common
	input  wire clk,
	input  wire rst
);

	`include "usb_defs.vh"


	// FSM
	// ---

	localparam
		ST_IDLE      = 0,
		ST_PID       = 1,
		ST_PID_CHECK = 2,
		ST_ERROR     = 3,
		ST_TOKEN_1   = 4,
		ST_TOKEN_2   = 5,
		ST_WAIT_EOP  = 6,
		ST_DATA      = 7;


	// Signals
	// -------

	// FSM
	reg  [3:0] state_nxt;
	reg  [3:0] state;

	reg state_prev_idle;
	reg state_prev_error;

	// Utils
	wire llu_bit_stb;
	wire llu_byte_stb;

	// Data shift reg & bit counting
	wire [7:0] data_nxt;
	reg  [7:0] data;
	reg  [3:0] bit_cnt;
	reg  bit_eop_ok;
	wire bit_last;

	// CRC checking
	wire crc_in_bit;
	wire crc_in_valid;
	reg  crc_in_first;

	reg  crc_cap;

	wire crc5_match;
	reg  crc5_ok;

	wire crc16_match;
	reg  crc16_ok;

	// PID capture and decoding
	wire pid_cap;
	reg  pid_cap_r;
	reg  pid_valid;
	reg  [3:0] pid;
	reg  pid_is_sof;
	reg  pid_is_token;
	reg  pid_is_data;
	reg  pid_is_handshake;

	// TOKEN data capture
	reg [10:0] token_data;


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
				// Wait for SYNC to be detected
				if (ll_valid && ll_sync && ~inhibit)
					state_nxt = ST_PID;

			ST_PID:
				// Wait for PID capture
				if (llu_byte_stb)
					state_nxt = ST_PID_CHECK;

			ST_PID_CHECK: begin
				// Default is to error if no match
				state_nxt = ST_ERROR;

				// Select state depending on packet type
				if (pid_valid) begin
					if (pid_is_sof)
						state_nxt = ST_TOKEN_1;
					else if (pid_is_token)
						state_nxt = ST_TOKEN_1;
					else if (pid_is_data)
						state_nxt = ST_DATA;
					else if (pid_is_handshake)
						state_nxt = ST_WAIT_EOP;
				end
			end

			ST_ERROR:
				// Error, wait for a possible IDLE state to resume
				if (ll_valid && (ll_eop || (ll_bs_err && (ll_sym == SYM_J))))
					state_nxt = ST_IDLE;

			ST_TOKEN_1:
				// First data byte
				if (ll_valid && ll_eop)
					state_nxt = ST_ERROR;
				else if (llu_byte_stb)
					state_nxt = ST_TOKEN_2;

			ST_TOKEN_2:
				// Second data byte
				if (ll_valid && ll_eop)
					state_nxt = ST_ERROR;
				else if (llu_byte_stb)
					state_nxt = ST_WAIT_EOP;

			ST_WAIT_EOP:
				// Need EOP at the right place
				if (ll_valid && ll_eop)
					state_nxt = (bit_eop_ok & (crc5_ok | pid_is_handshake)) ? ST_IDLE : ST_ERROR;
				else if (llu_byte_stb)
					state_nxt = ST_ERROR;

			ST_DATA:
				if (ll_valid) begin
					if (ll_eop)
						state_nxt = (bit_eop_ok & crc16_ok) ? ST_IDLE : ST_ERROR;
					else if (ll_bs_err)
						state_nxt = ST_ERROR;
				end
		endcase
	end

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;


	// Utility signals
	// ---------------

	always @(posedge clk)
	begin
		state_prev_idle  <= (state == ST_IDLE);
		state_prev_error <= (state == ST_ERROR);
	end

	assign llu_bit_stb  = ll_valid & ~ll_bs_skip;
	assign llu_byte_stb = ll_valid & ~ll_bs_skip & bit_last;


	// Data shift register and bit counter
	// -----------------------------------

	// Next word
	assign data_nxt = { ll_bit, data[7:1] };

	// Shift reg
	always @(posedge clk)
		if (llu_bit_stb)
			data <= data_nxt;

	// Bit counter
	always @(posedge clk)
		if (state == ST_IDLE)
			bit_cnt <= 4'b0110;
		else if (llu_bit_stb)
			bit_cnt <= { 1'b0, bit_cnt[2:0] } - 1;

	// Last bit ?
	assign bit_last = bit_cnt[3];

	// EOP OK at this position ?
	always @(posedge clk)
		if (state == ST_IDLE)
			bit_eop_ok <= 1'b0;
		else if (llu_bit_stb)
			bit_eop_ok <= (bit_cnt[2:1] == 2'b10);


	// CRC checks
	// ----------

	// CRC input data
	assign crc_in_bit   = ll_bit;
	assign crc_in_valid = llu_bit_stb;

	always @(posedge clk)
		if (state == ST_PID)
			crc_in_first <= 1'b1;
		else if (crc_in_valid)
			crc_in_first <= 1'b0;

	// CRC5 core
	usb_crc #(
		.WIDTH(5),
		.POLY(5'b00101),
		.MATCH(5'b01100)
	) crc_5_I (
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.crc(),
		.crc_match(crc5_match),
		.clk(clk),
		.rst(rst)
	);

	// CRC16 core
	usb_crc #(
		.WIDTH(16),
		.POLY(16'h8005),
		.MATCH(16'h800D)
	) crc_16_I (
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.crc(),
		.crc_match(crc16_match),
		.clk(clk),
		.rst(rst)
	);

	// Capture CRC status at end of each byte
		// This will be a bit 'late' (i.e. a couple cycles after the last
		// bit was input), but it's only used when EOP happens, which is
		// many cycles after that, so this delay is fine
	always @(posedge clk)
		crc_cap <= llu_byte_stb;

	always @(posedge clk)
		if (state == ST_IDLE) begin
			crc5_ok <= 1'b0;
			crc16_ok <= 1'b0;
		end else if (crc_cap) begin
			crc5_ok  <= crc5_match;
			crc16_ok <= crc16_match;
		end


	// PID capture and decoding
	// ------------------------

	// When to capture
	assign pid_cap = (state == ST_PID) & llu_byte_stb;

	// Check PID before capture
	always @(posedge clk)
		if (pid_cap)
			pid_valid <= (data_nxt[3:0] == ~data_nxt[7:4]) && (
				(data_nxt[3:0] == PID_SOF)   ||
				(data_nxt[3:0] == PID_OUT)   ||
				(data_nxt[3:0] == PID_IN)    ||
				(data_nxt[3:0] == PID_SETUP) ||
				(data_nxt[3:0] == PID_DATA0) ||
				(data_nxt[3:0] == PID_DATA1) ||
				(data_nxt[3:0] == PID_ACK)   ||
				(data_nxt[3:0] == PID_NAK)   ||
				(data_nxt[3:0] == PID_STALL)
			);

	always @(posedge clk)
		pid_cap_r <= pid_cap;

	// Capture and decode
	always @(posedge clk)
		if ((state == ST_PID) && llu_byte_stb)
		begin
			pid              <=  data_nxt;
			pid_is_sof       <= (data_nxt[3:0] == PID_SOF);
			pid_is_token     <= (data_nxt[3:0] == PID_OUT) || (data_nxt[3:0] == PID_IN) || (data_nxt[3:0] == PID_SETUP);
			pid_is_data      <= (data_nxt[3:0] == PID_DATA0) || (data_nxt[3:0] == PID_DATA1);
			pid_is_handshake <= (data_nxt[3:0] == PID_ACK) || (data_nxt[3:0] == PID_NAK) || (data_nxt[3:0] == PID_STALL);
		end


	// TOKEN data capture
	// ------------------

	always @(posedge clk)
		if ((state == ST_TOKEN_1) && llu_byte_stb)
			token_data[7:0] <= data_nxt[7:0];

	always @(posedge clk)
		if ((state == ST_TOKEN_2) && llu_byte_stb)
			token_data[10:8] <= data_nxt[2:0];


	// Output
	// ------

	// Generate pkt_start on PID capture
	always @(posedge clk)
		pkt_start <= pid_cap_r & pid_valid;

	// Generate packet done signals
	always @(posedge clk)
	begin
		pkt_done_ok  <= (state == ST_IDLE)  && !state_prev_idle && !state_prev_error;
		pkt_done_err <= (state == ST_ERROR) && !state_prev_error;
	end

	// Output PID and decoded
	assign pkt_pid          = pid;
	assign pkt_is_sof       = pid_is_sof;
	assign pkt_is_token     = pid_is_token;
	assign pkt_is_data      = pid_is_data;
	assign pkt_is_handshake = pid_is_handshake;

	// Output token data
	assign pkt_frameno = token_data;
	assign pkt_addr    = token_data[ 6:0];
	assign pkt_endp    = token_data[10:7];

	// Data byte and associated strobe
	assign pkt_data = data;

	always @(posedge clk)
		pkt_data_stb <= (state == ST_DATA) && llu_byte_stb;

endmodule // usb_rx_pkt
