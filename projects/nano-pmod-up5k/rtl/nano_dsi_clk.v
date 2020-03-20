/*
 * nano_dsi_clk.v
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

module nano_dsi_clk (
	// nano-PMOD - CLK lane
	output wire clk_lp,
	output wire clk_hs_p,
	output wire clk_hs_n,

	// Control interface
	input  wire hs_req,
	output wire hs_rdy,

	// Clock/Data sync
	output wire clk_sync,

	// Config
	input  wire [7:0] cfg_hs_prep,
	input  wire [7:0] cfg_hs_zero,
	input  wire [7:0] cfg_hs_trail,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// IO control
	reg io_lp;

	reg io_hs_active;
	reg io_hs_bit;

	// FSM
	localparam
		ST_LP11				= 0,
		ST_LP00				= 1,
		ST_HS_ZERO			= 2,
		ST_HS_CLK			= 3,
		ST_HS_TRAIL			= 4;

	reg  [2:0] fsm_state;
	reg  [2:0] fsm_state_next;

	// Timer
	reg  [7:0] timer_val;
	wire timer_trig;

	// Clocking
	reg  clk_sync_i;


	// IOBs
	// ----

	// LP bias control
	SB_IO #(
		.PIN_TYPE(6'b100100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_lp_I (
		.PACKAGE_PIN(clk_lp),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(1'b1),
		.D_OUT_0(io_lp),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);

	// HS drivers
	SB_IO #(
		.PIN_TYPE(6'b110000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_hs_p_I (
		.PACKAGE_PIN(clk_hs_p),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(io_hs_active),
		.D_OUT_0(io_hs_bit),
		.D_OUT_1(io_hs_bit),
		.D_IN_0(),
		.D_IN_1()
	);

	SB_IO #(
		.PIN_TYPE(6'b110000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_hs_n_I (
		.PACKAGE_PIN(clk_hs_n),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(io_hs_active),
		.D_OUT_0(~io_hs_bit),
		.D_OUT_1(~io_hs_bit),
		.D_IN_0(),
		.D_IN_1()
	);


	// FSM
	// ---

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			fsm_state <= ST_LP11;
		else
			fsm_state <= fsm_state_next;

	// Next State logic
	always @(*)
	begin
		// Default is to not move
		fsm_state_next = fsm_state;

		// Transitions ?
		case (fsm_state)
			ST_LP11:
				if (hs_req)
					fsm_state_next = ST_LP00;

			ST_LP00:
				if (timer_trig)
					fsm_state_next = ST_HS_ZERO;

			ST_HS_ZERO:
				if (timer_trig)
					fsm_state_next = ST_HS_CLK;

			ST_HS_CLK:
				if (~hs_req)
					fsm_state_next = ST_HS_TRAIL;

			ST_HS_TRAIL:
				if (timer_trig)
					fsm_state_next = ST_LP11;
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
				ST_LP00:		timer_val <= cfg_hs_prep;
				ST_HS_ZERO:		timer_val <= cfg_hs_zero;
				ST_HS_TRAIL:	timer_val <= cfg_hs_trail;
			endcase
		end else begin
			timer_val  <= timer_val - 1;
		end
	end

	assign timer_trig = timer_val[7];


	// Clock sync
	// ----------

	always @(posedge clk or posedge rst)
		if (rst)
			clk_sync_i <= 1'b0;
		else
			clk_sync_i <= ~clk_sync_i;

	assign clk_sync = clk_sync_i;


	// IO control
	// ----------

	always @(posedge clk)
	begin
		io_lp <= (fsm_state == ST_LP11);

		io_hs_active <=
			(fsm_state == ST_HS_ZERO) ||
			(fsm_state == ST_HS_CLK) ||
			(fsm_state == ST_HS_TRAIL);

		io_hs_bit <= clk_sync && (fsm_state == ST_HS_CLK);
	end

endmodule // nano_dsi_clk
