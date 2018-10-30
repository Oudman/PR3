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

`ifndef SQRT_M_TB_SV
`define SQRT_M_TB_SV

`include "sqrtM.sv"

`timescale 1ns/100ps

module sqrt_m_tb();

localparam LAT = 4;

// Declare inputs as regs and outputs as wires
bit	[23:0]	s2 = 0;
wire 	[12:0]	s_approx;
real				s_exact;
real				diff_abs;
real				diff_rel;
bit				clk = 1;
int				correct = 0, wrong = 0;

// clock generator(s)
always #(5ns) clk++;

// counter
always @(posedge clk)
begin
	s2 <= s2 + 1;
	if (-0.5 <= diff_abs && diff_abs <= 0.5)
		correct++;
	else
		wrong++;
end

assign s_exact = (s2 > LAT) ? $sqrt(s2-LAT) : 0;
assign diff_abs = (s2 > LAT) ? s_approx - s_exact : 0;
assign diff_rel = (s2 > LAT) ? diff_abs / s_exact : 0;

initial
begin
	#(700us) $stop(2);
end

sqrt #(
	.WIDTH					(64)
) sqr (
	.clk						(clk),
	.sink						(s2),
	.source					(s_approx)
);

endmodule

`endif
