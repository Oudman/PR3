// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ arctan_lim.sv
// -----------------------------------------------------------------------------
// Type:		function
// Purpose:	Approximate the atan2 of two ints, result in degrees
//				Testing has shown a maximum deviation of 0.23deg
// -----------------------------------------------------------------------------
// Input:	y, x
// Output:	atan2
// -----------------------------------------------------------------------------
// Fixed point notation, marked FP, is used in the following manner:
// - two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

`ifndef ATAN2_SV
`define ATAN2_SV

`include "arctan_lim.sv"

// atan2 approximation (out: FP)
function int atan2(int y, x);
	if (x == 0)
		atan2 = (y >= 0) ? 23040 : -23040;
	else if (y == 0)
		atan2 = (x >= 0) ? 0 : 46080;
	else if (x > 0 && y > 0 && x > y)
		atan2 =  arctan_lim( (y <<< 8) / x);
	else if (x > 0 && y > 0 && x < y)
		atan2 = -arctan_lim( (x <<< 8) / y) + 23040;
	else if (x > 0 && y < 0 && x > -y)
		atan2 = -arctan_lim(-(y <<< 8) / x);
	else if (x > 0 && y < 0 && x < -y)
		atan2 =  arctan_lim(-(x <<< 8) / y) - 23040;
	else if (x < 0 && y > 0 && -x > y)
		atan2 = -arctan_lim(-(y <<< 8) / x) + 46080;
	else if (x < 0 && y > 0 && -x < y)
		atan2 =  arctan_lim(-(x <<< 8) / y) + 23040;
	else if (x < 0 && y < 0 && -x > -y)
		atan2 =  arctan_lim( (y <<< 8) / x) - 46080;
	else if (x < 0 && y < 0 && -x < -y)
		atan2 = -arctan_lim( (x <<< 8) / y) - 23040;
endfunction

`endif
