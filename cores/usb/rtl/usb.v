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
	parameter integer EPDW = 16,
	parameter integer EVT_DEPTH = 0,

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
	input  wire [11:0] bus_addr,
	input  wire [15:0] bus_din,
	output wire [15:0] bus_dout,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// IRQ
	output wire irq,

	// SOF indication
	output wire sof,

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
	wire eps_bus_zero;
	reg  eps_bus_write;
	wire [15:0] eps_bus_dout;

	// Config / Status registers
	reg  cr_pu_ena;
	reg  cr_cel_ena;
	reg  cr_addr_chk;
	reg  [ 6:0] cr_addr;

	wire cel_state;
	reg  cel_rel;

	// Bus interface
	reg  csr_bus_req;
	wire csr_bus_clear;
	wire csr_bus_ack;
	reg  [15:0] csr_bus_dout;
	wire [15:0] csr_readout;

	reg  cr_bus_we;

	reg  eps_bus_req;
	wire eps_bus_clear;
	reg  eps_bus_ack_wait;
	wire eps_bus_req_ok;
	reg  [2:0] eps_bus_req_ok_dly;

	wire [15:0] evt_rd_data;
	wire evt_rd_rdy;
	reg  evt_rd_ack;

	// Events
	wire [11:0] evt_data;
	wire evt_stb;

	// Out-of-band conditions
	wire oob_se0;
	wire oob_sof;

	reg  [19:0] timeout_suspend;	//  3 ms with no activity
	reg  [19:0] timeout_reset;		// 10 ms SE0

	wire usb_suspend;
	wire usb_reset;
	reg  rst_pending;
	reg  rst_clear;

	// Start-Of-Frame indication
	reg  sof_ind;
	reg  sof_pending;
	reg  sof_clear;


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
		.cr_addr_chk(cr_addr_chk),
		.cr_addr(cr_addr),
		.evt_data(evt_data),
		.evt_stb(evt_stb),
		.cel_state(cel_state),
		.cel_rel(cel_rel),
		.cel_ena(cr_cel_ena),
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


	// CSR & Bus Interface
	// -------------------

	// Request lines for registers and strobes for actions
	always @(posedge clk)
		if (csr_bus_clear) begin
			csr_bus_req <= 1'b0;
			cr_bus_we   <= 1'b0;
			cel_rel     <= 1'b0;
			rst_clear   <= 1'b0;
			sof_clear   <= 1'b0;
			evt_rd_ack  <= 1'b0;
		end else begin
			csr_bus_req <= 1'b1;
			cr_bus_we   <= (bus_addr[1:0] == 2'b00) &  bus_we;
			cel_rel     <= (bus_addr[1:0] == 2'b01) &  bus_we & bus_din[13];
			rst_clear   <= (bus_addr[1:0] == 2'b01) &  bus_we & bus_din[ 9];
			sof_clear   <= (bus_addr[1:0] == 2'b01) &  bus_we & bus_din[ 8];
			evt_rd_ack  <= (bus_addr[1:0] == 2'b10) & ~bus_we & evt_rd_rdy;
		end

	// Read mux for CSR
	assign csr_readout = {
		cr_pu_ena,
		irq,
		cel_state,
		cr_cel_ena,
		usb_suspend,
		usb_reset,
		rst_pending,
		sof_pending,
		cr_addr_chk,
		cr_addr
	};

	always @(*)
		if (csr_bus_ack)
			case (bus_addr[1:0])
				2'b00:   csr_bus_dout = csr_readout;
				2'b10:   csr_bus_dout = evt_rd_data;
				default: csr_bus_dout = 16'h0000;
			endcase
		else
			csr_bus_dout = 16'h0000;

	// CSR Clear/Ack
	assign csr_bus_ack   = csr_bus_req;
	assign csr_bus_clear = ~bus_cyc | csr_bus_ack | bus_addr[11];

	// Write regs
	always @(posedge clk)
		if (cr_bus_we) begin
			cr_pu_ena  <= bus_din[15];
			cr_cel_ena <= bus_din[12];
			cr_addr_chk<= bus_din[7];
			cr_addr    <= bus_din[6:0];
		end

	// Request lines for EP Status access
	always @(posedge clk)
		if (eps_bus_clear) begin
			eps_bus_read  <= 1'b0;
			eps_bus_write <= 1'b0;
			eps_bus_req   <= 1'b0;
		end else begin
			eps_bus_read  <=  bus_addr[11] & ~bus_we;
			eps_bus_write <=  bus_addr[11] &  bus_we;
			eps_bus_req   <=  bus_addr[11];
		end

	assign eps_bus_zero = ~eps_bus_read;

	// EPS Clear
	assign eps_bus_clear = ~bus_cyc | eps_bus_ack_wait | (eps_bus_req & eps_bus_ready);

	// Track when request are accepted by the RAM
	assign eps_bus_req_ok = (eps_bus_req & eps_bus_ready);

	always @(posedge clk)
		eps_bus_req_ok_dly <= { eps_bus_req_ok_dly[1:0], eps_bus_req_ok & ~bus_we };

	// ACK wait state tracking
	always @(posedge clk or posedge rst)
		if (rst)
			eps_bus_ack_wait <= 1'b0;
		else
			eps_bus_ack_wait <= ((eps_bus_ack_wait & ~bus_we) | eps_bus_req_ok) & ~eps_bus_req_ok_dly[2];

	// Bus Ack
	assign bus_ack = csr_bus_ack | (eps_bus_ack_wait & (bus_we | eps_bus_req_ok_dly[2]));

	// Output is simply the OR of all local units since we force them to zero if
	// they're not accessed
	assign bus_dout = csr_bus_dout | eps_bus_dout;


	// Event handling
	// --------------

	generate
		if (EVT_DEPTH == 0) begin
			// We just save the # of notify since last read
			reg [3:0] evt_cnt;

			always @(posedge clk or posedge rst)
				if (rst)
					evt_cnt <= 4'h0;
				else
					evt_cnt <= evt_rd_ack ? { 3'b000, evt_stb } : (evt_cnt + evt_stb);

			assign evt_rd_rdy = 1'b1;
			assign evt_rd_data = { evt_cnt, 12'h000 };

			assign irq = (evt_cnt != 4'h0);

		end else if (EVT_DEPTH == 1) begin
			// Save the latest value and # of notify since last read
			reg [11:0] evt_last;
			reg [ 3:0] evt_cnt;

			always @(posedge clk or posedge rst)
				if (rst)
					evt_cnt <= 4'h0;
				else
					evt_cnt <= evt_rd_ack ? { 3'b000, evt_stb } : (evt_cnt + evt_stb);

			always @(posedge clk)
				if (evt_stb)
					evt_last <= evt_data;

			assign evt_rd_rdy = 1'b1;
			assign evt_rd_data = { evt_cnt, evt_last };

			assign irq = (evt_cnt != 4'h0);

		end else if (EVT_DEPTH > 1) begin
			// Small shift-reg FIFO
			wire [11:0] ef_wdata;
			wire [11:0] ef_rdata;
			wire ef_wren;
			wire ef_full;
			wire ef_rden;
			wire ef_empty;

			reg  ef_overflow;

			assign ef_wdata = evt_data;
			assign ef_wren  = evt_stb & ~ef_full;

			always @(posedge clk or posedge rst)
				if (rst)
					ef_overflow <= 1'b0;
				else
					ef_overflow <= (ef_overflow & ~evt_rd_ack) | (evt_stb & ef_full);

			assign evt_rd_rdy = ~ef_empty;
			assign evt_rd_data = { ~ef_empty, ef_overflow, 2'b00, ef_rdata };
			assign ef_rden = evt_rd_ack;

			assign irq = ~ef_rden;

			fifo_sync_shift #(
				.DEPTH(EVT_DEPTH),
				.WIDTH(12)
			) evt_fifo_I (
				.wr_data(ef_wdata),
				.wr_ena(ef_wren),
				.wr_full(ef_full),
				.rd_data(ef_rdata),
				.rd_ena(ef_rden),
				.rd_empty(ef_empty),
				.clk(clk),
				.rst(rst)
			);

		end
	endgenerate


	// USB reset/suspend
	// -----------------

	// Detect some conditions for triggers
	assign oob_se0 = ~phy_rx_dp & ~phy_rx_dn;
	assign oob_sof = rxpkt_start & rxpkt_is_sof;

	// Suspend timeout counter
	always @(posedge clk)
		if (oob_sof | usb_reset)
			timeout_suspend <= 20'hdcd80;	// 3 ms
		else
			timeout_suspend <= timeout_suspend + timeout_suspend[19];

	assign usb_suspend = ~timeout_suspend[19];

	// Reset timeout counter
	always @(posedge clk)
		if (~oob_se0)
			timeout_reset <= 20'h8ad00;
		else
			timeout_reset <= timeout_reset + timeout_reset[19];

	assign usb_reset = ~timeout_reset[19];

	always @(posedge clk or posedge rst)
		if (rst)
			rst_pending <= 1'b1;
		else
			rst_pending <= (rst_pending & ~rst_clear) | usb_reset;

	// Detection pin
	always @(posedge clk)
		if (rst)
			pad_pu <= 1'b0;
		else
			pad_pu <= cr_pu_ena;


	// Misc
	// ----

	always @(posedge clk)
		sof_ind <= rxpkt_start & rxpkt_is_sof;

	always @(posedge clk)
		sof_pending <= (sof_pending & ~sof_clear) | (rxpkt_start & rxpkt_is_sof);

	assign sof = sof_ind;

endmodule // usb
