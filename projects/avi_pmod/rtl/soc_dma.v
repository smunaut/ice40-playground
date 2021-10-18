/*
 * soc_dma.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module soc_dma (
	// Wishbone (from SoC)
    input  wire  [1:0] wb_addr,
    output reg  [31:0] wb_rdata,
    input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
    input  wire        wb_we,
    input  wire        wb_cyc,
    output reg         wb_ack,

	// Priority DMA access
	output wire        dma_req,
	input  wire        dma_gnt,

	output reg  [15:0] dma_addr,
	output wire [31:0] dma_data,
	output wire        dma_we,

	// QPI Memory interface
	output reg  [21:0] mi_addr,
	output reg  [ 6:0] mi_len,
	output wire        mi_rw,
	output wire        mi_valid,
	input  wire        mi_ready,

	output wire [31:0] mi_wdata,
	input  wire        mi_wack,
	input  wire        mi_wlast,

	input  wire [31:0] mi_rdata,
	input  wire        mi_rstb,
	input  wire        mi_rlast,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Bus
	wire        bus_rd_clr;
	wire        bus_wr_pre;

	reg         bus_we_csr;
	reg         bus_we_cmd_lo;
	reg         bus_we_cmd_hi;

	// FIFO Write width adapter
	reg  [63:0] cw_data;
	reg  [ 3:0] cw_valid;

	// FIFO
	wire [15:0] cf_wdata;
	wire        cf_we;
	wire        cf_full;
	wire [15:0] cf_rdata;
	wire        cf_re;
	wire        cf_empty;

	// Command execution
	localparam [2:0]
		ST_IDLE        = 0,
		ST_LD_EADDR_LO = 1,
		ST_LD_EADDR_HI = 2,
		ST_LD_IADDR    = 3,
		ST_LD_LEN_ID   = 4,
		ST_WAIT_GNT    = 5,
		ST_SUBMIT      = 6,
		ST_WAIT_DONE   = 7;

	reg   [2:0] state;
	reg   [2:0] state_nxt;

	reg   [7:0] cmd_cur_id;
	reg   [7:0] cmd_last_id;
	wire        cmd_busy;

	(* keep *) wire dma_addr_ld;


	// Bus interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	// Read mux
	assign bus_rd_clr = ~wb_cyc | wb_ack;

	always @(posedge clk)
		if (bus_rd_clr)
			wb_rdata <= 32'h00000000;
		else
			wb_rdata <= {
				16'h0000,
				cmd_last_id,
				cf_empty,
				cf_full,
				2'b00,
				cmd_busy,
				state
//				3'b000
			};

	// Write enables
	assign bus_wr_pre = wb_cyc & ~wb_ack & wb_we;

	always @(posedge clk)
	begin
		bus_we_csr    <= bus_wr_pre & (wb_addr[1:0] == 2'b00);
		bus_we_cmd_lo <= bus_wr_pre & (wb_addr[1:0] == 2'b10);
		bus_we_cmd_hi <= bus_wr_pre & (wb_addr[1:0] == 2'b11);
	end


	// Command FIFO
	// ------------

	// Write width adapter
	always @(posedge clk or posedge rst)
	begin
		if (rst) begin
			cw_valid <= 4'b0000;
			cw_data  <= 64'h0000000000000000;
		end else begin
			// Valid
			cw_valid <= cw_valid[0] ?
				{ 1'b0, cw_valid[3:1] } :
				(cw_valid | { {2{bus_we_cmd_hi}}, {2{bus_we_cmd_lo}} });

			// Data
			if (cw_valid[0] | bus_we_cmd_lo)
				cw_data[31: 0] <= bus_we_cmd_lo ? wb_wdata : cw_data[47:16];

			if (cw_valid[0] | bus_we_cmd_hi)
				cw_data[63:32] <= bus_we_cmd_hi ? wb_wdata : { 16'h0000, cw_data[63:48] };
		end
	end

	assign cf_wdata = cw_data[31:0];
	assign cf_we    = cw_valid[0];

	// FIFO
	fifo_sync_ram #(
		.DEPTH(256),
		.WIDTH(16)
	) fifo_I (
		.wr_data  (cf_wdata),
		.wr_ena   (cf_we),
		.wr_full  (cf_full),
		.rd_data  (cf_rdata),
		.rd_ena   (cf_re),
		.rd_empty (cf_empty),
		.clk      (clk),
		.rst      (rst)
	);


	// Command Execution
	// -----------------

	// State machine
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	always @(*)
	begin
		// Default
		state_nxt = state;

		// Transitions
		case (state)
			ST_IDLE:
				if (~cf_empty)
					state_nxt = ST_LD_EADDR_LO;

			ST_LD_EADDR_LO:
				state_nxt = ST_LD_EADDR_HI;

			ST_LD_EADDR_HI:
				state_nxt = ST_LD_IADDR;

			ST_LD_IADDR:
				state_nxt = ST_LD_LEN_ID;

			ST_LD_LEN_ID:
				state_nxt = ST_WAIT_GNT;

			ST_WAIT_GNT:
				if (dma_gnt)
					state_nxt = ST_SUBMIT;

			ST_SUBMIT:
				if (mi_ready)
					state_nxt = ST_WAIT_DONE;

			ST_WAIT_DONE:
				if (mi_rstb & mi_rlast)
					state_nxt = ST_IDLE;
		endcase
	end

	// FIFO read
	assign cf_re =
		(state == ST_LD_EADDR_LO) |
		(state == ST_LD_EADDR_HI) |
		(state == ST_LD_IADDR) |
		(state == ST_LD_LEN_ID);

	// Busy ?
	assign cmd_busy = ~cf_empty | (state != ST_IDLE);

	// Command
	assign mi_valid = (state == ST_SUBMIT);

	always @(posedge clk)
		if (state == ST_LD_EADDR_LO)
			mi_addr[15:0] <= cf_rdata;

	always @(posedge clk)
		if (state == ST_LD_EADDR_HI)
			mi_addr[21:16] <= cf_rdata[6:0];

	always @(posedge clk)
		if (state == ST_LD_LEN_ID)
			mi_len <= cf_rdata[6:0];

	// Never write to External RAM
	assign mi_rw = 1'b1;
	assign mi_wdata = 32'hxxxxxxxx;

	// Request access
	assign dma_req = (state != ST_IDLE);

	// Internal address
	assign dma_addr_ld = (state == ST_LD_IADDR);

	always @(posedge clk)
		dma_addr <= dma_addr_ld ? cf_rdata : (dma_addr + {16{dma_addr_ld}} + mi_rstb);
		/*
		if (state == ST_LD_IADDR)
			dma_addr <= cf_rdata;
		else
			dma_addr <= dma_addr + {15'd0, mi_rstb};
		*/

	// Data flow
	assign dma_data = mi_rdata;
	assign dma_we   = mi_rstb;

	// ID tracking
	always @(posedge clk)
		if (state == ST_LD_LEN_ID)
			cmd_cur_id <= cf_rdata[15:8];

	always @(posedge clk)
		if (state == ST_IDLE)
			cmd_last_id <= cmd_cur_id;

endmodule // soc_dma
