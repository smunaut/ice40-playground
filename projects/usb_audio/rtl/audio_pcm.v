/*
 * audio_pcm.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module audio_pcm (
	// Audio output
	output wire [1:0] audio,

	// Wishbone slave
	input  wire [ 1:0] wb_addr,
	output reg  [31:0] wb_rdata,
	input  wire [31:0] wb_wdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output wire        wb_ack,

	// USB
	input  wire usb_sof,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Wishbone
	reg  b_ack;
	reg  b_we_csr;
	reg  b_we_volume;
	reg  b_we_fifo;
	wire b_rd_rst;

	reg         run;
	reg  [15:0] volume[0:1];

	// FSM
	localparam
		ST_IDLE  = 0,
		ST_RUN   = 1,
		ST_FLUSH = 2;

	reg  [ 1:0] state;
	reg  [ 1:0] state_nxt;

	wire running;

	// Timebase
	wire        tick;
	reg  [ 9:0] tick_cnt;

	reg  [15:0] tpf_cnt;
	reg  [15:0] tpf_cap;

	// FIFO
    wire [31:0] fw_data;
    wire        fw_ena;
    wire        fw_full;

    wire [31:0] fr_data;
    wire        fr_ena;
    wire        fr_empty;

	reg  [ 9:0] f_lvl;
	wire [ 9:0] f_mod;

	// Audio pipeline
	reg  [15:0] av_volume [0:1];
	reg  [15:0] av_sample [0:1];
	reg  [31:0] av_scaled [0:1];

	wire [15:0] av_out[0:1];


	// Wishbone interface
	// ------------------

	// Ack
	always @(posedge clk)
		b_ack <= wb_cyc & ~b_ack;

	assign wb_ack = b_ack;

	// Write
	always @(posedge clk)
	begin
		if (b_ack) begin
			b_we_csr    <= 1'b0;
			b_we_volume <= 1'b0;
			b_we_fifo   <= 1'b0;
		end else begin
			b_we_csr    <= wb_cyc & wb_we & (wb_addr == 2'b00);
			b_we_volume <= wb_cyc & wb_we & (wb_addr == 2'b01);
			b_we_fifo   <= wb_cyc & wb_we & (wb_addr == 2'b10);
		end
	end

	always @(posedge clk)
		if (rst)
			run <= 1'b0;
		else if (b_we_csr)
			run <= wb_wdata[0];

	always @(posedge clk or posedge rst)
		if (rst)
			{ volume[1], volume[0] } <= 32'h00000000;
		else if (b_we_volume)
			{ volume[1], volume[0] } <= wb_wdata;

	assign fw_data = wb_wdata;
	assign fw_ena  = b_we_fifo & ~fw_full;

	// Read
	assign b_rd_rst = ~wb_cyc | b_ack;

	always @(posedge clk)
		if (b_rd_rst)
			wb_rdata <= 32'h00000000;
		else
			wb_rdata <= { tpf_cap, 2'b00, f_lvl, 2'b00, running, run };


	// FSM
	// ---

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next state
	always @(*)
	begin
		// Default is to stay
		state_nxt = state;

		// Transitions
		case (state)
		ST_IDLE:
			if (run)
				state_nxt = ST_RUN;

		ST_RUN:
			if (~run)
				state_nxt = ST_FLUSH;

		ST_FLUSH:
			if (fr_empty)
				state_nxt = ST_IDLE;
		endcase
	end

	// Misc
	assign running = (state == ST_RUN) | (state == ST_FLUSH);


	// Timebase
	// --------

	// Tick counter
	always @(posedge clk or posedge rst)
		if (rst)
			tick_cnt <= 0;
		else
			tick_cnt <= tick ? 10'd498 : (tick_cnt - 1);

	assign tick = tick_cnt[9];

	// Tick-per-usb frame counter
	always @(posedge clk or posedge rst)
		if (rst)
			tpf_cnt <= 16'h0000;
		else
			tpf_cnt <= tpf_cnt + tick;

	always @(posedge clk or posedge rst)
		if (rst)
			tpf_cap <= 16'h0000;
		else if (usb_sof)
			tpf_cap <= tpf_cnt;


	// FIFO
	// ----

	// Instance
	fifo_sync_ram #(
		.DEPTH(512),
		.WIDTH(32)
	) fifo_I (
		.wr_data  (fw_data),
		.wr_ena   (fw_ena),
		.wr_full  (fw_full),
		.rd_data  (fr_data),
		.rd_ena   (fr_ena),
		.rd_empty (fr_empty),
		.clk      (clk),
		.rst      (rst)
	);

	// Read
	assign fr_ena = ~fr_empty & tick & running;

	// Level counter
	always @(posedge clk)
		if (rst)
			f_lvl <= 0;
		else
			f_lvl <= f_lvl + f_mod;

	assign f_mod = { {9{fr_ena & ~fw_ena}}, fr_ena ^ fw_ena };


	// Volume & Mute
	// -------------

	always @(posedge clk)
	begin : outpipe
		integer i;

		for (i=0; i<2; i=i+1)
		begin
			av_volume[i] <= volume[i];
			av_sample[i] <= fr_empty ? 0 : fr_data[16*i+:16];
			av_scaled[i] <= $signed(av_volume[i]) * $signed(av_sample[i]);
		end
	end


	// PDM output
	// ----------

	assign av_out[0] = av_scaled[0][30:15] ^ 16'h8000;
	assign av_out[1] = av_scaled[1][30:15] ^ 16'h8000;

	pdm #(
		.WIDTH(16),
		.DITHER("NO"),
		.PHY("ICE40")
	) pdm_I[1:0] (
		.pdm     (audio),
		.cfg_val ({av_out[1], av_out[0]}),
		.cfg_oe  (1'b1),
		.clk     (clk),
		.rst     (rst)
	);

endmodule // audio_pcm
