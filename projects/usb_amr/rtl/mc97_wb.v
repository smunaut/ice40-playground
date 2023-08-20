/*
 * mc97_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module mc97_wb (
	// MC97 link
	output wire mc97_sdata_out,
	input  wire mc97_sdata_in,
	output wire mc97_sync,
	input  wire mc97_bitclk,
	output reg  mc97_reset_n,

	// Wishbone slave
	input  wire [ 3:0] wb_addr,
	output reg  [31:0] wb_rdata,
	input  wire [31:0] wb_wdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output wire        wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Wishbone
	reg  b_ack;

	wire b_wr_rst;
	wire b_rd_rst;

	reg  b_we_csr;
	reg  b_we_ll_stat;
	reg  b_we_ll_reg;
	reg  b_we_ll_gpio_out;
	reg  b_we_ll_fifo_data;
	reg  b_re_ll_fifo_data;
	reg  b_we_ll_fifo_csr;

	// FIFO PCM Input
    wire [15:0] fpi_w_data;
    wire        fpi_w_ena;
    wire        fpi_w_full;

    wire [15:0] fpi_r_data;
    wire        fpi_r_ena;
    wire        fpi_r_empty;

	wire [ 8:0] fpi_lvl;
	reg         fpi_ena;
	reg         fpi_flush;

	// FIFO PCM output
    wire [15:0] fpo_w_data;
    wire        fpo_w_ena;
    wire        fpo_w_full;

    wire [15:0] fpo_r_data;
    wire        fpo_r_ena;
    wire        fpo_r_empty;

	wire [ 8:0] fpo_lvl;
	reg         fpo_ena;
	reg         fpo_flush;

	// LL PCM interface
	wire [15:0] ll_pcm_out_data;
	wire        ll_pcm_out_ack;
	wire [15:0] ll_pcm_in_data;
	wire        ll_pcm_in_stb;

	// LL GPIO interface
	wire [19:0] ll_gpio_in;
	reg  [19:0] ll_gpio_out;
	reg         ll_gpio_ena;

	// LL Registers interface
	reg  [ 5:0] ll_reg_addr;
	reg  [15:0] ll_reg_wdata;
	wire [15:0] ll_reg_rdata;
	wire        ll_reg_rerr;
	reg         ll_reg_valid;
	reg         ll_reg_we;
	wire        ll_reg_ack;

	reg  [15:0] ll_reg_rdata_r;
	wire        ll_reg_rerr_r;

	// LL Misc interface
	reg         ll_run;
	wire        ll_rfi;
	wire        ll_stat_codec_ready;
	wire [12:0] ll_stat_slot_valid;
	wire [12:0] ll_stat_slot_req;
	wire        ll_stat_clr;


	// Bus Interface
	// -------------

	// Ack
	always @(posedge clk)
		b_ack <= wb_cyc & ~b_ack;

	assign wb_ack = b_ack;

	// Pre-control
	assign b_wr_rst = ~wb_cyc | b_ack | ~wb_we;
	assign b_rd_rst = ~wb_cyc | b_ack |  wb_we;

	// Write
	always @(posedge clk)
	begin
		if (b_wr_rst) begin
			b_we_csr          <= 1'b0;
			b_we_ll_stat      <= 1'b0;
			b_we_ll_reg       <= 1'b0;
			b_we_ll_gpio_out  <= 1'b0;
			b_we_ll_fifo_data <= 1'b0;
			b_we_ll_fifo_csr  <= 1'b0;
		end else begin
			b_we_csr          <= wb_addr == 4'h0;
			b_we_ll_stat      <= wb_addr == 4'h1;
			b_we_ll_reg       <= wb_addr == 4'h2;
			b_we_ll_gpio_out  <= wb_addr == 4'h5;
			b_we_ll_fifo_data <= wb_addr == 4'h6;
			b_we_ll_fifo_csr  <= wb_addr == 4'h7;
		end
	end

	// Read mux
	always @(posedge clk)
		if (b_rd_rst)
			wb_rdata <= 32'h00000000;
		else
			casez (wb_addr[2:0])
				3'h0:    wb_rdata <= { 28'h0, ll_rfi, ll_gpio_ena, mc97_reset_n, ll_run };
				3'h1:    wb_rdata <= { ll_stat_codec_ready, 2'h0, ll_stat_slot_req, 3'h0, ll_stat_slot_valid };
				3'h2:    wb_rdata <= { ll_reg_valid, ll_reg_we, ll_reg_rerr_r, 7'h0, ll_reg_addr, ll_reg_rdata_r };
				3'h4:    wb_rdata <= { 12'h0, ll_gpio_in  };
				3'h5:    wb_rdata <= { 12'h0, ll_gpio_out };
				3'h6:    wb_rdata <= { fpi_r_empty, 15'h0, fpi_r_data };
				3'h7:    wb_rdata <= {
								fpi_ena, fpi_flush, fpi_w_full, fpi_r_empty, 3'b000, fpi_lvl,
								fpo_ena, fpo_flush, fpo_w_full, fpo_r_empty, 3'b000, fpo_lvl
							};
				default: wb_rdata <= 32'hxxxxxxxx;
			endcase
	
	always @(posedge clk)
		if (b_rd_rst)
			b_re_ll_fifo_data <= 1'b0;
		else
			b_re_ll_fifo_data <= wb_addr == 4'h6;


	// PCM
	// ---

	// Bus interface
	assign fpi_r_ena  = b_re_ll_fifo_data & ~wb_rdata[28];
	assign fpo_w_data = wb_wdata[15:0];
	assign fpo_w_ena  = b_we_ll_fifo_data;

	always @(posedge clk)
		if (rst) begin
			fpi_ena <= 1'b0;
			fpo_ena <= 1'b0;
		end else if (b_we_ll_fifo_csr) begin
			fpi_ena <= wb_wdata[31];
			fpo_ena <= wb_wdata[15];
		end
	
	always @(posedge clk)
		if (rst) begin
			fpi_flush <= 1'b0;
			fpo_flush <= 1'b0;
		end else begin
			fpi_flush <= (fpi_flush & ~fpi_r_empty) | (b_we_ll_fifo_csr & wb_wdata[30]);
			fpo_flush <= (fpo_flush & ~fpo_r_empty) | (b_we_ll_fifo_csr & wb_wdata[14]);
		end

	// FIFO instances
	mc97_fifo fifo_pcm_in_I (
		.wr_data   (fpi_w_data),
		.wr_ena    (fpi_w_ena),
		.wr_full   (fpi_w_full),
		.rd_data   (fpi_r_data),
		.rd_ena    (fpi_r_ena),
		.rd_empty  (fpi_r_empty),
		.ctl_lvl   (fpi_lvl),
		.ctl_flush (fpi_flush),
		.clk       (clk),
		.rst       (rst)
	);

	mc97_fifo fifo_pcm_out_I (
		.wr_data   (fpo_w_data),
		.wr_ena    (fpo_w_ena),
		.wr_full   (fpo_w_full),
		.rd_data   (fpo_r_data),
		.rd_ena    (fpo_r_ena),
		.rd_empty  (fpo_r_empty),
		.ctl_lvl   (fpo_lvl),
		.ctl_flush (fpo_flush),
		.clk       (clk),
		.rst       (rst)
	);

	// Low-Level interface
	assign fpi_w_data = ll_pcm_in_data;
	assign fpi_w_ena  = ll_pcm_in_stb & fpi_ena;

	assign ll_pcm_out_data = fpo_r_data;
	assign fpo_r_ena = ll_pcm_out_ack & fpo_ena;


	// GPIO
	// ----

	always @(posedge clk or posedge rst)
		if (rst)
			ll_gpio_out <= 20'h00000;
		else if (b_we_ll_gpio_out)
			ll_gpio_out <= wb_wdata[19:0];


	always @(posedge clk or posedge rst)
		if (rst)
			ll_gpio_ena <= 1'b0;
		else if (b_we_csr)
			ll_gpio_ena <= wb_wdata[2];


	// Register access
	// ---------------

	always @(posedge clk)
		ll_reg_valid <= (ll_reg_valid | b_we_ll_reg) & ~ll_reg_ack;

	always @(posedge clk)
		if (b_we_ll_reg) begin
			ll_reg_we    <= wb_wdata[30];
			ll_reg_addr  <= wb_wdata[21:16];
			ll_reg_wdata <= wb_wdata[15:0];
		end

	always @(posedge clk)
		if (ll_reg_ack & ~ll_reg_we) begin
			ll_reg_rdata_r <= ll_reg_rdata;
			ll_reg_rerr_r  <= ll_reg_rerr;
		end


	// Misc
	// ----

	always @(posedge clk or posedge rst)
		if (rst) begin
			mc97_reset_n <= 1'b1;
			ll_run       <= 1'b0;
		end else if (b_we_csr) begin
			mc97_reset_n <= wb_wdata[1];
			ll_run       <= wb_wdata[0];
		end

	assign ll_stat_clr = b_we_ll_stat;


	// Low-level MC97
	// --------------

	mc97 ll_I (
		.mc97_sdata_out  (mc97_sdata_out),
		.mc97_sdata_in   (mc97_sdata_in),
		.mc97_sync       (mc97_sync),
		.mc97_bitclk     (mc97_bitclk),
		.pcm_out_data    (ll_pcm_out_data),
		.pcm_out_ack     (ll_pcm_out_ack),
		.pcm_in_data     (ll_pcm_in_data),
		.pcm_in_stb      (ll_pcm_in_stb),
		.gpio_in         (ll_gpio_in),
		.gpio_out        (ll_gpio_out),
		.gpio_ena        (ll_gpio_ena),
		.reg_addr        (ll_reg_addr),
		.reg_wdata       (ll_reg_wdata),
		.reg_rdata       (ll_reg_rdata),
		.reg_rerr        (ll_reg_rerr),
		.reg_valid       (ll_reg_valid),
		.reg_we          (ll_reg_we),
		.reg_ack         (ll_reg_ack),
		.cfg_run         (ll_run),
		.rfi             (ll_rfi),
		.stat_codec_ready(ll_stat_codec_ready),
		.stat_slot_valid (ll_stat_slot_valid),
		.stat_slot_req   (ll_stat_slot_req),
		.stat_clr        (ll_stat_clr),
		.clk             (clk),
		.rst             (rst)
	);

endmodule // mc97_wb
