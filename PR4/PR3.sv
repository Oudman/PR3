// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		PR3.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ input_buffer.sv
//  ~ TODO
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	phase extraction from three data signals
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef PR3_SV
`define PR3_SV

`include "input_buffer.sv"

module PR3 #(
	parameter NSINK = 3,													// number of antennas
	parameter WIDTH = 14,												// number of input bits per antenna
	parameter FFT = 11,													// fft width
	parameter FREQ = 100													// number of runs per second
)(
	input		wire									clk40,				// 40.0MHz
	input		wire									reset,				// synchronous reset
	input		wire signed		[WIDTH-1:0]		sink[0:NSINK-1],	//	antenna data buses			Q<WIDTH>.0
	output	bit									source_valid,		// output is valid
	output	bit									source_sop,			// first output entry
	output	bit									source_eop,			// last output entry
	output	bit unsigned	[23:0]			source_freq,		// frequency						UQ24.0
	output	bit signed		[15:0]			source_phaseA,		// phase A							Q3.13
	output	bit signed		[15:0]			source_phaseB		// phase B							Q3.13
);

// more parameters
localparam TICKS = 40000000 / FREQ;									// number of clk40 ticks per run
localparam MWIDTH = WIDTH + FFT;
localparam CWIDTH = $clog2(TICKS);

/*----------------------------------------------------------------------------*/
/*- wires and registers ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// control related
bit unsigned	[CWIDTH-1:0]	cnt;									// counter							UQ<lb(TICKS).0>
bit									start;								// start new run

// pll related
wire									clk;									// main clock

// input buffer related
wire									time_fft_valid;					// output is valid
wire									time_fft_sop;						// first output entry
wire									time_fft_eop;						// last output entry
wire signed		[WIDTH-1:0]		time_fft_re;						// output data bus				Q<WIDTH>.0

// fft related
wire									fft_trans_valid;					// output is valid
wire									fft_trans_sop;						// first output entry
wire									fft_trans_eop;						// last output entry
wire signed		[MWIDTH-1:0]	fft_trans_re;						// real data output bus			Q<O_WIDTH>.0
wire signed		[MWIDTH-1:0]	fft_trans_im;						// imaginair data output bus	Q<O_WIDTH>.0

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// run control
always @(posedge clk40)
begin
	cnt				<= (reset || cnt == TICKS-1'b1) ? {CWIDTH{1'b0}} : cnt + 1'b1;
	start				<= (reset || cnt != {CWIDTH{1'b0}}) ? 1'b0 : 1'b1;
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// pll module to generate the main clock signal
assign clk = clk40; // TODO

// input buffer
input_buffer #(
	.NSINK					(NSINK),
	.WIDTH					(WIDTH),
	.LENGTH					(2**FFT)
) ib (
	.sink_clk				(clk40),
	.source_clk				(clk),
	.reset					(reset),
	.sink_start				(start),
	.sink_data				(sink),
	.source_valid			(time_fft_valid),
	.source_sop				(time_fft_sop),
	.source_eop				(time_fft_eop),
	.source_data			(time_fft_re)
);

// fft operator
fft_int #(
	.POW						(FFT),
	.DATA_WIDTH				(WIDTH),
	.RES_WIDTH				(MWIDTH)
) fft (
	.clk						(clk),
	.aclr						(reset),
	.sink_valid				(time_fft_valid),
	.sink_sop				(time_fft_sop),
	.sink_eop				(time_fft_eop),
	.sink_Re					(time_fft_re),
	.sink_Im					({WIDTH{1'b0}}),
	.source_valid			(fft_trans_valid),
	.source_sop				(fft_trans_sop),
	.source_eop				(fft_trans_eop),
	.source_Re				(fft_trans_re),
	.source_Im				(fft_trans_im),
	.error					()
);

// carthesian to polar translation
// TODO

// peak detection
// TODO

assign source_valid = fft_trans_valid;
assign source_sop = fft_trans_sop;
assign source_eop = fft_trans_eop;
assign source_phaseA = fft_trans_im;

endmodule

`endif