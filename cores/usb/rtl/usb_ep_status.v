/*
 * usb_ep_status.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019 Sylvain Munaut
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

`default_nettype none

module usb_ep_status (
	// Priority port
	input  wire [ 7:0] p_addr_0,
	input  wire        p_read_0,
	input  wire        p_zero_0,
	input  wire        p_write_0,
	input  wire [15:0] p_din_0,
	output reg  [15:0] p_dout_3,

	// Aux R/W port
	input  wire [ 7:0] s_addr_0,
	input  wire        s_read_0,
	input  wire        s_zero_0,
	input  wire        s_write_0,
	input  wire [15:0] s_din_0,
	output reg  [15:0] s_dout_3,
	output wire        s_ready_0,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Signals
	wire s_ready_0_i;
	reg  [ 7:0] addr_1;
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
	assign s_ready_0_i = ~p_read_0 & ~p_write_0;
	assign s_ready_0 = s_ready_0_i;

	// Stage 1 : Address mux and Write delay
	always @(posedge clk)
	begin
		addr_1   <= (p_read_0 | p_write_0) ? p_addr_0 : s_addr_0;
		we_1     <= p_write_0 | (s_write_0 & s_ready_0_i);
		din_1    <= p_write_0 ? p_din_0 : s_din_0;
		p_read_1 <= p_read_0;
		p_zero_1 <= p_zero_0;
		s_read_1 <= s_read_0 & s_ready_0_i;
		s_zero_1 <= s_zero_0 & s_ready_0_i;
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
	SB_RAM40_4K #(
`ifdef SIM
		.INIT_FILE("usb_ep_status.hex"),
`endif
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

endmodule // usb_ep_status
