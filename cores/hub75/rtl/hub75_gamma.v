/*
 * hub75_gamma.v
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

module hub75_gamma #(
	parameter IW = 8,
	parameter OW = 10
)(
	input  wire [IW-1:0] in,
	output wire [OW-1:0] out,
	input  wire enable,
	input  wire clk
);
	reg  [15:0] gamma_rom [0:255];
	wire [ 7:0] rd_addr;
	reg  [15:0] rd_data;

	initial
		$readmemh("gamma_table.hex", gamma_rom);

	always @(posedge clk)
	begin
		// Read
		if (enable)
			rd_data <= gamma_rom[rd_addr];
	end

	genvar i;
	generate
		for (i=0; i<8; i=i+1)
			assign rd_addr[7-i] = in[IW-1-(i%IW)];
	endgenerate

	assign out = rd_data[15:16-OW];

endmodule // hub75_gamma
