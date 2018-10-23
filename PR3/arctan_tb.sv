// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		arctan_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of arctan.sv
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

module arctan_tb();

// Declare inputs as regs and outputs as wires
int		zfp = 0;
real		z;
int		atan_pos_approx;
int		atan_neg_approx;
real		atan_pos_exact;
real		atan_neg_exact;
real		diff_pos_abs;
real		diff_neg_abs;
bit		clk = 1;

// clock generator(s)
always #(50ns) clk++;

// counter
always @(posedge clk)
begin
	zfp <= zfp + 1;
end
assign z = zfp / 256.0;

//`include "arctan.sv"

assign atan_pos_approx = arctan(zfp);
assign atan_neg_approx = arctan(-zfp);
assign atan_pos_exact = 256 * $atan(z) * 57.29577951308;
assign atan_neg_exact = 256 * $atan(-z) * 57.29577951308;
assign diff_pos_abs = atan_pos_approx - atan_pos_exact;
assign diff_neg_abs = atan_neg_approx - atan_neg_exact;

initial
begin
	#(5ms) $stop(2);
end

endmodule