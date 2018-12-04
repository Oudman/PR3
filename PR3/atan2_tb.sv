// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ atan2.sv
//  ~ delay.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of atan2.sv
// -----------------------------------------------------------------------------

`ifndef ATAN2_TB_SV
`define ATAN2_TB_SV

`include "atan2.sv"
`include "delay.sv"

`timescale 1ns/100ps

module atan2_tb();

// Declare inputs as regs and outputs as wires
reg signed		[15:0]			cnt = 0;
reg									reset;
real									phase;
wire signed		[15:0]			x, y;
wire signed		[15:0]			corrp, corr;
wire signed		[15:0]			res;
real									diff;
reg									clk = 1;

// clock generator(s)
always #(50ns) clk++;

initial
begin
	reset = 1;
	#(200ns);
	reset = 0;
end

// counter
always @(negedge clk)
begin
	cnt <= cnt + 17;
end

assign phase = cnt / 10430.37835;
assign x = 2.0**14 * $cos(phase);
assign y = 2.0**14 * $sin(phase);
assign corrp = 2.0**15 * $atan2(y, x) / 3.141592654;
assign diff = res - corr;

initial
begin
	#(5ms) $stop(2);
end

atan2 #(
	.WIDTH					(16),
	.DELAY					(25)
) atan2 (
	.clk						(clk),
	.reset					(reset),
	.sink_x					(x),
	.sink_y					(y),
	.source					(res)
);

delay #(
	.WIDTH					(16),
	.DELAY					(25)
) delay (
	.clk						(clk),
	.reset					(reset),
	.sink						(corrp),
	.source					(corr)
);

endmodule

`endif
