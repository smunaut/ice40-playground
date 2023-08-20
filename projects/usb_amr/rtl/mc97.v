/*
 * mc97.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module mc97 (
	// MC97 link
	output wire mc97_sdata_out,
	input  wire mc97_sdata_in,
	output wire mc97_sync,
	input  wire mc97_bitclk,

	// User interface - Samples
	input  wire [15:0] pcm_out_data,
	output reg         pcm_out_ack,

	output wire [15:0] pcm_in_data,
	output reg         pcm_in_stb,

	// User interface - GPIO (slot 12)
	output reg  [19:0] gpio_in,
	input  wire [19:0] gpio_out,
	input  wire        gpio_ena,

	// User interface - Registers
	input  wire [ 5:0] reg_addr,
	input  wire [15:0] reg_wdata,
	output wire [15:0] reg_rdata,
	output reg         reg_rerr,
	input  wire        reg_valid,
	input  wire        reg_we,
	output reg         reg_ack,

	// User interface - Misc
	input  wire        cfg_run,

	output wire        rfi,

	output wire        stat_codec_ready,
	output reg  [12:0] stat_slot_valid,
	output reg  [12:0] stat_slot_req,
	input  wire        stat_clr,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	genvar i;

	// Sequencer
	reg  [12:0] seq_wr_slot;
	wire [12:0] seq_rd_slot;

	// MC97 Frame control
	wire [15:0] fc_tag_out;
	reg  [15:0] fc_tag_in;		// Captured input slot 0
	reg  [19:0] fc_status_addr;	// Captured input slot 1

	wire [12:0] fc_slotvalid;	// Mapped "slot valid" value
	wire [12:0] fc_slotreq;		// Mapped "slot request" value

	// Command FSM
	localparam [1:0]
		CS_IDLE    = 0,
		CS_SUBMIT  = 1,
		CS_WAIT    = 2,
		CS_CAPTURE = 3;

	reg   [1:0] cmd_state;
	reg   [1:0] cmd_state_nxt;

	// PCM samples
	reg         pcm_out_frame;

	// GPIO
	reg         gpio_ena_frame;

	// Interface to Shifter Unit
	reg   [4:0] sui_bitcnt;		// user -> amr
	reg         sui_out_sync;	// user -> amr
	reg  [19:0] sui_out_data;	// user -> amr
	reg  [19:0] sui_in_data;	// amr -> user
	reg  [ 2:0] sui_flip;		// amr -> user
	reg         sui_ack;       	// user

	// Shift Unit
	reg  [3:0] su_rst;

	reg  [5:0] su_bitcnt;
	reg  [2:0] su_trig;
	reg [19:0] su_data;

	reg  [3:0] rst_amr_cnt;
	wire       clk_amr;
	wire       rst_amr;

	// IOs
	wire iob_sdata_in;
	wire iob_sdata_out;
	reg  iob_sync;


	// Sequencer
	// ---------

	always @(posedge clk or posedge rst)
		if (rst)
			seq_wr_slot <= 13'h0001;
		else if (sui_ack)
			seq_wr_slot <= { seq_wr_slot[11:0], seq_wr_slot[12] };

	assign seq_rd_slot = { seq_wr_slot[1:0], seq_wr_slot[12:2] };


	// MC97 Frame control (TAG / SLOTREQ)
	// ------------------

	// Prepare output TAG value
	assign fc_tag_out = {
		cfg_run,                           //    [15] Frame valid,
		(cmd_state == CS_SUBMIT),          //    [14] Slot 1    - Command Address
		(cmd_state == CS_SUBMIT) & reg_we, //    [13] Slot 2    - Command Data
		2'b00,                             // [12:11] Slot 3-4  - (n/a)
		pcm_out_frame,                     //    [10] Slot 5    - Modem Line 1 PCM
		6'd0,                              //   [9:4] Slot 6-11 - (n/a)
		gpio_ena_frame,                    //     [3] Slot 12   - GPIO
		1'b0,                              //     [2] Reserved
		2'b00                              //   [1:0] Codec ID (always primary here)
	};

	// Capture input TAG value
	always @(posedge clk)
		if (sui_ack & seq_rd_slot[0])
			fc_tag_in <= sui_in_data[15:0];

	// Capture input STATUS_ADDR (Slot 1)
	always @(posedge clk)
		if (sui_ack & seq_rd_slot[1])
			fc_status_addr <= sui_in_data[15:0];

	// Map those
	generate
		for (i=1; i<13; i=i+1)
			assign fc_slotvalid[i] = fc_tag_in[15-i];
	endgenerate

	assign fc_slotvalid[0] = 1'b0; // Slot 0 fixed to 0 (special)

	generate
		for (i=3; i<13; i=i+1)
			assign fc_slotreq[i] = fc_status_addr[14-i];
	endgenerate

	assign fc_slotreq[2:0] = 3'b000; // Slot 0...2 fixed to 0 (special)

	// User Side status
		// Codec ready flag
	assign stat_codec_ready = fc_tag_in[15];

		// Slot valid flags
	always @(posedge clk)
		if (rst)
			stat_slot_valid[12:1] <= 1'b0;
		else
			stat_slot_valid[12:1] <= (stat_slot_valid[12:1] | fc_slotvalid[12:1]) & {12{~stat_clr}};

	initial
		stat_slot_valid[0] = 1'b0; // Slot 0 fixed to 0 (special)

		// Slot request flags
	always @(posedge clk)
		if (rst)
			stat_slot_req[12:3] <= 0;
		else
			stat_slot_req[12:3] <= (stat_slot_req[12:3] | fc_slotreq[12:3]) & {10{~stat_clr}};

	initial
		stat_slot_req[2:0] = 3'b000; // Slot 0-2 fixed to 0 (special)


	// Command FSM
	// -----------

	// State register
	always @(posedge clk)
		if (rst)
			cmd_state <= CS_IDLE;
		else
			cmd_state <= cmd_state_nxt;

	// Next-State
	always @(*)
	begin
		// Default is no-change
		cmd_state_nxt = cmd_state;

		// Transistions
		case (cmd_state)
			CS_IDLE:
				// Start new access for frame beginning
				if (sui_ack & seq_wr_slot[12] & reg_valid)
					cmd_state_nxt = CS_SUBMIT;

			CS_SUBMIT:
				// Command has been sent in this frame
				if (sui_ack & seq_wr_slot[12])
					// If it was a write, we're done.
					// For reads, we need to wait for an answer
					cmd_state_nxt = reg_we ? CS_IDLE : CS_WAIT;

			CS_WAIT:
				// No matter what, we move onto capture at the next slot
				// But here we check if the read worked or not (see reg_rerr)
				if (sui_ack & seq_rd_slot[1])
					cmd_state_nxt = CS_CAPTURE;

			CS_CAPTURE:
				if (sui_ack)
					cmd_state_nxt = CS_IDLE;
		endcase
	end

	// Ack
	always @(posedge clk)
	begin
		// Default
		reg_ack <= 1'b0;

		// Write ack
		if ((cmd_state == CS_SUBMIT) & sui_ack & seq_wr_slot[12] & reg_we)
			reg_ack <= 1'b1;

		// Read ack
		if ((cmd_state == CS_CAPTURE) & sui_ack)
			reg_ack <= 1'b1;
	end

	// Read error ?
	always @(posedge clk)
		if ((cmd_state == CS_WAIT) & sui_ack & seq_rd_slot[1])
			reg_rerr <= (sui_in_data[18:13] != reg_addr) | (fc_slotvalid[2:1] != 2'b11);

	// Read data
	assign reg_rdata = sui_in_data[19:4];


	// PCM samples
	// -----------

	// Output
	always @(posedge clk)
		if (sui_ack & seq_wr_slot[12])
			pcm_out_frame <= ~fc_slotreq[5];

	always @(posedge clk)
		pcm_out_ack <= sui_ack & seq_wr_slot[5] & pcm_out_frame;

	// Input
	assign pcm_in_data = sui_in_data[19:4];

	always @(posedge clk)
		pcm_in_stb <= sui_ack & seq_rd_slot[5] & fc_slotvalid[5];


	// Ring Frequency Indicator
	// ------------------------

	mc97_rfi rfi_I (
		.pcm_data (pcm_in_data),
		.pcm_stb  (pcm_in_stb),
		.rfi      (rfi),
		.clk      (clk),
		.rst      (rst)
	);


	// GPIO (slot 12)
	// ----

	// Register enable status for the frame
	always @(posedge clk)
		if (sui_ack & seq_wr_slot[12])
			gpio_ena_frame <= gpio_ena;

	// Capture GPIO input
	always @(posedge clk)
		if (sui_ack & seq_rd_slot[12])
			gpio_in <= sui_in_data;


	// Shifter control
	// ---------------

	always @(posedge clk or posedge rst)
		if (rst) begin
			sui_bitcnt   <= 5'd0;
			sui_out_sync <= 1'b0;
			sui_out_data <= 20'h00000;
		end else if (sui_ack) begin
			sui_bitcnt   <= seq_wr_slot[0] ? 5'd14 : 5'd18;
			sui_out_sync <= seq_wr_slot[0];
			sui_out_data <= 20'h00000;

			(* parallel_case *)
			case (1'b1)
				seq_wr_slot[ 0]: sui_out_data <= { fc_tag_out, 4'h0 };
				seq_wr_slot[ 1]: sui_out_data <=  (cmd_state == CS_SUBMIT)           ? { ~reg_we, reg_addr, 13'h0000 } : 20'h00000;
				seq_wr_slot[ 2]: sui_out_data <= ((cmd_state == CS_SUBMIT) & reg_we) ? {         reg_wdata,     4'h0 } : 20'h00000;
				seq_wr_slot[ 5]: sui_out_data <= pcm_out_frame  ? { pcm_out_data, 4'h0 } : 20'h00000;
				seq_wr_slot[12]: sui_out_data <= gpio_ena_frame ? gpio_out : 20'h00000;
			endcase
		end


	// Shifter
	// -------

	// Clock input
	SB_GB_IO #(
		.PIN_TYPE(6'b 0000_01),
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) clk_gb_I (
		.PACKAGE_PIN          (mc97_bitclk),
		.GLOBAL_BUFFER_OUTPUT (clk_amr)
	);

	// Reset
	always @(posedge clk_amr or posedge rst)
		if (rst)
			rst_amr_cnt <= 4'hf;
		else
			rst_amr_cnt <= rst_amr_cnt + {4{rst_amr_cnt[3]}};

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_amr_cnt[3]),
		.GLOBAL_BUFFER_OUTPUT         (rst_amr)
	);

	// Bit Counter
	always @(posedge clk_amr or posedge rst_amr)
		if (rst_amr)
			su_bitcnt <= 6'h3f;
		else
			su_bitcnt <= su_bitcnt[5] ? (su_bitcnt + {6{su_bitcnt[5]}}) : { 1'b1, sui_bitcnt };

	always @(*)
		su_trig[0] = ~su_bitcnt[5];

	always @(posedge clk_amr)
		su_trig[2:1] <= su_trig[1:0];

	// Sync signal
	always @(posedge clk_amr)
		iob_sync <= su_trig[0] ? sui_out_sync : iob_sync;

	// Data shift register
	always @(posedge clk_amr)
		su_data <= su_trig[1] ? { sui_out_data } : { su_data[18:0], iob_sdata_in };

	assign iob_sdata_out = su_data[19];

	// Data in capture register
	always @(posedge clk_amr)
		if (su_trig[1])
			sui_in_data[19:1] <= { su_data[17:0], iob_sdata_in };

	always @(posedge clk_amr)
		if (su_trig[2])
			sui_in_data[0] <= iob_sdata_in;

	// Flip signal
	always @(posedge clk_amr)
		if (rst_amr)
			sui_flip[0] <= 1'b0;
		else
			sui_flip[0] <= sui_flip[0] ^ su_trig[2];

	always @(posedge clk)
	begin
		if (rst) begin
			sui_flip[2:1] <= 2'b00;
			sui_ack       <= 1'b0;
		end else begin
			sui_flip[2:1] <= sui_flip[1:0];
			sui_ack       <= sui_flip[2] ^ sui_flip[1];
		end
	end


	// IOBs
	// ----

	SB_IO #(
		.PIN_TYPE    (6'b0101_00),
		.PULLUP      (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_sdata_out_I (
		.PACKAGE_PIN (mc97_sdata_out),
		.OUTPUT_CLK  (clk_amr),
		.D_OUT_0     (iob_sdata_out)
	);

	SB_IO #(
		.PIN_TYPE    (6'b0000_00),
		.PULLUP      (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_sdata_in_I (
		.PACKAGE_PIN (mc97_sdata_in),
		.INPUT_CLK   (clk_amr),
		.D_IN_1      (iob_sdata_in)
	);

	SB_IO #(
		.PIN_TYPE    (6'b0101_00),
		.PULLUP      (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_sync_I (
		.PACKAGE_PIN (mc97_sync),
		.OUTPUT_CLK  (clk_amr),
		.D_OUT_0     (iob_sync)
	);

endmodule // mc97
