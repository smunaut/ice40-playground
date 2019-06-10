/*
 * hub75_init_inject.v
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

module hub75_init_inject #(
	parameter integer N_BANKS  = 2,
	parameter integer N_ROWS   = 32,
	parameter integer N_COLS   = 64,
	parameter integer N_CHANS  = 3,

	parameter INIT_R1 = 16'h7FFF,
	parameter INIT_R2 = 16'h0040,

	// Auto-set
	parameter integer SDW         = N_BANKS * N_CHANS,
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS),
	parameter integer LOG_N_COLS  = $clog2(N_COLS)
)(
	// PHY interface signals input
	input  wire phy_in_addr_inc,
	input  wire phy_in_addr_rst,
	input  wire [LOG_N_ROWS-1:0] phy_in_addr,
	input  wire [SDW-1:0] phy_in_data,
	input  wire phy_in_clk,
	input  wire phy_in_le,
	input  wire phy_in_blank,

	// PHY interface signals input
	output reg  phy_out_addr_inc,
	output reg  phy_out_addr_rst,
	output reg  [LOG_N_ROWS-1:0] phy_out_addr,
	output reg  [SDW-1:0] phy_out_data,
	output reg  phy_out_clk,
	output reg  phy_out_le,
	output reg  phy_out_blank,

	// Control
	input  wire init_req,

	input  wire scan_go_in,

	input  wire bcm_rdy_in,
	output wire bcm_rdy_out,

	input  wire shift_rdy_in,
	input  wire blank_rdy_in,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// FSM
	localparam
		ST_IDLE		= 0,	// Idle
		ST_WAIT		= 1,	// Wait for all activity to be done so we can use the PHY
		ST_SHIFT	= 2,	// Shift the init
		ST_GO		= 3;	// Issue go to scan block

	reg [1:0] fsm_state;
	reg [1:0] fsm_state_next;

	// Request
	reg init_done;

	// Injection
	wire active;
	wire inject_data;
	wire inject_le;

	// Shift logic
	reg  [LOG_N_COLS:0] col_cnt;
	reg  col_last;
	reg  col_le;
	wire col_rst;

	reg  reg_sel;
	(* keep="true" *) wire [1:0] reg_bit;


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

		// Transistions ?
		case (fsm_state)
			ST_IDLE:
				if (scan_go_in & ~init_done)
					fsm_state_next = ST_WAIT;

			ST_WAIT:
				if (bcm_rdy_in & shift_rdy_in & blank_rdy_in)
					fsm_state_next = ST_SHIFT;

			ST_SHIFT:
				if (col_last & reg_sel)
					fsm_state_next = ST_GO;

			ST_GO:
				fsm_state_next = ST_IDLE;
		endcase
	end


	// Control
	// -------

	always @(posedge clk)
		if (rst)
			init_done <= 1'b0;
		else
			init_done <= (init_done | (fsm_state == ST_GO)) & ~init_req;

	// External handshake
	assign bcm_rdy_out = (fsm_state == ST_IDLE) & bcm_rdy_in;


	// Init sequence shift
	// -------------------

	// Flag
	assign active = (fsm_state == ST_SHIFT);

	// Column counter
	assign col_rst = col_last | (fsm_state != ST_SHIFT);

	always @(posedge clk)
		if (col_rst) begin
			col_cnt  <= N_COLS - 17;
			col_last <= 1'b0;
			col_le   <= 1'b0;
		end else begin
			col_cnt  <= col_cnt - 1;
			col_last <= col_cnt[LOG_N_COLS] & (col_cnt[3:0] == 4'h1);
			col_le   <= col_cnt[LOG_N_COLS] & (col_cnt[3:0] < (reg_sel ? 4'hd : 4'hc));
		end
	
	// Reg select
	always @(posedge clk)	
		reg_sel <= (fsm_state == ST_SHIFT) ? (reg_sel ^ col_last) : 1'b0;

	// ROM
	assign reg_bit[0] = INIT_R1[col_cnt[3:0]];
	assign reg_bit[1] = INIT_R2[col_cnt[3:0]];

	// Outputs
	assign inject_data = reg_bit[reg_sel];
	assign inject_le   = col_le;


	// PHY signal injection
	// --------------------

	always @(posedge clk)
	begin
		phy_out_addr_inc <= ~active ? phy_in_addr_inc : 1'b0;
		phy_out_addr_rst <= ~active ? phy_in_addr_rst : 1'b0;
		phy_out_addr     <= ~active ? phy_in_addr     : { LOG_N_ROWS{1'b0} };
		phy_out_data     <= ~active ? phy_in_data     : { SDW{inject_data} };
		phy_out_clk      <= ~active ? phy_in_clk      : 1'b1;
		phy_out_le       <= ~active ? phy_in_le       : inject_le;
		phy_out_blank    <= ~active ? phy_in_blank    : 1'b1;
	end

endmodule
