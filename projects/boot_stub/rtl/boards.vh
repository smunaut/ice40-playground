/*
 * boards.vh
 *
 * vim: ts=4 sw=4 syntax=verilog
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`ifdef BOARD_BITSY_V0
	// 1bitsquared iCEbreaker bitsy prototypes (v0.x)
	`define HAS_USB
	`define HAS_LEDS
	`define HAS_RGB
	`define RGB_DIM 3
	`define RGB_MAP 12'h201		// 41=Blue, 40=Red, 39=Green
`elsif BOARD_BITSY_V1
	// 1bitsquared iCEbreaker bitsy prod (v1.x)
	`define HAS_USB
	`define HAS_LEDS
	`define HAS_RGB
	`define RGB_DIM 3
	`define RGB_MAP 12'h210		// 41=Blue, 40=Green, 39=Red
`elsif BOARD_ICEBREAKER
	// 1bitsquare iCEbreaker
	`define HAS_USB
	`define HAS_LEDS
	`define HAS_RGB
	`define RGB_DIM 3
	`define RGB_MAP 12'h012		// 41=Red, 40=Green, 39=Blue
//	`define RGB_MAP 12'h120		// 41=Green, 40=Blue, 39=Red (Hacked v1.0b)
`elsif BOARD_ICEPICK
	// iCEpick
	`define HAS_RGB
	`define HAS_USB
	`define RGB_MAP 12'h012		// 41=Red, 40=Green, 39=Blue
//	`define RGB_MAP 12'h210		// 41=Blue, 40=Green, 39=Red (Alt RGB LED)
`elsif BOARD_ICE1USB
	// icE1usb
	`define HAS_USB
	`define HAS_RGB
	`define RGB_MAP 12'h012		// 41=Red, 40=Green, 39=Blue
`elsif BOARD_E1TRACER
	// osmocom E1 tracer
	`define HAS_USB
	`define HAS_RGB
	`define RGB_MAP 12'h012		// 41=Red, 40=Green, 39=Blue
`endif

// Defaults
`ifndef RGB_CURRENT_MODE
`define RGB_CURRENT_MODE "0b1"
`endif

`ifndef RGB0_CURRENT
`define RGB0_CURRENT "0b000001"
`endif

`ifndef RGB1_CURRENT
`define RGB1_CURRENT "0b000001"
`endif

`ifndef RGB2_CURRENT
`define RGB2_CURRENT "0b000001"
`endif

`ifndef RGB_MAP
// [11:8] - Color of RGB2 / pin 41
// [ 7:0] - Color of RGB1 / pin 40
// [ 3:0] - Color of RGB0 / pin 39
//          0=Red 1=Green 2=Blue
`define RGB_MAP 12'h210		// 41=Blue, 40=Green, 39=Red
`endif
