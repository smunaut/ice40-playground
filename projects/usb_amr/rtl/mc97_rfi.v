/*
 * mc97_rfi.v
 *
 * Detects 10-100 Hz ringing foR ring indication
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module mc97_rfi #(
	parameter integer CLK_FREQ = 24_000_000,
	parameter integer F_MIN = 10,	/* Hz */
	parameter integer F_MAX = 100	/* Hz */
)(
	// PCM tap
	input  wire [15:0] pcm_data,
	input  wire        pcm_stb,

	// Ring Frequency Indication
	output reg  rfi,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam integer CYC_MIN = CLK_FREQ / F_MAX;
	localparam integer CYC_MAX = CLK_FREQ / F_MIN;

	localparam integer WMIN = $clog2(CYC_MIN);
	localparam integer WMAX = $clog2(CYC_MAX);

	localparam [WMIN-1:0] K_MIN = CYC_MIN;
	localparam [WMAX-1:0] K_MAX = CYC_MAX;


	// Signals
	// -------

	// Rising edge detector
	wire       rid_is_neg;
	wire       rid_is_pos;
	reg  [2:0] rid_cnt;
	wire       rid_cnt_max;
	reg        rid_armed;
	reg        rid_stb;

	// Interval counter
	reg [WMIN:0] ic_min;
	reg [WMAX:0] ic_max;
	reg          ic_max_msb_r;
	reg          ic_armed;
	reg          ic_stb_ok;
	reg          ic_stb_err;

	// Validation
	reg [1:0] vs_cnt_err;
	reg [1:0] vs_cnt_ok;


	// Detect "Rising edges"
	// ---------------------

		// Anything going for < -16384 to >= 16384
		// in less than 8 samples

	assign rid_is_neg = (pcm_data[15:14] == 2'b10);
	assign rid_is_pos = (pcm_data[15:14] == 2'b01);

	always @(posedge clk or posedge rst)
		if (rst)
			rid_cnt <= 0;
		else if (pcm_stb)
			casez ({rid_is_neg, rid_cnt})
			4'b1zzz: rid_cnt <= 3'b000;
			4'b0000: rid_cnt <= 3'b001;
			4'b0001: rid_cnt <= 3'b010;
			4'b0010: rid_cnt <= 3'b011;
			4'b0011: rid_cnt <= 3'b100;
			4'b0100: rid_cnt <= 3'b101;
			4'b0101: rid_cnt <= 3'b110;
			4'b0110: rid_cnt <= 3'b111;
			4'b0111: rid_cnt <= 3'b111;
			default: rid_cnt <= 3'bxxx;
			endcase

	assign rid_cnt_max = (rid_cnt == 3'b111);

	always @(posedge clk or posedge rst)
		if (rst)
			rid_armed <= 0;
		else if (pcm_stb)
			rid_armed <= (rid_armed | rid_is_neg) & ~(rid_cnt_max | rid_is_pos);

	always @(posedge clk)
		rid_stb <= rid_armed & rid_is_pos & ~rid_cnt_max & pcm_stb;


	// Interval counter
	// ----------------

		// Measure interval between rising edge and detects :
		// - underflow : Rising edge less than 10 ms appart
		// - overflow  : No rising edge for more than 100 ms
		// - ok        : Rising edge occured withing expected interval

	always @(posedge clk)
		if (rid_stb) begin
			ic_min <= { 1'b1, K_MIN };
			ic_max <= { 1'b1, K_MAX };
		end else begin
			ic_min <= ic_min - ic_min[WMIN];
			ic_max <= ic_max[WMAX] ? (ic_max - 1) : { 1'b1, K_MAX }; // Auto-repeat if no edge
		end

	always @(posedge clk)
		ic_max_msb_r <= ic_max[WMAX];

	always @(posedge clk)
		if (rst)
			ic_armed <= 1'b0;
		else
			ic_armed <= (ic_armed & ic_max[WMAX]) | rid_stb;

	always @(posedge clk)
	begin
		ic_stb_ok  <=  ic_armed & rid_stb & ~ic_min[WMIN] & ic_max[WMAX];
		ic_stb_err <= (ic_armed & rid_stb &  ic_min[WMIN]) | (ic_max_msb_r & ~ic_max[WMAX]);
	end


	// Validation
	// ----------

		// Assert   on 4 succesive valid
		// Deassert on 4 succesive invalid ones

	always @(posedge clk)
		if (rst)
			vs_cnt_err <= 0;
		else
			vs_cnt_err <= (vs_cnt_err + ic_stb_err) & {2{~ic_stb_ok}};

	always @(posedge clk)
		if (rst)
			vs_cnt_ok <= 0;
		else
			vs_cnt_ok <= (vs_cnt_ok + ic_stb_ok) & {2{~ic_stb_err}};

	always @(posedge clk)
		if (rst)
			rfi <= 0;
		else
			rfi <= (rfi & ~&vs_cnt_err) | &vs_cnt_ok;

endmodule // mc97_rfi
