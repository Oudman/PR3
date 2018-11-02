// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		phase_extract.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ input_buffer.sv
//  ~ fft_int.sv
//  ~ peak_detect.sv
//  ~ delay.sv
//  ~ hypot.sv
//  ~ atan2.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	phase extraction from data signal
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef PHASE_EXTRACT_SV
`define PHASE_EXTRACT_SV

`include "input_buffer.sv"
`include "fft/fft_int.sv"
`include "delay.sv"
`include "hypot.sv"
`include "atan2.sv"
`include "peak_detect.sv"

module phase_extract #(
	parameter I_WIDTH,													// number of bits per entry
	parameter FFT,															// number of fft levels
	parameter O_WIDTH = I_WIDTH + FFT,								// number of bits of the fft output
	parameter RUNS															// number of runs
)(
	input		wire									clk,					// main clock
	input		wire									clk20,				// clock used to read sink
	input		wire									reset,				// synchronous reset
	input		wire									sink_start,			// start new run
	input		wire				[I_WIDTH-1:0]	sink_data,			//	connected to antenna			Q<I_WIDTH>.0
	output	bit									source_sop,			// first output entry
	output	wire									source_eop,			// last output entry
	output	wire									source_valid,		// output is valid
	output	int									source_freq,		// frequency output bus (Hz)	Q24.8
	output	wire unsigned	[O_WIDTH-1:0]	source_mag,			// magnitude output bus			UQ<WIDTH>.0
	output	shortint								source_phaseA,		// phase A output bus			Q3.13
	output	shortint								source_phaseB		// phase B output bus			Q3.13
);

// more parameters
localparam	FFT_LENGTH = 2**FFT;										// number of entries over which to apply fft

/*----------------------------------------------------------------------------*/
/*- wires and registers ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// input_buffer related
wire												time_fft_sop;			// sop output signal
wire												time_fft_eop;			// eop output signal
wire												time_fft_valid;		// valid output signal
wire signed		[I_WIDTH-1:0]				time_fft_re;			// real data output bus			Q<I_WIDTH>.0

// fft_int related
wire												fft_trans_sop;			// sop output signal
wire												fft_trans_eop;			// eop output signal
wire												fft_trans_valid;		// valid output signal
wire signed		[O_WIDTH-1:0]				fft_trans_re;			// real data output bus			Q<O_WIDTH>.0
wire signed		[O_WIDTH-1:0]				fft_trans_im;			// imaginair data output bus	Q<O_WIDTH>.0

// transformation related
wire												trans_peak_sop;		// sop output signal
wire												trans_peak_eop;		// eop output signal
wire												trans_peak_valid;		// valid output signal
wire unsigned	[O_WIDTH-1:0]				trans_peak_mag;		// magnitude data output bus	UQ<O_WIDTH>.0
shortint											trans_peak_phase0;	// phase data output bus		Q3.13
shortint											trans_peak_phase1;	// delayed phase output bus	Q3.13

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// input buffer
input_buffer #(
	.BATCH_SIZE				(FFT_LENGTH),
	.RUNS						(RUNS),
	.DATA_WIDTH				(I_WIDTH)
) i_buffer (
	.sink_clk				(clk20),
	.source_clk				(clk),
	.reset					(reset),
	.sink_start				(sink_start),
	.sink_data				(sink_data),
	.source_sop				(time_fft_sop),
	.source_eop				(time_fft_eop),
	.source_valid			(time_fft_valid),
	.source_data			(time_fft_re)
);

// fft operator
fft_int #(
	.POW						(FFT),
	.DATA_WIDTH				(I_WIDTH),
	.RES_WIDTH				(O_WIDTH)
) fft (
	.clk						(clk),
	.aclr						(reset),
	.sink_sop				(time_fft_sop),
	.sink_eop				(time_fft_eop),
	.sink_valid				(time_fft_valid),
	.sink_Re					(time_fft_re),
	.sink_Im					(0),
	.source_sop				(fft_trans_sop),
	.source_eop				(fft_trans_eop),
	.source_valid			(fft_trans_valid),
	.source_Re				(fft_trans_re),
	.source_Im				(fft_trans_im),
	.error					()
);

// carthesian to polar transformation
delay #(
	.WIDTH					(3),
	.DELAY					(5)
) delay_5 (
	.clk						(clk),
	.reset					(reset),
	.sink						({fft_trans_sop, fft_trans_eop, fft_trans_valid}),
	.source					({trans_peak_sop, trans_peak_eop, trans_peak_valid})
);

hypot #(
	.WIDTH					(O_WIDTH)
) hypo (
	.clk						(clk),
	.reset					(reset),
	.sink_x					(fft_trans_re),
	.sink_y					(fft_trans_im),
	.source					(trans_peak_mag)
);

atan2 #(
	.WIDTH					(O_WIDTH)
) atan (
	.clk						(clk),
	.reset					(reset),
	.sink_y					(fft_trans_im),
	.sink_x					(fft_trans_re),
	.source					(trans_peak_phase0)
);

delay #(
	.WIDTH					(16),
	.DELAY					(1)
) delay_1 (
	.clk						(clk),
	.reset					(reset),
	.sink						(trans_peak_phase0),
	.source					(trans_peak_phase1)
);

// peak detection
peak_detect #(
	.SIZE						(FFT_LENGTH/2),
	.WIDTH					(O_WIDTH)
) p_detect (
	.clk						(clk),
	.reset					(reset),
	.sink_sop				(trans_peak_sop),
	.sink_eop				(trans_peak_eop),
	.sink_valid				(trans_peak_valid),
	.sink_mag				(trans_peak_mag),
	.sink_phase				(trans_peak_phase1),
	.source_sop				(source_sop),
	.source_eop				(source_eop),
	.source_valid			(source_valid),
	.source_freq			(source_freq),
	.source_mag				(source_mag),
	.source_phaseA			(source_phaseA),
	.source_phaseB			(source_phaseB)
);

endmodule

`endif
