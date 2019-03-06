/*
 * usb.v
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

module usb #(
	parameter         TARGET = "ICE40",
	parameter [3:0]   ADDR_MSB = 4'h3,
	parameter integer EPDW = 16,

	/* Auto-set */
	parameter integer EPAW = 11 - $clog2(EPDW / 8)
)(
	// Pads
	inout  wire pad_dp,
	inout  wire pad_dn,
	output reg  pad_pu,

	// EP buffer interface
	input  wire [EPAW-1:0] ep_tx_addr_0,
	input  wire [EPDW-1:0] ep_tx_data_0,
	input  wire ep_tx_we_0,

	input  wire [EPAW-1:0] ep_rx_addr_0,
	output wire [EPDW-1:0] ep_rx_data_1,
	input  wire ep_rx_re_0,

	input  wire ep_clk,

	// Bus interface
	input  wire [15:0] bus_addr,
	input  wire [15:0] bus_din,
	output wire [15:0] bus_dout,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// Debug
	output wire [3:0] debug,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// PHY
	wire phy_rx_dp;
	wire phy_rx_dn;
	wire phy_rx_chg;

	wire phy_tx_dp;
	wire phy_tx_dn;
	wire phy_tx_en;

	// TX Low-Level
	wire txll_start;
	wire txll_bit;
	wire txll_last;
	wire txll_ack;

	// TX Packet
	wire txpkt_start;
	wire txpkt_done;
	wire [3:0] txpkt_pid;
	wire [9:0] txpkt_len;
	wire [7:0] txpkt_data;
	wire txpkt_data_ack;

	// RX Low-Level
	wire [1:0] rxll_sym;
	wire rxll_bit;
	wire rxll_valid;
	wire rxll_eop;
	wire rxll_sync;
	wire rxll_bs_skip;
	wire rxll_bs_err;

	// RX Packet
	wire rxpkt_start;
	wire rxpkt_done_ok;
	wire rxpkt_done_err;

	wire [ 3:0] rxpkt_pid;
	wire rxpkt_is_sof;
	wire rxpkt_is_token;
	wire rxpkt_is_data;
	wire rxpkt_is_handshake;

	wire [10:0] rxpkt_frameno;
	wire [ 6:0] rxpkt_addr;
	wire [ 3:0] rxpkt_endp;

	wire [ 7:0] rxpkt_data;
	wire rxpkt_data_stb;

	// EP Buffers
	wire [10:0] buf_tx_addr_0;
	wire [ 7:0] buf_tx_data_1;
	wire buf_tx_rden_0;

	wire [10:0] buf_rx_addr_0;
	wire [ 7:0] buf_rx_data_0;
	wire buf_rx_wren_0;

	// EP Status
	wire eps_read_0;
	wire eps_zero_0;
	wire eps_write_0;
	wire [ 7:0] eps_addr_0;
	wire [15:0] eps_wrdata_0;
	wire [15:0] eps_rddata_3;

	wire eps_bus_ready;
	reg  eps_bus_read;
	reg  eps_bus_zero;
	reg  eps_bus_write;
	wire [15:0] eps_bus_dout;

	// Config / Status registers
	reg         cr_pu_ena;
	reg  [ 6:0] cr_addr;
	wire [15:0] sr_notify;
	wire irq_stb;
	wire irq_state;
	reg  irq_ack;

	// Bus interface
	reg  eps_bus_req;
	wire eps_bus_clear;

	reg  bus_ack_wait;
	wire bus_req_ok;
	reg  [2:0] bus_req_ok_dly;

	// Out-of-band conditions
	wire oob_se0;
	wire oob_sop;

	reg  [19:0] timeout_suspend;	//  3 ms with no activity
	reg  [19:0] timeout_reset;		// 10 ms SE0

	reg  rst_usb_l;
	reg  suspend;

	// USB core logic reset
	wire rst_usb;


	// PHY
	// ---

	usb_phy #(
		.TARGET(TARGET)
	) phy_I (
		.pad_dp(pad_dp),
		.pad_dn(pad_dn),
		.rx_dp(phy_rx_dp),
		.rx_dn(phy_rx_dn),
		.rx_chg(phy_rx_chg),
		.tx_dp(phy_tx_dp),
		.tx_dn(phy_tx_dn),
`ifdef SIM
		.tx_en(1'b0),
`else
		.tx_en(phy_tx_en),
`endif
		.clk(clk),
		.rst(rst)
	);


	// TX
	// --

	usb_tx_ll tx_ll_I (
		.phy_tx_dp(phy_tx_dp),
		.phy_tx_dn(phy_tx_dn),
		.phy_tx_en(phy_tx_en),
		.ll_start(txll_start),
		.ll_bit(txll_bit),
		.ll_last(txll_last),
		.ll_ack(txll_ack),
		.clk(clk),
		.rst(rst)
	);

	usb_tx_pkt tx_pkt_I (
		.ll_start(txll_start),
		.ll_bit(txll_bit),
		.ll_last(txll_last),
		.ll_ack(txll_ack),
		.pkt_start(txpkt_start),
		.pkt_done(txpkt_done),
		.pkt_pid(txpkt_pid),
		.pkt_len(txpkt_len),
		.pkt_data(txpkt_data),
		.pkt_data_ack(txpkt_data_ack),
		.clk(clk),
		.rst(rst)
	);


	// RX
	// --

	usb_rx_ll rx_ll_I (
		.phy_rx_dp(phy_rx_dp),
		.phy_rx_dn(phy_rx_dn),
		.phy_rx_chg(phy_rx_chg),
		.ll_sym(rxll_sym),
		.ll_bit(rxll_bit),
		.ll_valid(rxll_valid),
		.ll_eop(rxll_eop),
		.ll_sync(rxll_sync),
		.ll_bs_skip(rxll_bs_skip),
		.ll_bs_err(rxll_bs_err),
		.clk(clk),
		.rst(rst)
	);

	usb_rx_pkt rx_pkt_I (
		.ll_sym(rxll_sym),
		.ll_bit(rxll_bit),
		.ll_valid(rxll_valid),
		.ll_eop(rxll_eop),
		.ll_sync(rxll_sync),
		.ll_bs_skip(rxll_bs_skip),
		.ll_bs_err(rxll_bs_err),
		.pkt_start(rxpkt_start),
		.pkt_done_ok(rxpkt_done_ok),
		.pkt_done_err(rxpkt_done_err),
		.pkt_pid(rxpkt_pid),
		.pkt_is_sof(rxpkt_is_sof),
		.pkt_is_token(rxpkt_is_token),
		.pkt_is_data(rxpkt_is_data),
		.pkt_is_handshake(rxpkt_is_handshake),
		.pkt_frameno(rxpkt_frameno),
		.pkt_addr(rxpkt_addr),
		.pkt_endp(rxpkt_endp),
		.pkt_data(rxpkt_data),
		.pkt_data_stb(rxpkt_data_stb),
		.inhibit(phy_tx_en),
		.clk(clk),
		.rst(rst)
	);


	// Transaction control
	// -------------------

	usb_trans trans_I (
		.txpkt_start(txpkt_start),
		.txpkt_done(txpkt_done),
		.txpkt_pid(txpkt_pid),
		.txpkt_len(txpkt_len),
		.txpkt_data(txpkt_data),
		.txpkt_data_ack(txpkt_data_ack),
		.rxpkt_start(rxpkt_start),
		.rxpkt_done_ok(rxpkt_done_ok),
		.rxpkt_done_err(rxpkt_done_err),
		.rxpkt_pid(rxpkt_pid),
		.rxpkt_is_sof(rxpkt_is_sof),
		.rxpkt_is_token(rxpkt_is_token),
		.rxpkt_is_data(rxpkt_is_data),
		.rxpkt_is_handshake(rxpkt_is_handshake),
		.rxpkt_frameno(rxpkt_frameno),
		.rxpkt_addr(rxpkt_addr),
		.rxpkt_endp(rxpkt_endp),
		.rxpkt_data(rxpkt_data),
		.rxpkt_data_stb(rxpkt_data_stb),
		.buf_tx_addr_0(buf_tx_addr_0),
		.buf_tx_data_1(buf_tx_data_1),
		.buf_tx_rden_0(buf_tx_rden_0),
		.buf_rx_addr_0(buf_rx_addr_0),
		.buf_rx_data_0(buf_rx_data_0),
		.buf_rx_wren_0(buf_rx_wren_0),
		.eps_read_0(eps_read_0),
		.eps_zero_0(eps_zero_0),
		.eps_write_0(eps_write_0),
		.eps_addr_0(eps_addr_0),
		.eps_wrdata_0(eps_wrdata_0),
		.eps_rddata_3(eps_rddata_3),
		.cr_addr(cr_addr),
		.sr_notify(sr_notify),
		.irq_stb(irq_stb),
		.irq_state(irq_state),
		.irq_ack(irq_ack),
		.debug(debug),
		.clk(clk),
		.rst(rst)
	);


	// EP buffers
	// ----------

	usb_ep_buf #(
		.TARGET(TARGET),
		.RWIDTH(8),
		.WWIDTH(EPDW)
	) tx_buf_I (
		.rd_addr_0(buf_tx_addr_0),
		.rd_data_1(buf_tx_data_1),
		.rd_en_0(buf_tx_rden_0),
		.rd_clk(clk),
		.wr_addr_0(ep_tx_addr_0),
		.wr_data_0(ep_tx_data_0),
		.wr_en_0(ep_tx_we_0),
		.wr_clk(ep_clk)
	);

	usb_ep_buf #(
		.TARGET(TARGET),
		.RWIDTH(EPDW),
		.WWIDTH(8)
	) rx_buf_I (
		.rd_addr_0(ep_rx_addr_0),
		.rd_data_1(ep_rx_data_1),
		.rd_en_0(ep_rx_re_0),
		.rd_clk(ep_clk),
		.wr_addr_0(buf_rx_addr_0),
		.wr_data_0(buf_rx_data_0),
		.wr_en_0(buf_rx_wren_0),
		.wr_clk(clk)
	);


	// EP Status / Buffer Descriptors
	// ------------------------------

	usb_ep_status ep_status_I (
		.p_addr_0(eps_addr_0),
		.p_read_0(eps_read_0),
		.p_zero_0(eps_zero_0),
		.p_write_0(eps_write_0),
		.p_din_0(eps_wrdata_0),
		.p_dout_3(eps_rddata_3),
		.s_addr_0(bus_addr[7:0]),
		.s_read_0(eps_bus_ready),
		.s_zero_0(eps_bus_zero),
		.s_write_0(eps_bus_write),
		.s_din_0(bus_din),
		.s_dout_3(eps_bus_dout),
		.s_ready_0(eps_bus_ready),
		.clk(clk),
		.rst(rst)
	);


	// Bus Interface
	// -------------

	(* keep="true" *) wire bus_msb_match;

	wire [15:0] csr_dout;
	wire csr_bus_clear;
	reg  csr_req;
	reg  cr_bus_we;
	reg  sr_bus_re;

	// Match the MSB
	assign bus_msb_match = bus_addr[15:12] == ADDR_MSB;

	// Request lines for registers
	always @(posedge clk)
		if (csr_bus_clear) begin
			csr_req   <= 1'b0;
			cr_bus_we <= 1'b0;
			sr_bus_re <= 1'b0;
		end else begin
			csr_req   <= bus_msb_match & ~bus_addr[11];
			cr_bus_we <= bus_msb_match & ~bus_addr[11] &  bus_we;
			sr_bus_re <= bus_msb_match & ~bus_addr[11] & ~bus_we;
		end

	// Request lines for EP Status access
	always @(posedge clk)
		if (eps_bus_clear) begin
			eps_bus_read  <= 1'b0;
			eps_bus_zero  <= 1'b1;
			eps_bus_write <= 1'b0;
			eps_bus_req   <= 1'b0;
		end else begin
			eps_bus_read  <=  bus_msb_match &  bus_addr[11] & ~bus_we;
			eps_bus_zero  <= ~bus_msb_match | ~bus_addr[11];
			eps_bus_write <=  bus_msb_match &  bus_addr[11] &  bus_we;
			eps_bus_req   <=  bus_msb_match &  bus_addr[11];
		end

	// Condition to force the requests to zero :
	//  no access needed, ack pending or this cycle went through
	assign csr_bus_clear = ~bus_cyc | csr_req;
	assign eps_bus_clear = ~bus_cyc | bus_ack_wait | (eps_bus_req & eps_bus_ready);

	// Track when request are accepted by the RAM
	assign bus_req_ok = (eps_bus_req & eps_bus_ready);

	always @(posedge clk)
		bus_req_ok_dly <= { bus_req_ok_dly[1:0], bus_req_ok & ~bus_we };

	// ACK wait state tracking
	always @(posedge clk or posedge rst)
		if (rst)
			bus_ack_wait <= 1'b0;
		else
			bus_ack_wait <= ((bus_ack_wait & ~bus_we) | bus_req_ok) & ~bus_req_ok_dly[2];

	// Bus Ack
	assign bus_ack = csr_req | (bus_ack_wait & (bus_we | bus_req_ok_dly[2]));

	// Output is simply the OR of all local units since we force them to zero if
	// they're not accessed
	assign bus_dout = eps_bus_dout | csr_dout;


	// Config registers
	// ----------------

	// Write regs
	always @(posedge clk)
		if (cr_bus_we) begin
			cr_pu_ena <= bus_din[15];
			cr_addr   <= bus_din[13:8];
		end

	// Write strobe
	always @(posedge clk)
		irq_ack <= cr_bus_we & bus_din[0];

	// Read mux
	assign csr_dout = sr_bus_re ? sr_notify : 16'h0000;


	// USB reset/suspend
	// -----------------

	// Detect some conditions for triggers
	assign oob_se0 = !phy_rx_dp && !phy_rx_dn;
	assign oob_sop = rxpkt_start & rxpkt_is_sof;

	// Suspend timeout counter
	always @(posedge clk)
		if (rst_usb)
			timeout_suspend <= 20'ha3280;
		else
			timeout_suspend <= oob_sop ? 20'ha3280 : (timeout_suspend - timeout_suspend[19]);

	always @(posedge clk)
		if (rst_usb)
			suspend <= 1'b0;
		else
			suspend <= ~timeout_suspend[19];

	// Reset timeout counter
	always @(posedge clk)
		if (rst)
			timeout_reset <= 20'hf5300;
		else
			timeout_reset <= oob_se0 ? (timeout_reset - timeout_reset[19]) : 20'hf5300;

	always @(posedge clk)
		if (rst)
			rst_usb_l <= 1'b1;
		else
			rst_usb_l <= ~timeout_reset[19];

	// Global reset driver
	generate
		if (TARGET == "GENERIC")
			assign rst_usb = rst_usb_l;
		else if (TARGET == "ICE40")
			SB_GB usb_rst_gb_I (
				.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_usb_l),
				.GLOBAL_BUFFER_OUTPUT(rst_usb)
			);
	endgenerate

	// Detection pin
	always @(posedge clk)
		if (rst)
			pad_pu <= 1'b0;
		else
			pad_pu <= cr_pu_ena;

endmodule // usb
