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
// -----------------------------------------------------------------------------
// Input:	x, y
// Output:	hypot
// -----------------------------------------------------------------------------

// hypot approximation
function int hypot(int x, y);
	hypot = sqrt(x*x + y*y);
endfunction