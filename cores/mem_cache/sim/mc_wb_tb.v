/*
 * mc_wb_tb.v
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

module mc_wb_tb;

	// Signals
	// -------

	// Wishbone bus
	reg  [19:0] wb_addr;
	reg  [31:0] wb_wdata;
	reg  [ 3:0] wb_wmask;
	wire [31:0] wb_rdata;
	reg         wb_cyc;
	reg         wb_we;
	wire        wb_ack;

	// Cache request/response
	wire [19:0] req_addr_pre;

	wire        req_valid;
	wire        req_write;
	wire [31:0] req_wdata;
	wire [ 3:0] req_wmask;

	wire        resp_ack;
	wire        resp_nak;
	wire [31:0] resp_rdata;

	// Memory interface
	wire [19:0] mi_addr;
	wire [ 6:0] mi_len;
	wire        mi_rw;
	wire        mi_valid;
	wire        mi_ready;

	wire [31:0] mi_wdata;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// Clocks / Sync
	wire [3:0] clk_read_delay;

	reg  pll_lock = 1'b0;
	reg  clk = 1'b0;
	wire rst;

	reg  [3:0] rst_cnt = 4'h8;


	// Recording setup
	// ---------------

	initial begin : dump
		integer i;

		$dumpfile("mc_wb_tb.vcd");
		$dumpvars(0,mc_wb_tb);
		$dumpvars(0,mc_wb_tb);

		for (i=0; i<4; i=i+1) begin
			$dumpvars(0, mc_wb_tb.dut_I.way_valid[i]);
			$dumpvars(0, mc_wb_tb.dut_I.way_dirty[i]);
			$dumpvars(0, mc_wb_tb.dut_I.way_age[i]);
			$dumpvars(0, mc_wb_tb.dut_I.way_tag[i]);
		end
	end


	// DUT
	// ---

	mc_core #(
		.N_WAYS(4),
		.ADDR_WIDTH(20),
		.CACHE_LINE(64),
		.CACHE_SIZE(64)
	) dut_I (
		.req_addr_pre(req_addr_pre),
		.req_valid(req_valid),
		.req_write(req_write),
		.req_wdata(req_wdata),
		.req_wmask(req_wmask),
		.resp_ack(resp_ack),
		.resp_nak(resp_nak),
		.resp_rdata(resp_rdata),
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
		.clk(clk),
		.rst(rst)
	);

	mc_bus_wb #(
		.ADDR_WIDTH(20)
	) bus_adapt_I (
		.wb_addr(wb_addr),
		.wb_wdata(wb_wdata),
		.wb_wmask(wb_wmask),
		.wb_rdata(wb_rdata),
		.wb_cyc(wb_cyc),
		.wb_we(wb_we),
		.wb_ack(wb_ack),
		.req_addr_pre(req_addr_pre),
		.req_valid(req_valid),
		.req_write(req_write),
		.req_wdata(req_wdata),
		.req_wmask(req_wmask),
		.resp_ack(resp_ack),
		.resp_nak(resp_nak),
		.resp_rdata(resp_rdata),
		.clk(clk),
		.rst(rst)
	);


	// Simulated memory
	// ----------------

	mem_sim mem_I (
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
		.clk(clk),
		.rst(rst)
	);


	// Stimulus
	// --------

	task wb_write;
		input [19:0] addr;
		input [31:0] data;
		begin
			wb_addr  <= addr;
			wb_wdata <= data;
			wb_wmask <= 4'h0;
			wb_we    <= 1'b1;
			wb_cyc   <= 1'b1;

			@(posedge clk);
			while (~wb_ack)
				@(posedge clk);

			wb_addr  <= 4'hx;
			wb_wdata <= 32'hxxxxxxxx;
			wb_wmask <= 4'hx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;
		end
	endtask

	task wb_read;
		input [19:0] addr;
		begin
			wb_addr  <= addr;
			wb_we    <= 1'b0;
			wb_cyc   <= 1'b1;

			@(posedge clk);
			while (~wb_ack)
				@(posedge clk);

			wb_addr  <= 4'hx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;
		end
	endtask

	initial begin
		// Defaults
		wb_addr  <= 4'hx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_wmask <= 4'hx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		@(negedge rst);
		@(posedge clk);

		#200 @(posedge clk);

		wb_write(20'h00010, 32'hcafedead);
		wb_read (20'h00010);
		wb_read (20'h00011);

	end


	// Clock / Reset
	// -------------

	// Native clocks
	initial begin
		# 200 pll_lock = 1'b1;
		# 100000 $finish;
	end

	always #4 clk = ~clk;

	// Reset
	always @(posedge clk or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h8;
		else if (rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst = rst_cnt[3];

endmodule
