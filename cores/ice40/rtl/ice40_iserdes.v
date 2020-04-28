/*
 * ice40_iserdes.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
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

module ice40_iserdes #(
	parameter EDGE_SEL  = "SINGLE_POS",	// "SINGLE_POS" / "SINGLE_NEG" / "DUAL_POS" / "DUAL_POS_NEG"
	parameter PHASE_SEL = "STATIC",		// "STATIC" / "DYNAMIC"
	parameter integer PHASE = 0,
	parameter integer SERDES_GRP = 0
)(
	input  wire [1:0] d,
	output wire [3:0] q,
	input  wire       edge_sel,
	input  wire [1:0] phase_sel,
	input  wire       sync,
	input  wire       clk_1x,
	input  wire       clk_4x
);

	genvar i, j;

	/* 				 0	 1
	 * SINGLE_POS	POS	 /
	 * SINGLE_NEG	NEG  /
	 * DUAL_POS		POS  /
	 * DUAL_POS_NEG	POS	NEG
	 */

	// FIXME: The DUAL_POS_NEG mode would need a negative edge sync signal as
	// well


	// Signals
	// -------

	wire [3:0] shift_in[0:1];
	wire [3:0] shift_out[0:1];

	wire [3:0] fcap_in[0:1];
	wire [3:0] fcap_out[0:1];


	// Fast paths
	// ----------

	// - For the "SINGLE_{POS,NEG}", we only have a single path
	// - For the "DUAL_POS_POS" case it's a single path as well with a pre-sel
	//   mux. If dynamic phase is also enabled, this option will have an added
	//   delay (because need for mux between path and between phase)
	// - For the "DUAL_POS_NEG" case, we have two independent paths

	generate
		for (j=0; j<2; j=j+1) begin
			if ((j == 0) || (EDGE_SEL == "DUAL_POS_NEG"))
			begin : fp
				localparam IS_NEG = (EDGE_SEL == "SINGLE_NEG") || (j == 1);
				wire edge_active;
				wire din_mux;
				wire din;

				// Edge Select
				// -----------

				assign edge_active = (EDGE_SEL != "DUAL_POS_NEG") || (edge_sel == j);

				if (EDGE_SEL == "DUAL_POS_POS") begin
					// Need a pre-mux
					(* dont_touch *)
					SB_LUT4 #(
						.LUT_INIT(16'hFC30)
					) lut_edgemux_I (
						.I0(1'b0),
						.I1(edge_sel),
						.I2(d[0]),
						.I3(d[1]),	// Fast Path for the neg-edge
						.O(din_mux)
					);

					if (PHASE_SEL == "DYNAMIC")
						// If we have dynamic phase, we need the added stage
						// for timing
						ice40_serdes_dff #(
							.NEG(IS_NEG),
							.SERDES_GRP( (SERDES_GRP << 8) | 'h4b0 | (j << 4) )
						) dff_edgemux_I (
							.d(din_mux),
							.q(din),
							.c(clk_4x)
						);
					else
						// This mux can be packed with the first shift
						// register stage
						assign din = din_mux;

				end else begin
					// Directly from IOB signal
					assign din = d[j];
				end


				// Shifter
				// -------

				assign shift_in[j] = { shift_out[j][2:0], din };

				for (i=0; i<4; i=i+1)
				begin
					ice40_serdes_dff #(
						.NEG(IS_NEG),
						.SERDES_GRP( (SERDES_GRP << 8) | 'h4a0 | (j << 4) | i )
					) dff_shift_I (
						.d(shift_in[j][i]),
						.q(shift_out[j][i]),
						.c(clk_4x)
					);
				end


				// Fast Capture
				// ------------

				// If we have dynamic phase selection, apply the LSB here
				if (PHASE_SEL == "DYNAMIC")
					assign fcap_in[j] = edge_active ? (phase_sel[0] ? shift_out[j] : shift_in[j]) : 4'h0;
				else
					assign fcap_in[j] = edge_active ? shift_out[j] : 4'h0;

				// Register
				for (i=0; i<4; i=i+1)
				begin
					ice40_serdes_dff #(
						.NEG(IS_NEG),
						.ENA(1),
						.SERDES_GRP( (SERDES_GRP << 8) | 'h490 | (j << 4) | i )
					) dff_shift_I (
						.d(fcap_in[j][i]),
						.q(fcap_out[j][i]),
						.e(sync),
						.c(clk_4x)
					);
				end
			end
			else
			begin
				// Dummy
				assign fcap_out[j]  = 4'h0;
			end
		end
	endgenerate


	// Slow Capture
	// ------------

	generate
		if (PHASE_SEL == "STATIC")
		begin
			// Static Phase
			// - - - - - - -

			wire [3+PHASE:0] scap_in;
			wire [3+PHASE:0] scap_out;

			// Input
			if (PHASE > 0)
				assign scap_in[3+PHASE:4] = scap_out[PHASE-1:0];

			assign scap_in[3:0] = fcap_out[0] | fcap_out[1];

			// Registers
			for (i=0; i<(4+PHASE); i=i+1)
				ice40_serdes_dff #(
					.SERDES_GRP( (SERDES_GRP << 8) | 'h680 | i )
				) dff_scap_I (
					.d(scap_in[i]),
					.q(scap_out[i]),
					.c(clk_1x)
				);

			// Output
			assign q = scap_out[3+PHASE:PHASE];
		end
		else
		begin
			// Dynamic Phase
			// - - - - - - -

			wire [5:0] scap_in;
			wire [5:0] scap_out;

			// Input
			if (EDGE_SEL == "DUAL_POS_NEG")
			begin

				// Dual Edge Path
				// - - - - - - - -

				wire [1:0] scap_pre_or;

				// Pre-OR
				(* SERDES_GRP=( (SERDES_GRP << 8) | 'h680 | 6 ) *)
				(* dont_touch *)
				SB_LUT4 #(
					.LUT_INIT(16'hFFF0)
				) or_lut_2_I (
					.I0(1'b0),
					.I1(1'b0),
					.I2(fcap_out[1][2]),
					.I3(fcap_out[0][2]),
					.O(scap_pre_or[0])
				);

				(* SERDES_GRP=( (SERDES_GRP << 8) | 'h680 | 7 ) *)
				(* dont_touch *)
				SB_LUT4 #(
					.LUT_INIT(16'hFFF0)
				) or_lut_3_I (
					.I0(1'b0),
					.I1(1'b0),
					.I2(fcap_out[1][3]),
					.I3(fcap_out[0][3]),
					.O(scap_pre_or[1])
				);

				// Main muxes
				(* dont_touch *)
				SB_LUT4 #(
					.LUT_INIT(16'hFE54)
				) mux_lut_I[3:0] (
					.I0(phase_sel[1]),
					.I1(fcap_out[1][3:0]),
					.I2(fcap_out[0][3:0]),
					.I3({scap_out[5:4], scap_pre_or}),
					.O(scap_in[3:0])
				);

				// Save regs
				assign scap_in[5:4] = fcap_out[0][1:0] | fcap_out[1][1:0];

			end
			else
			begin

				// Single Edge Path
				// - - - - - - - - -

				assign scap_in = {
					fcap_out[0][1:0],
					phase_sel[1] ?
						{ scap_out[5:4], fcap_out[0][3:2] } :
						fcap_out[0][3:0]
				};

			end

			// Registers
			for (i=0; i<6; i=i+1)
				ice40_serdes_dff #(
					.SERDES_GRP( (SERDES_GRP << 8) | 'h680 | i )
				) dff_scap_I (
					.d(scap_in[i]),
					.q(scap_out[i]),
					.c(clk_1x)
				);

			// Output
			assign q = scap_out[3:0];
		end
	endgenerate

endmodule
