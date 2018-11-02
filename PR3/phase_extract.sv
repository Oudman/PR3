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
// Control:	clk, clk20
// Sink:		data
// Source:	-
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
	parameter SINK_WIDTH,												// number of bits per entry
	parameter FFT_DEPTH,													// number of fft levels
	parameter RUNS															// number of runs
)(
	input		wire							clk,							// main clock
	input		wire							clk20,						// 20.48MHz
	input		wire	[SINK_WIDTH-1:0]	sink							//	connected to antenna			Q<SINK_WIDTH>.0
);

// more parameters
localparam	FFT_LENGTH = 2**FFT_DEPTH;								// number of entries over which to apply fft
localparam	FFT_WIDTH = SINK_WIDTH + FFT_DEPTH;					// number of bits of the fft output

/*----------------------------------------------------------------------------*/
/*- wire/reg declarations ----------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// input_buffer related
bit										time_reset;						// reintialize input buffer
wire										time_fft_sop;					// sop output signal
wire										time_fft_eop;					// eop output signal
wire										time_fft_valid;				// valid output signal
wire 	[SINK_WIDTH-1:0]				time_fft_re;					// real data output bus			Q<SINK_WIDTH>.0

// fft_int related
bit										fft_reset;						// reset fft
wire										fft_trans_sop;					// sop output signal
wire										fft_trans_eop;					// eop output signal
wire										fft_trans_valid;				// valid output signal
wire	[FFT_WIDTH-1:0]				fft_trans_re;					// real data output bus			Q<FFT_WIDTH>.0
wire	[FFT_WIDTH-1:0]				fft_trans_im;					// imaginair data output bus	Q<FFT_WIDTH>.0

// transformation related
wire										trans_peak_sop;				// sop output signal
wire										trans_peak_eop;				// eop output signal
wire										trans_peak_valid;				// valid output signal
wire	[FFT_WIDTH-1:0]				trans_peak_mag;				// magnitude data output bus	UQ<FFT_WIDTH>.0
shortint									trans_peak_phase0;			// phase data output bus		Q3.13
shortint									trans_peak_phase1;			// delayed phase output bus	Q3.13

// peak_detect related
bit										peak_reset;						// reset peak detection
wire										peak_sop;						// sop output signal
wire										peak_eop;						// eop output signal
wire										peak_valid;						// valid output signal
int										peak_freq;						// frequency output bus (kHz)	Q24.8
int										peak_mag;						// magnitude output bus			Q24.8
int										peak_phaseA;					// phase A output bus (deg)	Q24.8
int										peak_phaseB;					// phase B output bus (deg)	Q24.8

/*----------------------------------------------------------------------------*/
/*- module synchronization and control ---------------------------------------*/
/*----------------------------------------------------------------------------*/

// TODO: update this section

// load time buffer
initial
begin
	@(posedge clk20);
	time_reset = 1;
	@(posedge clk20);
	time_reset = 0;
end

// load fft
initial
begin
	@(posedge clk);
	fft_reset = 1;
	@(posedge clk);
	fft_reset = 0;
end

/*----------------------------------------------------------------------------*/
/*- module instances ---------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// input buffer
input_buffer #(
	.BATCH_SIZE				(FFT_LENGTH),
	.RUNS						(RUNS),
	.DATA_WIDTH				(SINK_WIDTH)
) i_buffer (
	.sink_clk				(clk20),
	.source_clk				(clk),
	.reset					(time_reset),
	.sink_data				(sink),
	.source_sop				(time_fft_sop),
	.source_eop				(time_fft_eop),
	.source_valid			(time_fft_valid),
	.source_data			(time_fft_re)
);

// fft operator
fft_int #(
	.POW						(FFT_DEPTH),
	.DATA_WIDTH				(SINK_WIDTH),
	.RES_WIDTH				(FFT_WIDTH)
) fft (
	.clk						(clk),
	.aclr						(fft_reset),
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
	.sink						({fft_trans_sop, fft_trans_eop, fft_trans_valid}),
	.source					({trans_peak_sop, trans_peak_eop, trans_peak_valid})
);

hypot #(
	.WIDTH					(FFT_WIDTH)
) hypo (
	.clk						(clk),
	.sink_x					(fft_trans_re),
	.sink_y					(fft_trans_im),
	.source					(trans_peak_mag)
);

atan2 #(
	.WIDTH					(FFT_WIDTH)
) atan (
	.clk						(clk),
	.sink_y					(fft_trans_im),
	.sink_x					(fft_trans_re),
	.source					(trans_peak_phase0)
);

delay #(
	.WIDTH					(16),
	.DELAY					(1)
) delay_1 (
	.clk						(clk),
	.sink						(trans_peak_phase0),
	.source					(trans_peak_phase1)
);

// peak detection
peak_detect #(
	.SIZE						(FFT_LENGTH/2),
	.WIDTH					(FFT_WIDTH)
) p_detect (
	.clk						(clk),
	.reset					(peak_reset),
	.sink_sop				(trans_peak_sop),
	.sink_eop				(trans_peak_eop),
	.sink_valid				(trans_peak_valid),
	.sink_mag				(trans_peak_mag),
	.sink_phase				(trans_peak_phase1),
	.source_sop				(peak_sop),
	.source_eop				(peak_eop),
	.source_valid			(peak_valid),
	.source_freq			(peak_freq),
	.source_mag				(peak_mag),
	.source_phaseA			(peak_phaseA),
	.source_phaseB			(peak_phaseB)
);

endmodule

`endif
