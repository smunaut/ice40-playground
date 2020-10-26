/*
 * picorv32_ice40_regs.v
 *
 * vim: ts=4 sw=4
 *
 * Implementation of register file for the PicoRV32 on iCE40
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module picorv32_ice40_regs (
	input  wire        clk,
	input  wire        wen,
	input  wire  [5:0] waddr,
	input  wire  [5:0] raddr1,
	input  wire  [5:0] raddr2,
	input  wire [31:0] wdata,
	output wire [31:0] rdata1,
	output wire [31:0] rdata2
);

	ice40_ebr #(
		.READ_MODE(0),
		.WRITE_MODE(0),
		.MASK_WORKAROUND(0),
		.NEG_WR_CLK(0),
		.NEG_RD_CLK(1)
	) regs[3:0] (
		.wr_addr ({ 4{2'b00, waddr} }),
		.wr_data ({ 2{wdata} }),
		.wr_mask (64'h0000000000000000),
		.wr_ena  (wen),
		.wr_clk  (clk),
		.rd_addr ({2'b00, raddr2, 2'b00, raddr2, 2'b00, raddr1, 2'b00, raddr1}),
		.rd_data ({rdata2, rdata1}),
		.rd_ena  (1'b1),
		.rd_clk  (clk)
	);

endmodule // picorv32_ice40_regs
