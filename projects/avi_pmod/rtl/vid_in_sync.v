/*
 * vid_in_sync.v
 *
 * vim: ts=4 sw=4
 *
 * Synchronizes to input signal.
 * Outputs a strobe along with double pixel data (32b) along
 * with sync information, including middle line info for line
 * doubling.
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_in_sync (
	// Raw video (at pixel clock rate)
	input  wire  [7:0] vi_data,

	// Output pixel
	output wire [31:0] vo_data,
	output wire        vo_valid,

	// Decoded BT656 sync
	output reg         vo_sync,
	output reg   [2:0] vo_fvh,	// { F, V, H }
	output reg         vo_err,

	// Mid line
	output wire        vo_mid,

	// Clock / Reset
	input wire         clk,
	input wire         rst
);

	// Signals
	// -------

	// Data shift register
	reg  [31:0] data_sr;

	// Sync marker
	reg         sync_mark;

	// Protection bit
	reg   [3:0] sync_p;
	wire        sync_p_err;

	reg   [3:0] stb_cnt;


	// BT656
	// -----

	// Shift register
	always @(posedge clk)
		data_sr <= { data_sr[24:0], vi_data };

	// Sync marker detection
	always @(posedge clk)
		sync_mark <= ({data_sr[15:0], vi_data} == 24'hff0000);

	// Protection bits
	always @(*)
		case (vi_data[6:4])
			3'b000:  sync_p = 4'b0000;
			3'b001:  sync_p = 4'b1101;
			3'b010:  sync_p = 4'b1011;
			3'b011:  sync_p = 4'b0110;
			3'b100:  sync_p = 4'b0111;
			3'b101:  sync_p = 4'b1010;
			3'b110:  sync_p = 4'b1100;
			3'b111:  sync_p = 4'b0001;
			default: sync_p = 4'bxxxx;
		endcase

	assign sync_p_err = ~vi_data[7] | ((vi_data[3:0] != sync_p));

	// Strobe
	always @(posedge clk)
		if (sync_mark)
			stb_cnt <= 3'b100;
		else
			stb_cnt <= { 1'b0, stb_cnt[1:0] } + 1;

	// Output
	assign vo_data  = data_sr;
	assign vo_valid = stb_cnt[2];

	always @(posedge clk)
	begin
		vo_sync <= sync_mark;
		vo_fvh  <= vi_data[6:4] & {3{sync_mark}};
		vo_err  <= sync_mark & sync_p_err;
	end

endmodule // vid_in_sync
