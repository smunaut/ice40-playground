/*
 * ice40_ebr.v
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

module ice40_ebr #(
	parameter integer READ_MODE  = 0,	/* 0 =  256x16, 1 =  512x8 */
	parameter integer WRITE_MODE = 0,	/* 2 = 1024x4,  3 = 2048x2 */
	parameter integer MASK_WORKAROUND = 0,
	parameter integer NEG_WR_CLK = 0,
	parameter integer NEG_RD_CLK = 0,
	parameter INIT_FILE = "",

	// auto
	parameter integer WAW = 8 + WRITE_MODE,
	parameter integer WDW = 16 / (1 << WRITE_MODE),
	parameter integer RAW = 8 + READ_MODE,
	parameter integer RDW = 16 / (1 << READ_MODE)
)(
	// Write
	input  wire [WAW-1:0] wr_addr,
	input  wire [WDW-1:0] wr_data,
	input  wire [WDW-1:0] wr_mask,
	input  wire           wr_ena,
	input  wire           wr_clk,

	// Read
	input  wire [RAW-1:0] rd_addr,
	output wire [RDW-1:0] rd_data,
	input  wire           rd_ena,
	input  wire           rd_clk
);

	genvar i;

	// Constants
	// ---------

	localparam integer WRITE_MODE_RAM = MASK_WORKAROUND ? 0 : WRITE_MODE;

	localparam integer RDO = (1 << READ_MODE) >> 2;
	localparam integer WDO = (1 << WRITE_MODE_RAM) >> 2;


	// Functions
	// ---------

	function [15:0] bitrev16 (input [15:0] sig);
		bitrev16 = {
			sig[15], sig[7], sig[11], sig[3], sig[13], sig[5], sig[9], sig[1],
			sig[14], sig[6], sig[10], sig[2], sig[12], sig[4], sig[8], sig[0]
		};
	endfunction


	// Signals
	// -------

	// Raw RAM
	wire [10:0] ram_wr_addr;
	wire [15:0] ram_wr_data;
	wire [15:0] ram_wr_mask;

	wire [10:0] ram_rd_addr;
	wire [15:0] ram_rd_data;


	// Read mapping
	// ------------

	wire [15:0] rd_data_i;

	assign { ram_rd_addr[7:0], ram_rd_addr[8], ram_rd_addr[9], ram_rd_addr[10] } = { rd_addr, {(3-READ_MODE){1'b0}} };

	assign rd_data_i = bitrev16({ {RDO{1'b0}}, ram_rd_data[15:RDO] });
	assign rd_data = rd_data_i[RDW-1:0];


	// Write mapping
	// -------------

	generate
		if ((WRITE_MODE == 0) | (MASK_WORKAROUND == 0) ) begin
			// Normal Mapping rule
			wire [15:0] wr_data_i = bitrev16({ {(16-WDW){1'b0}}, wr_data });
			wire [15:0] wr_mask_i = bitrev16({ {(16-WDW){1'b0}}, wr_mask });

			assign ram_wr_data = { wr_data_i[15-WDO:0], {WDO{1'b0}} };
			assign ram_wr_mask = { wr_mask_i[15-WDO:0], {WDO{1'b0}} };
			assign { ram_wr_addr[7:0], ram_wr_addr[8], ram_wr_addr[9], ram_wr_addr[10] } = { wr_addr, {(3-WRITE_MODE){1'b0}} };

		end else begin
			// We want mask support for non x16 mode
			// To do this we have to stay in x16 mode and manually handle the
			// write width adaptation
			wire [15:0] submask;

			assign ram_wr_data = bitrev16( {(1<<WRITE_MODE){wr_data}} );
			assign ram_wr_mask = bitrev16( {(1<<WRITE_MODE){wr_mask}} | submask );
			assign ram_wr_addr = { 3'b000, wr_addr[WAW-1:WAW-8] };

			for (i=0; i<16; i=i+1)
				assign submask[i] = !((i >> (4-WRITE_MODE)) == wr_addr[WRITE_MODE-1:0]);
		end
	endgenerate


	// Memory block
	// ------------

	generate
		if ((NEG_RD_CLK == 0) && (NEG_WR_CLK == 0))
			SB_RAM40_4K #(
				.INIT_FILE(INIT_FILE),
				.WRITE_MODE(WRITE_MODE_RAM),
				.READ_MODE(READ_MODE)
			) ebr_I (
				.RDATA(ram_rd_data),
				.RADDR(ram_rd_addr),
				.RCLK(rd_clk),
				.RCLKE(rd_ena),
				.RE(1'b1),
				.WDATA(ram_wr_data),
				.WADDR(ram_wr_addr),
				.MASK(ram_wr_mask),
				.WCLK(wr_clk),
				.WCLKE(wr_ena),
				.WE(1'b1)
			);

		else if ((NEG_RD_CLK != 0) && (NEG_WR_CLK == 0))
			SB_RAM40_4KNR #(
				.INIT_FILE(INIT_FILE),
				.WRITE_MODE(WRITE_MODE_RAM),
				.READ_MODE(READ_MODE)
			) ebr_I (
				.RDATA(ram_rd_data),
				.RADDR(ram_rd_addr),
				.RCLKN(rd_clk),
				.RCLKE(rd_ena),
				.RE(1'b1),
				.WDATA(ram_wr_data),
				.WADDR(ram_wr_addr),
				.MASK(ram_wr_mask),
				.WCLK(wr_clk),
				.WCLKE(wr_ena),
				.WE(1'b1)
			);

		else if ((NEG_RD_CLK == 0) && (NEG_WR_CLK != 0))
			SB_RAM40_4KNW #(
				.INIT_FILE(INIT_FILE),
				.WRITE_MODE(WRITE_MODE_RAM),
				.READ_MODE(READ_MODE)
			) ebr_I (
				.RDATA(ram_rd_data),
				.RADDR(ram_rd_addr),
				.RCLK(rd_clk),
				.RCLKE(rd_ena),
				.RE(1'b1),
				.WDATA(ram_wr_data),
				.WADDR(ram_wr_addr),
				.MASK(ram_wr_mask),
				.WCLKN(wr_clk),
				.WCLKE(wr_ena),
				.WE(1'b1)
			);

		else if ((NEG_RD_CLK != 0) && (NEG_WR_CLK != 0))
			SB_RAM40_4KNRNW #(
				.INIT_FILE(INIT_FILE),
				.WRITE_MODE(WRITE_MODE_RAM),
				.READ_MODE(READ_MODE)
			) ebr_I (
				.RDATA(ram_rd_data),
				.RADDR(ram_rd_addr),
				.RCLKN(rd_clk),
				.RCLKE(rd_ena),
				.RE(1'b1),
				.WDATA(ram_wr_data),
				.WADDR(ram_wr_addr),
				.MASK(ram_wr_mask),
				.WCLKN(wr_clk),
				.WCLKE(wr_ena),
				.WE(1'b1)
			);

	endgenerate

endmodule
