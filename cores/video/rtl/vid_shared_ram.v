/*
 * vid_shared_ram.v
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

module vid_shared_ram #(
	parameter TYPE = "EBR",	// "EBR" / "SPRAM"
	parameter integer AW = (TYPE == "EBR") ? 8 : 14
)(
	// Priority read port
	input  wire [AW-1:0] p_addr_0,
	input  wire          p_read_0,
	input  wire          p_zero_0,
	output reg  [  15:0] p_dout_3,

	// Aux R/W port
	input  wire [AW-1:0] s_addr_0,
	input  wire [  15:0] s_din_0,
	input  wire          s_read_0,
	input  wire          s_zero_0,
	input  wire          s_write_0,
	output reg  [  15:0] s_dout_3,
	output wire          s_ready_0,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Signals
	reg  [AW-1:0] addr_1;
	reg  [15:0] din_1;
	reg  we_1;
	reg  p_read_1;
	reg  p_zero_1;
	reg  s_read_1;
	reg  s_zero_1;

	wire [15:0] dout_2;
	reg  p_read_2;
	reg  p_zero_2;
	reg  s_read_2;
	reg  s_zero_2;

	// "Arbitration"
	assign s_ready_0 = ~p_read_0;

	// Stage 1 : Address mux and Write delay
	always @(posedge clk)
	begin
		addr_1   <= p_read_0 ? p_addr_0 : s_addr_0;
		we_1     <= s_write_0 & ~p_read_0;
		din_1    <= s_din_0;
		p_read_1 <= p_read_0;
		p_zero_1 <= p_zero_0;
		s_read_1 <= s_read_0 & ~p_read_0;
		s_zero_1 <= s_zero_0 & ~p_read_0;
	end

	// Stage 2 : Delays
	always @(posedge clk)
	begin
		p_read_2 <= p_read_1 | p_zero_1;
		p_zero_2 <= p_zero_1;
		s_read_2 <= s_read_1 | s_zero_1;
		s_zero_2 <= s_zero_1;
	end

	// Stage 3 : Output registers
	always @(posedge clk)
		if (p_read_2)
			p_dout_3 <= p_zero_2 ? 16'h0000 : dout_2;

	always @(posedge clk)
		if (s_read_2)
			s_dout_3 <= s_zero_2 ? 16'h0000 : dout_2;

	// RAM element
	generate
		if (TYPE == "SPRAM")
			SB_SPRAM256KA spram_I (
				.DATAIN(din_1),
				.ADDRESS(addr_1),
				.MASKWREN(4'hf),
				.WREN(we_1),
				.CHIPSELECT(1'b1),
				.CLOCK(clk),
				.STANDBY(1'b0),
				.SLEEP(1'b0),
				.POWEROFF(1'b1),
				.DATAOUT(dout_2)
			);

		else if (TYPE == "EBR")
			SB_RAM40_4K #(
				.WRITE_MODE(0),
				.READ_MODE(0)
			) ebr_I (
				.RDATA(dout_2),
				.RADDR({3'b000, addr_1}),
				.RCLK(clk),
				.RCLKE(1'b1),
				.RE(1'b1),
				.WDATA(din_1),
				.WADDR({3'b000, addr_1}),
				.MASK(16'h0000),
				.WCLK(clk),
				.WCLKE(we_1),
				.WE(1'b1)
			);
	endgenerate

endmodule // vid_shared_ram
