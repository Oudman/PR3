// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		peak_detect.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ hypot.sv
//  ~ atan2.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	fft peak detection, peak interpolation and peak data output
//				each fft bin is assumed to be 10kHz wide
// -----------------------------------------------------------------------------
// Control:	clk, reset
// Sink:		sop, eop, valid, re, im
// Source:	sop, eop, valid, freq, mag, phaseA, phaseB
// -----------------------------------------------------------------------------
// Fixed point notation, marked FP, is used in the following manner:
// - 32 bit two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

module peak_detect #(
	parameter BATCH_SIZE	= 1024,										// number of entries per input batch
	parameter DATA_WIDTH	= 20											// number of bits per entry
)(
	input		wire							clk,							// input data speed
	input		wire							reset,						// synchronous reset
	input		wire							sink_sop,					// first input entry
	input		wire							sink_eop,					// last input entry
	input		wire							sink_valid,					// input is valid
	input		wire	[DATA_WIDTH-1:0]	sink_re,						//	real part of input data
	input		wire	[DATA_WIDTH-1:0]	sink_im,						//	imaginair part of input data
	output	bit							source_sop,					// first output entry
	output	bit							source_eop,					// last output entry
	output	bit							source_valid,				// output is valid
	output	int							source_freq,				// frequency of peak (kHz; FP)
	output	int							source_mag,					// magnitude of peak (FP)
	output	int							source_phaseA,				// possible phase of peak (deg; FP)
	output	int							source_phaseB				// alternative phase of peak (deg; FP)
);

// more parameters
localparam BIN_WIDTH = 10;												// bin width (kHz)
localparam NPEAKS = 4;													// number of peaks to detect
localparam shortint EXPEAKS[NPEAKS] = '{200, 400, 600, 800};// expected locations of peaks (bin)
localparam PEAKDEV = 50;												// maximum deviation between expectation and reality (bins)
localparam ADDR_WIDTH = $clog2(BATCH_SIZE);						// memory address width

/*----------------------------------------------------------------------------*/
/*- wire/logic declarations --------------------------------------------------*/
/*----------------------------------------------------------------------------*/
int										sink_mag;						// magnitude of complex input (FP)
int										buff_re[0:BATCH_SIZE-1];	// data buffer, real part (FP)
int										buff_im[0:BATCH_SIZE-1];	// data buffer, imaginair part (FP)
int										buff_mag[0:BATCH_SIZE-1];	// data buffer, magnitude (FP)
bit	[ADDR_WIDTH-1:0]				peaks[0:NPEAKS-1];			// indices of peaks
bit	[$clog2(BATCH_SIZE)-1:0]	sink_pos;						// sink entry position
bit										sink_done;						// high:		buffer is fully loaded
bit	[$clog2(NPEAKS)-1:0]			source_pos;						// source entry position
bit										source_done;					// high:		peaks have all been output
int										delta;							// delta at source_pos

/*----------------------------------------------------------------------------*/
/*- functions and tasks ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// quadratic interpolation (out: FP)
function automatic int quadratic_delta(const ref bit [$clog2(BATCH_SIZE)-1:0] i);
	automatic int y1 = buff_mag[i-1];
	automatic int y2 = buff_mag[i];
	automatic int y3 = buff_mag[i+1];
	quadratic_delta = ((y3 - y1) <<< 7) / (2*y2 - y1 - y3);
endfunction

/*----------------------------------------------------------------------------*/
/*- main code ----------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
assign delta = quadratic_delta(peaks[source_pos]);

always @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		for (byte i = 0; i < NPEAKS; i++)
			peaks[i]					<= 0;
		sink_pos					<= 0;
		sink_done				<= 0;
		source_pos				<= 0;
		source_done				<= 0;
		source_valid			<= 0;
	end
	else if (!sink_done && sink_valid)								// loading of buffer
	begin
		for (byte i = 0; i < NPEAKS; i++)
			if (EXPEAKS[i] - PEAKDEV <= sink_pos && sink_pos < EXPEAKS[i] + PEAKDEV && sink_re > buff_mag[peaks[i]])
				peaks[i]					<= sink_pos;
		buff_re[sink_pos]		<= sink_re;
		buff_im[sink_pos]		<= sink_im;
		buff_mag[sink_pos]	<= hypot(sink_re, sink_im) <<< 8;
		sink_done				<= (sink_pos == BATCH_SIZE - 1) ? 1 : 0;
		sink_pos					<= sink_pos + 1;
	end
	else if (sink_done && !source_done)								// export of data
	begin
		source_valid			<= 1;
		source_sop				<= (source_pos == 0) ? 1 : 0;
		source_eop				<= (source_pos == NPEAKS-1) ? 1 : 0;
		//source_freq <= ((peaks[source_pos] <<< 8) + delta) * BIN_WIDTH;
		//source_mag <= buff_r[peaks[source_pos]];
		//source_phaseA <= phase_A(peaks[source_pos], delta);
		//source_phaseB <= phase_B(peaks[source_pos], delta);
		source_done				<= (source_pos == NPEAKS-1) ? 1 : 0;
		source_pos				<= source_pos + 1;
	end
	else																		// wait
	begin
		source_valid			<= 0;
	end
end

endmodule