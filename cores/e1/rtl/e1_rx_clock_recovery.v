/*
 * e1_rx_clock_recovery.v
 *
 * vim: ts=4 sw=4
 *
 * E1 Clock recovery/sampling
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

module e1_rx_clock_recovery (
	// Input
	input  wire in_hi,
	input  wire in_lo,
	input  wire in_stb,

	// Output
	output wire out_hi,
	output wire out_lo,
	output wire out_stb,

	// Common
	input  wire clk,
	input  wire rst
);

	reg [5:0] cnt;
	reg enabled;

	always @(posedge clk)
		if (rst)
			enabled <= 1'b0;
		else
			enabled <= enabled | in_stb;

	always @(posedge clk)
	begin
		if (rst)
			cnt <= 5'h0f;
		else begin
			if (in_stb)
				cnt <= 5'h01;
			else if (cnt[5])
				cnt <= 5'h0d;
			else if (enabled)
				cnt <= cnt - 1;
		end
	end

	assign out_hi = in_hi;
	assign out_lo = in_lo;
	assign out_stb = cnt[5];

endmodule // e1_rx_clock_recovery
