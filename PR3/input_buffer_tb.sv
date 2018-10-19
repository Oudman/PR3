// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		input_buffer_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of input_buffer.sv
// -----------------------------------------------------------------------------

`timescale 1ns/10ps

module input_buffer_tb();

// testing parameters
localparam DATA_WIDTH = 14;
localparam BATCH_SIZE = 2048;
localparam RUNS = 3;

// Declare inputs as regs and outputs as wires
bit							reset = 0, sink_clk = 0, source_clk = 0;
wire [DATA_WIDTH-1:0]	dataIn;
wire							source_sop, source_eop, source_valid;
wire [DATA_WIDTH-1:0]	dataOut;
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
always #(24414ps) sink_clk++;	// F = 20.48 MHz
always #(10ns) source_clk++;	// F = 50.00 MHz

// sine approx generator
always @(negedge sink_clk)
begin
	sin1 = sin1_mag * $sin(sin1_off + 2 * pi * sin1_freq * $time / 1E9);
	sin2 = sin2_mag * $sin(sin2_off + 2 * pi * sin2_freq * $time / 1E9);
	sin3 = sin3_mag * $sin(sin3_off + 2 * pi * sin3_freq * $time / 1E9);
	sin4 = sin4_mag * $sin(sin4_off + 2 * pi * sin4_freq * $time / 1E9);
	noise = $random / 2**(32-4);
end

assign dataIn = sin1 + sin2 + sin3 + sin4 + noise;

initial
begin
	forever begin
		reset = 1;
		#(1us);
		reset = 0;
		#(999us);
	end
end


initial
begin
	#(2ms) $stop(2);
end

// Connect module(s) to test
input_buffer #(
	.DATA_WIDTH		(DATA_WIDTH),
	.BATCH_SIZE		(BATCH_SIZE),
	.RUNS				(RUNS)
) buff (
	.reset			(reset),
	.sink_clk		(sink_clk),
	.sink_data		(dataIn),
	.source_clk		(source_clk),
	.source_sop		(source_sop),
	.source_eop		(source_eop),
	.source_valid	(source_valid),
	.source_data	(dataOut)
);

endmodule
