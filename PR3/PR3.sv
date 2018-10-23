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
// Fixed point notation, marked FP, is used in the following manner:
// - 32 bit two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

module PR3 #(
	parameter DATA_WIDTH = 14											// number of input bits per antenna
)(
	input		wire							clk,							// 50.0MHz
	input		wire							reset,						// synchronous reset
	input		wire	[DATA_WIDTH-1:0]	data1,						//	connected to antenna #1
	input		wire	[DATA_WIDTH-1:0]	data2,						//	connected to antenna #2
	input		wire	[DATA_WIDTH-1:0]	data3							//	connected to antenna #3
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