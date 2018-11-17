// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ atan2.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of atan2.sv
// -----------------------------------------------------------------------------

`ifndef ATAN2_TB_SV
`define ATAN2_TB_SV

`include "atan2.sv"

`timescale 1ns/100ps

module atan2_tb();

// Declare inputs as regs and outputs as wires
shortint	cnt = 0;
real		phase;
shortint	x, y;
shortint	res;
real		diff, diffB;
bit		clk = 1;

// clock generator(s)
always #(50ns) clk++;

// counter
always @(posedge clk)
begin
	cnt <= cnt + 17;
end

assign phase = cnt / 10430.37835;
assign x = 16384.0 * $cos(phase);
assign y = 16384.0 * $sin(phase);
assign diff = res / 8192.0 - (phase - 17*0.0023968);
assign diffB = (diff > 0.5) ? diff - 6.283185307 : diff;

initial
begin
	#(5ms) $stop(2);
end

atan2 #(
	.WIDTH					(16),
	.DELAY					(25)
) atan2 (
	.clk						(clk),
	.sink_x					(x),
	.sink_y					(y),
	.source					(res)
);

endmodule

`endif
