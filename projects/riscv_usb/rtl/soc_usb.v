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
	input  wire [  11:0] wb_addr,
	output wire [DW-1:0] wb_rdata,
	input  wire [DW-1:0] wb_wdata,
	input  wire          wb_we,
	input  wire    [1:0] wb_cyc,
	output wire    [1:0] wb_ack,

	// Clock / Reset
	input  wire clk_sys,
	input  wire clk_48m,
	input  wire rst
);

	// Signals
	// -------

	// Bus OR
	wire [DW-1:0] wb_rdata_i[0:1];

	// Wishbone in 48 MHz domain
	wire [11:0] ub_addr;
	wire [15:0] ub_wdata;
	wire [15:0] ub_rdata;
	wire        ub_cyc;
	wire        ub_we;
	wire        ub_ack;

	// IOs
	wire pad_dp_i, pad_dp_o, pad_dp_oe;
	wire pad_dn_i, pad_dn_o, pad_dn_oe;
	wire pad_pu_i, pad_pu_o, pad_pu_oe;

	// EP Buffer
	wire [ 8:0] ep_tx_addr_0;
	wire [31:0] ep_tx_data_0;
	wire        ep_tx_we_0;

	wire [ 8:0] ep_rx_addr_0;
	wire [31:0] ep_rx_data_1;
	wire        ep_rx_re_0;

	reg ack_ep;


	// Cross-clock
	// -----------
		// Bring control reg wishbone to 48 MHz domain

	xclk_wb #(
		.DW(16),
		.AW(12)
	)  wb_48m_xclk_I (
		.s_addr  (wb_addr[11:0]),
		.s_wdata (wb_wdata[15:0]),
		.s_rdata (wb_rdata_i[0][15:0]),
		.s_cyc   (wb_cyc[0]),
		.s_ack   (wb_ack[0]),
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

	if (DW != 16)
		assign wb_rdata_i[0][DW-1:16] = 0;


	// Core
	// ----

	usb #(
		.EPDW(32)
	) usb_I (
		.pad_dp_i     (pad_dp_i),
		.pad_dp_o     (pad_dp_o),
		.pad_dp_oe    (pad_dp_oe),
		.pad_dn_i     (pad_dn_i),
		.pad_dn_o     (pad_dn_o),
		.pad_dn_oe    (pad_dn_oe),
		.pad_pu_o     (pad_pu_o),
		.pad_pu_oe    (pad_pu_oe),
		.ep_tx_addr_0 (ep_tx_addr_0),
		.ep_tx_data_0 (ep_tx_data_0),
		.ep_tx_we_0   (ep_tx_we_0),
		.ep_rx_addr_0 (ep_rx_addr_0),
		.ep_rx_data_1 (ep_rx_data_1),
		.ep_rx_re_0   (ep_rx_re_0),
		.ep_clk       (clk_sys),
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


	// EP data
	// -------

	assign ep_tx_addr_0 = wb_addr[8:0];
	assign ep_rx_addr_0 = wb_addr[8:0];

	assign ep_tx_data_0 = wb_wdata;
	assign wb_rdata_i[1] = ack_ep ? ep_rx_data_1 : 32'h00000000;

	assign ep_tx_we_0 = wb_cyc[1] & wb_we & ~ack_ep;
	assign ep_rx_re_0 = 1'b1;

	assign wb_ack[1] = ack_ep;

	always @(posedge clk_sys or posedge rst)
		if (rst)
			ack_ep <= 1'b0;
		else
			ack_ep <= wb_cyc[1] & ~ack_ep;


	// Bus read data
	// -------------

	assign wb_rdata = wb_rdata_i[0] | wb_rdata_i[1];

endmodule // soc_usb
