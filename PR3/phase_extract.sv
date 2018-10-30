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
wire										fft_peak_sop;					// sop output signal
wire										fft_peak_eop;					// eop output signal
wire										fft_peak_valid;				// valid output signal
wire	[FFT_WIDTH-1:0]				fft_peak_re;					// real data output bus			Q<FFT_WIDTH>.0
wire	[FFT_WIDTH-1:0]				fft_peak_im;					// imaginair data output bus	Q<FFT_WIDTH>.0

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
) buff (
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
	.source_sop				(fft_peak_sop),
	.source_eop				(fft_peak_eop),
	.source_valid			(fft_peak_valid),
	.source_Re				(fft_peak_re),
	.source_Im				(fft_peak_im),
	.error					()
);

// peak detection
peak_detect #(
	.BATCH_SIZE				(FFT_LENGTH/2),
	.DATA_WIDTH				(FFT_WIDTH)
) pd (
	.clk						(clk),
	.reset					(peak_reset),
	.sink_sop				(fft_peak_sop),
	.sink_eop				(fft_peak_eop),
	.sink_valid				(fft_peak_valid),
	.sink_re					(fft_peak_re),
	.sink_im					(fft_peak_im),
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
