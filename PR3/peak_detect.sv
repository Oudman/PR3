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
	parameter BATCH_SIZE,												// number of entries per input batch
	parameter DATA_WIDTH													// number of bits per entry
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

/*----------------------------------------------------------------------------*/
/*- struct + task + function definitions -------------------------------------*/
/*----------------------------------------------------------------------------*/
typedef struct {
	shortint	bin;
	byte		delta;
	int		re[0:2];
	int		im[0:2];
	int		mag[0:2];
} chunk;

// reset chunk
task automatic chunk_reset(ref chunk chnk);
	chnk.bin			<= 0;
	chnk.delta		<= 0;
	for (byte i = 0; i < 3; i++)
	begin
		chnk.re[i]		<= 0;
		chnk.im[i]		<= 0;
		chnk.mag[i]		<= 0;
	end
endtask

// shift data in chunk
task automatic chunk_shift(ref chunk chnk);
	chnk.bin			<= chnk.bin + 1;
	for (byte i = 0; i < 2; i++)
	begin
		chnk.re[i]		<= chnk.re[i+1];
		chnk.im[i]		<= chnk.im[i+1];
		chnk.mag[i]		<= chnk.mag[i+1];
	end
	chnk.re[2]		<= sink_re;
	chnk.im[2]		<= sink_im;
	chnk.mag[2]		<= hypot(sink_re, sink_im) <<< 8;
endtask

// quadratic interpolation (out: FP)
task automatic chunk_quadratic_delta(ref chunk chnk);
	chnk.delta 		<= ((chnk.mag[2] - chnk.mag[0]) <<< 7) / (2*chnk.mag[1] - chnk.mag[0] - chnk.mag[2]);
endtask

/*----------------------------------------------------------------------------*/
/*- wire/logic declarations --------------------------------------------------*/
/*----------------------------------------------------------------------------*/
chunk										buffer;							// data buffer
chunk										peaks[0:NPEAKS-1];			// peak data
bit	[$clog2(BATCH_SIZE)-1:0]	sink_pos;						// sink entry position
bit										sink_done;						// high:		buffer is fully loaded
bit	[$clog2(NPEAKS)-1:0]			source_pos;						// source entry position
bit										source_done;					// high:		peaks have all been output

/*----------------------------------------------------------------------------*/
/*- main code ----------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		for (byte i = 0; i < NPEAKS; i++)
			chunk_reset(peaks[i]);
		sink_pos			<= 0;
		sink_done		<= 0;
		source_pos		<= 0;
		source_done		<= 0;
		source_valid	<= 0;
	end
	else if (!sink_done && sink_valid)								// loading of buffer
	begin
		for (byte i = 0; i < NPEAKS; i++)
			if (EXPEAKS[i]-PEAKDEV <= sink_pos && sink_pos < EXPEAKS[i]+PEAKDEV && buffer.mag[1] > peaks[i].mag[1])
				peaks[i] 		<= buffer;
		chunk_shift(buffer);
		sink_done		<= (sink_pos == BATCH_SIZE - 1) ? 1 : 0;
		sink_pos			<= sink_pos + 1;
	end
	else if (sink_done && !source_done)								// export of data
	begin
		source_valid	<= 1;
		source_sop		<= (source_pos == 0) ? 1 : 0;
		source_eop		<= (source_pos == NPEAKS-1) ? 1 : 0;
		//source_freq		<= ((peaks[source_pos] <<< 8) + delta) * BIN_WIDTH;
		//source_mag		<= buff_r[peaks[source_pos]];
		//source_phaseA	<= phase_A(peaks[source_pos], delta);
		//source_phaseB	<= phase_B(peaks[source_pos], delta);
		source_done		<= (source_pos == NPEAKS-1) ? 1 : 0;
		source_pos		<= source_pos + 1;
	end
	else																		// wait
	begin
		source_valid	<= 0;
	end
end

endmodule