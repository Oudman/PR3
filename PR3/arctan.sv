// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		arctan.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		function
// Purpose:	Approximate the arctan of a fixed point int, result in degrees
//				Testing has shown a maximum deviation of 0.36deg
// -----------------------------------------------------------------------------
// Input:	z
// Output:	arctan
// -----------------------------------------------------------------------------
// Fixed point notation, marked FP, is used in the following manner:
// - two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

// arctan approximation (max 0.22deg deviation) (in: FP; out: FP)
function automatic int arctan(int z);
	if (z >= 0)
	begin
		if (z > 256)
			arctan = 23040 - arctan_h(65536/z);
		else
			arctan = arctan_h(z);
	end
	else
	begin
		if (z < -256)
			arctan = arctan_h(65536/-z) - 23040;
		else
			arctan = -arctan_h(-z);
	end
endfunction

// arctan approximation (max 0.22deg deviation in range z=[0,1]) (in: FP; out: FP)
// using https://math.stackexchange.com/questions/1098487/atan2-faster-approximation
function int arctan_h(shortint z);
	arctan_h = (z * (2949120 - 4009 * (z - 256))) >>> 16;
endfunction