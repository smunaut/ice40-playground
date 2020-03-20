/*
 * pkt_mux.v
 *
 * vim: ts=4 sw=4
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
 */

`default_nettype none

module pkt_mux #(
	parameter integer N = 3
)(
	// Multiple packet FIFOs interfaces
	input  wire [8*N-1:0] pkt_data,
	input  wire [  N-1:0] pkt_last,
	input  wire [  N-1:0] pkt_valid,
	output wire [  N-1:0] pkt_ack,

	// HS PHY interface
	output wire [7:0] hs_data,
	output wire hs_start,
	output wire hs_last,

	output wire hs_clk_req,
	input  wire hs_clk_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// FSM
	localparam
		ST_CLK_OFF	= 0,
		ST_CLK_BOOT	= 1,
		ST_CLK_RUN	= 2,
		ST_STREAM	= 3,
		ST_EOTP		= 4;

	reg  [2:0] fsm_state;
	reg  [2:0] fsm_state_next;

	// EoTp
	reg [7:0] eotp_data;
	reg [1:0] eotp_cnt;
	reg eotp_last;

	// HS clock


	// FSM
	// ---

	// State register
	always @(posedge clk)
		if (rst)
			fsm_state <= ST_CLK_OFF;
		else
			fsm_state <= fsm_state_next;

	// Next-State logic
	always @(*)
	begin
		// Default is to not move
		fsm_state_next = fsm_state;

		// Transitions ?
		case (fsm_state)
			ST_CLK_OFF:
				if ( )
					fsm_state_next = ST_STREAM;

			ST_CLK_BOOT:
				if (hs_clk_rdy)
					fsm_state_next = ST_CLK_RUN;

			ST_CLK_RUN:
				if (hs_clk_timeout)
					fsm_state_next = ST_CLK_OFF;
				else if ( )
					fsm_state_next = ST_STREAM;

			ST_STREAM:
				if ( )
					fsm_state_next = ST_EOTP;

			ST_EOTP:
				if (hs_ack & eotp_last)
					fsm_state_next = ST_CLK_RUN;
		endcase
	end


	// EoTp logic
	// ----------

	always @(posedge clk)
		if (fsm_state != ST_EOTP) begin
			eotp_cnt  <= 2'b00;
			eotp_last <= 1'b0;
		end else if (hs_ack) begin
			eotp_cnt  <= eotp_cnt + 1;
			eotp_last <= (eotp_cnt == 2'b10);
		end

	always @(eotp_cnt)
		case (eotp_cnt)
			2'b00: eotp_data = 8'h08;
			2'b01: eotp_data = 8'h0f;
			2'b10: eotp_data = 8'h0f;
			2'b11: eotp_data = 8'h01;
		endcase


	// HS clock
	// --------

	reg [15:0] hs_clk_timer;
	wire hs_clk_timeout;

	// Request
	assign hs_clk_req = (fsm_state != ST_CLK_OFF);

	// Time-Out
	always @(posedge clk)
		if (fsm_state != ST_CLK_RUN)
			hs_clk_timer <= 0;
		else if (~hs_clk_timeout)
			hs_clk_timer <= hs_clk_timer + 1

	assign hs_clk_timeout <= hs_clk_timer[15];


	// Data mux
	// --------

	// "Any" valid - Is there any channel valid

	// "Any Other" valid - Is there any channel valid other than the current one



	input  wire [8*N-1:0] pkt_data,
	input  wire [  N-1:0] pkt_last,
	input  wire [  N-1:0] pkt_valid,
	output wire [  N-1:0] pkt_ack,

	// Data mux
	// --------



endmodule // pkt_mux
