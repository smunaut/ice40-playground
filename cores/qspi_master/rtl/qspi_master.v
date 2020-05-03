/*
 * qspi_master.v
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

module qspi_master #(
	parameter integer CMD_READ  = 16'hEBEB,
	parameter integer CMD_WRITE = 16'h0202,
	parameter integer DUMMY_CLK = 6,
	parameter integer PAUSE_CLK = 3,
	parameter integer FIFO_DEPTH  = 1,
	parameter integer N_CS = 2,				/* CS count */
	parameter integer PHY_SPEED = 1,		/* Speed Factor: 1x 2x 4x */
	parameter integer PHY_WIDTH = 1,		/* Width Factor: 1x 2x    */
	parameter integer PHY_DELAY = 6,		/* See PHY doc */

	// auto
	parameter integer PTW = (PHY_WIDTH * 4 * PHY_SPEED),	/* PHY Total   Width */
	parameter integer PCW = (            4 * PHY_SPEED),	/* PHY Channel Width */
	parameter integer PSW = (                PHY_SPEED)		/* PHY Signal  Width */
)(
	// PHY interface
	input  wire [PTW-1:0]  phy_io_i,
	output reg  [PTW-1:0]  phy_io_o,
	output reg  [    3:0]  phy_io_oe,
	output reg  [PSW-1:0]  phy_clk_o,
	output reg  [N_CS-1:0] phy_cs_o,

	// Memory interface
	input  wire [ 1:0] mi_addr_cs,
	input  wire [23:0] mi_addr,
	input  wire [ 6:0] mi_len,
	input  wire        mi_rw,		/* 0=Write, 1=Read */
	input  wire        mi_valid,
	output wire        mi_ready,

	input  wire [31:0] mi_wdata,
	output wire        mi_wack,
	output wire        mi_wlast,

	output wire [31:0] mi_rdata,
	output wire        mi_rstb,
	output wire        mi_rlast,

	// Wishbone interface
	input  wire [ 4:0] wb_addr,
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Common
	input wire clk,
	input wire rst
);

	localparam integer STW = 32;				/* Shifter Total Width */
	localparam integer SCW = STW / PHY_WIDTH;	/* Shifter Channel Width */


	// Mapping Helpers
	// ---------------

	/*
	 * PHY signal mapping:
	 * 		phy_io = [ chan_1 | chan_0 ]
	 * 		chan_i = [ io_3 | io_2 | io_1 | io_0 ]
	 * 		io_i   = [ t_0 ... t_n ]  (t_0 being the 'first')
	 *
	 * Shifter-Out format:
	 * Shifter-In format:
	 * 		shift_data = [ chan_1 | chan_0 ]
	 * 		chan_i_qpi = [ io_3(0) io_2(0) io_1(0) io_0(0) io_3(1) ... ]
	 * 		chan_i_spi = [ t_0 t_1 ... t_n ]  (t_0 being 'first')
	 *
	 * Mem IF data:
	 * 		mi_{r,w}data = [ b3 | b2 | b1 | b0 ]
	 *
	 * 		Data is stored in memory in big-endian (b3 b2 b1 b0)
	 * 		and in case of multiple channel (b1 b0) in chan 0 and (b3 b2) in chan 1
	 *
	 * Wishbone data:
	 *      spi_xfer: bits are taken in order and shifted out MSB first
	 *                In case of multiple channel the register is split in 2x16 bits
	 *      qpi_cmd:  bits are taken in order and shifted out MSB first
	 *      qpi_read / qpi_data: See Mem IF data mapping
	 */


	function [PTW-1:0] shift2phy_spi;
		input [STW-1:0] shift;
		input [PTW-1:0] base;
		integer chan;
		begin
			// Set default value for the signals that don't matter for SPI
			shift2phy_spi = base;

			// Overwrite only the PHY IO0 line (MOSI)
			for (chan=0; chan<PHY_WIDTH; chan=chan+1)
				shift2phy_spi[chan*PCW+:PSW] = shift[((chan+1)*SCW-1)-:PSW];
		end
	endfunction

	function [STW-1:0] shift_spi;
		input [STW-1:0] shift;
		integer chan;
		begin
			for (chan=0; chan<PHY_WIDTH; chan=chan+1)
				shift_spi[chan*SCW+:SCW] = { shift[chan*SCW+:SCW-PSW], {PSW{1'bx}} };
		end
	endfunction

	function [PTW-1:0] shift2phy_qpi_cmd;
		input [STW-1:0] shift;
		integer chan, io, t;
		begin
			for (chan=0; chan<PHY_WIDTH; chan=chan+1)
				for (t=0; t<PHY_SPEED; t=t+1)
					for (io=0; io<4; io=io+1)
						shift2phy_qpi_cmd[chan*PCW + io*PSW + t] = shift[STW - (4*PHY_SPEED) + t*4 + io];
		end
	endfunction

	function [STW-1:0] shift_qpi_cmd;
		input [STW-1:0] shift;
		begin
			shift_qpi_cmd[STW-1:0] = { shift[STW-PCW-1:0], {PCW{1'bx}} };
		end
	endfunction

	function [PTW-1:0] shift2phy_qpi_data;
		input [STW-1:0] shift;
		integer chan, io, t;
		begin
			for (chan=0; chan<PHY_WIDTH; chan=chan+1)
				for (t=0; t<PHY_SPEED; t=t+1)
					for (io=0; io<4; io=io+1)
						shift2phy_qpi_data[chan*PCW + io*PSW + t] = shift[(chan+1)*SCW - (4*PHY_SPEED) + t*4 + io];
		end
	endfunction

	function [STW-1:0] shift_qpi_data;
		input [STW-1:0] shift;
		integer chan;
		begin
			if (SCW == PCW)
				shift_qpi_data = { STW{1'bx} };
			else
				for (chan=0; chan<PHY_WIDTH; chan=chan+1)
					shift_qpi_data[chan*SCW+:SCW] = { shift[chan*SCW+:SCW-PCW], {PCW{1'bx}} };
		end
	endfunction

	function [STW-1:0] phy2shift_spi;
		input [STW-1:0] prev;
		input [PTW-1:0] phy;
		integer chan, t;
		begin
			for (chan=0; chan<PHY_WIDTH; chan=chan+1)
			begin
				// Shift previous data
				phy2shift_spi[chan*SCW+PSW+:SCW-PSW] = prev[chan*SCW+:SCW-PSW];

				// Map new data
				phy2shift_spi[chan*SCW+:PSW] = phy[chan*PCW+PSW+:PSW];
			end
		end
	endfunction

	function [STW-1:0] phy2shift_qpi;
		input [STW-1:0] prev;
		input [PTW-1:0] phy;
		integer chan, t, io;
		begin
			for (chan=0; chan<PHY_WIDTH; chan=chan+1)
			begin
				// Shift previous data
				if (PCW != SCW)
					phy2shift_qpi[chan*SCW+PCW+:SCW-PCW] = prev[chan*SCW+:SCW-PCW];

				// Map new data
				for (t=0; t<PHY_SPEED; t=t+1)
					for (io=0; io<4; io=io+1)
						phy2shift_qpi[chan*SCW + t*4 + io] = phy[chan*PCW + io*PSW + t];
			end
		end
	endfunction


	// Signals
	// -------

	// Wishbone interface
	wire        wbi_we_csr;
	wire [31:0] wbi_rd_csr;
	wire        wbi_rd_rst;

	// Command & Reponse FIFOs
	wire [35:0] cf_di;
	reg         cf_wren;
	wire        cf_full;
	wire [35:0] cf_do;
	wire        cf_rden;
	wire        cf_empty;

	wire [31:0] rf_di;
	wire        rf_wren_safe;
	wire        rf_wren;
	wire        rf_full;
	wire [31:0] rf_do;
	wire        rf_rden;
	wire        rf_empty;

	reg         rf_overflow;
	reg         rf_overflow_clr;
	reg         rf_rden_arm;

	// External control
	reg  [ 1:0] ectl_cs;
	reg         ectl_req;
	wire        ectl_grant;
	wire        ectl_idle;

	// Main state machine
	localparam
		ST_IDLE			= 0,
		ST_CMD_EXEC		= 1,
		ST_MI_WR_DATA	= 2,
		ST_MI_RD_DUMMY	= 3,
		ST_MI_RD_DATA	= 4,
		ST_FLUSH        = 5,
		ST_PAUSE		= 6;

	reg [2:0] state;
	reg [2:0] state_nxt;

	// Xfer counter
	reg  [ 7:0] xfer_cnt;
	wire        xfer_last;

	// Pause counter
	reg  [ 3:0] pause_cnt;
	wire        pause_last;

	// Memory interface
	wire [ 7:0] mi_spi_cmd;

	// Shift-Out
	localparam
		SO_MODE_SPI			= 2'b00,
		SO_MODE_QPI_RD		= 2'b01,
		SO_MODE_QPI_WR		= 2'b10,
		SO_MODE_QPI_CMD		= 2'b11;

	localparam
		SO_LD_SRC_WB		= 2'b00,
		SO_LD_SRC_MI_DATA	= 2'b10,
		SO_LD_SRC_MI_CMD	= 2'b11;

	localparam
		SO_DST_NONE			= 2'b00,
		SO_DST_WB			= 2'b10,
		SO_DST_MI			= 2'b11;

	wire        so_ld_now;
	reg         so_ld_valid;
	reg  [ 1:0] so_ld_mode;
	reg  [ 1:0] so_ld_dst;
	reg  [ 5:0] so_ld_cnt;
	reg  [ 1:0] so_ld_src;

	reg         so_valid;
	reg  [ 1:0] so_mode;
	reg  [ 1:0] so_dst;
	reg  [ 5:0] so_cnt;
	wire        so_last;
	reg  [31:0] so_data;

	// Shift-In
	wire        si_mode_0;
	wire        si_mode_nm1;
	reg  [ 1:0] si_dst_1;
	wire [ 1:0] si_dst_n;

	reg  [31:0] si_data_n;


	// Wishbone interface
	// ------------------

	// Ack
	always @(posedge clk)
	begin
		// Default is direct ack
		wb_ack <= wb_cyc & ~wb_ack;

		// Block on write to full command fifo
		if (wb_we & wb_addr[4] & cf_full)
			wb_ack <= 1'b0;

		// Block on read from empty response fifo if in blocking mode
		if (~wb_we & (wb_addr == 5'h3) & rf_empty)
			wb_ack <= 1'b0;
	end

	// CSR
	assign wbi_we_csr = wb_ack & wb_we & ~wb_addr[4];

	always @(posedge clk)
		if (rst)
			ectl_req <= 1'b0;
		else if (wbi_we_csr)
			ectl_req <= (ectl_req & ~wb_wdata[2]) | wb_wdata[1];

	always @(posedge clk)
		if (wbi_we_csr)
			ectl_cs <= wb_wdata[5:4];

	assign ectl_idle  = (state == ST_IDLE);
	assign ectl_grant = (state == ST_CMD_EXEC);

	always @(posedge clk)
		rf_overflow_clr <= wbi_we_csr & wb_wdata[9];

	assign wbi_rd_csr = {
		16'h0000,
		rf_empty, rf_full, rf_overflow, 1'b0,
		cf_empty, cf_full, 2'b0,
		2'b00, ectl_cs,
		1'b0, ectl_grant, ectl_req, ectl_idle
	};

	// Command FIFO write
	assign cf_di = { wb_addr[3:0], wb_wdata };

	always @(posedge clk)
		cf_wren <= wb_cyc & wb_we & ~wb_ack & wb_addr[4] & ~cf_full;

	// Response FIFO read
	always @(posedge clk)
		rf_rden_arm <= ~rf_empty & wb_addr[1] & ~wb_we;

	assign rf_rden = wb_ack & rf_rden_arm;

	// Read mux
	assign wbi_rd_rst = ~wb_cyc | wb_ack;

	always @(posedge clk)
		if (wbi_rd_rst)
			wb_rdata <= 32'h0000000;
		else
			wb_rdata <= wb_addr[1] ? rf_do : wbi_rd_csr;

	// FIFOs
	generate
		if (FIFO_DEPTH > 4) begin
			// Command
			fifo_sync_ram #(
				.DEPTH(FIFO_DEPTH),
				.WIDTH(36)
			) cmd_fifo_I (
				.wr_data(cf_di),
				.wr_ena(cf_wren),
				.wr_full(cf_full),
				.rd_data(cf_do),
				.rd_ena(cf_rden),
				.rd_empty(cf_empty),
				.clk(clk),
				.rst(rst)
			);

			// Response
			fifo_sync_ram #(
				.DEPTH(FIFO_DEPTH),
				.WIDTH(32)
			) rsp_fifo_I (
				.wr_data(rf_di),
				.wr_ena(rf_wren_safe),
				.wr_full(rf_full),
				.rd_data(rf_do),
				.rd_ena(rf_rden),
				.rd_empty(rf_empty),
				.clk(clk),
				.rst(rst)
			);
		end else begin
			// Command
			fifo_sync_shift #(
				.DEPTH(FIFO_DEPTH),
				.WIDTH(36)
			) cmd_fifo_I (
				.wr_data(cf_di),
				.wr_ena(cf_wren),
				.wr_full(cf_full),
				.rd_data(cf_do),
				.rd_ena(cf_rden),
				.rd_empty(cf_empty),
				.clk(clk),
				.rst(rst)
			);

			// Response
			fifo_sync_shift #(
				.DEPTH(FIFO_DEPTH),
				.WIDTH(32)
			) rsp_fifo_I (
				.wr_data(rf_di),
				.wr_ena(rf_wren_safe),
				.wr_full(rf_full),
				.rd_data(rf_do),
				.rd_ena(rf_rden),
				.rd_empty(rf_empty),
				.clk(clk),
				.rst(rst)
			);
		end
	endgenerate

	// Response overflow tracking
	assign rf_wren_safe = rf_wren & ~rf_full;

	always @(posedge clk)
		rf_overflow <= (rf_overflow & ~rf_overflow_clr) | (rf_wren & rf_full);

	// Capture responses
	assign rf_di   = si_data_n;
	assign rf_wren = (si_dst_n == 2'b01);


	// Main Control
	// ------------

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next-State logic
	always @(*)
	begin
		// Default
		state_nxt = state;

		// Transitions ?
		case (state)
			ST_IDLE:
				if (mi_valid)
					state_nxt = mi_rw ? ST_MI_RD_DUMMY : ST_MI_WR_DATA;
				else if (ectl_req)
					state_nxt = ST_CMD_EXEC;

			ST_CMD_EXEC:
				if (~ectl_req & cf_empty)
					state_nxt = ST_PAUSE;

			ST_MI_WR_DATA:
				if (xfer_last & so_ld_now)
					state_nxt = ST_FLUSH;

			ST_MI_RD_DUMMY:
				if (so_ld_now)
					state_nxt = ST_MI_RD_DATA;

			ST_MI_RD_DATA:
				if (xfer_last & so_ld_now)
					state_nxt = ST_FLUSH;

			ST_FLUSH:
				if (~so_valid)
					state_nxt = ST_PAUSE;

			ST_PAUSE:
				if (pause_last)
					state_nxt = ST_IDLE;
		endcase
	end

	// Xfer counter
	always @(posedge clk)
		if (state == ST_IDLE)
			xfer_cnt <= { 1'b0, mi_len } - 1;
		else if (((state == ST_MI_WR_DATA) || (state == ST_MI_RD_DATA)) && so_ld_now)
			xfer_cnt <= xfer_cnt - 1;

	assign xfer_last = xfer_cnt[7];

	// Pause counter
	always @(posedge clk)
		if (state == ST_PAUSE)
			pause_cnt <= pause_cnt - 1;
		else
			pause_cnt <= PAUSE_CLK - 2;
	
	assign pause_last = pause_cnt[3];

	// SPI command
	assign mi_spi_cmd = mi_rw ? CMD_READ[8*mi_addr_cs+:8] : CMD_WRITE[8*mi_addr_cs+:8];

	// ROM for command fifo counter
	(* mem2reg *)
	reg [5:0] cmd_len_rom[0:15];

	initial
	begin : rom_cmd_len
		integer i;
		for (i=0; i<16; i=i+1)
			cmd_len_rom[i] = (((i >> 2) & 3) == 0) ?
				(((i & 3) << 3) - PHY_SPEED + 7) :
				(((i & 3) << 1) - PHY_SPEED + 1);
	end

	// Shift control
		// When to load
	assign so_ld_now = ~so_valid | so_last;

		// What to load
	always @(*)
	begin
		// Defaults
		so_ld_valid = 1'b0;
		so_ld_mode  = 2'bxx;
		so_ld_dst   = 2'bxx;
		so_ld_cnt   = 6'bxxxxxx;
		so_ld_src   = 2'bxx;

		case (state)
			ST_IDLE: begin
				so_ld_valid = mi_valid;
				so_ld_mode  = SO_MODE_QPI_CMD;
				so_ld_dst   = SO_DST_NONE;
				so_ld_cnt   = (32 / 4) - PHY_SPEED - 1;
				so_ld_src   = SO_LD_SRC_MI_CMD;
			end

			ST_CMD_EXEC: begin
				so_ld_valid = ~cf_empty;
				case (cf_do[35:34])
					2'b00: { so_ld_mode, so_ld_dst } = { SO_MODE_SPI,     SO_DST_WB   };
					2'b01: { so_ld_mode, so_ld_dst } = { SO_MODE_QPI_RD,  SO_DST_WB   };
					2'b10: { so_ld_mode, so_ld_dst } = { SO_MODE_QPI_WR,  SO_DST_NONE };
					2'b11: { so_ld_mode, so_ld_dst } = { SO_MODE_QPI_CMD, SO_DST_NONE };
				endcase
				so_ld_cnt   = cmd_len_rom[cf_do[35:32]];
				so_ld_src   = SO_LD_SRC_WB;
			end

			ST_MI_WR_DATA: begin
				so_ld_valid = 1'b1;
				so_ld_mode  = SO_MODE_QPI_WR;
				so_ld_dst   = SO_DST_NONE;
				so_ld_cnt   = (32 / (4 * PHY_WIDTH)) - PHY_SPEED - 1;
				so_ld_src   = SO_LD_SRC_MI_DATA;
			end

			ST_MI_RD_DUMMY: begin
				so_ld_valid = 1'b1;
				so_ld_mode  = SO_MODE_QPI_RD;
				so_ld_dst   = SO_DST_NONE;
				so_ld_cnt   = DUMMY_CLK - PHY_SPEED - 1;
			end

			ST_MI_RD_DATA: begin
				so_ld_valid = 1'b1;
				so_ld_mode  = SO_MODE_QPI_RD;
				so_ld_dst   = SO_DST_MI;
				so_ld_cnt	= (32 / (4 * PHY_WIDTH)) - PHY_SPEED - 1;
			end
		endcase
	end

	// Command interface
	assign cf_rden = (state == ST_CMD_EXEC) & so_ld_now & ~cf_empty;

	// Memory interface
	assign mi_ready = (state == ST_IDLE);

	assign mi_wack  = (state == ST_MI_WR_DATA) & so_ld_now;
	assign mi_wlast = xfer_last;

	assign mi_rdata = si_data_n;
	assign mi_rstb  = si_dst_n[1];
	assign mi_rlast = si_dst_n[0];

	// Chip select
	always @(posedge clk)
		if (rst)
			phy_cs_o <= { N_CS{1'b1} };
		else begin
			case (state)
				ST_IDLE: begin
					// Default
					phy_cs_o <= { N_CS{1'b1} };

					if (mi_valid)
						phy_cs_o[mi_addr_cs] <= 1'b0;
					else if (ectl_req)
						phy_cs_o[ectl_cs] <= 1'b0;
				end

				ST_FLUSH:
					if (~so_valid)
						phy_cs_o <= { N_CS{1'b1} };

				ST_PAUSE:
					phy_cs_o <= { N_CS{1'b1} };
			endcase
		end


	// Shift-Out unit
	// --------------

		//					  Shift								Output
		// SPI mode			: Each chan shifts PHY_SPEED		Output only defined for MOSI
		// QPI read			: n/a                               n/a
		// QPI data mode	: Each chan shifts 4 * PHY_SPEED	Output QPI mode
		// QPI command mode	: Word shifts 4 * PHY_SPEED         chan[1] replicates chan[0]

	// Validity
	always @(posedge clk)
		if (rst)
			so_valid <= 1'b0;
		else
			so_valid <= (so_valid & ~so_last) | (so_ld_now & so_ld_valid);

	// Mode / Read-destination
	always @(posedge clk)
		if (so_ld_now) begin
			so_mode <= so_ld_mode;
			so_dst  <= so_ld_dst;
		end

	// Counter
	always @(posedge clk)
		if (so_ld_now)
			so_cnt <= so_ld_cnt;
		else
			so_cnt <= so_cnt - PHY_SPEED;

	assign so_last = so_cnt[5];

	// Shift register
	always @(posedge clk)
	begin
		casez ({so_ld_now, so_ld_src, so_mode})
			{ 1'b0, 2'bzz, SO_MODE_SPI }:		so_data <= shift_spi(so_data);
			{ 1'b0, 2'bzz, SO_MODE_QPI_WR }:	so_data <= shift_qpi_data(so_data);
			{ 1'b0, 2'bzz, SO_MODE_QPI_CMD }:	so_data <= shift_qpi_cmd(so_data);
			{ 1'b1, SO_LD_SRC_WB, 2'bzz }:		so_data <= cf_do[31:0];
			{ 1'b1, SO_LD_SRC_MI_DATA, 2'bzz }:	so_data <= mi_wdata;
			{ 1'b1, SO_LD_SRC_MI_CMD, 2'bzz }:	so_data <= { mi_spi_cmd, mi_addr };
			default:							so_data <= 32'hxxxxxxxx;
		endcase
	end

	// IO control
	always @(*)
	begin : io_ctrl
		integer chan, i;

		// Control
		if (so_valid) begin
			// Clock
			if (PHY_SPEED > 1)
				for (i=0; i<PSW; i=i+1)
					phy_clk_o[i] = ~so_last | (i >= (PHY_SPEED-1-so_cnt[$clog2(PHY_SPEED)-1:0]));
			else
				phy_clk_o <= 1'b1;

			// Output Enable
			case (so_mode)
				SO_MODE_SPI:		phy_io_oe = 4'b0001;
				SO_MODE_QPI_RD:		phy_io_oe = 4'b0000;
				SO_MODE_QPI_WR:		phy_io_oe = 4'b1111;
				SO_MODE_QPI_CMD:	phy_io_oe = 4'b1111;
				default:            phy_io_oe = 4'bxxxx;
			endcase
		end else begin
			// Disable all
			phy_clk_o <= {PSW{1'b0}};
			phy_io_oe <= 4'b0000;
		end

		// Data
		if (so_mode[0])
			phy_io_o = shift2phy_qpi_cmd(so_data);
		else
			phy_io_o = shift2phy_qpi_data(so_data);

		if (~so_mode[1])
			phy_io_o = shift2phy_spi(so_data, phy_io_o);
	end


	// Shift-In unit
	// -------------

	// Capture control
	assign si_mode_0 = so_mode[0];

	always @(posedge clk)
	begin
		// Default destination is 'none'
		si_dst_1 <= 2'b00;

		// If it's a read, send it somewhere
		if (so_valid & so_last & ~so_mode[1] & so_dst[1])
			si_dst_1 <= so_dst[0] ? { 1'b1, (state == ST_FLUSH) } : 2'b01;
	end

	// Delay for PHY pipeline
	delay_bit #(PHY_DELAY)    dly_si_mode (si_mode_0, si_mode_nm1, clk);
	delay_bus #(PHY_DELAY, 2) dly_si_dst  (si_dst_1,  si_dst_n,    clk);

	// Shifter
	always @(posedge clk)
	begin
		// 2 modes:
		//  0 - SPI shift-in      PHY_SPEED bits at a time per channel
		//  1 - QPI shift-in  4 * PHY_SPEED bits at a time per channel
		if (si_mode_nm1)
			si_data_n <= phy2shift_qpi(si_data_n, phy_io_i);
		else
			si_data_n <= phy2shift_spi(si_data_n, phy_io_i);
	end

endmodule
