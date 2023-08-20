/*
 * mc97_rfi_tb.v
 *
 * vim: ts=4 sw=4
 *
 */

`default_nettype none

module mc97_rfi_tb;

	localparam integer GEN_FREQ = 15; /* Hz */

	// Signals
	// -------

	// Tick
	reg  [15:0] tick_cnt;
	wire        tick;

	// Tone Generation
	real phase;
	real phase_inc = 6.28 * GEN_FREQ / 8000;
	real tmp;

	// DUT connections
	reg  [15:0] pcm_data = 0;
	wire        pcm_stb;

	wire        rfi;

	// Clock reset
	reg clk = 1'b0;
	reg rst = 1'b1;


	// Setup recording
	// ---------------

	initial begin
		$dumpfile("mc97_rfi_tb.vcd");
		$dumpvars(0,mc97_rfi_tb);
		# 600000000 $finish;
	end

	always #500 clk <= !clk; // 1 MHz

	initial begin
		#2000 rst = 0;
	end


	// Generate tone
	// -------------

	// Tick at 8000 Hz
	always @(posedge clk)
		if (rst)
			tick_cnt <= 0;
		else
			tick_cnt <= tick ? 16'd123 : (tick_cnt - 1);

	assign tick = tick_cnt[15];

	// Tone
	always @(posedge clk)
		if (rst)
			phase <= 0.0;
		else if (tick)
			phase <= phase + phase_inc;

	always @(*)
	begin
		tmp = $cos(phase) * (1 << 24) / GEN_FREQ;

		if (tmp > 32767)
			pcm_data = 32767;
		else if (tmp < -32768)
			pcm_data = -32768;
		else
			pcm_data = tmp;
	end

	assign pcm_stb = tick;


	// DUT
	// ---

	mc97_rfi #(
		.CLK_FREQ(1_000_000),
		.F_MIN(10),
		.F_MAX(100)
	) rfi_I (
		.pcm_data (pcm_data),
		.pcm_stb  (pcm_stb),
		.rfi      (rfi),
		.clk      (clk),
		.rst      (rst)
	);

endmodule // mc97_rfi_tb
