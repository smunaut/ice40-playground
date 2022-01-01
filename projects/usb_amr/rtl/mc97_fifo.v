/*
 * mc97_fifo.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module mc97_fifo (
	// Write
    input  wire [15:0] wr_data,
    input  wire        wr_ena,
    output wire        wr_full,

	// Read
    output wire [15:0] rd_data,
    input  wire        rd_ena,
    output wire        rd_empty,

	// Control
	output reg  [ 8:0] ctl_lvl,
	input  wire        ctl_flush,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	(* keep *) reg [8:0] mod;

	wire wr_ena_i;
	wire rd_ena_i;


	// FIFO Instance
	// -------------

	fifo_sync_ram #(
		.DEPTH(256),
		.WIDTH(16)
	) fifo_I (
		.wr_data  (wr_data),
		.wr_ena   (wr_ena_i),
		.wr_full  (wr_full),
		.rd_data  (rd_data),
		.rd_ena   (rd_ena_i),
		.rd_empty (rd_empty),
		.clk      (clk),
		.rst      (rst)
	);


	// Control
	// -------

	assign wr_ena_i = ~wr_full  &  wr_ena ;
	assign rd_ena_i = ~rd_empty & (rd_ena | ctl_flush);


	// Level
	// -----

	// Level counter
	always @(posedge clk)
		if (rst)
			ctl_lvl <= 0;
		else
			ctl_lvl <= ctl_lvl + mod;

	assign mod = { {8{rd_ena_i & ~wr_ena_i}}, rd_ena_i ^ wr_ena_i };

endmodule // mc97_fifo
