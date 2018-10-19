// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		peak_detect.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
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
int											sink_r;						// magnitude of complex input (FP)
int											sink_th;						// phase of complex input in degrees (FP)
int											buff_r[0:BATCH_SIZE-1];	// magnitude data (FP)
int											buff_th[0:BATCH_SIZE-1];// phase data (deg; FP)
bit		[ADDR_WIDTH-1:0]				peaks[0:NPEAKS-1];		// indices of peaks
bit		[$clog2(BATCH_SIZE)-1:0]	sink_pos;					// sink entry position
bit											sink_done;					// high:		buffer is fully loaded
bit		[$clog2(NPEAKS)-1:0]			source_pos;					// source entry position
bit											source_done;				// high:		peaks have all been output

/*----------------------------------------------------------------------------*/
/*- functions and tasks ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// barycentric interpolation (out: FP)
function automatic int barycentric_delta(const ref bit	[$clog2(BATCH_SIZE)-1:0] i);
	automatic int y1 = buff_r[i-1];
	automatic int y2 = buff_r[i];
	automatic int y3 = buff_r[i+1];
	barycentric_delta = ((y3 - y1) <<< 8) / (y1 + y2 + y3);
endfunction

// phase A interpolation (in: int+FP; out: FP)
function automatic int phase_A(const ref bit [$clog2(BATCH_SIZE)-1:0] i, int delta);
	automatic int y2 = buff_th[i];
	automatic int y13 = (delta < 0) ? buff_th[i-1] : buff_th[i+1];
	automatic int abs_delta = (delta < 0) ? -delta : delta;
	automatic int diffA = y13 - y2;
	phase_A = y2 + (abs_delta * diffA >>> 8);
endfunction

// phase B interpolation (in: int+FP; out: FP)
function automatic int phase_B(const ref bit [$clog2(BATCH_SIZE)-1:0] i, int delta);
	automatic int y2 = buff_th[i];
	automatic int y13 = (delta < 0) ? buff_th[i-1] : buff_th[i+1];
	automatic int abs_delta = (delta < 0) ? -delta : delta;
	automatic int diffA = y13 - y2;
	automatic int diffB = (y13 < 0) ? diffA + 92160 : diffA - 92160;
	phase_B = y2 + (abs_delta * diffB >>> 8);
endfunction

// sqrt approximation (max -42.3% and +73.2% deviation) (in: non-FP; out: non-FP)
function automatic int sqrt_h(const ref longint s);
	for (byte i = 0; i < 32; i++)
		sqrt_h[i] = s[2*i+1] || s[2*i];
endfunction

// sqrt approximation (max 0.005% deviation, excluding rounding errors) (in: non-FP; out: non-FP)
function int sqrt(longint s);
	if (s < 2)
		sqrt = s;
	else
	begin
		int tmp;
		sqrt = sqrt_h(s);
		sqrt = (sqrt + s / sqrt) / 2; // max 15% deviation
		sqrt = (sqrt + s / sqrt) / 2; // max 1% deviation
		sqrt = (sqrt + s / sqrt) / 2; // max 0.005% deviation
	end
endfunction

// hypot approximation (in: non-FP; out: FP)
function int hypot(bit signed [DATA_WIDTH-1:0] x, y);
	hypot = sqrt(x*x + y*y) <<< 8;
endfunction

// arctan approximation (max 0.22deg deviation in range [0,1]) (in: FP; out: FP)
// using https://math.stackexchange.com/questions/1098487/atan2-faster-approximation
function int arctan_h(byte z);
	arctan_h = (z * (2949120 - 4009 * (z - 256))) >>> 16;
endfunction

// arctan approximation (max 0.22deg deviation) (in: FP; out: FP)
function automatic int arctan(const ref shortint z);
	if (z >= 0)
	begin
		if (z > 256)
			arctan = 23040 - arctan_h(65536/z);
		else if (z == 256)
			arctan = 11520;
		else
			arctan = arctan_h(z);
	end
	else
	begin
		if (z < -256)
			arctan = arctan_h(65536/-z) - 23040;
		else if (z == -256)
			arctan = -11520;
		else
			arctan = -arctan_h(-z);
	end
endfunction

// atan2 approximation (in: non-FP; out: FP)
// using https://en.wikipedia.org/wiki/Atan2
function int atan2(bit signed [DATA_WIDTH-1:0] x, y);
	if (x == 0)
		atan2 = (y >= 0) ? 23040 : -23040;
	else
	begin
		automatic shortint z = (y <<< 8) / x; // FP
		if (x > 0)
			atan2 = arctan(z);
		else if (y >= 0)
			atan2 = arctan(z) + 46080;
		else
			atan2 = arctan(z) - 46080;
	end
endfunction

/*----------------------------------------------------------------------------*/
/*- main code ----------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
assign sink_r = hypot(sink_re, sink_im);
assign sink_th = atan2(sink_re, sink_im);

always @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		for (bit [$clog2(NPEAKS+1)-1:0] i = 0; i < NPEAKS; i++)
			peaks[i] <= 0;
		sink_pos <= 0;
		sink_done <= 0;
		source_pos <= 0;
		source_done <= 0;
		source_valid <= 0;
	end
	else if (!sink_done && sink_valid)								// loading of buffer
	begin
		for (bit [$clog2(NPEAKS+1)-1:0] i = 0; i < NPEAKS; i++)
			if (EXPEAKS[i] - PEAKDEV <= sink_pos && sink_pos < EXPEAKS[i] + PEAKDEV && sink_r > buff_r[peaks[i]])
				peaks[i] <= sink_pos;
		buff_r[sink_pos] <= sink_r;
		buff_th[sink_pos] <= sink_th;
		sink_done <= (sink_pos == BATCH_SIZE - 1) ? 1 : 0;
		sink_pos <= sink_pos + 1;
	end
	else if (sink_done && !source_done)								// export of data
	begin
		source_valid <= 1;
		source_sop <= (source_pos == 0) ? 1 : 0;
		source_eop <= (source_pos == NPEAKS-1) ? 1 : 0;
		source_freq <= ((peaks[source_pos] <<< 8) + barycentric_delta(peaks[source_pos])) * BIN_WIDTH;
		source_mag <= buff_r[peaks[source_pos]];
		//source_phaseA <= phase_A(peaks[source_pos], barycentric_delta(peaks[source_pos]));
		//source_phaseB <= phase_B(peaks[source_pos], barycentric_delta(peaks[source_pos]));
		source_done <= (source_pos == NPEAKS-1) ? 1 : 0;
		source_pos <= source_pos + 1;
	end
	else																		// wait
	begin
		source_valid <= 0;
	end
end

endmodule