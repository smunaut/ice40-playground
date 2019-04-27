/*
 * usb_trans.v
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

module usb_trans #(
	parameter integer ADDR_MATCH = 1
)(
	// TX Packet interface
	output wire txpkt_start,
	input  wire txpkt_done,

	output reg  [3:0] txpkt_pid,
	output wire [9:0] txpkt_len,

	output wire [7:0] txpkt_data,
	input  wire txpkt_data_ack,

	// RX Packet interface
	input  wire rxpkt_start,
	input  wire rxpkt_done_ok,
	input  wire rxpkt_done_err,

	input  wire [ 3:0] rxpkt_pid,
	input  wire rxpkt_is_sof,
	input  wire rxpkt_is_token,
	input  wire rxpkt_is_data,
	input  wire rxpkt_is_handshake,

	input  wire [10:0] rxpkt_frameno,
	input  wire [ 6:0] rxpkt_addr,
	input  wire [ 3:0] rxpkt_endp,

	input  wire [ 7:0] rxpkt_data,
	input  wire rxpkt_data_stb,

	// EP Data Buffers
	output wire [10:0] buf_tx_addr_0,
	input  wire [ 7:0] buf_tx_data_1,
	output wire buf_tx_rden_0,

	output wire [10:0] buf_rx_addr_0,
	output wire [ 7:0] buf_rx_data_0,
	output wire buf_rx_wren_0,

	// EP Status RAM
	output wire eps_read_0,
	output wire eps_zero_0,
	output wire eps_write_0,
	output wire [ 7:0] eps_addr_0,
	output wire [15:0] eps_wrdata_0,
	input  wire [15:0] eps_rddata_3,

	// Config / Status
	input  wire cr_addr_chk,
	input  wire [ 6:0] cr_addr,

	output wire [11:0] evt_data,
	output wire evt_stb,

	output wire cel_state,
	input  wire cel_rel,
	input  wire cel_ena,

	// Common
	input  wire clk,
	input  wire rst
);

	`include "usb_defs.vh"

	// Signals
	// -------

	// Micro-Code
	reg  [ 3:0] mc_a_reg;

	reg mc_rst_n;
	(* keep="true" *) wire [ 3:0] mc_match_bits;
	wire mc_match;
	wire mc_jmp;

	wire [ 7:0] mc_pc;
	reg  [ 7:0] mc_pc_nxt;
	wire [15:0] mc_opcode;

	(* keep="true" *) wire mc_op_ld;
	(* keep="true" *) wire mc_op_ep;
	(* keep="true" *) wire mc_op_zlen;
	(* keep="true" *) wire mc_op_tx;
	(* keep="true" *) wire mc_op_notify;
	(* keep="true" *) wire mc_op_evt_clr;
	(* keep="true" *) wire mc_op_evt_rto;

	// Events
	wire [3:0] evt_rst;
	wire [3:0] evt_set;
	reg  [3:0] evt;

	reg  [3:0] pkt_pid;

	wire rto_now;
	reg  [9:0] rto_cnt;

	// Transaction / EndPoint / Buffer infos
	reg        trans_is_setup;
	reg  [3:0] trans_endp;
	reg        trans_dir;

	reg  [2:0] ep_type;
	reg        ep_bd_dual;
	reg        ep_bd_ctrl;
	reg        ep_bd_idx_cur;
	reg        ep_bd_idx_nxt;
	reg        ep_data_toggle;

	reg  [2:0] bd_state;

	// EP & BD Infos fetch/writeback
	localparam
		EPFW_IDLE		= 4'b0000,
		EPFW_RD_STATUS	= 4'b0100,
		EPFW_RD_BD_W0	= 4'b0110,
		EPFW_RD_BD_W1	= 4'b0111,
		EPFW_WR_STATUS	= 4'b1000,
		EPFW_WR_BD_W0	= 4'b1010;

	reg  [3:0] epfw_state;
	reg  [5:0] epfw_cap_dl;
	reg  epfw_issue_wb;

	// Control Endpoint Lockout
	reg  cel_state_i;

	// Packet TX
	reg  txpkt_start_i;

	// Address
	reg  [10:0] addr;
	wire addr_inc;
	wire addr_ld;

	// Length
	reg [10:0] bd_length;
	reg [ 9:0] xfer_length;
	wire len_ld;
	wire len_bd_dec;
	wire len_xf_inc;


	// Micro-Code execution engine
	// ---------------------------

	// Local reset to avoid being in the critical path
	always @(posedge clk or posedge rst)
		if (rst)
			mc_rst_n <= 1'b0;
		else
			mc_rst_n <= 1'b1;

	// Conditional Jump handling
	assign mc_match_bits = (mc_a_reg[3:0] & mc_opcode[7:4]) ^ mc_opcode[3:0];
	assign mc_match = ~|mc_match_bits;
	assign mc_jmp = mc_opcode[15] & mc_rst_n & (mc_match ^ mc_opcode[14]);
	assign mc_pc = mc_jmp ? {mc_opcode[13:8], 2'b00} : mc_pc_nxt;

	// Program counter
	always @(posedge clk or posedge rst)
		if (rst)
			mc_pc_nxt <= 8'h00;
		else
			mc_pc_nxt <= mc_pc + 1;

	// Microcode ROM
	SB_RAM40_4K #(
		.INIT_FILE("usb_trans_mc.hex"),
		.WRITE_MODE(0),
		.READ_MODE(0)
	) mc_rom_I (
		.RDATA(mc_opcode),
		.RADDR({3'b000, mc_pc}),
		.RCLK(clk),
		.RCLKE(1'b1),
		.RE(1'b1),
		.WDATA(16'h0000),
		.WADDR(11'h000),
		.MASK(16'h0000),
		.WCLK(1'b0),
		.WCLKE(1'b0),
		.WE(1'b0)
	);

	// Decode opcodes
	assign mc_op_ld      = mc_opcode[15:12] == 4'b0001;
	assign mc_op_ep      = mc_opcode[15:12] == 4'b0010;
	assign mc_op_zlen    = mc_opcode[15:12] == 4'b0011;
	assign mc_op_tx      = mc_opcode[15:12] == 4'b0100;
	assign mc_op_notify  = mc_opcode[15:12] == 4'b0101;
	assign mc_op_evt_clr = mc_opcode[15:12] == 4'b0110;
	assign mc_op_evt_rto = mc_opcode[15:12] == 4'b0111;

	// A-register
	always @(posedge clk)
		if (mc_op_ld)
			casez (mc_opcode[2:1])
				2'b00:   mc_a_reg <= evt;
				2'b01:   mc_a_reg <= pkt_pid ^ { ep_data_toggle & mc_opcode[0], 3'b000 };
				2'b10:   mc_a_reg <= { cel_state_i, ep_type };
				2'b11:   mc_a_reg <= { 1'b0, bd_state };
				default: mc_a_reg <= 4'hx;
			endcase


	// Events
	// ------

	// Latch events
	always @(posedge clk or posedge rst)
		if (rst)
			evt <= 4'h0;
		else
			evt <= (evt & ~evt_rst) | evt_set;

	assign evt_rst = {4{mc_op_evt_clr}} & mc_opcode[3:0];
	assign evt_set = { rto_now, txpkt_done, rxpkt_done_err, rxpkt_done_ok };

	// Capture Packet PID
	if (ADDR_MATCH) begin
		always @(posedge clk)
			if (rxpkt_done_ok) begin
				if (rxpkt_is_token & cr_addr_chk)
					pkt_pid <= (rxpkt_addr == cr_addr) ? rxpkt_pid : PID_INVAL;
				else
					pkt_pid <= rxpkt_pid;
			end
	end else begin
		always @(*)
			pkt_pid = rxpkt_pid;
	end

	// RX Timeout counter
	always @(posedge clk or posedge rst)
		if (rst)
			rto_cnt <= 0;
		else
			if (mc_op_evt_rto)
				rto_cnt <= { 2'b01, mc_opcode[7:0] };
			else
				rto_cnt <= {
					rto_cnt[9] & rto_cnt[8] & ~rxpkt_start,
					rto_cnt[8:0] - rto_cnt[9]
				};

	assign rto_now = rto_cnt[9] & ~rto_cnt[8];


	// Host NOTIFY
	// -----------

	assign evt_stb = mc_op_notify;
	assign evt_data = {
		mc_opcode[3:0], // [11:8] Micro-code return value
		trans_endp,     // [ 7:4] Endpoint
		trans_dir,      //    [3] Direction
		trans_is_setup, //    [2] SETUP transaction
		ep_bd_idx_cur,  //    [1] BD where it happenned
		1'b0
	};


	// EP infos
	// --------

	// Capture EP# and direction when we get a TOKEN packet
	always @(posedge clk)
		if (rxpkt_done_ok & rxpkt_is_token) begin
			trans_is_setup   <= rxpkt_pid == PID_SETUP;
			trans_endp       <= rxpkt_endp;
			trans_dir        <= rxpkt_pid == PID_IN;
		end

	// EP Status Fetch/WriteBack (epfw)

		// State
	always @(posedge clk or posedge rst)
		if (rst)
			epfw_state <= EPFW_IDLE;
		else
			case (epfw_state)
				EPFW_IDLE:
					if (epfw_issue_wb)
						epfw_state <= EPFW_WR_STATUS;
					else if (rxpkt_done_ok & rxpkt_is_token)
						epfw_state <= EPFW_RD_STATUS;
					else if (epfw_cap_dl[1:0] == 2'b01)
						epfw_state <= EPFW_RD_BD_W0;
					else
						epfw_state <= EPFW_IDLE;

				EPFW_RD_STATUS:
					epfw_state <= EPFW_IDLE;

				EPFW_RD_BD_W0:
					epfw_state <= EPFW_RD_BD_W1;

				EPFW_RD_BD_W1:
					epfw_state <= EPFW_IDLE;

				EPFW_WR_STATUS:
					epfw_state <= EPFW_WR_BD_W0;

				EPFW_WR_BD_W0:
					epfw_state <= EPFW_IDLE;

				default:
					epfw_state <= EPFW_IDLE;
			endcase

		// Issue command to RAM
	assign eps_zero_0  = 1'b0;
	assign eps_read_0  = epfw_state[2];
	assign eps_write_0 = epfw_state[3];

	assign eps_addr_0  = {
		trans_endp,
		trans_dir,
		epfw_state[1],
		epfw_state[1] & ep_bd_idx_cur,
		epfw_state[0]
	};

	assign eps_wrdata_0 = epfw_state[1] ?
		{ bd_state, trans_is_setup, 2'b00, xfer_length[9:0] } :
		{ 8'h00, ep_data_toggle, ep_bd_idx_nxt, ep_bd_ctrl, ep_bd_dual, 1'b0, ep_type };

		// Delay line for what to expect on read data
	always @(posedge clk or posedge rst)
		if (rst)
			epfw_cap_dl = 6'b000000;
		else
			epfw_cap_dl <= {
				epfw_state[1],
				epfw_state[2] & ~^epfw_state[1:0],
				epfw_cap_dl[5:2]
			};

		// Capture read data
	always @(posedge clk)
	begin
		// EP Status
		if (epfw_cap_dl[1:0] == 2'b01) begin
			ep_type        <= eps_rddata_3[2:0];
			ep_bd_dual     <= eps_rddata_3[4];
			ep_bd_ctrl     <= eps_rddata_3[5];
			ep_bd_idx_cur  <= eps_rddata_3[5] ? trans_is_setup : eps_rddata_3[6];
			ep_bd_idx_nxt  <= eps_rddata_3[6];
			ep_data_toggle <= eps_rddata_3[7] & ~trans_is_setup; /* For SETUP, DT == 0 */
		end else begin
			ep_data_toggle <= ep_data_toggle ^ (mc_op_ep & mc_opcode[0]);
			ep_bd_idx_nxt  <= ep_bd_idx_nxt  ^ (mc_op_ep & mc_opcode[1] & ep_bd_dual );
		end

		// BD Word 0
		if (epfw_cap_dl[1:0] == 2'b10) begin
			bd_state <= eps_rddata_3[15:13];
		end else begin
			bd_state <= (mc_op_ep & mc_opcode[2]) ? mc_opcode[5:3]: bd_state;
		end
	end

		// When do to write backs
	always @(posedge clk)
		epfw_issue_wb <= mc_op_ep & mc_opcode[7];


	// Control Endpoint Lockout
	// ------------------------

	always @(posedge clk or posedge rst)
		if (rst)
			cel_state_i <= 1'b0;
		else
			cel_state_i <= cel_ena & ((cel_state_i & ~cel_rel) | (mc_op_ep & mc_opcode[8]));

	assign cel_state = cel_state_i;


	// Packet TX
	// ---------

	always @(posedge clk)
		if (mc_op_tx)
			txpkt_pid <= mc_opcode[3:0] ^ { mc_opcode[4] & ep_data_toggle, 3'b000 };

	always @(posedge clk)
		txpkt_start_i <= mc_op_tx;

	assign txpkt_start = txpkt_start_i;
	assign txpkt_len = bd_length[9:0];


	// Data Address/Length shared logic
	// --------------------------------

	// Address
	always @(posedge clk)
		addr <= addr_ld ? eps_rddata_3[10:0] : (addr + addr_inc);

	assign addr_ld  = epfw_cap_dl[1:0] == 2'b11;
	assign addr_inc = txpkt_data_ack | txpkt_start_i | rxpkt_data_stb;

	// Buffer length (decrements)
	always @(posedge clk)
		if (mc_op_zlen)
			bd_length <= 0;
		else
			bd_length <= len_ld ? { 1'b1, eps_rddata_3[9:0] } : (bd_length -  len_bd_dec);

	// Xfer length (increments)
	always @(posedge clk)
		xfer_length <= len_ld ? 10'h000 : (xfer_length + len_xf_inc);

	// Length control
	assign len_ld = epfw_cap_dl[1:0] == 2'b10;

	assign len_bd_dec = (rxpkt_data_stb | rxpkt_start) & bd_length[10];
	assign len_xf_inc =  rxpkt_data_stb;


	// Data read logic
	// ---------------

	assign buf_tx_addr_0 = addr;
	assign buf_tx_rden_0 = txpkt_data_ack | txpkt_start_i;

	assign txpkt_data = buf_tx_data_1;


	// Data write logic
	// ----------------

	assign buf_rx_addr_0 = addr;
	assign buf_rx_data_0 = rxpkt_data;
	assign buf_rx_wren_0 = rxpkt_data_stb & bd_length[10];

endmodule // usb_trans
