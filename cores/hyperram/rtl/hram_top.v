/*
 * hram_top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
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

module hram_top (
	// PHY interface
	output reg  [ 1:0] phy_ck_en,

	input  wire [ 3:0] phy_rwds_in,
	output reg  [ 3:0] phy_rwds_out,
	output reg  [ 1:0] phy_rwds_oe,

	input  wire [31:0] phy_dq_in,
	output reg  [31:0] phy_dq_out,
	output reg  [ 1:0] phy_dq_oe,

	output reg  [ 3:0] phy_cs_n,
	output wire        phy_rst_n,

	// PHY configuration
	output wire [ 7:0] phy_cfg_wdata,
	input  wire [ 7:0] phy_cfg_rdata,
	output wire        phy_cfg_stb,

	// Memory interface
	input  wire [ 1:0] mi_addr_cs,
	input  wire [31:0] mi_addr,
	input  wire [ 6:0] mi_len,
	input  wire        mi_rw,		/* 0=Write, 1=Read */
	input  wire        mi_linear,	/* 0=Wrapped burst, 1=Linear */
	input  wire        mi_valid,
	output wire        mi_ready,

	input  wire [31:0] mi_wdata,
	input  wire [ 3:0] mi_wmsk,
	output wire        mi_wack,
	output wire        mi_wlast,

	output wire [31:0] mi_rdata,
	output wire        mi_rstb,
	output wire        mi_rlast,

	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire [ 3:0] wb_addr,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output wire        wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// FSM
	// ---

	localparam
		ST_IDLE_CFG		= 0,
		ST_IDLE_RUN		= 1,
		ST_CMD_ADDR_MSB	= 2,
		ST_CMD_ADDR_LSB	= 3,
		ST_LATENCY		= 4,
		ST_DATA_WRITE	= 5,
		ST_DATA_READ	= 6,
		ST_DONE			= 7;

	reg [3:0] state;
	reg [3:0] state_nxt;


	// Signals
	// -------

	// Control
	wire running;

	reg  [ 3:0] lat_cnt;
	wire        lat_last;

	reg  [ 7:0] xfer_cnt;
	wire        xfer_last;

	reg  [95:0] sr_data;
	reg  [11:0] sr_mask;
	reg  [ 5:0] sr_oe;
	reg  [ 1:0] sr_src;
	reg  [ 1:0] sr_ce;

	wire [ 1:0] cap_in;
	wire [ 1:0] cap_out;

	// Current transaction
	reg         cmd_is_read;
	reg         cmd_is_reg;
	reg         cmd_is_wb;
	reg  [ 3:0] cmd_cs;

	// Wishbone interface
	reg         wb_ack_i;

	reg         wbi_we_csr;
	reg         wbi_we_exec;
	reg         wbi_we_wq_data;
	reg         wbi_ae_wq_data;
	reg         wbi_we_wq_attr;

	wire        wbi_cmd_now;
	wire  [3:0] wbi_cmd_len;
	wire  [3:0] wbi_cmd_lat;
	wire  [1:0] wbi_cmd_cs;
	wire        wbi_cmd_is_reg;
	wire        wbi_cmd_is_read;

	reg  [15:0] wbi_csr;
	wire [31:0] wbi_csr_rd;
	reg  [ 5:0] wbi_attr;


	// FSM
	// ---

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE_CFG;
		else
			state <= state_nxt;

	// Next-State logic
	always @(*)
	begin
		// Default is to stay put
		state_nxt = state;

		// Transisions
		case (state)
			ST_IDLE_CFG:
				if (wbi_cmd_now)
					state_nxt = ST_CMD_ADDR_MSB;
				else if (running)
					state_nxt = ST_IDLE_RUN;

			ST_IDLE_RUN:
				if (mi_valid)
					state_nxt = ST_CMD_ADDR_MSB;
				else if (!running)
					state_nxt = ST_IDLE_CFG;

			ST_CMD_ADDR_MSB:
				state_nxt = ST_CMD_ADDR_LSB;

			ST_CMD_ADDR_LSB:
				state_nxt = (cmd_is_reg & ~cmd_is_read) ? ST_DONE : ST_LATENCY;

			ST_LATENCY:
				if (lat_last)
					state_nxt = cmd_is_read ? ST_DATA_READ : ST_DATA_WRITE;

			ST_DATA_WRITE:
				if (xfer_last)
					state_nxt = ST_DONE;

			ST_DATA_READ:
				if (xfer_last)
					state_nxt = ST_DONE;

			ST_DONE:
				state_nxt = running ? ST_IDLE_RUN : ST_IDLE_CFG;
		endcase
	end


	// Control
	// -------

	// State
	assign running = wbi_csr[0];

	// Command latch
	always @(posedge clk)
	begin
		if ((state == ST_IDLE_RUN) & mi_valid)
		begin
			cmd_is_read <= mi_rw;
			cmd_is_reg  <= 1'b0;
			cmd_is_wb   <= 1'b0;
			cmd_cs      <= 4'hf ^ (1 << mi_addr_cs);
		end
		else if ((state == ST_IDLE_CFG) & wbi_cmd_now)
		begin
			cmd_is_read <= wbi_cmd_is_read;
			cmd_is_reg  <= wbi_cmd_is_reg;
			cmd_is_wb   <= 1'b1;
			cmd_cs      <= 4'hf ^ (1 << wbi_cmd_cs);
		end
	end

	// Shift register control
	always @(*)
	begin
		// Defaults
		sr_ce[1]  = 1'b0;
		sr_ce[0]  = 1'b0;
		sr_src[1] = 1'b0;
		sr_src[0] = 1'b0;

		// Memory interface Command accept
		if ((state == ST_IDLE_RUN) & mi_valid)
		begin
			sr_ce[1]  = 1'b1;
			sr_src[1] = 1'b1;
		end

		// Wishbone accesses
		if (wbi_ae_wq_data)
		begin
			sr_ce[1]  = 1'b1;
			sr_ce[0]  = 1'b1;
			sr_src[1] = 1'b0;
			sr_src[0] = 1'b1;
		end

		// Config mode capture
		if (cap_out == 2'b01)
		begin
			sr_ce[1]  = 1'b1;
			sr_ce[0]  = 1'b1;
			sr_src[1] = 1'b0;
			sr_src[0] = 1'b0;
		end

		// Normal "shift"
		if ((state == ST_CMD_ADDR_MSB) || (state == ST_CMD_ADDR_LSB))
		begin
			sr_ce[1]  = 1'b1;
			sr_ce[0]  = 1'b1;
			sr_src[1] = 1'b0;
			sr_src[0] = 1'b0;
		end
	end

	// Shift register
	always @(posedge clk)
	begin
		// MSBs [95:32]
		if (sr_ce[1])
		begin
			sr_oe  [ 5: 2] <= sr_src[1] ? 4'b1110 : sr_oe  [3:0];
			sr_mask[11: 4] <= sr_src[1] ? 8'h00   : sr_mask[7:0];
			sr_data[95:32] <= sr_src[1] ?
				{ mi_rw, 1'b0, mi_linear, mi_addr[31:3], 13'h0000, mi_addr[2:0], 16'h0000 } :
				sr_data[63:0];
		end

		// LSBs [31: 0]
		if (sr_ce[0])
		begin
			sr_oe  [ 1:0] <= sr_src[0] ? wbi_attr[5:4] : 2'b11;
			sr_mask[ 3:0] <= sr_src[0] ? wbi_attr[3:0] : phy_rwds_in;
			sr_data[31:0] <= sr_src[0] ? wb_wdata      : phy_dq_in;
		end
	end

	// Latency counter
	always @(posedge clk)
	begin
		if (state == ST_IDLE_RUN)
			lat_cnt <= wbi_csr[11:8] - 1;
		else if (state == ST_IDLE_CFG)
			lat_cnt <= wbi_cmd_lat - 1;
		else if (state == ST_LATENCY)
			lat_cnt <= lat_cnt - 1;
	end

	assign lat_last = lat_cnt[3];

	// Transfer counter
	always @(posedge clk)
	begin
		if (state == ST_IDLE_RUN)
			xfer_cnt <= { 1'b0, mi_len } - 1;
		else if (state == ST_IDLE_CFG)
			xfer_cnt <= { 4'h0, wbi_cmd_len } - 1;
		else if ((state == ST_DATA_WRITE) || (state == ST_DATA_READ))
			xfer_cnt <= xfer_cnt - 1;
	end

	assign xfer_last = xfer_cnt[7];

	// Input capture
		// 00 - Nothing
		// 01 - Capture WB
		// 10 - Capture MemIF
		// 11 - Capture MemIF last
	assign cap_in[1] = (state == ST_DATA_READ) & ~cmd_is_wb;
	assign cap_in[0] = (state == ST_DATA_READ) & (cmd_is_wb | xfer_last);

	hram_dline #(
		.N(3)
	) cap_I[1:0] (
		.di(cap_in),
		.do(cap_out),
		.delay(wbi_csr[14:12]),
		.clk(clk)
	);


	// PHY drive
	// ---------

	// Main signals
	always @(*)
	begin
		// Defaults
		phy_ck_en    = 2'b00;
		phy_rwds_out = 4'h0;
		phy_rwds_oe  = 2'b00;
		phy_dq_out   = sr_data[95:64];
		phy_dq_oe    = 2'b00;
		phy_cs_n     = 4'hf;

		// Special per-state overrides
		case (state)
			ST_CMD_ADDR_MSB: begin
				phy_ck_en    = 2'b11;
				phy_dq_oe    = sr_oe[5:4];
				phy_cs_n     = cmd_cs;
			end

			ST_CMD_ADDR_LSB: begin
				phy_ck_en    = 2'b11;
				phy_dq_oe    = sr_oe[5:4];
				phy_cs_n     = cmd_cs;
			end

			ST_LATENCY: begin
				phy_ck_en    = 2'b11;
				phy_cs_n     = cmd_cs;
			end

			ST_DATA_WRITE: begin
				phy_ck_en    = 2'b11;
				phy_dq_oe    = 2'b11;
				phy_rwds_oe  = 2'b11;
				phy_dq_out   = cmd_is_wb ? sr_data[95:64] : mi_wdata;
				phy_rwds_out = cmd_is_wb ? sr_mask[11: 8] : mi_wmsk;
				phy_cs_n     = cmd_cs;
			end

			ST_DATA_READ: begin
				phy_ck_en    = 2'b11;
				phy_cs_n     = cmd_cs;
			end

			ST_DONE: begin
				phy_cs_n     = cmd_cs;
			end
		endcase
	end

	// OOB
	assign phy_rst_n = ~wbi_csr[1];


	// Memory interface
	// ----------------

	assign mi_ready = (state == ST_IDLE_RUN);
	assign mi_wack  = (state == ST_DATA_WRITE) & ~cmd_is_wb;
	assign mi_wlast = xfer_last;

	assign mi_rdata = phy_dq_in;
	assign mi_rstb  = cap_out[1];
	assign mi_rlast = cap_out[0];


	// Wishbone interface
	// ------------------

	// Ack
	always @(posedge clk)
		wb_ack_i <= wb_cyc & ~wb_ack_i;

	assign wb_ack = wb_ack_i;

	// Read Mux
	always @(posedge clk)
		if (~wb_cyc | wb_ack)
			wb_rdata <= 32'h00000000;
		else
			case (wb_addr[1:0])
				2'b00:   wb_rdata <= wbi_csr_rd;
				2'b10:   wb_rdata <= sr_data[95:64];
				2'b11:   wb_rdata <= { 26'h0000000, sr_oe[5:4], sr_mask[11:8] };
				default: wb_rdata <= 32'hxxxxxxxx;
			endcase

	assign wbi_csr_rd[31:16] = { 8'h00, phy_cfg_rdata };
	assign wbi_csr_rd[15: 0] = (wbi_csr & 16'hff03) | {
				12'h000,
				(state == ST_IDLE_RUN),
				(state == ST_IDLE_CFG),
				2'b00
			};

	// Read/Write/Access Enables
	always @(posedge clk)
	begin
		if (wb_ack) begin
			wbi_we_csr     <= 1'b0;
			wbi_we_exec    <= 1'b0;
			wbi_we_wq_data <= 1'b0;
			wbi_ae_wq_data <= 1'b0;
			wbi_we_wq_attr <= 1'b0;
		end else begin
			wbi_we_csr     <= wb_cyc & wb_we & (wb_addr[1:0] == 2'b00);
			wbi_we_exec    <= wb_cyc & wb_we & (wb_addr[1:0] == 2'b01);
			wbi_we_wq_data <= wb_cyc & wb_we & (wb_addr[1:0] == 2'b10);
			wbi_ae_wq_data <= wb_cyc &         (wb_addr[1:0] == 2'b10);
			wbi_we_wq_attr <= wb_cyc & wb_we & (wb_addr[1:0] == 2'b11);
		end
	end

	// CSR
	always @(posedge clk)
		if (rst)
			wbi_csr <= 16'h0000;
		else if (wbi_we_csr)
			wbi_csr <= wb_wdata[15:0];

	// PHY config
	assign phy_cfg_wdata = wb_wdata[23:16];
	assign phy_cfg_stb   = wbi_we_csr;

	// Attrs
	always @(posedge clk)
		if (wbi_we_wq_attr)
			wbi_attr <= wb_wdata[5:0];

	// Command execute
	assign wbi_cmd_now     = wbi_we_exec;
	assign wbi_cmd_len     = wb_wdata[11:8];
	assign wbi_cmd_lat     = wb_wdata[ 7:4];
	assign wbi_cmd_cs      = wb_wdata[ 3:2];
	assign wbi_cmd_is_reg  = wb_wdata[1];
	assign wbi_cmd_is_read = wb_wdata[0];

endmodule
