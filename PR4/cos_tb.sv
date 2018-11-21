// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		cos_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ cos.sv
//  ~ delay.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of cos.sv
// -----------------------------------------------------------------------------

`ifndef COS_TB_SV
`define COS_TB_SV

`include "cos.sv"
`include "delay.sv"

`timescale 1ns/100ps

module cos_tb();

// Declare inputs as regs and outputs as wires
reg signed		[15:0]			cnt = 0;
reg									reset;
real									phase;
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

assign phase = cnt * 3.141592654 / 2.0**15;
assign corrp = 2.0**15 * $cos(phase);
assign diff = res - corr;

initial
begin
	#(5ms) $stop(2);
end

cos cos (
	.clk						(clk),
	.reset					(reset),
	.sink						(cnt),
	.source					(res)
);

delay #(
	.WIDTH					(16),
	.DELAY					(4)
) delay (
	.clk						(clk),
	.reset					(reset),
	.sink						(corrp),
	.source					(corr)
);

endmodule

`endif
