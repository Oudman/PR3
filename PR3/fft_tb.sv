// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		fft_tb.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Type:		testbench
// Purpose:	testing of fft_int.sv
// -----------------------------------------------------------------------------

`timescale 1ns/10ps

module fft_tb();

// testing parameters
localparam FFT_DEPTH = 12;
localparam SINK_WIDTH = 14;
localparam FFT_WIDTH = SINK_WIDTH + FFT_DEPTH;

// Declare inputs as regs and outputs as wires
bit signed [SINK_WIDTH-1:0] time_fft_re, time_fft_im = 0;
bit clk = 1, reset = 1, time_fft_sop = 0, time_fft_eop = 0, time_fft_valid = 0;
wire fft_freq_sop, fft_freq_eop, fft_freq_valid, error;
wire signed [FFT_WIDTH-1:0] fft_peak_re, fft_peak_im;
real fft_peak_r, fft_peak_theta;
const real					pi = 3.1416;
real							sin025, sin05, sin075, sin1, sin2, sin3, sin4, sin5, sin6, sin7, sin8;

// clock generator(s)
always #(25441ps) clk++;	// Fs = 20.48 MHz

// sine approx generator
always @(negedge clk)
begin
	sin025 = 1024 * $sin(2 * pi * 25E4 * $time / 1E9);
	sin05  = 1024 * $sin(2 * pi * 50E4 * $time / 1E9);
	sin075 = 1024 * $sin(2 * pi * 75E4 * $time / 1E9);
	sin1 = 1024 * $sin(2 * pi * 1.0E6 * $time / 1E9);
	sin2 = 1024 * $sin(2 * pi * 2.0E6 * $time / 1E9);
	sin3 = 1024 * $sin(2 * pi * 3.0E6 * $time / 1E9);
	sin4 = 1024 * $sin(2 * pi * 4.0E6 * $time / 1E9);
	sin5 = 1024 * $sin(2 * pi * 5.0E6 * $time / 1E9);
	sin6 = 1024 * $sin(2 * pi * 6.0E6 * $time / 1E9);
	sin7 = 1024 * $sin(2 * pi * 7.0E6 * $time / 1E9);
	sin8 = 1024 * $sin(2 * pi * 8.0E6 * $time / 1E9);
end

assign time_fft_re = sin025 + sin05 + sin075 + sin1 + sin2 + sin3 + sin4 + sin5 + sin6 + sin7 + sin8;

assign fft_peak_r = $hypot(fft_peak_re, fft_peak_im);
assign fft_peak_theta = $atan2(fft_peak_im, fft_peak_re);

initial
begin
	#(100ns) reset = 0;
	time_fft_valid = 1;
	forever
	begin
		time_fft_sop = 1;
		repeat(1) @(posedge clk);
		time_fft_sop = 0;
		repeat(2**FFT_DEPTH-2) @(posedge clk);
		time_fft_eop = 1;
		repeat(1) @(posedge clk);
		time_fft_eop = 0;
	end
end

initial
begin
	#(1ms) $stop(2);
end

// Connect module(s) to test
fft_int #(
	.POW						(FFT_DEPTH),								// FFT length N = 2**POW
	.DATA_WIDTH				(SINK_WIDTH),								// input width
	.RES_WIDTH				(FFT_WIDTH)									// output width
) fft (
	.clk						(clk),										// clock:	processing speed
	.aclr						(reset),										// high:		reset
	.sink_sop				(time_fft_sop),							// high:		start of input packet, valid if sink_valid is high
	.sink_eop				(time_fft_eop),							// high:		end of input packet
	.sink_valid				(time_fft_valid),							// high:		input is valid
	.sink_Re					(time_fft_re),								// 			real part of input
	.sink_Im					(time_fft_im),								// 			imaginair part of input
	.source_sop				(fft_freq_sop),							// high:		start of output packet, valid if source_valid is high
	.source_eop				(fft_freq_eop),							// high:		end of output packet
	.source_valid			(fft_freq_valid),							// high:		output is valid
	.source_Re				(fft_peak_re),								// 			real part of output
	.source_Im				(fft_peak_im),								// 			imaginair part of output
	.error					(error)										// high:		something is shit
);

endmodule
