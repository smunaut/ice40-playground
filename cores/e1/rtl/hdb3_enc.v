/*
 * hdb3_enc.v
 *
 * vim: ts=4 sw=4
 *
 * HDB3 bit ->symbols encoding as described in G.703
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

module hdb3_enc (
	// Input
	input  wire in_data,
	input  wire in_valid,

	// Output
	output wire out_pos,
	output wire out_neg,
	output reg  out_valid,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	reg [3:0] d_pos;
	reg [3:0] d_neg;

	reg [1:0] zcnt;		// Zero-Count
	reg pstate;			// Pulse state
	reg vstate; 		// Violation state

	// Output
	assign out_pos = d_pos[3];
	assign out_neg = d_neg[3];

	always @(posedge clk)
		out_valid <= in_valid;

	// Main logic
	always @(posedge clk)
	begin
		if (rst) begin
			// Reset state
			d_pos  <= 4'h0;
			d_neg  <= 4'h0;
			zcnt   <= 2'b00;
			pstate <= 1'b0;
			vstate <= 1'b0;

		end else if (in_valid) begin
			// Check for 4 zeros
			if ((zcnt == 2'b11) && (in_data == 1'b0)) begin
				// This is a run, handle special case
				// But need to check if it's 000V or B00V
				if (pstate == vstate) begin
					// Pulse State is the same state as the last violation
					// state. So this next violation state is going to be
					// opposite polarity, so no DC to compensate -> 000V

						// New data: Violation bit
					d_pos[0] <=  pstate;
					d_neg[0] <= ~pstate;

						// Shift reg
					d_pos[3:1] <= d_pos[2:0];
					d_neg[3:1] <= d_neg[2:0];

						// Zero count: Reset
					zcnt <= 2'b00;

						// Pulse state tracking
					pstate <= pstate;

						// Violation state tracking
					vstate <= vstate ^ 1;

				end else begin
					// Pulse State is the opposite state as the last violation
					// state. So this next violation would be the same
					// polarity ... need to use B00V to avoid DC

						// New data: Violation bit
					d_pos[0] <= ~pstate;
					d_neg[0] <=  pstate;

						// Shift reg
					d_pos[2:1] <= d_pos[1:0];
					d_neg[2:1] <= d_neg[1:0];

						// Balancing bit
					d_pos[3] <= ~pstate;
					d_neg[3] <=  pstate;

						// Zero count: Reset
					zcnt <= 2'b00;

						// Pulse state tracking
					pstate <= pstate ^ 1;

						// Violation state tracking
					vstate <= vstate ^ 1;
				end
			end else begin
				// Normal case
					// New data
				d_pos[0] <= in_data & ~pstate;
				d_neg[0] <= in_data &  pstate;

					// Shift reg
				d_pos[3:1] <= d_pos[2:0];
				d_neg[3:1] <= d_neg[2:0];

					// Zero count
				if (in_data == 1'b0)
					zcnt <= zcnt + 1;
				else
					zcnt <= 2'b00;

					// Pulse state tracking
				pstate <= pstate ^ in_data;

					// Violation state tracking
				vstate <= vstate;
			end
		end
	end

endmodule // hdb3_enc
