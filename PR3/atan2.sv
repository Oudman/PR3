// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ arctan.sv
// -----------------------------------------------------------------------------
// Type:		function
// Purpose:	Approximate the atan2 of two ints
// -----------------------------------------------------------------------------
// Input:	z
// Output:	atan2
// -----------------------------------------------------------------------------
// Fixed point notation, marked FP, is used in the following manner:
// - two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

// atan2 approximation (in: non-FP; out: FP)
// using https://en.wikipedia.org/wiki/Atan2
function int atan2(int y, x);
	if (x == 0)
		atan2 = (y >= 0) ? 23040 : -23040;
	else
	begin
		automatic int z = (y <<< 8) / x; // FP
		if (x > 0)
			atan2 = arctan(z);
		else if (y >= 0)
			atan2 = arctan(z) + 46080;
		else
			atan2 = arctan(z) - 46080;
	end
endfunction