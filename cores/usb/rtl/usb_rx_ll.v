/*
 * usb_rx_ll.v
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

module usb_rx_ll (
	// PHY
	input  wire phy_rx_dp,
	input  wire phy_rx_dn,
	input  wire phy_rx_chg,

	// Low-Level
	output wire [1:0] ll_sym,
	output wire ll_bit,
	output wire ll_valid,
	output wire ll_eop,
	output wire ll_sync,
	output wire ll_bs_skip,
	output wire ll_bs_err,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Sampling
	reg        samp_active;
	(* keep="true" *) wire samp_sync;
	reg  [2:0] samp_cnt;
	wire [1:0] samp_sym_0;
	reg        samp_valid_0;

	// Decoding
	(* keep="true" *) wire dec_sym_same_0;
	(* keep="true" *) wire dec_sym_se_0;	/* Symbol is SE0 or SE1 */
	reg  [2:0] dec_eop_state_1;
	reg  [3:0] dec_sync_state_1;
	reg  [3:0] dec_rep_state_1;

	reg  [1:0] dec_sym_1;
	reg        dec_bit_1;
	reg        dec_valid_1;
	wire       dec_eop_1;
	wire       dec_sync_1;
	wire [2:0] dec_rep_1;
	reg        dec_bs_skip_1;
	wire       dec_bs_err_1;


	// Sampling
	// --------

	// Active
		// The EOP and Error signals are from the next stage, but the pipeline
		// violation doesn't matter, we just want to stop before the next
		// packet so that the resync works well at the beginning of the next
		// packet.
	always @(posedge clk or posedge rst)
		if (rst)
			samp_active <= 1'b0;
		else
			samp_active <= (samp_active | phy_rx_chg) & ~(dec_valid_1 & (dec_eop_1 | dec_bs_err_1));

	// When to resync
	assign samp_sync = ~samp_active | (~samp_cnt[2] && phy_rx_chg);

	// Sampling phase tracking
	always @(posedge clk)
		if (samp_sync)
			samp_cnt <= 3'b101;
		else
			/* The following case implements :
			 * samp_cnt <= (samp_cnt - 1) & { samp_cnt[2], 2'b11 };
			 * but in a way that synthesis understands well */
			case (samp_cnt)
				3'b000:  samp_cnt <= 3'b011;
				3'b001:  samp_cnt <= 3'b000;
				3'b010:  samp_cnt <= 3'b001;
				3'b011:  samp_cnt <= 3'b010;
				3'b100:  samp_cnt <= 3'b011;
				3'b101:  samp_cnt <= 3'b100;
				3'b110:  samp_cnt <= 3'b101;
				3'b111:  samp_cnt <= 3'b110;
				default: samp_cnt <= 3'bxxx;
			endcase

	// Output to next stage
	always @(posedge clk)
		samp_valid_0 <= samp_active & (samp_cnt[1:0] == 2'b01) & ~samp_valid_0;

	assign samp_sym_0 = { phy_rx_dp, phy_rx_dn };


	// Bit de-stuffing & NRZI
	// ----------------------

	// Compare with previous
	assign dec_sym_same_0 = (samp_sym_0 == dec_sym_1);
	assign dec_sym_se_0 = ~^samp_sym_0;

	// Symbol and Bit-value
	always @(posedge clk)
		if (samp_valid_0)
		begin
			dec_sym_1 <= samp_sym_0;
			dec_bit_1 <= (samp_sym_0[0]  ^ samp_sym_0[1]) &	// Symbol is J or K
			             (dec_sym_1[0]   ^ dec_sym_1[1]) &	// Previous symbol is J or K
			             ~(samp_sym_0[1] ^ dec_sym_1[1]);	// Same symbol
		end

	always @(posedge clk)
		dec_valid_1 <= samp_valid_0;

	// EOP detect
	always @(posedge clk)
		if (samp_valid_0)
			case ({dec_eop_state_1[1:0], samp_sym_0})
				4'b0000: dec_eop_state_1 <= 3'b001;	// SE0
				4'b0100: dec_eop_state_1 <= 3'b010;	// SE0
				4'b1000: dec_eop_state_1 <= 3'b010;	// We should get J but maybe we tolerate >2 SE0 ?
				4'b1010: dec_eop_state_1 <= 3'b111; // J
				default: dec_eop_state_1 <= 3'b000;
			endcase

	assign dec_eop_1 = dec_eop_state_1[2];

	// Sync tracking
	always @(posedge clk)
		if (samp_valid_0)
		begin
			if (dec_sym_se_0)
				dec_sync_state_1 <= 4'b0000;
			else
				casez ({dec_sync_state_1[2:0], samp_sym_0[1]})
					4'b0000: dec_sync_state_1 <= 4'b0001;
					4'b0011: dec_sync_state_1 <= 4'b0010;
					4'b0100: dec_sync_state_1 <= 4'b0011;
					4'b0111: dec_sync_state_1 <= 4'b0100;
					4'b1000: dec_sync_state_1 <= 4'b0101;
					4'b1011: dec_sync_state_1 <= 4'b0110;
					4'b1100: dec_sync_state_1 <= 4'b0111;
					4'b1110: dec_sync_state_1 <= 4'b1001;
					4'b???0: dec_sync_state_1 <= 4'b0001;
					default: dec_sync_state_1 <= 4'b0000;
				endcase
		end

	assign dec_sync_1 = dec_sync_state_1[3];

	// Repeat tracking
	always @(posedge clk)
		if (samp_valid_0)
			if (dec_sym_same_0 == 1'b0)
				dec_rep_state_1 <= 4'b0000;
			else
				// This is basically a saturated increment with flag for >=6
				case (dec_rep_state_1[2:0])
					3'b000:  dec_rep_state_1 <= 4'b0001;
					3'b001:  dec_rep_state_1 <= 4'b0010;
					3'b010:  dec_rep_state_1 <= 4'b0011;
					3'b011:  dec_rep_state_1 <= 4'b0100;
					3'b100:  dec_rep_state_1 <= 4'b0101;
					3'b101:  dec_rep_state_1 <= 4'b0110;
					3'b110:  dec_rep_state_1 <= 4'b1111;
					3'b111:  dec_rep_state_1 <= 4'b1111;
					default: dec_rep_state_1 <= 4'bxxxx;
				endcase

	assign dec_bs_err_1  = dec_rep_state_1[3];
	assign dec_rep_1     = dec_rep_state_1[2:0];

	always @(posedge clk)
		if (samp_valid_0)
			dec_bs_skip_1 <= (dec_rep_state_1[2:0] == 3'b110);


	// Output
	// ------

	assign ll_sym     = dec_sym_1;
	assign ll_bit     = dec_bit_1;
	assign ll_valid   = dec_valid_1;
	assign ll_eop     = dec_eop_1;
	assign ll_sync    = dec_sync_1;
	assign ll_bs_skip = dec_bs_skip_1;
	assign ll_bs_err  = dec_bs_err_1;

endmodule // usb_rx_ll
