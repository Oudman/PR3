// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		phase_extract_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ phase_extract.sv
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of phase_extract.sv
// -----------------------------------------------------------------------------

`ifndef PHASE_EXTRACT_TB_SV
`define PHASE_EXTRACT_TB_SV

`include "phase_extract.sv"

`timescale 1ns/10ps

module phase_extract_tb();

// testing parameters
localparam SINK_WIDTH = 14;
localparam FFT_DEPTH = 11;
localparam RUNS = 3;

// Declare inputs as regs and outputs as wires
wire [SINK_WIDTH-1:0] data;
bit clk50 = 0, clk20 = 0;
const real					pi = 3.1416;
real							sin1, sin2, sin3, sin4, noise;
const real					sin1_freq = 2.0E6;
const real					sin1_mag = 1024;
const real					sin1_off = 314;
const real					sin2_freq = 4.0E6;
const real					sin2_mag = 1024;
const real					sin2_off = 42;
const real					sin3_freq = 6.0E6;
const real					sin3_mag = 1024;
const real					sin3_off = 12345;
const real					sin4_freq = 8.0E6;
const real					sin4_mag = 1024;
const real					sin4_off = 278;

// clock generator(s)
always #(25ns) clk20++;	// F = 20.48 MHz
always #(10ns) clk50++;		// F = 50.00 MHz

// sine approx generator
always @(negedge clk20)
begin
	sin1 = sin1_mag * $sin(sin1_off + 2 * pi * sin1_freq * $time / 1E9);
	sin2 = sin2_mag * $sin(sin2_off + 2 * pi * sin2_freq * $time / 1E9);
	sin3 = sin3_mag * $sin(sin3_off + 2 * pi * sin3_freq * $time / 1E9);
	sin4 = sin4_mag * $sin(sin4_off + 2 * pi * sin4_freq * $time / 1E9);
	noise = $random / 2**(32-10);
end

assign data = sin1 + sin2 + sin3 + sin4 + noise;

initial
begin
	#(1ms) $stop(2);
end

// Connect module(s) to test
phase_extract #(
	.SINK_WIDTH				(SINK_WIDTH),								// number of bits per entry
	.FFT_DEPTH				(FFT_DEPTH),								// number of fft levels
	.RUNS						(RUNS)										// number of runs
) pe (
	.clk						(clk50),										// clock:	main clock
	.clk20					(clk20),										// clock:	20MHz
	.sink						(data)										//				connected to antenna
);

endmodule

`endif
