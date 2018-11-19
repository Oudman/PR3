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
	parameter WIDTH,														// magnitude bus width in bits
	parameter BIN,															// bin width (Hz)
	parameter NPEAKS,														// number of peaks
	parameter shortint PEAKSEP[0:NPEAKS]							// borders of peak ranges
)(
	input		wire									clk,					// proccessing speed
	input		wire									reset,				// reset
	input		wire									sink_valid,			// input is valid
	input		wire									sink_sop,			// first input entry
	input		wire									sink_eop,			// last input entry
	input		wire unsigned	[WIDTH-1:0]		sink_mag,			//	real input bus					UQ<WIDTH>.0
	input		wire signed		[15:0]			sink_phase,			//	imaginair input bus			Q3.13
	output	reg									source_valid,		// output is valid
	output	reg									source_sop,			// first output entry
	output	reg									source_eop,			// last output entry
	output	reg signed		[15:0]			source_phaseA,		// phase A output bus			Q3.13
	output	reg signed		[15:0]			source_phaseB		// phase B output bus			Q3.13
);

// more parameters
localparam AWIDTH = $clog2(PEAKSEP[NPEAKS]);						// address width

/*----------------------------------------------------------------------------*/
/*- struct definition and registers ------------------------------------------*/
/*----------------------------------------------------------------------------*/
typedef struct {
	reg signed		[AWIDTH:0]		bin;								// central bin number			Q<AWIDTH+1>.0
	reg unsigned	[WIDTH-1:0]		mag[0:2];						// magnitude						UQ<WIDTH>.0
	reg signed		[15:0]			phs[0:2];						// phase								Q3.13
} chunk;

chunk									buffer;								// input buffer
chunk									peaks[0:NPEAKS-1];				// peak data
reg									sink_done;							// input has been processed
reg									source_done;						// output has been processed

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		buffer.bin		<= -({AWIDTH+1{1'b0}} + 2'd2);
		buffer.mag		<= '{default:{WIDTH{1'b0}}};
		buffer.phs		<= '{default:{16'h0000}};
		for (byte i = 0; i < NPEAKS; i++)
		begin
			peaks[i].bin	<= {AWIDTH+1{1'bx}};
			peaks[i].mag	<= '{default:{WIDTH{1'b0}}};
			peaks[i].phs	<= '{default:{16'hxxxx}};
		end
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_phaseA	<= 16'hxxxx;
		source_phaseB	<= 16'hxxxx;
		sink_done		<= 1'b0;
		source_done		<= 1'b0;
	end
	else if (!sink_done)													// continue with input
	begin
		if (sink_valid)													// only if sink is valid
		begin
			for (byte i = 0; i < NPEAKS; i++)
				if (PEAKSEP[i] <= buffer.bin && buffer.bin < PEAKSEP[i+1] && buffer.mag[1] > peaks[i].mag[1])
					peaks[i]			<= buffer;
			buffer.bin		<= buffer.bin + 1'b1;
			buffer.mag		<= '{buffer.mag[1], buffer.mag[2], sink_mag};
			buffer.phs		<= '{buffer.phs[1], buffer.phs[2], sink_phase};
		end
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_phaseA	<= 16'hxxxx;
		source_phaseB	<= 16'hxxxx;
		sink_done		<= (buffer.bin >= PEAKSEP[NPEAKS]-1) ? 1'b1 : 1'b0;
	end
	else if (!source_done)												// continue with output
	begin
		buffer.bin		<= {AWIDTH+1{1'bx}};
		buffer.mag		<= '{default:{WIDTH{1'bx}}};
		buffer.phs		<= '{default:{16'hxxxx}};
		source_valid	<= 1'b1;
		source_sop		<= 1'bz;
		source_eop		<= 1'bz;
		source_phaseA	<= 16'hzzzz;
		source_phaseB	<= 16'hzzzz;
		source_done		<= 16'h1;
	end
	else																		// wait
	begin
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_phaseA	<= 16'hxxxx;
		source_phaseB	<= 16'hxxxx;
	end
end

endmodule

`endif
