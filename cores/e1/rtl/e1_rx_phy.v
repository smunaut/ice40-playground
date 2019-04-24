/*
 * e1_rx_phy.v
 *
 * vim: ts=4 sw=4
 *
 * E1 RX IOB instances
 *
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
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

module e1_rx_phy (
	// IO pads
	input  wire pad_rx_hi_p,
	input  wire pad_rx_hi_n,	// Unused in ice40
	input  wire pad_rx_lo_p,
	input  wire pad_rx_lo_n,	// Unused in ice40

	// Output
	output wire rx_hi,
	output wire rx_lo,

	// Common
	input  wire clk,
	input  wire rst
);

    SB_IO #(
        .PIN_TYPE(6'b000000),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVDS_INPUT")
    ) rx_hi_I (
        .PACKAGE_PIN(pad_rx_hi_p),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b1),
        .INPUT_CLK(clk),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(1'b0),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b0),
        .D_IN_0(rx_hi),
        .D_IN_1()
    );

    SB_IO #(
        .PIN_TYPE(6'b000000),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVDS_INPUT")
    ) rx_lo_I (
        .PACKAGE_PIN(pad_rx_lo_p),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b1),
        .INPUT_CLK(clk),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(1'b0),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b0),
        .D_IN_0(rx_lo),
        .D_IN_1()
    );

endmodule // e1_rx_phy
