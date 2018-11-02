// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		hypot.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ sqrt.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Approximate the Euclidean length of a vector.
// Latency:	1 clocktick + latency of module sqrt
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef HYPOT_SV
`define HYPOT_SV

`include "sqrt.sv"

module hypot #(
	parameter WIDTH														// input bus width
)(
	input		wire									clk,					// clock signal
	input		wire		signed	[WIDTH-1:0]	sink_x,				// sink, x							Q<WIDTH>.0
	input		wire		signed	[WIDTH-1:0]	sink_y,				// sink, y							Q<WIDTH>.0
	output	wire		unsigned	[WIDTH-1:0]	source				// source, hypot(x,y)			UQ<WIDTH>.0
);

// registers and such
bit unsigned	[2*WIDTH-2:0]				s2;						// x**2 + y**2						UQ<2*WIDTH-1>.0

// the  code
always_ff @(posedge clk)
begin
	s2					<= sink_x**2+ sink_y**2;
end

sqrt #(
	.WIDTH					(2*WIDTH - 1)
) sqr (
	.clk						(clk),
	.sink						(s2),
	.source					(source)
);

endmodule

`endif
