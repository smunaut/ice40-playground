/*
 * vid_pix_fifo.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_frame_grab (
	// Video data (pre-sync'd) and control
	input  wire [31:0] vid_data,
	input  wire        vid_valid,
	input  wire        vid_clk,
	input  wire        vid_rst,

	// QPI Memory interface
	output wire [21:0] mi_addr,
	output wire [ 6:0] mi_len,
	output wire        mi_rw,
	output wire        mi_valid,
	input  wire        mi_ready,

	output wire [31:0] mi_wdata,
	input  wire        mi_wack,
	input  wire        mi_wlast,

	input  wire [31:0] mi_rdata,
	input  wire        mi_rstb,
	input  wire        mi_rlast,

	// Wishbone
	input  wire [15:0] wb_addr,
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Control
	output wire        ctrl_vid_run,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Control FSM
	localparam [3:0]
		ST_DISABLED     = 0,	/* Discard data  */
		ST_SYNC_1       = 1,	/* Discard data until EAV F=0 V=0 */
		ST_SYNC_2       = 2,	/* Discard data until EAV F=0 V=1 */
		ST_FRAME_START  = 3,	/* Start frame capture */
		ST_BURST_WAIT   = 4,	/* Wait for data */
		ST_BURST_START  = 5,	/* Send command  */
		ST_BURST_DATA   = 6,	/* Data phase    */
		ST_BURST_NEXT   = 7,	/* Prepare next  */
		ST_FRAME_DONE   = 8;	/* Frame capture done */

	reg   [3:0] state;
	reg   [3:0] state_nxt;

	// Pixel FIFO Write port
	reg   [1:0] pfw_active_sync;
	wire        pfw_active;

	// Pixel FIFO Read port
	wire [31:0] pfr_data;
	reg         pfr_ena;
	wire        pfr_aempty;
	wire        pfr_empty;

	wire [ 4:0] pfr_rwd_words;
	wire        pfr_rwd_stb;

	wire        pfr_rst;

	// Input pre-process
	wire        pfr_data_sync;
	wire  [2:0] pfr_data_fvh;
	reg         state_v_zone;

	reg         pix_stb;
	reg         pix_sync;
	reg   [2:0] pix_fvh;

	// Memory
	reg         mem_first_burst;
	reg  [21:0] mem_addr;
	reg  [20:0] mem_len;

	// 'Done' descriptor infos
	reg         df_wdata_ok;
	reg   [3:0] df_wdata_fid;
	reg   [9:0] df_wdata_htotal;
	reg   [5:0] df_wdata_vblank;
	reg   [9:0] df_wdata_vtotal;

	// Descriptor FIFOs
	wire [31:0] pf_wdata;
	wire        pf_we;
	wire        pf_we_safe;
	wire        pf_full;
	wire [31:0] pf_rdata;
	wire        pf_re;
	wire        pf_empty;

	reg         pf_overflow;
	wire        pf_overflow_clr;
	reg         pf_underflow;
	wire        pf_underflow_set;
	wire        pf_underflow_clr;

	wire [31:0] df_wdata;
	wire        df_we;
	wire        df_we_safe;
	wire        df_full;
	wire [31:0] df_rdata;
	wire        df_re;
	wire        df_empty;

	reg         df_overflow;
	wire        df_overflow_clr;

	// Bus interface
	wire        bus_rd_clr;
	wire [31:0] bus_rdata_csr;
	wire [31:0] bus_rdata_df;
	reg         bus_we_csr;
	reg         bus_we_fifo;

	// CSRs
	reg         csr_frame_cap_ena;
	reg         csr_pix_cap_ena;
	reg         csr_fifo_ena;
	reg         csr_vid_ena;


	// Ingress FIFO
	// ------------

	// Write control / enable
	always @(posedge vid_clk or posedge vid_rst)
		if (vid_rst)
			pfw_active_sync <= 2'b00;
		else
			pfw_active_sync <= { pfw_active_sync[0], csr_pix_cap_ena };

	assign pfw_active = pfw_active_sync[1];

	// Instance
	vid_pix_fifo pix_fifo_I (
		.w_data      (vid_data),
		.w_ena       (vid_valid & pfw_active),
		.w_clk       (vid_clk),
		.r_data      (pfr_data),
		.r_ena       (pfr_ena),
		.r_aempty    (pfr_aempty),
		.r_empty     (pfr_empty),
		.r_rwd_words (pfr_rwd_words),
		.r_rwd_stb   (pfr_rwd_stb),
		.r_clk       (clk),
		.rst         (pfr_rst)
	);

	assign pfr_rst = ~csr_fifo_ena;

	// External Control
	assign ctrl_vid_run = csr_vid_ena;


	// Control FSM
	// -----------

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_DISABLED;
		else
			state <= state_nxt;

	// Next-state logic
	always @(*)
	begin
		// Default is no change
		state_nxt = state;

		// Transitions
		case (state)
			ST_DISABLED:
				/* Wait until we get enabled */
				if (csr_frame_cap_ena)
					state_nxt = ST_SYNC_1;

			ST_SYNC_1:
				if (pfr_data_sync & (pfr_data_fvh[1:0] == 2'b01))
					state_nxt = ST_SYNC_2;

			ST_SYNC_2:
				if (pfr_data_sync & (pfr_data_fvh[1:0] == 2'b11))
					state_nxt = ST_FRAME_START;

			ST_FRAME_START:
				/* If we have no descriptor, skip frame. Else start capture */
				state_nxt = pf_empty ? ST_SYNC_1 : ST_BURST_WAIT;

			ST_BURST_WAIT:
				/* Wait until we're sure we have enough pixels for burst */
				if (~pfr_aempty)
					state_nxt = ST_BURST_START;

			ST_BURST_START:
				/* Wait until command is accepted */
				if (mi_ready)
					state_nxt = ST_BURST_DATA;

			ST_BURST_DATA:
				/* Wait for last data */
				if (mi_wack & mi_wlast)
					if (pfr_data_sync & (pfr_data_fvh[1:0] == 2'b11) & (state_v_zone == 1'b0))
						/* We're at the end of frame */
						state_nxt = ST_FRAME_DONE;
					else
						/* Just continue */
						state_nxt = ST_BURST_NEXT;

			ST_BURST_NEXT:
				/* Just a state to do prep for next burst */
				/* We still need to handle running out of memory */
				state_nxt = mem_len[20] ? ST_BURST_WAIT : ST_FRAME_DONE;

			ST_FRAME_DONE:
				/* Just a state to finish up frame */
				/* It might have been early abort, so go back to sync */
				state_nxt = (state_v_zone == 1'b1) ? ST_SYNC_1 : ST_SYNC_2;

			default:
				state_nxt = ST_DISABLED;
		endcase

		// Force disabled state
		if (~csr_frame_cap_ena)
			state_nxt = ST_DISABLED;
	end


	// Input pre-process
	// -----------------

	// Sync find
	assign pfr_data_sync = (pfr_data[31:8] == 24'hff0000);
	assign pfr_data_fvh  = pfr_data[6:4];

	// Track V zone
	always @(posedge clk)
		if (pfr_ena & pfr_data_sync & pfr_data_fvh[0])	// EAV
			state_v_zone <= pfr_data_fvh[1];

	// Registered version of metadata of pixel passing by
	always @(posedge clk)
	begin
		pix_stb  <= pfr_ena;
		pix_sync <= pfr_data_sync;
		pix_fvh  <= pfr_data_fvh;
	end


	// Pixel FIFO control
	// ------------------

	// Don't use rewind
	assign pfr_rwd_words = 5'd0;
	assign pfr_rwd_stb   = 1'b0;

	// When to read is ... complex
	always @(*)
	begin
		// Default is not to read
		pfr_ena = 1'b0;

		// Then it depends on the current state
		case (state)
			ST_DISABLED:
				/* Discard data  */
				pfr_ena = 1'b1;

			ST_SYNC_1:
				/* Discard data until EAV F=0 V=0 */
				pfr_ena = ~(pfr_data_sync & (pfr_data_fvh[1:0] == 2'b01));

			ST_SYNC_2:
				/* Discard data until EAV F=0 V=1 */
				pfr_ena = ~(pfr_data_sync & (pfr_data_fvh[1:0] == 2'b11));

			ST_BURST_DATA:
				/* Only go to the start of next frame */
				pfr_ena = mi_wack & ~(pfr_data_sync & (pfr_data_fvh[1:0] == 2'b11) & (state_v_zone == 1'b0) & ~mem_first_burst);
		endcase
	end


	// Memory control
	// --------------

	// Keep track of first burst
	always @(posedge clk)
		mem_first_burst <= (mem_first_burst & ~(state == ST_BURST_NEXT)) | (state == ST_FRAME_START);

	// Address and length counters (in words)
	always @(posedge clk)
		if (state == ST_FRAME_START) begin
			mem_addr <= { pf_rdata[25:12], 8'h00 };
			mem_len  <= { 1'b1, pf_rdata[11:0], 8'h00 } - 64;
		end else if (state == ST_BURST_NEXT) begin
			mem_addr <= mem_addr + 64;
			mem_len  <= mem_len  - 64;
		end

	// Memory commands
	assign mi_valid = (state == ST_BURST_START);
	assign mi_addr  = mem_addr;
	assign mi_len   = 7'd63;	/* Always 64 words bursts */
	assign mi_rw    = 1'b0;		/* Always write */

	// Data
	assign mi_wdata = {
		pfr_data[ 7: 0],
		pfr_data[15: 8],
		pfr_data[23:16],
		pfr_data[31:24]
	};


	// Descriptor control
	// ------------------

	// Frame start
	assign pf_re = (state == ST_FRAME_START) & ~pf_empty;
	assign pf_underflow_set = (state == ST_FRAME_START) & pf_empty;

	// Keep track of stuff for the 'done' descriptor
	always @(posedge clk)
		if (state == ST_FRAME_START)
			df_wdata_fid <= pf_rdata[29:26];

	always @(posedge clk)
		df_wdata_ok <= (df_wdata_ok | (state == ST_FRAME_START)) & ~((state == ST_BURST_NEXT) & ~mem_len[20]);

	always @(posedge clk)
		if (state == ST_FRAME_START) begin
			df_wdata_vblank <= 0;
			df_wdata_vtotal <= 0;
		end else begin
			df_wdata_vblank <= df_wdata_vblank + (pix_stb & pix_sync & (pix_fvh[1:0] == 2'b11));
			df_wdata_vtotal <= df_wdata_vtotal + (pix_stb & pix_sync & pix_fvh[0]);
		end

	always @(posedge clk)
		if (pix_stb & pix_sync & pix_fvh[0])
			df_wdata_htotal <= 0;
		else
			df_wdata_htotal <= df_wdata_htotal + pix_stb;

	// Frame done
	assign df_wdata = {
		1'b0,				// [31] Dummy
		df_wdata_ok,		// [30]    Frame OK
		df_wdata_fid,		// [29:26] Frame ID
		df_wdata_htotal,	// [25:16] H total
		df_wdata_vblank,	// [15:10] V blank
		df_wdata_vtotal		// [ 9: 0] V total
	};

	assign df_we = (state == ST_FRAME_DONE);


	// Frame descriptor FIFOs
	// ----------------------

	// "Pending" FIFO
	fifo_sync_shift #(
		.DEPTH(2),
		.WIDTH(32)
	) fifo_pending_I (
		.wr_data  (pf_wdata),
		.wr_ena   (pf_we_safe),
		.wr_full  (pf_full),
		.rd_data  (pf_rdata),
		.rd_ena   (pf_re),
		.rd_empty (pf_empty),
		.clk      (clk),
		.rst      (rst)
	);

	assign pf_we_safe = pf_we & ~pf_full;

	always @(posedge clk)
		if (rst)
			pf_overflow <= 1'b0;
		else
			pf_overflow <= (pf_overflow & ~pf_overflow_clr) | (pf_we & pf_full);

	always @(posedge clk)
		if (rst)
			pf_underflow <= 1'b0;
		else
			pf_underflow <= (pf_underflow & ~pf_underflow_clr) | pf_underflow_set;

	// "Done" FIFO
	fifo_sync_shift #(
		.DEPTH(2),
		.WIDTH(32)
	) fifo_done_I (
		.wr_data  (df_wdata),
		.wr_ena   (df_we_safe),
		.wr_full  (df_full),
		.rd_data  (df_rdata),
		.rd_ena   (df_re),
		.rd_empty (df_empty),
		.clk      (clk),
		.rst      (rst)
	);

	assign df_we_safe = df_we & ~df_full;

	always @(posedge clk)
		if (rst)
			df_overflow <= 1'b0;
		else
			df_overflow <= (df_overflow & ~df_overflow_clr) | (df_we & df_full);


	// Bus interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	// Read Mux
	assign bus_rd_clr = ~wb_cyc | wb_ack;

	always @(posedge clk)
		if (bus_rd_clr)
			wb_rdata <= 32'h00000000;
		else
			wb_rdata <= wb_addr[0] ? bus_rdata_df : bus_rdata_csr;

	assign bus_rdata_csr = {
		16'h0000,
		pf_full,
		pf_empty,
		pf_overflow,
		pf_underflow,
		df_full,
		df_empty,
		df_overflow,
		1'b0,
		4'h0,
		csr_frame_cap_ena,
		csr_pix_cap_ena,
		csr_fifo_ena,
		csr_vid_ena
	};

	assign bus_rdata_df = { ~df_empty, df_rdata[30:0] };

	// Write enable
	always @(posedge clk)
	begin
		bus_we_csr  <= wb_cyc & ~wb_ack & wb_we & ~wb_addr[0];
		bus_we_fifo <= wb_cyc & ~wb_ack & wb_we &  wb_addr[0];
	end

	// FIFO read / write
	assign pf_wdata = wb_wdata;
	assign pf_we = bus_we_fifo;

	assign df_re = wb_ack & wb_addr[0] & ~wb_we & wb_rdata[31];

	// CSR
	always @(posedge clk or posedge rst)
		if (rst) begin
			csr_frame_cap_ena <= 1'b0;
			csr_pix_cap_ena   <= 1'b0;
			csr_fifo_ena      <= 1'b0;
			csr_vid_ena       <= 1'b0;
		end else if (bus_we_csr) begin
			csr_frame_cap_ena <= wb_wdata[3];
			csr_pix_cap_ena   <= wb_wdata[2];
			csr_fifo_ena      <= wb_wdata[1];
			csr_vid_ena       <= wb_wdata[0];
		end

	assign pf_overflow_clr  = bus_we_csr & wb_wdata[13];
	assign pf_underflow_clr = bus_we_csr & wb_wdata[12];
	assign df_overflow_clr  = bus_we_csr & wb_wdata[ 9];

endmodule // vid_frame_grab
