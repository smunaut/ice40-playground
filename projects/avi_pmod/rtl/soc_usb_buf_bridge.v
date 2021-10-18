/*
 * soc_usb_buf_bridge.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module soc_usb_buf_bridge (
	// Wishbone (from SoC)
    input  wire [15:0] wb_addr,
    output reg  [31:0] wb_rdata,
    input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
    input  wire        wb_we,
    input  wire        wb_cyc,
    output reg         wb_ack,

	// Priority DMA access
	input  wire        dma_req,
	output wire        dma_gnt,

	input  wire [15:0] dma_addr,
	input  wire [31:0] dma_data,
	input  wire        dma_we,

	// USB EP buffer
	output wire [ 8:0] ep_tx_addr_0,
	output wire [31:0] ep_tx_data_0,
	output wire        ep_tx_we_0,

	output wire [ 8:0] ep_rx_addr_0,
	input  wire [31:0] ep_rx_data_1,
	output wire        ep_rx_re_0,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// DMA state
	reg dma_active;

	// Mux
	wire [15:0] mux_addr;
	wire [31:0] mux_wdata;

	// Local memory
	wire [13:0] lmem_addr_0;
	wire [31:0] lmem_rdata_1;
	wire [31:0] lmem_wdata_0;
	wire  [3:0] lmem_wmsk_0;
	wire  [7:0] lmem_wmsk_nibble_0;
	wire        lmem_we_0;


	// DMA state
	// ---------

	always @(posedge clk)
		// Release ASAP
		if (~dma_req)
			dma_active <= 1'b0;

		// Only allow when WB is not used or ack
		else if (~wb_cyc | wb_ack)
			dma_active <= 1'b1;

	assign dma_gnt = dma_active;


	// Wishbone
	// --------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~dma_active & ~wb_ack;

	// Read
	always @(*)
		if (~wb_ack)
			wb_rdata = 32'h00000000;
		else
			wb_rdata = wb_addr[14] ? lmem_rdata_1 : ep_rx_data_1;


	// Access mux
	// ----------

	// Address
	assign mux_addr  = dma_active ? dma_addr  : wb_addr;

	assign ep_tx_addr_0 = mux_addr[ 8:0];
	assign ep_rx_addr_0 = mux_addr[ 8:0];
	assign lmem_addr_0  = mux_addr[13:0];

	// Write data
	assign mux_wdata = dma_active ? dma_data : wb_wdata;

	assign ep_tx_data_0 = mux_wdata;
	assign lmem_wdata_0 = mux_wdata;

	// Write mask
	assign lmem_wmsk_0 = dma_active ? 4'h0 : wb_wmsk;

	// Write enable
	assign ep_tx_we_0 = (dma_we | (wb_ack & wb_we)) & (mux_addr[14] == 1'b0);
	assign lmem_we_0  = (dma_we | (wb_ack & wb_we)) & (mux_addr[14] == 1'b1);


	// Local Memory (64k SPRAM)
	// ------------

	assign lmem_wmsk_nibble_0 = {
		lmem_wmsk_0[3], lmem_wmsk_0[3],
		lmem_wmsk_0[2], lmem_wmsk_0[2],
		lmem_wmsk_0[1], lmem_wmsk_0[1],
		lmem_wmsk_0[0], lmem_wmsk_0[0]
	};

	ice40_spram_gen #(
		.ADDR_WIDTH(14),
		.DATA_WIDTH(32)
	) spram_I (
		.addr    (lmem_addr_0),
		.rd_data (lmem_rdata_1),
		.rd_ena  (1'b1),
		.wr_data (lmem_wdata_0),
		.wr_mask (lmem_wmsk_nibble_0),
		.wr_ena  (lmem_we_0),
		.clk     (clk)
	);

endmodule // soc_usb_buf_bridge
