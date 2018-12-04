// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		PR3_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ PR3.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of PR3.sv
// -----------------------------------------------------------------------------

`ifndef INPUT_BUFFER_TB_SV
`define INPUT_BUFFER_TB_SV

`include "PR3.sv"

`timescale 1ns/10ps

module PR3_tb();

// testing parameters
localparam NSINK = 3;
localparam WIDTH = 14;
localparam FFT = 11;
localparam FREQ = 5000;

// Declare inputs as regs and outputs as wires
reg									clk = 0;
reg									reset = 0;
reg signed		[WIDTH-1:0]		dataIn[0:NSINK-1];
wire									source_valid, source_sop, source_eop;
wire unsigned	[23:0]			source_freq;
wire signed		[15:0]			source_phaseA, source_phaseB;
const real							pi = 3.1416;
const real							sin1_freq = 2.002E6;
const real							sin1_mag = 1024;
const real							sin1_off = 0.00;
const real							sin2_freq = 4.003E6;
const real							sin2_mag = 1024;
const real							sin2_off = 0.25;
const real							sin3_freq = 6.005E6;
const real							sin3_mag = 1024;
const real							sin3_off = 0.50;
const real							sin4_freq = 8.007E6;
const real							sin4_mag = 1024;
const real							sin4_off = 0.75;

// clock generator(s)
always #(12500ps) clk++;		// F = 40.0 MHz

// sine calculator
function real sineat(real offset);
	automatic real sin1 = sin1_mag * $sin(sin1_off + 2 * pi * sin1_freq * ($time / 1E9 + offset));
	automatic real sin2 = sin2_mag * $sin(sin2_off + 2 * pi * sin2_freq * ($time / 1E9 + offset));
	automatic real sin3 = sin3_mag * $sin(sin3_off + 2 * pi * sin3_freq * ($time / 1E9 + offset));
	automatic real sin4 = sin4_mag * $sin(sin4_off + 2 * pi * sin4_freq * ($time / 1E9 + offset));
	//automatic real noise = $random / 2**(32-4);
	sineat = sin1 + sin2 + sin3 + sin4;// + noise;
endfunction

// sine approx generator
always @(negedge clk)
begin
	dataIn[0] = sineat(0.0);
	dataIn[1] = sineat(0.3);
	dataIn[2] = sineat(0.2);
end

initial
begin
	reset = 1;
	#(200ns);
	reset = 0;
end

initial
begin
	#(2ms) $stop(2);
end

// Connect module(s) to test
PR3 #(
	.NSINK					(NSINK),
	.WIDTH					(WIDTH),
	.FFT						(FFT),
	.FREQ						(FREQ)
) pr (
	.clk40					(clk),
	.reset					(reset),
	.sink						(dataIn),
	.source_valid			(source_valid),
	.source_sop				(source_sop),
	.source_eop				(source_eop),
	.source_freq			(source_freq),
	.source_phaseA			(source_phaseA),
	.source_phaseB			(source_phaseB)
);

endmodule

`endif
