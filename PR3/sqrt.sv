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
// Type:		function
// Purpose:	Approximate the square root of a given longint
//				Testing has shown a maximum deviation of 1 for numbers < 10000 and a
// 			maximum deviation of 1% for numbers > 10000
// -----------------------------------------------------------------------------
// Input:	s
// Output:	sqrt
// -----------------------------------------------------------------------------

`ifndef SQRT_SV
`define SQRT_SV

// sqrt approximation (max 1% deviation, excluding rounding errors)
function int sqrt(longint s);
	if (s < 2)
		sqrt = s;
	else
	begin
		sqrt = sqrt_h(s);
		sqrt = (sqrt + s / sqrt) / 2; // max 15% deviation
		sqrt = (sqrt + s / sqrt) / 2; // max 1% deviation
	end
endfunction

// sqrt approximation (max -42.3% and +73.2% deviation)
function automatic int sqrt_h(const ref longint s);
	for (byte i = 0; i < 32; i++)
		sqrt_h[i] = s[2*i+1] || s[2*i];
endfunction

`endif
