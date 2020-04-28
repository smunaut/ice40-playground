/*
 * qspi_master_tb.v
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
`timescale 1ns / 100ps

module qspi_master_tb;

	// Signals
	// -------

	// Memory interface
	wire [ 1:0] mi_addr_cs;
	reg  [23:0] mi_addr;
	reg  [ 6:0] mi_len;
	reg         mi_rw;
	reg         mi_valid;
	wire        mi_ready;

	reg  [31:0] mi_wdata;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// Wishbone interface
	reg  [31:0] wb_wdata;
	wire [31:0] wb_rdata;
	reg  [ 4:0] wb_addr;
	reg         wb_we;
	reg         wb_cyc;
	wire        wb_ack;

	// Clocks / Sync
	reg  pll_lock = 1'b0;
	reg  clk = 1'b0;
	wire rst;

	reg        rst_div;
	reg  [1:0] clk_div;
	reg  [3:0] rst_cnt = 4'h8;


	// Recording setup
	// ---------------

	initial begin
		$dumpfile("qspi_master_tb.vcd");
		$dumpvars(0,qspi_master_tb);
	end


	// DUT
	// ---

	qspi_master #(
		.CMD_READ(16'h3802),
		.CMD_WRITE(16'hEBEB),
		.DUMMY_CLK(6),
		.PAUSE_CLK(9),
		.FIFO_DEPTH(1),
		.N_CS(2),
		.PHY_SPEED(4),
		.PHY_WIDTH(1),
		.PHY_DELAY(2)
	) dut_I (
		.mi_addr_cs(mi_addr_cs),
		.mi_addr(mi_addr),
		.mi_len(mi_len),
		.mi_rw(mi_rw),
		.mi_valid(mi_valid),
		.mi_ready(mi_ready),
		.mi_wdata(mi_wdata),
		.mi_wack(mi_wack),
		.mi_wlast(mi_wlast),
		.mi_rdata(mi_rdata),
		.mi_rstb(mi_rstb),
		.mi_rlast(mi_rlast),
		.wb_wdata(wb_wdata),
		.wb_rdata(wb_rdata),
		.wb_addr(wb_addr),
		.wb_we(wb_we),
		.wb_cyc(wb_cyc),
		.wb_ack(wb_ack),
		.clk(clk),
		.rst(rst)
	);


	// Mem interface
	// -------------

	// Fixed values
	assign mi_addr_cs = 2'b01;

	always @(posedge clk)
		if (rst)
			mi_wdata <= 32'h00010203;
		else if (mi_wack)
			mi_wdata <= mi_wdata + 32'h04040404;


	// Stimulus
	// --------

	task wb_write;
		input [ 4:0] addr;
		input [31:0] data;
		begin
			wb_addr  <= addr;
			wb_wdata <= data;
			wb_we    <= 1'b1;
			wb_cyc   <= 1'b1;

			while (~wb_ack)
				@(posedge clk);

			wb_addr  <= 4'hx;
			wb_wdata <= 32'hxxxxxxxx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;

			@(posedge clk);
		end
	endtask

	task mi_burst_write;
		input [23:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b0;
			mi_valid <= 1'b1;

			@(posedge clk);
			while (~mi_ready)
				@(posedge clk);

			mi_valid <= 1'b0;
		end
	endtask

	task mi_burst_read;
		input [23:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b1;
			mi_valid <= 1'b1;

			@(posedge clk);
			while (~mi_ready)
				@(posedge clk);

			mi_valid <= 1'b0;
		end
	endtask

	initial begin
		// Defaults
		wb_addr  <= 4'hx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		mi_addr  <= 32'hxxxxxxxx;
		mi_len   <= 7'hx;
		mi_rw    <= 1'bx;
		mi_valid <= 1'b0;

		@(negedge rst);
		@(posedge clk);

		// Switch to command mode
		wb_write(5'h00, 32'h00000002);

		// Send SPI command
		wb_write(5'h10, 32'h01234567);	// 8-bit SPI xfer

		#200
		@(posedge clk);
		wb_write(5'h13, 32'h9f000000);

		#400
		@(posedge clk);
		wb_write(5'h1f, 32'h01234567);	// 32-bit QPI command write

		// Wait
		#200
		@(posedge clk);

		// Switch to run-time mode
		wb_write(5'h00, 32'h00000004);

		// Execute 32 byte burst
		mi_burst_read (24'h123456, 7'd31);
		mi_burst_read (24'h002000, 7'd31);
		mi_burst_write(24'h003000, 7'd31);
	end


	// Clock / Reset
	// -------------

	// Native clocks
	initial begin
		# 200 pll_lock = 1'b1;
		# 100000 $finish;
	end

	always #10 clk = ~clk;		// 50   MHz

	// Reset
	always @(posedge clk or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h8;
		else if (rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst = rst_cnt[3];

endmodule
