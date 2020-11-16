`default_nettype none

module sram_1rw1r_32_256_8_sky130 (
	// Port 0: RW
	input  wire        clk0,
	input  wire        csb0,
	input  wire        web0,
	input  wire  [3:0] wmask0,	// 1=write, 0=do not write
	input  wire  [7:0] addr0,
	input  wire [31:0] din0,
	output wire [31:0] dout0,

	// Port 1: R
	input  wire        clk1,
	input  wire        csb1,
	input  wire  [7:0] addr1,
	output wire [31:0] dout1
);

	wire [10:0] ram_addr0;
	wire [10:0] ram_addr1;
	wire        we, re0, re1;
	wire [31:0] mask;


	assign ram_addr0 = { 3'b000, addr0 };
	assign ram_addr1 = { 3'b000, addr1 };

	assign re0 = ~csb0;
	assign re1 = ~csb1;

	assign we = ~csb0 & ~web0;
	assign mask = {
		{ 8{ ~wmask0[3] } },
		{ 8{ ~wmask0[2] } },
		{ 8{ ~wmask0[1] } },
		{ 8{ ~wmask0[0] } }
	};


	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ram0_hi_I (
		.RDATA (dout0[31:16]),
		.RCLK  (clk0),
		.RCLKE (re0),
		.RE    (1'b1),
		.RADDR (ram_addr0),
		.WCLK  (clk0),
		.WCLKE (we),
		.WE    (1'b1),
		.WADDR (ram_addr0),
		.MASK  (mask[31:16]),	// 0=write, 1=do not write
		.WDATA (din0[31:16])
	);

	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ram1_hi_I (
		.RDATA (dout1[31:16]),
		.RCLK  (clk1),
		.RCLKE (re1),
		.RE    (1'b1),
		.RADDR (ram_addr1),
		.WCLK  (clk0),
		.WCLKE (we),
		.WE    (1'b1),
		.WADDR (ram_addr0),
		.MASK  (mask[31:16]),	// 0=write, 1=do not write
		.WDATA (din0[31:16])
	);

	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ram0_lo_I (
		.RDATA (dout0[15:0]),
		.RCLK  (clk0),
		.RCLKE (re0),
		.RE    (1'b1),
		.RADDR (ram_addr0),
		.WCLK  (clk0),
		.WCLKE (we),
		.WE    (1'b1),
		.WADDR (ram_addr0),
		.MASK  (mask[15:0]),	// 0=write, 1=do not write
		.WDATA (din0[15:0])
	);

	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ram1_lo_I (
		.RDATA (dout1[15:0]),
		.RCLK  (clk1),
		.RCLKE (re1),
		.RE    (1'b1),
		.RADDR (ram_addr1),
		.WCLK  (clk0),
		.WCLKE (we),
		.WE    (1'b1),
		.WADDR (ram_addr0),
		.MASK  (mask[15:0]),	// 0=write, 1=do not write
		.WDATA (din0[15:0])
	);

endmodule // sram_1rw1r_32_256_8_sky130
