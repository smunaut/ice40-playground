/*
 * hub75_bcm.v
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

module hub75_bcm #(
	parameter integer N_ROWS   = 32,
	parameter integer N_PLANES = 8,

	// Auto-set
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS)
)(
	// PHY
	output wire phy_addr_inc,
	output wire phy_addr_rst,
	output wire [LOG_N_ROWS-1:0] phy_addr,
	output wire phy_le,

	// Shifter interface
	output wire [N_PLANES-1:0] shift_plane,
	output wire shift_go,
	input  wire shift_rdy,

	// Blanking interface
	output wire [N_PLANES-1:0] blank_plane,
	output wire blank_go,
	input  wire blank_rdy,

	// Control
	input  wire [LOG_N_ROWS-1:0] ctrl_row,
	input  wire ctrl_row_first,
	input  wire ctrl_go,
	output wire ctrl_rdy,

	// Config
	input  wire [7:0] cfg_pre_latch_len,
	input  wire [7:0] cfg_latch_len,
	input  wire [7:0] cfg_post_latch_len,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	genvar i;

	// Signals
	// -------

	// FSM
	localparam
		ST_IDLE				= 0,
		ST_SHIFT			= 1,
		ST_WAIT_TO_LATCH	= 2,
		ST_PRE_LATCH		= 3,
		ST_DO_LATCH			= 4,
		ST_POST_LATCH		= 5,
		ST_ISSUE_BLANK		= 6;

	reg  [2:0] fsm_state;
	reg  [2:0] fsm_state_next;

	reg  [7:0] timer_val;
	wire timer_trig;

	reg  [N_PLANES-1:0] plane;
	wire plane_last;

	reg  [LOG_N_ROWS-1:0] addr;
	reg  [LOG_N_ROWS-1:0] addr_out;
	reg  addr_do_inc;
	reg  addr_do_rst;
	wire le;


	// FSM
	// ---

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			fsm_state <= ST_IDLE;
		else
			fsm_state <= fsm_state_next;

	// Next-State logic
	always @(*)
	begin
		// Default is to not move
		fsm_state_next = fsm_state;

		// Transitions ?
		case (fsm_state)
			ST_IDLE:
				if (ctrl_go)
					fsm_state_next = ST_SHIFT;

			ST_SHIFT:
				fsm_state_next = ST_WAIT_TO_LATCH;

			ST_WAIT_TO_LATCH:
				if (shift_rdy & blank_rdy)
					fsm_state_next = ST_PRE_LATCH;

			ST_PRE_LATCH:
				if (timer_trig)
					fsm_state_next = ST_DO_LATCH;

			ST_DO_LATCH:
				if (timer_trig)
					fsm_state_next = ST_POST_LATCH;

			ST_POST_LATCH:
				if (timer_trig)
					fsm_state_next = ST_ISSUE_BLANK;

			ST_ISSUE_BLANK:
				fsm_state_next = plane_last ? ST_IDLE : ST_SHIFT;
		endcase
	end


	// Timer
	// -----

	always @(posedge clk)
	begin
		if (fsm_state != fsm_state_next) begin
			// Default is to trigger all the time
			timer_val <= 8'h80;

			// Preload for next state
			case (fsm_state_next)
				ST_PRE_LATCH:	timer_val <= cfg_pre_latch_len;
				ST_DO_LATCH:	timer_val <= cfg_latch_len;
				ST_POST_LATCH:	timer_val <= cfg_post_latch_len;
			endcase
		end else begin
			timer_val <= timer_val - 1;
		end
	end

	assign timer_trig = timer_val[7];


	// Plane counter
	// -------------

	always @(posedge clk)
		if (fsm_state == ST_IDLE)
			plane <= { {(N_PLANES-1){1'b0}}, 1'b1 };
		else if (fsm_state == ST_ISSUE_BLANK)
			plane <= { plane[N_PLANES-2:0], 1'b0 };

	assign plane_last = plane[N_PLANES-1];


	// External Control
	// ----------------

	// Shifter
	assign shift_plane = plane;
	assign shift_go = (fsm_state == ST_SHIFT);

	// Blanking
	assign blank_plane = plane;
	assign blank_go = (fsm_state == ST_ISSUE_BLANK);

	// Address
	always @(posedge clk)
		if (ctrl_go)
			addr <= ctrl_row;

	always @(posedge clk)
	begin
		addr_do_inc <= (addr_do_inc | (ctrl_go & ~ctrl_row_first)) & ~(fsm_state == ST_POST_LATCH);
		addr_do_rst <= (addr_do_rst | (ctrl_go &  ctrl_row_first)) & ~(fsm_state == ST_POST_LATCH);
	end

	always @(posedge clk)
		if (fsm_state == ST_DO_LATCH)
			addr_out <= addr;

	// Latch
	assign le = (fsm_state == ST_DO_LATCH);

	// Ready ?
	assign ctrl_rdy = (fsm_state == ST_IDLE);


	// PHY
	// ---

	assign phy_addr = addr_out;
	assign phy_le = le;

	assign phy_addr_inc = (fsm_state == ST_DO_LATCH) ? addr_do_inc : 1'b0;
	assign phy_addr_rst = (fsm_state == ST_DO_LATCH) ? addr_do_rst : 1'b0;

endmodule // hub75_bcm
