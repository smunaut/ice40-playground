/*
 * mc97_tb.v
 *
 * vim: ts=4 sw=4
 *
 */

`default_nettype none

module mc97_tb;

	// Signals
	// -------

	wire mc97_sdata_out;
	wire mc97_sdata_in;
	wire mc97_sync;
	reg  mc97_bitclk = 1'b0;

	wire [15:0] pcm_out_data;
	wire        pcm_out_ack;
	wire [15:0] pcm_in_data;
	wire        pcm_in_stb;

	wire [19:0] gpio_in;
	wire [19:0] gpio_out;
	wire        gpio_ena;

	wire [ 5:0] reg_addr;
	wire [15:0] reg_wdata;
	wire [15:0] reg_rdata;
	wire        reg_rerr;
	wire        reg_valid;
	wire        reg_we;
	wire        reg_ack;

	wire        cfg_run;

	wire        stat_codec_ready;
	wire [12:0] stat_slot_valid;
	wire [12:0] stat_slot_req;
	wire        stat_clr;

	reg clk = 1'b0;
	reg rst = 1'b1;


	// Setup recording
	// ---------------

	initial begin
		$dumpfile("mc97_tb.vcd");
		$dumpvars(0,mc97_tb);
		# 2000000 $finish;
	end

	always #29.833 clk <= !clk; // 24 MHz
	always #40.690 mc97_bitclk <= !mc97_bitclk; // 12.288 MHz

	initial begin
		#200 rst = 0;
	end


	// DUT
	// ---


	mc97 dut_I (
		.mc97_sdata_out  (mc97_sdata_out),
		.mc97_sdata_in   (mc97_sdata_in),
		.mc97_sync       (mc97_sync),
		.mc97_bitclk     (mc97_bitclk),
		.pcm_out_data    (pcm_out_data),
		.pcm_out_ack     (pcm_out_ack),
		.pcm_in_data     (pcm_in_data),
		.pcm_in_stb      (pcm_in_stb),
		.gpio_in         (gpio_in),
		.gpio_out        (gpio_out),
		.gpio_ena        (gpio_ena),
		.reg_addr        (reg_addr),
		.reg_wdata       (reg_wdata),
		.reg_rdata       (reg_rdata),
		.reg_rerr        (reg_rerr),
		.reg_valid       (reg_valid),
		.reg_we          (reg_we),
		.reg_ack         (reg_ack),
		.cfg_run         (cfg_run),
		.stat_codec_ready(stat_codec_ready),
		.stat_slot_valid (stat_slot_valid),
		.stat_slot_req   (stat_slot_req),
		.stat_clr        (stat_clr),
		.clk             (clk),
		.rst             (rst)
	);

	assign mc97_sdata_in = mc97_sdata_out;

	assign pcm_out_data = 16'hcafe;

	assign gpio_ena = 1'b1;
	assign gpio_out = 20'hb00b5;

	assign reg_addr = 5'h1e;
	assign reg_wdata = 16'hbabe;
	assign reg_we = 1'b1;
	assign reg_valid = 1'b1;

	assign cfg_run = 1'b1;
	assign stat_clr = 1'b0;

endmodule // mc97_tb
