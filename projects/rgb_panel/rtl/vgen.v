/*
 * vgen.v
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * vim: ts=4 sw=4
 */

`default_nettype none

module vgen #(
	parameter ADDR_BASE = 24'h040000,
	parameter integer N_FRAMES = 30,
	parameter integer N_ROWS   = 64,	// # of rows (must be power of 2!!!)
	parameter integer N_COLS   = 64,	// # of columns
	parameter integer BITDEPTH = 24,

	// Auto-set
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS),
	parameter integer LOG_N_COLS  = $clog2(N_COLS)
)(
	// SPI reader interface
	output wire [23:0] sr_addr,
	output wire [15:0] sr_len,
	output wire sr_go,
	input  wire sr_rdy,

	input wire [7:0] sr_data,
	input wire sr_valid,

	// Frame Buffer write interface
	output wire [LOG_N_ROWS-1:0] fbw_row_addr,
	output wire fbw_row_store,
	input  wire fbw_row_rdy,
	output wire fbw_row_swap,

	output wire [BITDEPTH-1:0] fbw_data,
	output wire [LOG_N_COLS-1:0] fbw_col_addr,
	output wire fbw_wren,

	output wire frame_swap,
	input  wire frame_rdy,

	// UI
	input  wire ui_up,
	input  wire ui_mode,
	input  wire ui_down,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam integer FW = 23 - LOG_N_ROWS - LOG_N_COLS;

	// Signals
	// -------

	// FSM
	localparam
		ST_FRAME_WAIT	= 0,
		ST_ROW_SPI_CMD	= 1,
		ST_ROW_SPI_READ	= 2,
		ST_ROW_WRITE	= 3,
		ST_ROW_WAIT		= 4;

	reg  [2:0] fsm_state;
	reg  [2:0] fsm_state_next;

	// UI
	reg mode;
	reg [3:0] cfg_rep;
	reg [1:0] frame_sel;

	// Counters
	reg [FW-1:0] cnt_frame;
	reg cnt_frame_first;
	reg cnt_frame_last;

	reg [3:0] cnt_rep;
	reg cnt_rep_last;

	reg [LOG_N_ROWS-1:0] cnt_row;
	reg cnt_row_last;

	reg [LOG_N_COLS:0] cnt_col;

	// SPI
	reg [7:0] sr_data_r;
	wire [15:0] sr_data16;

	// Output
	wire [7:0] color [0:2];


	// FSM
	// ---

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			fsm_state <= ST_FRAME_WAIT;
		else
			fsm_state <= fsm_state_next;

	// Next-State logic
	always @(*)
	begin
		// Default is not to move
		fsm_state_next = fsm_state;

		// Transitions ?
		case (fsm_state)
			ST_FRAME_WAIT:
				if (frame_rdy & sr_rdy)
					fsm_state_next = ST_ROW_SPI_CMD;

			ST_ROW_SPI_CMD:
				fsm_state_next = ST_ROW_SPI_READ;

			ST_ROW_SPI_READ:
				if (sr_rdy)
					fsm_state_next = ST_ROW_WRITE;

			ST_ROW_WRITE:
				if (fbw_row_rdy)
					fsm_state_next = cnt_row_last ? ST_ROW_WAIT : ST_ROW_SPI_CMD;

			ST_ROW_WAIT:
				if (fbw_row_rdy)
					fsm_state_next = ST_FRAME_WAIT;
		endcase
	end


	// UI handling
	// -----------

	// Mode toggle
	always @(posedge clk or posedge rst)
		if (rst)
			mode <= 1'b0;
		else
			mode <= mode ^ ui_mode;

	// Repetition counter
	always @(posedge clk or posedge rst)
		if (rst)
			cfg_rep <= 4'h6;
		else if (~mode) begin
			if (ui_down & ~&cfg_rep)
				cfg_rep <= cfg_rep + 1;
			else if (ui_up & |cfg_rep)
				cfg_rep <= cfg_rep - 1;
		end

	// Latch request for prev / next frame
	always @(posedge clk)
		if (~mode)
			frame_sel <= cnt_rep_last ? 2'b10 : 2'b00;
		else if ((fsm_state == ST_ROW_WAIT) && fbw_row_rdy)
			frame_sel <= 2'b00;
		else if (ui_up)
			frame_sel <= 2'b10;
		else if (ui_down)
			frame_sel <= 2'b11;


	// Counters
	// --------

	// Frame counter
	always @(posedge clk or posedge rst)
		if (rst)
			cnt_frame <= 0;
		else if ((fsm_state == ST_ROW_WAIT) && fbw_row_rdy && frame_sel[1])
			if (frame_sel[0])
				cnt_frame <= cnt_frame_last  ? { (FW){1'b0} } : (cnt_frame + 1);
			else
				cnt_frame <= cnt_frame_first ? (N_FRAMES - 1) : (cnt_frame - 1);

	always @(posedge clk)
	begin
		// Those end up one cycle late vs 'cnt_frame' but that's fine, they
		// won't be used until a while later
		cnt_frame_last  <= (cnt_frame == (N_FRAMES - 1));
		cnt_frame_first <= (cnt_frame == 0);
	end

	// Repeat counter
	always @(posedge clk)
		if ((fsm_state == ST_ROW_WAIT) && fbw_row_rdy) begin
			cnt_rep <= cnt_rep_last ? 4'h0 : (cnt_rep + 1);
			cnt_rep_last <= (cnt_rep == cfg_rep);
		end

	// Row counter
	always @(posedge clk)
		if (fsm_state == ST_FRAME_WAIT) begin
			cnt_row <= 0;
			cnt_row_last <= 1'b0;
		end else if ((fsm_state == ST_ROW_WRITE) && fbw_row_rdy) begin
			cnt_row <= cnt_row + 1;
			cnt_row_last <= (cnt_row == (1 << LOG_N_ROWS) - 2);
		end

	// Column counter
	always @(posedge clk)
		if (fsm_state != ST_ROW_SPI_READ)
			cnt_col <= 0;
		else if (sr_valid)
			cnt_col <= cnt_col + 1;


	// SPI reader
	// ----------

	// Requests
	assign sr_addr = { cnt_frame, cnt_row, {(LOG_N_COLS+1){1'b0}} } + ADDR_BASE;
	assign sr_len = (N_COLS << 1) - 1;
	assign sr_go = (fsm_state == ST_ROW_SPI_CMD);

	// Data
	always @(posedge clk)
		if (sr_valid)
			sr_data_r <= sr_data;
	
	assign sr_data16 = { sr_data, sr_data_r };


	// Front-Buffer write
	// ------------------

	assign fbw_wren = sr_valid & cnt_col[0];
	assign fbw_col_addr = cnt_col[6:1];

	// Map to color
	assign color[2] = { sr_data16[15:11], sr_data16[15:13] };
	assign color[1] = { sr_data16[10: 5], sr_data16[10: 9] };
	assign color[0] = { sr_data16[ 4: 0], sr_data16[ 4: 2] };

	generate
		if (BITDEPTH == 8)
			assign fbw_data = { color[2][7:5], color[1][7:5], color[0][7:6] };
		else if (BITDEPTH == 16)
			assign fbw_data = { color[2][7:3], color[1][7:2], color[0][7:3] };
		else if (BITDEPTH == 24)
			assign fbw_data = { color[2], color[1], color[0] };
	endgenerate


	// Back-Buffer store
	// -----------------

	assign fbw_row_addr  = cnt_row;
	assign fbw_row_store = (fsm_state == ST_ROW_WRITE) && fbw_row_rdy;
	assign fbw_row_swap  = (fsm_state == ST_ROW_WRITE) && fbw_row_rdy;


	// Next frame
	// ----------

	assign frame_swap = (fsm_state == ST_ROW_WAIT) && fbw_row_rdy;

endmodule // vgen
