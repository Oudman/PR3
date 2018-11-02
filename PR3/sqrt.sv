// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		sqrt.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Approximate the square root of a given longint. Testing has shown
//				that output is correct within 0.05% + 0.5 deviation. Note that the
//				output bus width is one	bit wider than half of the input data bus.
// Latency:	4 clockticks
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef SQRT_SV
`define SQRT_SV

module sqrt #(
	parameter WIDTH														// input bus data width
)(
	input		wire									clk,					// clock signal
	input		wire									reset,				// synchronous reset
	input		wire			[WIDTH-1:0]			sink,					// sink								UQ<WIDTH>.0
	output	bit			[WIDTH/2:0]			source				// source (unsigned!)			UQ<WIDTH/2+1>.0
);

/*----------------------------------------------------------------------------*/
/*- registers ----------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
bit	[WIDTH-1:0]						s[0:3];							//	input								UQ<WIDTH>.0
bit	[WIDTH/2+1:0]					sqrt[0:3];						// output WIP						UQ<WIDTH/2+2>.0

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always_ff @(posedge clk)
begin
	if (reset)																// reset all
	begin
		s					<= '{4{0}};
		sqrt				<= '{4{0}};
		source			<= 0;
	end
	else																		// approximate sqrt
	begin
		begin																	// stage I
			for (byte i = 0; i < WIDTH/2; i++)
				sqrt[0][i]		<= sink[2*i] || sink[2*i+1];
			s[0]				<= sink;
		end
		begin																	// stage II
			s[1]				<= (s[0] > 1) ? s[0] - 1 : s[0];
			sqrt[1]			<= (1 + sqrt[0] + s[0] / sqrt[0]) / 2;
		end
		begin																	// stage III
			s[2]				<= s[1];
			sqrt[2]			<= (1 + sqrt[1] + s[1] / sqrt[1]) / 2;
		end
		begin																	// stage IV
			source			<= (1 + sqrt[2] + s[2] / sqrt[2]) / 2;
		end
	end
end

endmodule

`endif
