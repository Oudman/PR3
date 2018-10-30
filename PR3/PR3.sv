// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		PR3.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ pll.v
//  ~ phase_extract.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	phase extraction from three data signals
// -----------------------------------------------------------------------------
// Control:	clk, reset
// Sink:		data1, data2, data3
// Source:	-
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

module PR3 #(
	parameter DATA_WIDTH = 14											// number of input bits per antenna
)(
	input		wire							clk,							// 50.0MHz
	input		wire							reset,						// synchronous reset
	input		wire	[DATA_WIDTH-1:0]	data1,						//	antenna #1 data bus		(Q<DATA_WIDTH>.0)
	input		wire	[DATA_WIDTH-1:0]	data2,						//	antenna #2 data bus		(Q<DATA_WIDTH>.0)
	input		wire	[DATA_WIDTH-1:0]	data3							//	antenna #3 data bus		(Q<DATA_WIDTH>.0)
);

// wires
wire clk20;

// pll module to generate a 20.48MHz clock signal
pll pll (
	.refclk					(clk),
	.rst						(reset),
	.outclk_0 				(clk20)
);

// phase extraction on antenna #1
phase_extract #(
	.SINK_WIDTH				(DATA_WIDTH),
	.FFT_DEPTH				(11),
	.RUNS						(3)
) pe1 (
	.clk						(clk),
	.clk20					(clk20),
	.sink						(data1)
);

endmodule