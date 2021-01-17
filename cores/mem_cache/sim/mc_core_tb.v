/*
 * mc_core_tb.v
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

module mc_core_tb;

	// Signals
	// -------

	// Cache request/response
	reg  [19:0] req_addr_pre;
	reg         req_valid_pre;
	reg         req_write_pre;
	reg  [31:0] req_wdata_pre;
	reg  [ 3:0] req_wmsk_pre;

	reg         req_valid;
	reg         req_write;
	reg  [31:0] req_wdata;
	reg  [ 3:0] req_wmsk;

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

		$dumpfile("mc_core_tb.vcd");
		$dumpvars(0,mc_core_tb);
		$dumpvars(0,mc_core_tb);

		for (i=0; i<4; i=i+1) begin
			$dumpvars(0, mc_core_tb.dut_I.way_valid[i]);
			$dumpvars(0, mc_core_tb.dut_I.way_dirty[i]);
			$dumpvars(0, mc_core_tb.dut_I.way_age[i]);
			$dumpvars(0, mc_core_tb.dut_I.way_tag[i]);
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
		.req_wmsk(req_wmsk),
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

	task mc_req_write;
		input [20:0] addr;
		input [31:0] data;
		input [ 3:0] msk;
		begin
			req_addr_pre <= addr;
			req_valid_pre <= 1'b1;
			req_write_pre <= 1'b1;
			req_wdata_pre <= data;
			req_wmsk_pre  <= msk;
			@(posedge clk);

			req_addr_pre  <= 20'hxxxxx;
			req_valid_pre <= 1'b0;
			req_write_pre <= 1'bx;
			req_wdata_pre <= 32'hxxxxxxxx;
			req_wmsk_pre  <=  4'hx;
		end
	endtask

	task mc_req_read;
		input [31:0] addr;
		begin
			req_addr_pre <= addr;
			req_valid_pre <= 1'b1;
			req_write_pre <= 1'b0;
			@(posedge clk);

			req_addr_pre  <= 20'hxxxxx;
			req_valid_pre <= 1'b0;
			req_write_pre <= 1'bx;
		end
	endtask

	initial begin
		// Defaults
		req_addr_pre  <= 20'hxxxxx;
		req_valid_pre <= 1'b0;
		req_write_pre <= 1'bx;
		req_wdata_pre <= 32'hxxxxxxxx;
		req_wmsk_pre  <=  4'hx;

		@(negedge rst);
		@(posedge clk);

		#200 @(posedge clk);

		// Execute 32 byte burst
		mc_req_read(20'h00010);
		#200 @(posedge clk);
		mc_req_read(20'h00010);
		mc_req_write(20'h0001f, 32'h01234567, 4'h0);
		mc_req_write(20'h00010, 32'h600dbabe, 4'h0);
		mc_req_read(20'h0001f);

		mc_req_read(20'h10010);
		#200 @(posedge clk);
		mc_req_read(20'h10010);
		@(posedge clk);

		mc_req_read(20'h20010);
		#200 @(posedge clk);
		mc_req_read(20'h20010);
		@(posedge clk);

		mc_req_read(20'h30010);
		#200 @(posedge clk);
		mc_req_read(20'h30010);
		@(posedge clk);

		mc_req_read(20'h40010);
		#400 @(posedge clk);
		mc_req_read(20'h40010);
		@(posedge clk);

		mc_req_read(20'h20010);
		@(posedge clk);
		mc_req_read(20'h20010);
		@(posedge clk);
	end

	always @(posedge clk)
	begin
		req_valid <= req_valid_pre;
		req_write <= req_write_pre;
		req_wdata <= req_wdata_pre;
		req_wmsk  <= req_wmsk_pre;
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
