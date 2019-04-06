/*
 * iobuf.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
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

module iobuf (
	// Wishbone slave
	input  wire [15:0] wb_addr,
	output wire [31:0] wb_rdata,
	input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
	input  wire [ 2:0] wb_cyc,	// 0=EP buf, 1=SPRAM, 2=DMA
	input  wire wb_we,
	output wire [ 2:0] wb_ack,

	// USB EP-Buf master
	output wire [ 8:0] ep_tx_addr_0,
	output wire [31:0] ep_tx_data_0,
	output wire ep_tx_we_0,

	output wire [ 8:0] ep_rx_addr_0,
	input  wire [31:0] ep_rx_data_1,
	output wire ep_rx_re_0,

	// E1 RX data if (write)
	input  wire [ 7:0] e1rx_data,
	input  wire [ 4:0] e1rx_ts,
	input  wire [ 3:0] e1rx_frame,
	input  wire [ 6:0] e1rx_mf,
	input  wire e1rx_we,
	output wire e1rx_rdy,

	// E1 TX data if (read)
	output wire [ 7:0] e1tx_data,
	input  wire [ 4:0] e1tx_ts,
	input  wire [ 3:0] e1tx_frame,
	input  wire [ 6:0] e1tx_mf,
	input  wire e1tx_re,
	output wire e1tx_rdy,

	/* Clock / Reset */
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// SPRAM
	wire [13:0] spr_addr;
	wire [31:0] spr_rdata;
	wire [31:0] spr_wdata;
	wire [ 3:0] spr_wmsk;
	wire spr_cyc;
	wire spr_we;
	wire spr_ack;

	wire [13:0] spr0_addr;
	wire [31:0] spr0_rdata;
	wire [31:0] spr0_wdata;
	wire [ 3:0] spr0_wmsk;
	wire spr0_cyc;
	wire spr0_we;
	wire spr0_ack;

	wire [13:0] spr1_addr;
	wire [31:0] spr1_rdata;
	wire [31:0] spr1_wdata;
	wire [ 3:0] spr1_wmsk;
	wire spr1_cyc;
	wire spr1_we;
	wire spr1_ack;

	wire [13:0] spr2_addr;
	wire [31:0] spr2_rdata;
	wire [31:0] spr2_wdata;
	wire [ 3:0] spr2_wmsk;
	wire spr2_cyc;
	wire spr2_we;
	wire spr2_ack;

	// EP Buffer
	wire [ 8:0] epb_addr;
	wire [31:0] epb_rdata;
	wire [31:0] epb_wdata;
	wire epb_cyc;
	wire epb_we;
	wire epb_ack;

	wire [ 8:0] epb0_addr;
	wire [31:0] epb0_rdata;
	wire [31:0] epb0_wdata;
	wire epb0_cyc;
	wire epb0_we;
	wire epb0_ack;

	wire [ 8:0] epb1_addr;
	wire [31:0] epb1_rdata;
	wire [31:0] epb1_wdata;
	wire epb1_cyc;
	wire epb1_we;
	wire epb1_ack;

	// DMA
	wire [31:0] wb_rdata_dma;


	// SPRAM
	// -----

	// Instance
	wb_spram #(
		.W(32)
	) spram_I (
		.addr(spr_addr),
		.rdata(spr_rdata),
		.wdata(spr_wdata),
		.wmsk(spr_wmsk),
		.cyc(spr_cyc),
		.we(spr_we),
		.ack(spr_ack),
		.clk(clk),
		.rst(rst)
	);

	// Arbiter
	wb_arbiter #(
		.N(3),
		.DW(32),
		.AW(14)
	) spram_arb_I (
		.s_addr({spr2_addr, spr1_addr, spr0_addr}),
		.s_rdata({spr2_rdata, spr1_rdata, spr0_rdata}),
		.s_wdata({spr2_wdata, spr1_wdata, spr0_wdata}),
		.s_wmsk({spr2_wmsk, spr1_wmsk, spr0_wmsk}),
		.s_cyc({spr2_cyc, spr1_cyc, spr0_cyc}),
		.s_we({spr2_we, spr1_we, spr0_we}),
		.s_ack({spr2_ack, spr1_ack, spr0_ack}),
		.m_addr(spr_addr),
		.m_rdata(spr_rdata),
		.m_wdata(spr_wdata),
		.m_wmsk(spr_wmsk),
		.m_cyc(spr_cyc),
		.m_we(spr_we),
		.m_ack(spr_ack),
		.clk(clk),
		.rst(rst)
	);


	// E1 data IF
	// ----------

	wb_e1data #(
		.AW(14),
		.DW(32)
	) e1data_I (
		.wb_addr(spr0_addr),
		.wb_rdata(spr0_rdata),
		.wb_wdata(spr0_wdata),
		.wb_wmsk(spr0_wmsk),
		.wb_cyc(spr0_cyc),
		.wb_we(spr0_we),
		.wb_ack(spr0_ack),
		.e1rx_data(e1rx_data),
		.e1rx_ts(e1rx_ts),
		.e1rx_frame(e1rx_frame),
		.e1rx_mf(e1rx_mf),
		.e1rx_we(e1rx_we),
		.e1rx_rdy(e1rx_rdy),
		.e1tx_data(e1tx_data),
		.e1tx_ts(e1tx_ts),
		.e1tx_frame(e1tx_frame),
		.e1tx_mf(e1tx_mf),
		.e1tx_re(e1tx_re),
		.e1tx_rdy(e1tx_rdy),
		.clk(clk),
		.rst(rst)
	);


	// EP buffer
	// ---------

	// Instance
	wb_epbuf #(
		.AW(9),
		.DW(32)
	) epbuf_I (
		.wb_addr(epb_addr),
		.wb_rdata(epb_rdata),
		.wb_wdata(epb_wdata),
		.wb_cyc(epb_cyc),
		.wb_we(epb_we),
		.wb_ack(epb_ack),
		.ep_tx_addr_0(ep_tx_addr_0),
		.ep_tx_data_0(ep_tx_data_0),
		.ep_tx_we_0(ep_tx_we_0),
		.ep_rx_addr_0(ep_rx_addr_0),
		.ep_rx_data_1(ep_rx_data_1),
		.ep_rx_re_0(ep_rx_re_0),
		.clk(clk),
		.rst(rst)
	);

	// Arbiter
	wb_arbiter #(
		.N(2),
		.DW(32),
		.AW(9)
	) epbam_arb_I (
		.s_addr({epb1_addr, epb0_addr}),
		.s_rdata({epb1_rdata, epb0_rdata}),
		.s_wdata({epb1_wdata, epb0_wdata}),
		.s_wmsk(8'hff),
		.s_cyc({epb1_cyc, epb0_cyc}),
		.s_we({epb1_we, epb0_we}),
		.s_ack({epb1_ack, epb0_ack}),
		.m_addr(epb_addr),
		.m_rdata(epb_rdata),
		.m_wdata(epb_wdata),
		.m_cyc(epb_cyc),
		.m_we(epb_we),
		.m_ack(epb_ack),
		.clk(clk),
		.rst(rst)
	);


	// DMA
	// ---

	wb_dma #(
		.A0W(14),
		.A1W(9),
		.DW(32)
	) dma_I (
		.m0_addr(spr2_addr),
		.m0_rdata(spr2_rdata),
		.m0_wdata(spr2_wdata),
		.m0_cyc(spr2_cyc),
		.m0_we(spr2_we),
		.m0_ack(spr2_ack),
		.m1_addr(epb1_addr),
		.m1_rdata(epb1_rdata),
		.m1_wdata(epb1_wdata),
		.m1_cyc(epb1_cyc),
		.m1_we(epb1_we),
		.m1_ack(epb1_ack),
		.ctl_addr(wb_addr[1:0]),
		.ctl_rdata(wb_rdata_dma),
		.ctl_wdata(wb_wdata),
		.ctl_cyc(wb_cyc[2]),
		.ctl_we(wb_we),
		.ctl_ack(wb_ack[2]),
		.clk(clk),
		.rst(rst)
	);

	assign spr2_wmsk = 4'hf;


	// External accesses
	// -----------------

	assign spr1_addr  = wb_addr[13:0];
	assign spr1_wdata = wb_wdata;
	assign spr1_wmsk  = wb_wmsk;
	assign spr1_cyc   = wb_cyc[1];
	assign spr1_we    = wb_we;
	assign wb_ack[1]  = spr1_ack;

	assign epb0_addr  = wb_addr[8:0];
	assign epb0_wdata = wb_wdata;
	assign epb0_cyc   = wb_cyc[0];
	assign epb0_we    = wb_we;
	assign wb_ack[0]  = epb0_ack;

	assign wb_rdata = spr1_rdata | epb0_rdata | wb_rdata_dma;

endmodule // iobuf
