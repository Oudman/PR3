// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		PR3.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ pll.v
//  ~ phase_extract.sv
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

`include "pll.v"
`include "phase_extract.sv"

module PR3 #(
	parameter WIDTH = 14,												// number of input bits per antenna
	parameter RUNS = 3,													// number of runs
	parameter FFT = 11,													// fft width
	parameter SPEED = 4000												// number of runs per second
)(
	input		wire									clk20,				// 20.0MHz
	input		wire									reset,				// synchronous reset
	input		wire signed		[WIDTH-1:0]		data1,				//	antenna #1 data bus		Q<WIDTH>.0
	input		wire signed		[WIDTH-1:0]		data2,				//	antenna #2 data bus		Q<WIDTH>.0
	input		wire signed		[WIDTH-1:0]		data3					//	antenna #3 data bus		Q<WIDTH>.0
);

// more parameters
localparam TICKS = 20000000 / SPEED;								// number of clk20 ticks per run

/*----------------------------------------------------------------------------*/
/*- wires and registers ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
wire												clk;						// main clock
bit unsigned	[$clog2(TICKS)-1:0]		cnt;						// counter						UQ<lb(TICKS).0>
bit												start;					// start new run

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// clocktick counter
always @(posedge clk20)
begin
	cnt				<= (reset || cnt == TICKS-1) ? 0 : cnt + 1;
end

// run control
always @(posedge clk)
begin
	start				<= (reset || start != 0 || cnt != 0) ? 0 : 1;
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// pll module to generate the main clock signal
pll (
	.refclk					(clk20),
	.rst						(),
	.outclk_0				(clk)
);

// phase extraction on antenna #1
phase_extract #(
	.I_WIDTH					(WIDTH),
	.FFT						(FFT),
	.RUNS						(RUNS)
) pe1 (
	.clk						(clk),
	.clk20					(clk20),
	.reset					(reset),
	.sink_start				(start),
	.sink_data				(data1),
	.source_sop				(),
	.source_eop				(),
	.source_valid			(),
	.source_freq			(),
	.source_mag				(),
	.source_phaseA			(),
	.source_phaseB			()
);

endmodule

`endif
