// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		sqrt_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ sqrt.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of sqrt.sv
// -----------------------------------------------------------------------------

`ifndef SQRT_TB_SV
`define SQRT_TB_SV

`include "sqrt.sv"

`timescale 1ns/100ps

module sqrt_tb();

// Declare inputs as regs and outputs as wires
int		s2 = 0;
int		s_approx;
real		s_exact;
real		diff_abs;
real		diff_rel;
bit		clk = 1;

// clock generator(s)
always #(25ns) clk++;

// counter
always @(posedge clk)
begin
	s2 <= s2 + 1;
end

assign s_approx = sqrt(s2);
assign s_exact = $sqrt(s2);
assign diff_abs = s_approx - s_exact;
assign diff_rel = diff_abs / s_exact;

initial
begin
	#(5ms) $stop(2);
end

endmodule

`endif
