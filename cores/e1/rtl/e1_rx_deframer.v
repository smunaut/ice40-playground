/*
 * e1_rx_deframer.v
 *
 * vim: ts=4 sw=4
 *
 * E1 Frame alignement recovery and checking as described G.706
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

module e1_rx_deframer #(
	parameter integer TS0_START = 0
)(
	// Input
	input  wire in_bit,
	input  wire in_valid,

	// Output
	output reg  [7:0] out_data,
	output reg  [3:0] out_frame,
	output reg  [4:0] out_ts,
	output reg  out_ts_is0,
	output reg  out_first,
	output reg  out_last,
	output reg  out_valid,

	output wire out_err_crc,
	output wire out_err_mfa,
	output wire out_err_fas,
	output wire out_err_nfas,

	output reg  aligned,

	// Common
	input  wire clk,
	input  wire rst
);

	// FSM defines
	// -----------

	localparam
		ST_FRAME_SEARCH = 0,
		ST_FRAME_VALIDATE = 1,
		ST_MULTIFRAME_SEARCH = 2,
		ST_MULTIFRAME_VALIDATE = 3,
		ST_ALIGNED = 4;

	reg [2:0] fsm_state;
	reg [2:0] fsm_state_nxt;


	// Signals
	// -------

	// Input
	reg  strobe;
	reg  [7:0] data;
	reg  data_match_fas;

	// Position tracking
	reg  [2:0] bit;
	reg  bit_first;
	reg  bit_last;

	reg  [4:0] ts;
	reg  ts_is_ts0;
	reg  ts_is_ts31;

	reg  [3:0] frame;
	reg  frame_smf_first;		// First of a sub-multiframe
	reg  frame_smf_last;		// Last of a sub-multiframe
	reg  frame_mf_first;		// First of the multiframe
	reg  frame_mf_last;			// Last of the multiframe

	// Alignement control signal
	wire align_frame;
	wire align_mframe;

	// Helpers
	reg  fas_pos;
	reg [6:0] mfa_timeout;

	reg  [15:0] ts0_msbs;
	wire [5:0] ts0_msbs_sync;
	wire [3:0] ts0_msbs_crc;
	reg  ts0_msbs_match_mf;
	reg  ts0_msbs_match_crc;

	wire crc_in_bit;
	wire crc_in_first;
	wire crc_in_valid;
	wire crc_capture;

	wire [3:0] crc_out;
	reg  [3:0] crc_smf;

	reg ed_fas,  ep_fas;
	reg ed_nfas, ep_nfas;
	reg ed_crc,  ep_crc;
	reg ed_mfa,  ep_mfa;

	reg [1:0] ec_fas;
	reg [1:0] ec_nfas;
	reg [1:0] ec_crc;
	reg [1:0] ec_mfa;

	reg error;


	// Input shift register
	// --------------------

	// Strobe signal
	always @(posedge clk)
		if (rst)
			strobe <= 1'b0;
		else
			strobe <= in_valid;

	// Actual data
	always @(posedge clk)
		if (in_valid)
			data <= { data[6:0], in_bit };

	// Pre-matching of FAS
	always @(posedge clk)
		if (in_valid)
			data_match_fas <= (data[5:0] == 6'b001101) & in_bit;


	// FSM logic
	// ---------

	// State register
	always @(posedge clk)
		if (rst | error)
			fsm_state <= ST_FRAME_SEARCH;
		else if (strobe)
			fsm_state <= fsm_state_nxt;

	// State transitions
	always @(*)
	begin
		// Default is to stay on the current state
		fsm_state_nxt <= fsm_state;

		// Act depending on current state
		case (fsm_state)
			ST_FRAME_SEARCH: begin
				// As soon as we have a FAS, we assume we're byte align
				// and check it's the right one
				if (data_match_fas)
					fsm_state_nxt <= ST_FRAME_VALIDATE;
			end

			ST_FRAME_VALIDATE: begin
				// We expect a non-FAS then a FAS, any error and we retry
				// frame search
				if (bit_last & ts_is_ts0)
					if (fas_pos)
						fsm_state_nxt <= data_match_fas ? ST_MULTIFRAME_SEARCH : ST_FRAME_SEARCH;
					else
						fsm_state_nxt <= data[6] ? ST_FRAME_VALIDATE : ST_FRAME_SEARCH;
			end

			ST_MULTIFRAME_SEARCH: begin
				// Either we find a possible alignement and we proceed to
				// validate it, or we timeout and fall back to frame search
				if (bit_last & ts_is_ts0)
					if (mfa_timeout[6])
						fsm_state_nxt <= ST_FRAME_SEARCH;
					else if (ts0_msbs_match_mf)
						fsm_state_nxt <= ST_MULTIFRAME_VALIDATE;
			end

			ST_MULTIFRAME_VALIDATE: begin
				// If we get a second alignement of the MSBs at the right
				// position before the timeout, we're good and aligned !
				if (bit_last & ts_is_ts0)
					if (mfa_timeout[6])
						fsm_state_nxt <= ST_FRAME_SEARCH;
					else if (frame_mf_first & ts0_msbs_match_mf)
						fsm_state_nxt <= ST_ALIGNED;
			end

			ST_ALIGNED: begin
				// Nothing to do. Only error case cas get us out and they're
				// handled separately
			end
		endcase
	end


	// Position tracking
	// -----------------

	// Bit position
	always @(posedge clk)
		if (align_frame) begin
			bit <= 3'b000;
			bit_first <= 1'b1;
			bit_last  <= 1'b0;
		end else if (strobe) begin
			bit <= bit + 1;
			bit_first <= (bit == 3'b111);
			bit_last  <= (bit == 3'b110);
		end

	// Time Slot
	always @(posedge clk)
		if (align_frame) begin
			ts <= 5'h01;
			ts_is_ts0  <= 1'b0;
			ts_is_ts31 <= 1'b0;
		end else if (strobe & bit_last) begin
			ts <= ts + 1;
			ts_is_ts0  <= ts_is_ts31;
			ts_is_ts31 <= (ts == 5'h1e);
		end

	// Frame
	always @(posedge clk)
		if (align_mframe) begin
			frame <= 4'h0;
			frame_smf_first <= 1'b1;
			frame_smf_last  <= 1'b0;
			frame_mf_first  <= 1'b1;
			frame_mf_last   <= 1'b0;
		end else if (strobe & bit_last & ts_is_ts31) begin
			frame <= frame + 1;
			frame_smf_first <= frame_smf_last;
			frame_smf_last  <= (frame[2:0] == 3'h6);
			frame_mf_first  <= frame_mf_last;
			frame_mf_last   <= (frame == 4'he);
		end

	// Control for alignement
	assign align_frame  = (fsm_state == ST_FRAME_SEARCH);
	assign align_mframe = (fsm_state == ST_MULTIFRAME_SEARCH);


	// Helpers
	// -------

	// Frame Alignement Signal position tracking
		// During ST_FRAME_SEARCH, the frame counter is still locked until we
		// have multi-frame alignement. So just track the LSB of the frame
		// number independently so we can check the next FAS
	always @(posedge clk)
		if (align_frame)
			fas_pos <= 1'b0;
		else
			fas_pos <= fas_pos ^ (strobe & bit_last & ts_is_ts0);

	// Multi Frame Alignement timout
		// We have 8 ms = 64 frames to acquire multi frame alignement
	always @(posedge clk)
		if (align_frame)
			mfa_timeout <= 7'h3f;
		else if (strobe & bit_last & ts_is_ts0)
			mfa_timeout <= mfa_timeout - 1;

	// Track the history of all 16 TS0 MSBs
	// and also update some pre-matching flags
	always @(posedge clk)
		if (fsm_state == ST_FRAME_SEARCH) begin
			// If we're not aligned =>avoid spurious matches
			ts0_msbs <= 16'hffff;
			ts0_msbs_match_mf  <= 1'b0;
			ts0_msbs_match_crc <= 1'b0;
		end else if (strobe & ts_is_ts0 & bit_first) begin
			// We register it ASAP so that when we have the full byte (i.e.
			// when the FSM updates), the history is up to date
			ts0_msbs <= { ts0_msbs[14:0], data[0] };
			ts0_msbs_match_mf  <= (ts0_msbs_sync == 6'b001011);
			ts0_msbs_match_crc <= (crc_smf == ts0_msbs_crc);
		end

	assign ts0_msbs_sync = { ts0_msbs[14], ts0_msbs[12], ts0_msbs[10], ts0_msbs[8], ts0_msbs[6], ts0_msbs[4] };
	assign ts0_msbs_crc  = { ts0_msbs[6], ts0_msbs[4], ts0_msbs[2], ts0_msbs[0] };

	// CRC4 computation
	assign crc_in_bit  = (bit_first & ts_is_ts0 & fas_pos) ? 1'b0 : data[0];
	assign crc_in_first = bit_first & ts_is_ts0 & frame_smf_first;
	assign crc_in_valid = strobe;
	assign crc_capture  = crc_in_first;

	e1_crc4 crc_I (
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.out_crc4(crc_out),
		.clk(clk),
		.rst(rst)
	);

	always @(posedge clk)
		if (crc_capture)
			crc_smf <= crc_out;

	// Track errors of FAS, non-FAS, CRC
		// We register these detection bits and so the counter will be 'late'
		// but they're used as LOS detection which is pretty much async to the
		// rest and used to go back to ST_SEARCH_BIT anyway ...

	always @(posedge clk)
		// Only track when we're frame aligned
		if ((fsm_state != ST_MULTIFRAME_SEARCH) && (fsm_state != ST_ALIGNED)) begin
			ep_fas  <= 1'b0;
			ed_fas  <= 1'b0;
			ep_nfas <= 1'b0;
			ed_nfas <= 1'b0;
		end else begin
			ep_fas  <= strobe & bit_last & ts_is_ts0 &  fas_pos;
			ed_fas  <= strobe & bit_last & ts_is_ts0 &  fas_pos & ~data_match_fas;
			ep_nfas <= strobe & bit_last & ts_is_ts0 & ~fas_pos;
			ed_nfas <= strobe & bit_last & ts_is_ts0 & ~fas_pos & ~data[6];
		end

	always @(posedge clk)
		// CRC and MultiFrameAlign errors tracked only when properly
		// aligned to the multiframe
		if (fsm_state != ST_ALIGNED) begin
			ep_crc <= 1'b0;
			ed_crc <= 1'b0;
			ep_mfa <= 1'b0;
			ed_mfa <= 1'b0;
		end else begin
			ep_crc <= strobe & bit_last & ts_is_ts0 & frame_smf_last;
			ed_crc <= strobe & bit_last & ts_is_ts0 & frame_smf_last & ~ts0_msbs_match_crc;
			ep_mfa <= strobe & bit_last & ts_is_ts0 & frame_mf_first;
			ed_mfa <= strobe & bit_last & ts_is_ts0 & frame_mf_first & ~ts0_msbs_match_mf;
		end

	always @(posedge clk)
		if (fsm_state == ST_FRAME_SEARCH) begin
			ec_fas  <= 0;
			ec_nfas <= 0;
			ec_crc  <= 0;
			ec_mfa  <= 0;
		end else begin
			ec_fas  <= (ep_fas  & ~ed_fas)  ? 0 : (ec_fas  + ed_fas);
			ec_nfas <= (ep_nfas & ~ed_nfas) ? 0 : (ec_nfas + ed_nfas);
			ec_crc  <= (ep_crc  & ~ed_crc)  ? 0 : (ec_crc  + ed_crc);
			ec_mfa  <= (ep_mfa  & ~ed_mfa)  ? 0 : (ec_mfa  + ed_mfa);
		end

	always @(posedge clk)
		error <= (ec_fas == 2'b11) | (ec_nfas == 2'b11) | (ec_crc == 2'b11) | (ec_mfa == 2'b11);


	// Output
	// ------

	// Data output
	always @(posedge clk)
		if (rst) begin
			out_valid   <= 1'b0;
			out_data    <= 8'h00;
			out_frame   <= 4'h0;
			out_ts      <= 5'h00;
			out_ts_is0  <= 1'b1;
			out_first   <= 1'b1;
			out_last    <= 1'b0;
		end else begin
			if (TS0_START)
				out_valid <= strobe && bit_last && (
					(fsm_state == ST_ALIGNED) || (
						(fsm_state == ST_MULTIFRAME_VALIDATE) &&
						(ts_is_ts0 && ~mfa_timeout[6] && frame_mf_first && ts0_msbs_match_mf)
					)
				);
			else
				out_valid <= strobe & bit_last & (fsm_state == ST_ALIGNED);

			out_data    <= data;
			out_frame   <= frame;
			out_ts      <= ts;
			out_ts_is0  <= ts_is_ts0;
			out_first   <= ts_is_ts0  & frame_mf_first;
			out_last    <= ts_is_ts31 & frame_mf_last;
		end

	// Error indicators
	assign out_err_crc  = ed_crc;
	assign out_err_mfa  = ed_mfa;
	assign out_err_fas  = ed_fas;
	assign out_err_nfas = ed_nfas;

	// Status
	always @(posedge clk)
		if (rst)
			aligned <= 1'b0;
		else
			aligned <= fsm_state == ST_ALIGNED;

endmodule // e1_rx_deframer
