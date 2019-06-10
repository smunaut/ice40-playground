/*
 * hub75_scan.v
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

module hub75_scan #(
	parameter integer N_ROWS   = 32,

	parameter SCAN_MODE = "ZIGZAG",		// 'LINEAR' or 'ZIGZAG'

	// Auto-set
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS)
)(
	// BCM interface
	output wire [LOG_N_ROWS-1:0] bcm_row,
	output wire bcm_row_first,
	output wire bcm_go,
	input  wire bcm_rdy,

	// Frame buffer read interface
	output wire [LOG_N_ROWS-1:0] fb_row_addr,
	output wire fb_row_load,	// Back-buffer load request
	input  wire fb_row_rdy,		// Back-buffer loaded
	output wire fb_row_swap,	// Buffer swap

	// Control
	input  wire ctrl_go,
	output wire ctrl_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// FSM
	localparam
		ST_IDLE		= 0,	// Idle
		ST_LOAD		= 1,	// Load back-buffer with next-row
		ST_WAIT		= 2,	// Wait for back-buffer & BCM to be ready
		ST_PAINT	= 3;	// Swap buffer, issue BCM paint, go to next row

	reg [1:0] fsm_state;
	reg [1:0] fsm_state_next;

	// Row counter
	reg [LOG_N_ROWS-1:0] row;
	reg row_first;
	reg row_last;


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
					fsm_state_next = ST_LOAD;

			ST_LOAD:
				fsm_state_next = ST_WAIT;

			ST_WAIT:
				if (bcm_rdy & fb_row_rdy)
					fsm_state_next = ST_PAINT;

			ST_PAINT:
				fsm_state_next = row_last ? ST_IDLE : ST_LOAD;
		endcase
	end


	// Row counter
	// -----------

	always @(posedge clk)
		if (fsm_state == ST_IDLE) begin
			row <= 0;
			row_first <= 1'b1;
			row_last  <= 1'b0;
		end else if (fsm_state == ST_PAINT) begin
			if (SCAN_MODE == "ZIGZAG") begin
				row <= ~(row + {LOG_N_ROWS{row[LOG_N_ROWS-1]}});
				row_first <= 1'b0;
				row_last  <= (row == {1'b0, {(LOG_N_ROWS-1){1'b1}}});
			end else begin
				row <= row + 1;
				row_first <= 1'b0;
				row_last  <= (row == {{(LOG_N_ROWS-1){1'b1}}, 1'b0});
			end
		end


	// External interfaces
	// -------------------

	// BCM
	assign bcm_row       = row;
	assign bcm_row_first = row_first;
	assign bcm_go        = (fsm_state == ST_PAINT);

	// Frame Buffer pre loader
	assign fb_row_addr = row;
	assign fb_row_load = (fsm_state == ST_LOAD);
	assign fb_row_swap = (fsm_state == ST_PAINT);

	// Ready signal
	assign ctrl_rdy = (fsm_state == ST_IDLE);

endmodule // hub75_scan
