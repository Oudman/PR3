// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		peak_detect.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	fft peak detection, peak interpolation and peak data output
//				each fft bin is assumed to be 10kHz wide
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef PEAK_DETECT_SV
`define PEAK_DETECT_SV

module peak_detect #(
	parameter SIZE,														// number of entries per input batch
	parameter WIDTH														// number of bits per entry
)(
	input		wire									clk,					// input data speed
	input		wire									reset,				// synchronous reset
	input		wire									sink_sop,			// first input entry
	input		wire									sink_eop,			// last input entry
	input		wire									sink_valid,			// input is valid
	input		wire unsigned	[WIDTH-1:0]		sink_mag,			//	real input bus					UQ<WIDTH>.0
	input		shortint								sink_phase,			//	imaginair input bus			Q3.13
	output	bit									source_sop,			// first output entry
	output	bit									source_eop,			// last output entry
	output	bit									source_valid,		// output is valid
	output	int									source_freq,		// frequency output bus (Hz)	Q24.8
	output	bit unsigned	[WIDTH-1:0]		source_mag,			// magnitude output bus			UQ<WIDTH>.0
	output	shortint								source_phaseA,		// phase A output bus			Q3.13
	output	shortint								source_phaseB		// phase B output bus			Q3.13
);

// more parameters
localparam BIN_WIDTH = 10000;											// bin width (Hz)
localparam NPEAKS = 4;													// number of peaks to detect
localparam shortint EXPEAKS[NPEAKS] = '{200, 400, 600, 800};// expected locations of peaks (bin)
localparam PEAKDEV = 50;												// maximum deviation between expectation and reality (bins)

/*----------------------------------------------------------------------------*/
/*- struct definition and registers ------------------------------------------*/
/*----------------------------------------------------------------------------*/
typedef struct {
	bit signed		[$clog2(SIZE):0]		bin;						// central bin number			Q<lb(SIZE)+1>.0
	bit unsigned	[WIDTH-1:0]				mag[0:2];				// magnitude						UQ<WIDTH>.0
	shortint										phs[0:2];				// phase								Q3.13
} chunk;

chunk												buffer;					// data buffer
chunk												peaks[0:NPEAKS-1];	// peak data
bit												sink_done;				// buffer is fully loaded
bit												source_done;			// peaks have all been output
bit unsigned	[$clog2(NPEAKS+2)-1:0]	source_pos;				// source position				UQ<lb(NPEAKS+2)>.0

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		buffer.bin		<= -2;
		buffer.mag		<= '{3{0}};
		for (byte i = 0; i < NPEAKS; i++)
			peaks[i].mag	<= '{3{0}};
		sink_done		<= 0;
		source_pos		<= 0;
		source_done		<= 0;
		source_valid	<= 0;
	end
	else if (sink_valid && !sink_done)								// loading of buffer
	begin
		for (byte i = 0; i < NPEAKS; i++)
			if (EXPEAKS[i]-PEAKDEV <= buffer.bin && buffer.bin < EXPEAKS[i]+PEAKDEV && buffer.mag[1] > peaks[i].mag[1])
				peaks[i] 		<= buffer;
		buffer.bin		<= buffer.bin + 1;
		buffer.mag		<= '{buffer.mag[1], buffer.mag[2], sink_mag};
		buffer.phs		<= '{buffer.phs[1], buffer.phs[2], sink_phase};
		sink_done		<= (buffer.bin >= SIZE - 1) ? 1 : 0;
		source_valid	<= 0;
	end
	else if (sink_done && !source_done)								// export of data
	begin
		source_valid	<= 1;
		source_sop		<= (source_pos == 0) ? 1 : 0;
		source_eop		<= (source_pos == NPEAKS-1) ? 1 : 0;
		source_freq		<= (peaks[source_pos].bin << 8) * BIN_WIDTH;
		source_mag		<= peaks[source_pos].mag[1];
		source_phaseA	<= peaks[source_pos].phs[1];
		source_phaseB	<= peaks[source_pos].phs[1];
		
		source_pos		<= source_pos + 1;
		source_done		<= (source_pos == NPEAKS-1) ? 1 : 0;
	end
	else																		// wait
	begin
		source_valid	<= 0;
	end
end

endmodule

`endif
