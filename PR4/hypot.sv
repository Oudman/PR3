// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		hypot.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ ALTSQRT (Intel IP)
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Approximate the Euclidean length of a vector.
// Latency:	DELAY clockticks
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

module hypot #(
	parameter WIDTH,														// input bus width
	parameter DELAY														// latency in clocktics
)(
	input		wire									clk,					// clock signal
	input		wire									reset,				// reset
	input		wire		signed	[WIDTH-1:0]	sink_x,				// sink, x							Q<WIDTH>.0
	input		wire		signed	[WIDTH-1:0]	sink_y,				// sink, y							Q<WIDTH>.0
	output	wire		unsigned	[WIDTH-1:0]	source				// source, hypot(x,y)			UQ<WIDTH>.0
);

localparam MWIDTH = 2*WIDTH-1;

/*----------------------------------------------------------------------------*/
/*- registers ----------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
bit unsigned	[MWIDTH-1:0]				s2;						// x**2 + y**2						UQ<2*WIDTH-1>.0

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always_ff @(posedge clk)
begin
	if (reset)
	begin																		// synchronous reset
		s2					<= {MWIDTH{1'b0}};
	end
	else
	begin																		// stage I
		s2					<= sink_x**2+ sink_y**2;
	end
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// square root module
altsqrt #(
	.pipeline				(DELAY-1),
	.q_port_width			(WIDTH),
	.r_port_width			(0),
	.width					(MWIDTH)
) sqrt (
	.clk						(clk),
	.aclr						(reset),
	.ena						(),
	.q							(source),
	.radical					(s2),
	.remainder				()
);

endmodule

`endif
