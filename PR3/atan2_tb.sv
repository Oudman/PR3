// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of atan2.sv
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

module atan2_tb();

// Declare inputs as regs and outputs as wires
real		phase = 0.0;
real		step = 180.0;
real		x, y;
int		xfp, yfp;
int		res;
real		diff;
bit		clk = 1;
real		pi = 3.14159;

// clock generator(s)
always #(50ns) clk++;

// counter
always @(posedge clk)
begin
	phase = phase + step;
	if (phase >= 180.0)
	begin
		step = step / 2.0;
		phase = -180.0 + step;
	end
end

//`include "atan2.sv"
//`include "arctan_lim.sv"

assign x = 16384.0 * $cos(phase * pi/180.0);
assign y = 16384.0 * $sin(phase * pi/180.0);
assign xfp = 256 * x;
assign yfp = 256 * y;
assign res = atan2(yfp, xfp);
assign diff = (res / 256.0 - phase > 180.0) ? (res / 256.0 - phase - 360) : ((res / 256.0 - phase < -180.0) ? (res / 256.0 - phase + 360) : (res / 256.0 - phase));

initial
begin
	#(5ms) $stop(2);
end

endmodule