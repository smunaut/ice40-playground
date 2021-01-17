/*
 * vid_framebuf.v
 *
 * Video framebuffer memory
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_framebuf (
	// Video Read port
	input  wire [13:0] v_addr_0,
	output wire [31:0] v_data_1,
	input  wire        v_re_0,

	// Aux R/W port
	input  wire [13:0] a_addr_0,
	output wire [31:0] a_rdata_1,
	input  wire [31:0] a_wdata_0,
	input  wire [ 3:0] a_wmsk_0,
	input  wire        a_we_0,
	output wire        a_rdy_0,

	// Clock
	input  wire clk
);

	// Signals
	// -------

	wire [13:0] ram_addr;
	wire [31:0] ram_rdata;
	wire [31:0] ram_wdata;
	wire [ 7:0] ram_mask_n;
	wire        ram_we;


	// Memory
	// ------

	SB_SPRAM256KA spram_I[1:0] (
		.DATAIN     (ram_wdata),
		.ADDRESS    (ram_addr),
		.MASKWREN   (ram_mask_n),
		.WREN       (ram_we),
		.CHIPSELECT (1'b1),
		.CLOCK      (clk),
		.STANDBY    (1'b0),
		.SLEEP      (1'b0),
		.POWEROFF   (1'b1),
		.DATAOUT    (ram_rdata)
	);


	// Muxing
	// ------

	assign ram_addr = v_re_0 ? v_addr_0 : a_addr_0;

	assign ram_wdata = a_wdata_0;
	assign ram_mask_n  = {
		~a_wmsk_0[3], ~a_wmsk_0[3],
		~a_wmsk_0[2], ~a_wmsk_0[2],
		~a_wmsk_0[1], ~a_wmsk_0[1],
		~a_wmsk_0[0], ~a_wmsk_0[0]
	};
	assign ram_we = a_we_0 & ~v_re_0;

	assign a_rdata_1 = ram_rdata;
	assign v_data_1  = ram_rdata;

	assign a_rdy_0 = ~v_re_0;

endmodule // vid_framebuf
