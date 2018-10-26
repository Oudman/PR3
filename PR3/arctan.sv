// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		arctan.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ arctan_lim.sv
// -----------------------------------------------------------------------------
// Type:		function
// Purpose:	Approximate the arctan of a fixed point int, result in degrees
// -----------------------------------------------------------------------------
// Input:	z
// Output:	arctan
// -----------------------------------------------------------------------------
// Fixed point notation, marked FP, is used in the following manner:
// - two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

`ifndef ARCTAN_SV
`define ARCTAN_SV

`include "arctan_lim.sv"

// arctan approximation (in: FP; out: FP)
function automatic int arctan(int z);
	if (z >= 0)
	begin
		if (z > 256)
			arctan = 23040 - arctan_lim(65536/z);
		else
			arctan = arctan_lim(z);
	end
	else
	begin
		if (z < -256)
			arctan = arctan_lim(65536/-z) - 23040;
		else
			arctan = -arctan_lim(-z);
	end
endfunction

`endif
