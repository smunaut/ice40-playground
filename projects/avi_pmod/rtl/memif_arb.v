/*
 * memif_arb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module memif_arb #(
	parameter integer AW = 22,
	parameter integer DW = 32,
	parameter WRITE_DISABLE = 2'b00,

	// auto-set
	parameter integer AL = AW - 1,
	parameter integer DL = DW - 1
)(
	// Upstream (to controller)
	output reg  [AL:0] u_addr,
	output reg  [ 6:0] u_len,
	output reg         u_rw,
	output wire        u_valid,
	input  wire        u_ready,

	output reg  [DL:0] u_wdata,
	input  wire        u_wack,
	input  wire        u_wlast,

	input  wire [DL:0] u_rdata,
	input  wire        u_rstb,
	input  wire        u_rlast,

	// Downstream 0
	input  wire [AL:0] d0_addr,
	input  wire [ 6:0] d0_len,
	input  wire        d0_rw,
	input  wire        d0_valid,
	output wire        d0_ready,

	input  wire [DL:0] d0_wdata,
	output wire        d0_wack,
	output wire        d0_wlast,

	output wire [DL:0] d0_rdata,
	output wire        d0_rstb,
	output wire        d0_rlast,

	// Downstream 1
	input  wire [AL:0] d1_addr,
	input  wire [ 6:0] d1_len,
	input  wire        d1_rw,
	input  wire        d1_valid,
	output wire        d1_ready,

	input  wire [DL:0] d1_wdata,
	output wire        d1_wack,
	output wire        d1_wlast,

	output wire [DL:0] d1_rdata,
	output wire        d1_rstb,
	output wire        d1_rlast,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// FSM
	localparam [1:0]
		ST_IDLE = 0,
		ST_CMD  = 1,
		ST_WAIT = 2;

	reg  [1:0] state;
	reg  [1:0] state_nxt;

	// Mux control
	reg        mux_prio;
	reg        mux_sel;
	wire       mux_sel_nxt;


	// FSM & Control
	// -------------

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next state
	always @(*)
	begin
		// Default is no change
		state_nxt = state;

		// Transitions
		case (state)
			ST_IDLE:
				if (d0_valid | d1_valid)
					state_nxt = ST_CMD;

			ST_CMD:
				if (u_ready)
					state_nxt = ST_WAIT;

			ST_WAIT:
				if ((u_wlast & u_wack) | (u_rlast & u_rstb))
					state_nxt = ST_IDLE;
		endcase
	end


	// Command Mux
	// -----------

	// Valid
	assign u_valid = (state == ST_CMD);

	// Decide next
	assign mux_sel_nxt = mux_prio ? d1_valid : ~d0_valid;

	// Always register next when idle
	always @(posedge clk)
		if (state == ST_IDLE) begin
			// Mux select
			mux_sel <= mux_sel_nxt;

			// Command
			u_addr <= mux_sel_nxt ? d1_addr : d0_addr;
			u_len  <= mux_sel_nxt ? d1_len  : d0_len;
			u_rw   <= mux_sel_nxt ? d1_rw   : d0_rw;
		end
	
	// Accept command
	// (technically we already registered all the info so we don't need to
	// wait for u_ready but we need to raise ready for a single cycle)
	assign d0_ready = (state == ST_CMD) & (mux_sel == 1'b0) & u_ready;
	assign d1_ready = (state == ST_CMD) & (mux_sel == 1'b1) & u_ready;

	// Toggle priority
	always @(posedge clk)
		if (state == ST_CMD)
			mux_prio <= ~mux_sel;


	// Write Data mux
	// --------------

	// Data
	always @(*)
	begin
		u_wdata = 32'hxxxxxxxx;

		if ((mux_sel == 1'b0) & ~WRITE_DISABLE[0])
			u_wdata = d0_wdata;
		else if ((mux_sel == 1'b1) & ~WRITE_DISABLE[1])
			u_wdata = d1_wdata;
	end

	// Downstream 0
	assign d0_wack  = u_wack  & (mux_sel == 1'b0);
	assign d0_wlast = u_wlast;

	// Downstream 1
	assign d1_wack  = u_wack  & (mux_sel == 1'b1);
	assign d1_wlast = u_wlast;


	// Read Data mux
	// -------------

	// Downstream 0
	assign d0_rdata = u_rdata;
	assign d0_rstb  = u_rstb  & (mux_sel == 1'b0);
	assign d0_rlast = u_rlast;

	// Downstream 1
	assign d1_rdata = u_rdata;
	assign d1_rstb  = u_rstb  & (mux_sel == 1'b1);
	assign d1_rlast = u_rlast;

endmodule // memif_arb
