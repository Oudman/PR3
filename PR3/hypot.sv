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
// Type:		function
// Purpose:	Approximate the Euclidean length of a vector of two ints
//				Testing has shown a maximum deviation of 1 for results < 100 and a
// 			maximum deviation of 1% for results > 100
// -----------------------------------------------------------------------------
// Input:	x, y
// Output:	hypot
// -----------------------------------------------------------------------------

`ifndef HYPOT_SV
`define HYPOT_SV

`include "sqrt.sv"

// hypot approximation
function automatic int hypot(int x, y);
	hypot = sqrt(x*x + y*y);
endfunction

`endif
