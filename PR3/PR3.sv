// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		PR3.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ input_buffer.sv
//  ~ fft_int.sv
//  ~ hypot.sv
//  ~ atan2.sv
//  ~ delay.sv
//  ~ peak_detect.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Phase extraction from three data signals. Frequency output is in
// 			Hertz and phase output in pi radians.
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
`include "fft_int.sv"
`include "hypot.sv"
`include "atan2.sv"
`include "delay.sv"
`include "peak_detect.sv"

module PR3 #(
	parameter NSINK = 3,													// number of antennas
	parameter WIDTH = 14,												// number of input bits per antenna
	parameter FFT = 11,													// fft width
	parameter FREQ = 5000,												// number of runs per second
	parameter NBPP = 5													// number of bins per peak
)(
	input		wire									clk40,				// 40.0MHz reference clock
	input		wire									reset,				// synchronous reset
	input		wire signed		[WIDTH-1:0]		sink[0:NSINK-1],	//	antenna data buses			Q<WIDTH>.0
	output	reg									source_valid,		// output is valid
	output	reg				[31:0]			source_data			// output data bus
);

// more parameters
localparam TICKS = 20480000 / FREQ;									// number of clk20 ticks per run
localparam MWIDTH = WIDTH + FFT;										// number of bits used for intermediate results
localparam CWIDTH = $clog2(TICKS);									// number of counter bits
localparam TR_DELAY = 2 * MWIDTH + 2;								// latency of carthesian to polar transformation

/*----------------------------------------------------------------------------*/
/*- wires and registers ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// control related
reg unsigned	[CWIDTH-1:0]	cnt;									// counter							UQ<lb(TICKS).0>
reg									start;								// start new run

// pll related
wire									clk20;								// 20.48MHz input clock
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
wire signed		[MWIDTH-1:0]	fft_trans_re;						// real data output bus			Q<MWIDTH>.0
wire signed		[MWIDTH-1:0]	fft_trans_im;						// imaginair data output bus	Q<MWIDTH>.0

// transformation related
wire									trans_peak_valid;					// output is valid
wire									trans_peak_sop;					// first output entry
wire									trans_peak_eop;					// last outptu entry
wire unsigned	[MWIDTH-1:0]	trans_peak_mag;					// magnitude data output bus	UQ<MWIDTH>.0
wire signed		[15:0]			trans_peak_phase;					// phase data output bus		Q1.15

// peak detection + phase extraction related
wire									peak_fifo_valid;					// output is valid
wire									peak_fifo_sop;						// first output entry
wire									peak_fifo_eop;						// last outptu entry
wire				[31:0]			peak_fifo_data;					// phase data output bus

// source control related
reg									fifo_todo;							// write next cycle
reg				[23:0]			fifo_num;							// block number
reg				[7:0]				fifo_antenna;						// antenna number
reg				[31:0]			fifo_buffer;						// data buffer

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// run control
always @(posedge clk20)
begin
	cnt				<= (reset || cnt == TICKS-1'b1) ? {CWIDTH{1'b0}} : cnt + 1'b1;
	start				<= (reset || cnt != {CWIDTH{1'b0}}) ? 1'b0 : 1'b1;
end

// source control
always @(posedge clk)
begin
	if (reset)																// reset all
	begin
		source_valid	<= 1'b0;
		source_data		<= 32'hxxxxxxxx;
		fifo_todo		<= 1'b0;
		fifo_num			<= 24'h000000;
		fifo_antenna	<= 8'h00;
		fifo_buffer		<= 32'hxxxxxxxx;
	end
	else if (peak_fifo_valid || fifo_todo)							// write output
	begin
		source_valid	<= 1'b1;
		if (peak_fifo_sop)												// new antenna block
			source_data		<= {fifo_num, fifo_antenna};
		else																	// continue with antenna block
			source_data		<= fifo_buffer;
		if (peak_fifo_eop)												// last entry of antenna block
		begin
			if (fifo_antenna == NSINK-1)								// last antenna block of complete block
			begin
				fifo_num			<= fifo_num + 1'b1;
				fifo_antenna	<= 8'h00;
			end
			else																// non-last antenna block of complete block
				fifo_antenna	<= fifo_antenna + 1'b1;
		end
		fifo_todo		<= peak_fifo_valid;
		fifo_buffer		<= (peak_fifo_valid) ? peak_fifo_data : 32'hxxxxxxxx;
	end
	else																		// wait
	begin
		source_valid	<= 1'b0;
		source_data		<= 32'hxxxxxxxx;
		fifo_buffer		<= 32'hxxxxxxxx;
	end
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// pll for the input clock
altera_pll #(
	.reference_clock_frequency	("40.000000 MHz"),
	.number_of_clocks		(2),
	.output_clock_frequency0	("20.480000 MHz"),
	.duty_cycle0			(50),
	.output_clock_frequency1	("51.200000 MHz"),
	.duty_cycle1			(50)
) pll (
	.rst						(),
	.outclk					({clk, clk20}),
	.refclk					(clk40)
);

// input buffer
input_buffer #(
	.NSINK					(NSINK),
	.WIDTH					(WIDTH),
	.LENGTH					(2**FFT)
) ib (
	.sink_clk				(clk20),
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
hypot #(
	.WIDTH					(MWIDTH),
	.DELAY					(TR_DELAY)
) hypo (
	.clk						(clk),
	.reset					(reset),
	.sink_x					(fft_trans_re),
	.sink_y					(fft_trans_im),
	.source					(trans_peak_mag)
);

atan2 #(
	.WIDTH					(MWIDTH),
	.DELAY					(TR_DELAY)
) atan2 (
	.clk						(clk),
	.reset					(reset),
	.sink_x					(fft_trans_re),
	.sink_y					(fft_trans_im),
	.source					(trans_peak_phase)
);

delay #(
	.WIDTH					(3),
	.DELAY					(TR_DELAY)
) delay (
	.clk						(clk),
	.reset					(reset),
	.sink						({fft_trans_valid, fft_trans_sop, fft_trans_eop}),
	.source					({trans_peak_valid, trans_peak_sop, trans_peak_eop})
);

// peak detection
peak_detect #(
	.WIDTH					(MWIDTH),
	.BIN						(10000),
	.NPEAKS					(4),
	.PEAKSEP					('{100, 300, 500, 700, 900}),
	.NBPP						(NBPP)
) pd (
	.clk						(clk),
	.reset					(reset),
	.sink_valid				(trans_peak_valid),
	.sink_sop				(trans_peak_sop),
	.sink_eop				(trans_peak_eop),
	.sink_mag				(trans_peak_mag),
	.sink_phase				(trans_peak_phase),
	.source_valid			(peak_fifo_valid),
	.source_sop				(peak_fifo_sop),
	.source_eop				(peak_fifo_eop),
	.source_data			(peak_fifo_data)
);

endmodule

`endif
