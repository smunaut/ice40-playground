/*
 * soc_usb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module soc_usb #(
	parameter integer DW = 32
)(
	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,

	// Wishbone slave
	input  wire [  13:0] wb_addr,
	output wire [DW-1:0] wb_rdata,
	input  wire [DW-1:0] wb_wdata,
	input  wire          wb_we,
	input  wire          wb_cyc,
	output wire          wb_ack,

	// Clock / Reset
	input  wire clk_sys,
	input  wire clk_48m,
	input  wire rst
);

	// Signals
	// -------

	// Wishbone in 48 MHz domain
	wire [13:0] ub_addr;
	wire [31:0] ub_wdata;
	wire [31:0] ub_rdata;
	wire        ub_cyc;
	wire        ub_we;
	wire        ub_ack;

	// IOs
	wire pad_dp_i, pad_dp_o, pad_dp_oe;
	wire pad_dn_i, pad_dn_o, pad_dn_oe;
	wire pad_pu_i, pad_pu_o, pad_pu_oe;


	// Cross-clock
	// -----------

	xclk_wb #(
		.DW(32),
		.AW(14)
	)  wb_48m_xclk_I (
		.s_addr  (wb_addr),
		.s_wdata (wb_wdata),
		.s_rdata (wb_rdata),
		.s_cyc   (wb_cyc),
		.s_ack   (wb_ack),
		.s_we    (wb_we),
		.s_clk   (clk_sys),
		.m_addr  (ub_addr),
		.m_wdata (ub_wdata),
		.m_rdata (ub_rdata),
		.m_cyc   (ub_cyc),
		.m_ack   (ub_ack),
		.m_we    (ub_we),
		.m_clk   (clk_48m),
		.rst     (rst)
	);


	// Core
	// ----

	usb_sky130 usb_I (
		.pad_dp_i     (pad_dp_i),
		.pad_dp_o     (pad_dp_o),
		.pad_dp_oe    (pad_dp_oe),
		.pad_dn_i     (pad_dn_i),
		.pad_dn_o     (pad_dn_o),
		.pad_dn_oe    (pad_dn_oe),
		.pad_pu_o     (pad_pu_o),
		.pad_pu_oe    (pad_pu_oe),
		.wb_addr      (ub_addr),
		.wb_rdata     (ub_rdata),
		.wb_wdata     (ub_wdata),
		.wb_we        (ub_we),
		.wb_cyc       (ub_cyc),
		.wb_ack       (ub_ack),
		.clk          (clk_48m),
		.rst          (rst)
	);


	// IOs
	// ---

	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) io_I[2:0] (
		.PACKAGE_PIN  ({usb_dp,    usb_dn,    usb_pu}),
		.OUTPUT_ENABLE({pad_dp_oe, pad_dn_oe, pad_pu_oe}),
		.D_OUT_0      ({pad_dp_o,  pad_dn_o,  pad_pu_o}),
		.D_IN_0       ({pad_dp_i,  pad_dn_i,  pad_pu_i})
	);

endmodule // soc_usb
