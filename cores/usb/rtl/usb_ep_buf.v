/*
 * usb_ep_buf.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019 Sylvain Munaut
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

module usb_ep_buf #(
	parameter TARGET = "ICE40",
	parameter integer RWIDTH = 8,	// 8/16/32/64
	parameter integer WWIDTH = 8,	// 8/16/32/64
	parameter integer AWIDTH = 11,	// Assuming 'byte' access

	parameter integer ARW = AWIDTH - $clog2(RWIDTH / 8),
	parameter integer AWW = AWIDTH - $clog2(WWIDTH / 8)
)(
	// Read port
	input  wire [ARW-1:0] rd_addr_0,
	output wire [RWIDTH-1:0] rd_data_1,
	input  wire rd_en_0,
	input  wire rd_clk,

	// Write port
	input  wire [AWW-1:0] wr_addr_0,
	input  wire [WWIDTH-1:0] wr_data_0,
	input  wire wr_en_0,
	input  wire wr_clk
);
	// MODE 0:  256 x 16
	// MODE 1:  512 x 8
	// MODE 2: 1024 x 4
	// MODE 3: 2048 x 2

	localparam WRITE_MODE = 3 - $clog2(WWIDTH / 8);
	localparam READ_MODE  = 3 - $clog2(RWIDTH / 8);


	// Helpers to map to the right bits of SB_RAM40_4K
	// -----------------------------------------------

	function [7:0] ram_rd_map8 (input [15:0] rdata);
		ram_rd_map8 = {
			rdata[14],
			rdata[12],
			rdata[10],
			rdata[ 8],
			rdata[ 6],
			rdata[ 4],
			rdata[ 2],
			rdata[ 0]
		};
	endfunction

	function [15:0] ram_wr_map8 (input [7:0] wdata);
		ram_wr_map8 = {
			1'b0, wdata[7],	// 14
			1'b0, wdata[6],	// 12
			1'b0, wdata[5], // 10
			1'b0, wdata[4], //  8
			1'b0, wdata[3], //  6
			1'b0, wdata[2], //  4
			1'b0, wdata[1], //  2
			1'b0, wdata[0]  //  0
		};
	endfunction

	function [3:0] ram_rd_map4 (input [15:0] rdata);
		ram_rd_map4 = {
			rdata[13],
			rdata[ 9],
			rdata[ 5],
			rdata[ 1]
		};
	endfunction

	function [15:0] ram_wr_map4 (input [3:0] wdata);
		ram_wr_map4 = {
			2'h0, wdata[3], // 13
			3'h0, wdata[2], //  9
			3'h0, wdata[1], //  5
			3'h0, wdata[0], //  1
			1'b0
		};
	endfunction

	function [1:0] ram_rd_map2 (input [15:0] rdata);
		ram_rd_map2 = {
			rdata[11],
			rdata[ 3]
		};
	endfunction

	function [15:0] ram_wr_map2 (input [1:0] wdata);
		ram_wr_map2 = {
			4'h0, wdata[1], // 11
			7'h0, wdata[0], //  3
			3'h0
		};
	endfunction


	// Helpers to shuffle bits across blocks
	// -------------------------------------

	function [63:0] ram_rd_shuffle_64(input [63:0] src);
		ram_rd_shuffle_64 = {
			src[63], src[55], src[47], src[39], src[31], src[23], src[15], src[ 7],
			src[59], src[51], src[43], src[35], src[27], src[19], src[11], src[ 3],
			src[61], src[53], src[45], src[37], src[29], src[21], src[13], src[ 5],
			src[57], src[49], src[41], src[33], src[25], src[17], src[ 9], src[ 1],
			src[62], src[54], src[46], src[38], src[30], src[22], src[14], src[ 6],
			src[58], src[50], src[42], src[34], src[26], src[18], src[10], src[ 2],
			src[60], src[52], src[44], src[36], src[28], src[20], src[12], src[ 4],
			src[56], src[48], src[40], src[32], src[24], src[16], src[ 8], src[ 0]
		};
	endfunction

	function [31:0] ram_rd_shuffle_32(input [31:0] src);
		ram_rd_shuffle_32 = {
			src[31], src[27], src[23], src[19], src[15], src[11], src[ 7], src[ 3],
			src[29], src[25], src[21], src[17], src[13], src[ 9], src[ 5], src[ 1],
			src[30], src[26], src[22], src[18], src[14], src[10], src[ 6], src[ 2],
			src[28], src[24], src[20], src[16], src[12], src[ 8], src[ 4], src[ 0]
		};
	endfunction

	function [15:0] ram_rd_shuffle_16(input [15:0] src);
		ram_rd_shuffle_16 = {
			src[15], src[13], src[11], src[ 9], src[ 7], src[ 5], src[ 3], src[ 1],
			src[14], src[12], src[10], src[ 8], src[ 6], src[ 4], src[ 2], src[ 0]
		};
	endfunction


	function [63:0] ram_wr_shuffle_64(input [63:0] src);
		ram_wr_shuffle_64 = {
			src[63], src[31], src[47], src[15], src[55], src[23], src[39], src[ 7],
			src[62], src[30], src[46], src[14], src[54], src[22], src[38], src[ 6],
			src[61], src[29], src[45], src[13], src[53], src[21], src[37], src[ 5],
			src[60], src[28], src[44], src[12], src[52], src[20], src[36], src[ 4],
			src[59], src[27], src[43], src[11], src[51], src[19], src[35], src[ 3],
			src[58], src[26], src[42], src[10], src[50], src[18], src[34], src[ 2],
			src[57], src[25], src[41], src[ 9], src[49], src[17], src[33], src[ 1],
			src[56], src[24], src[40], src[ 8], src[48], src[16], src[32], src[ 0]
		};
	endfunction

	function [31:0] ram_wr_shuffle_32(input [31:0] src);
		ram_wr_shuffle_32 = {
			src[31], src[15], src[23], src[ 7], src[30], src[14], src[22], src[ 6],
			src[29], src[13], src[21], src[ 5], src[28], src[12], src[20], src[ 4],
			src[27], src[11], src[19], src[ 3], src[26], src[10], src[18], src[ 2],
			src[25], src[ 9], src[17], src[ 1], src[24], src[ 8], src[16], src[ 0]
		};
	endfunction

	function [15:0] ram_wr_shuffle_16(input [15:0] src);
		ram_wr_shuffle_16 = {
			src[15], src[ 7], src[14], src[ 6], src[13], src[ 5], src[12], src[ 4],
			src[11], src[ 3], src[10], src[ 2], src[ 9], src[ 1], src[ 8], src[ 0]
		};
	endfunction


	// Storage array
	// -------------

	initial begin
		$display("READ_MODE  : %d", READ_MODE);
		$display("WRITE_MODE : %d", WRITE_MODE);
	end

	wire [10:0] ram_raddr;
	wire [10:0] ram_waddr;

	wire [RWIDTH-1:0] rd_data_1_ram;
	wire [WWIDTH-1:0] wr_data_0_ram;

	genvar i;
	generate
		// Map address lines for various modes
		assign ram_raddr[7:0] = rd_addr_0[ARW-1:ARW-8];
		assign ram_waddr[7:0] = wr_addr_0[AWW-1:AWW-8];

		if (READ_MODE == 3)
			assign ram_raddr[10:8] = { rd_addr_0[0], rd_addr_0[1], rd_addr_0[2] };
		else if (READ_MODE == 2)
			assign ram_raddr[10:8] = { 1'b0, rd_addr_0[0], rd_addr_0[1] };
		else if (READ_MODE == 1)
			assign ram_raddr[10:8] = { 2'b00, rd_addr_0[0] };
		else
			assign ram_raddr[10:8] = { 3'b000 };

		if (WRITE_MODE == 3)
			assign ram_waddr[10:8] = { wr_addr_0[0], wr_addr_0[1], wr_addr_0[2] };
		else if (WRITE_MODE == 2)
			assign ram_waddr[10:8] = { 1'b0, wr_addr_0[0], wr_addr_0[1] };
		else if (WRITE_MODE == 1)
			assign ram_waddr[10:8] = { 2'b00, wr_addr_0[0] };
		else
			assign ram_waddr[10:8] = { 3'b000 };

		// Shuffle the bits
		if (READ_MODE == 0)
			assign rd_data_1 = ram_rd_shuffle_64(rd_data_1_ram);
		else if (READ_MODE == 1)
			assign rd_data_1 = ram_rd_shuffle_32(rd_data_1_ram);
		else if (READ_MODE == 2)
			assign rd_data_1 = ram_rd_shuffle_16(rd_data_1_ram);
		else
			assign rd_data_1 = rd_data_1_ram;

		if (WRITE_MODE == 0)
			assign wr_data_0_ram = ram_wr_shuffle_64(wr_data_0);
		else if (WRITE_MODE == 1)
			assign wr_data_0_ram = ram_wr_shuffle_32(wr_data_0);
		else if (WRITE_MODE == 2)
			assign wr_data_0_ram = ram_wr_shuffle_16(wr_data_0);
		else
			assign wr_data_0_ram = wr_data_0;

		// 4 blocks
		for (i=0; i<4; i=i+1)
		begin : block
			wire [15:0] ram_rdata;
			wire [15:0] ram_wdata;

			// Block
			SB_RAM40_4K #(
				.WRITE_MODE(WRITE_MODE),
				.READ_MODE(READ_MODE)
			) ram_I (
				.RDATA(ram_rdata),
				.RCLK(rd_clk),
				.RCLKE(rd_en_0),
				.RE(1'b1),
				.RADDR(ram_raddr),
				.WCLK(wr_clk),
				.WCLKE(wr_en_0),
				.WE(1'b1),
				.WADDR(ram_waddr),
				.MASK(16'h0000),
				.WDATA(ram_wdata)
			);

			// Map the right bits
			if (READ_MODE == 3)
				assign rd_data_1_ram[i*2+:2] = ram_rd_map2(ram_rdata);
			else if (READ_MODE == 2)
				assign rd_data_1_ram[i*4+:4] = ram_rd_map4(ram_rdata);
			else if (READ_MODE == 1)
				assign rd_data_1_ram[i*8+:8] = ram_rd_map8(ram_rdata);
			else
				assign rd_data_1_ram[i*16+:16] = ram_rdata;

			if (WRITE_MODE == 3)
				assign ram_wdata = ram_wr_map2(wr_data_0_ram[i*2+:2]);
			else if (WRITE_MODE == 2)
				assign ram_wdata = ram_wr_map4(wr_data_0_ram[i*4+:4]);
			else if (WRITE_MODE == 1)
				assign ram_wdata = ram_wr_map8(wr_data_0_ram[i*8+:8]);
			else
				assign ram_wdata = wr_data_0_ram[i*16+:16];
		end
	endgenerate

endmodule // usb_ep_buf
