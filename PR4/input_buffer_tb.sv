// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		input_buffer_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ input_buffer.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of input_buffer.sv
// -----------------------------------------------------------------------------

`ifndef INPUT_BUFFER_TB_SV
`define INPUT_BUFFER_TB_SV

`include "input_buffer.sv"

`timescale 1ns/10ps

module input_buffer_tb();

// testing parameters
localparam NSINK = 3;
localparam WIDTH = 14;
localparam LENGTH = 2048;

// Declare inputs as regs and outputs as wires
bit					sink_clk = 0, source_clk = 0;
bit					reset = 0, start = 0;
reg signed [WIDTH-1:0]	dataIn[0:NSINK-1];
wire					source_sop, source_eop, source_valid;
wire [WIDTH-1:0]	dataOut;
const real			pi = 3.1416;
const real			sin1_freq = 2.0E6;
const real			sin1_mag = 1024;
const real			sin1_off = 0.00;
const real			sin2_freq = 4.0E6;
const real			sin2_mag = 1024;
const real			sin2_off = 0.25;
const real			sin3_freq = 6.0E6;
const real			sin3_mag = 1024;
const real			sin3_off = 0.50;
const real			sin4_freq = 8.0E6;
const real			sin4_mag = 1024;
const real			sin4_off = 0.75;

// clock generator(s)
always #(24414ps) sink_clk++;		// F = 20.48 MHz
always #(20000ps) source_clk++;	// F = 25.00 MHz

// sine calculator
function real sineat(real offset);
	automatic real sin1 = sin1_mag * $sin(sin1_off + 2 * pi * sin1_freq * ($time / 1E9 + offset));
	automatic real sin2 = sin2_mag * $sin(sin2_off + 2 * pi * sin2_freq * ($time / 1E9 + offset));
	automatic real sin3 = sin3_mag * $sin(sin3_off + 2 * pi * sin3_freq * ($time / 1E9 + offset));
	automatic real sin4 = sin4_mag * $sin(sin4_off + 2 * pi * sin4_freq * ($time / 1E9 + offset));
	automatic real noise = $random / 2**(32-4);
	sineat = sin1 + sin2 + sin3 + sin4 + noise;
endfunction

// sine approx generator
always @(negedge sink_clk)
begin
	dataIn[0] = sineat(0.0);
	dataIn[1] = sineat(0.3);
	dataIn[2] = sineat(0.2);
end

initial
begin
	reset = 1;
	#(50ns);
	reset = 0;
	#(50ns);
	forever begin
		@(negedge sink_clk)
		start = 1;
		@(negedge sink_clk)
		start = 0;
		#(300us-48828ps);
	end
end

initial
begin
	#(2ms) $stop(2);
end

// Connect module(s) to test
input_buffer #(
	.NSINK			(NSINK),
	.WIDTH			(WIDTH),
	.LENGTH			(LENGTH)
) buff (
	.sink_clk		(sink_clk),
	.source_clk		(source_clk),
	.reset			(reset),
	.sink_start		(start),
	.sink_data		(dataIn),
	.source_valid	(source_valid),
	.source_sop		(source_sop),
	.source_eop		(source_eop),
	.source_data	(dataOut)
);

endmodule

`endif
