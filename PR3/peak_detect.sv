// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		peak_detect.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ LPM_DIVIDE (Intel IP)
//  ~ delay.sv
//  ~ cos.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	fft output peak detection, peak interpolation and peak data output
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

`include "delay.sv"
`include "cos.sv"

module peak_detect #(
	parameter WIDTH,														// magnitude bus width in bits
	parameter BIN,															// bin width (Hz)
	parameter NPEAKS,														// number of peaks
	parameter shortint PEAKSEP[0:NPEAKS],							// borders of peak ranges
	parameter NBPP															// number of bins per peak
)(
	input		wire									clk,					// proccessing speed
	input		wire									reset,				// reset
	input		wire									sink_valid,			// input is valid
	input		wire									sink_sop,			// first input entry
	input		wire									sink_eop,			// last input entry
	input		wire unsigned	[WIDTH-1:0]		sink_mag,			//	real input bus					UQ<WIDTH>.0
	input		wire signed		[15:0]			sink_phase,			//	imaginair input bus			Q1.15
	output	reg									source_valid,		// output is valid
	output	reg									source_sop,			// first output entry
	output	reg									source_eop,			// last output entry
	output	reg 				[31:0]			source_data			// serialized output data
);

// more parameters
localparam BWIDTH = $clog2(PEAKSEP[NPEAKS]);						// bin address width
localparam PWIDTH = $clog2(NPEAKS);									// peak address width
localparam LWIDTH = 2;													// chunk side lobe width // TODO: should always be NBPP/2
localparam NBINS = 2 * LWIDTH + 1;									// number of bins per chunk
localparam NBWIDTH = $clog2(NBINS);									// chunk bin address width

/*----------------------------------------------------------------------------*/
/*- struct definition and registers ------------------------------------------*/
/*----------------------------------------------------------------------------*/
// struct definition
typedef struct {
	reg signed		[BWIDTH:0]		bin;								// central bin number			Q<BWIDTH+1>.0
	reg unsigned	[WIDTH-1:0]		mag[0:NBINS-1];				// magnitude						UQ<WIDTH>.0
	reg signed		[15:0]			phs[0:NBINS-1];				// phase								Q1.15
	reg unsigned	[23:0]			ifreq;							// interpolated frequency		UQ24.0
	reg signed		[15:0]			iphsA;							// interpolated peak phase A	Q1.15
	reg signed		[15:0]			iphsB;							// interpolated peak phase B	Q1.15
} chunk;

// peak data
chunk									peaks[0:NPEAKS-1];				// peak data

// sink related
reg									sink_done;							// input has been processed
chunk									buffer;								// input buffer

// processing logic related
reg									logic_done;							// processing logic is completed
reg									wip[0:9];							// execute pipeline step
reg									mp[0:9];								// switch between m and p
reg unsigned	[PWIDTH-1:0]	pk[0:9];								// peak on which to calculate	UQ<PWIDTH>.0
reg signed		[15:0]			cosin;								// cosine input					Q1.15
wire signed		[15:0]			cosout;								// cosine output					Q1.15
reg signed		[WIDTH+15:0]	stcos;								// 									Q<WIDTH+1>.15
reg signed		[2*WIDTH-1:0]	numer;								// division numerator			Q<WIDTH>.<WIDTH>
reg signed		[WIDTH-1:0]		denom;								// division denominator			Q<WIDTH>.0
wire signed		[2*WIDTH-1:0]	z;										// division quotient				Q<WIDTH>.<WIDTH>
reg signed		[15:0]			dm;									// delta m							Q1.15
reg signed		[15:0]			dp;									// delta p							Q1.15
reg signed		[15:0]			delta[7:8];							// delta								Q1.15
reg signed		[15:0]			diff;									// phase difference				Q1.15
reg signed		[32:0]			addA;									// 									Q3.30
reg signed		[32:0]			addB;									// 									Q3.30
reg unsigned	[23:0]			fbin;									//	frequency in bins				UQ<BWIDTH>.<24-BWIDTH>
reg unsigned	[47-BWIDTH:0]	fbin_;								//	frequency in bins				UQ24.<24-BWIDTH>

// source related
reg									source_done;						// output has been completed
reg unsigned	[PWIDTH-1:0]	peak;									// selected peak					UQ<BWIDTH>.0
reg									ir;									// interpolated or raw data
reg unsigned	[NBWIDTH:0]		pos;									// data

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// sink control
always_ff @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		buffer.bin		<= {BWIDTH+1{1'b0}} - 1'b1 - LWIDTH;
		buffer.mag		<= '{default:{WIDTH{1'b0}}};
		buffer.phs		<= '{default:{16'h0000}};
		for (byte i = 0; i < NPEAKS; i++)
		begin
			peaks[i].bin	<= {BWIDTH+1{1'bx}};
			peaks[i].mag	<= '{default:{WIDTH{1'b0}}};
			peaks[i].phs	<= '{default:{16'hxxxx}};
		end
		sink_done		<= 1'b0;
	end
	else if (sink_valid && !sink_done)								// continue with input
	begin
		buffer.bin		<= buffer.bin + 1'b1;
		buffer.mag[0:NBINS-2] <= buffer.mag[1:NBINS-1];
		buffer.mag[NBINS-1] <= sink_mag;
		buffer.phs[0:NBINS-2] <= buffer.phs[1:NBINS-1];
		buffer.phs[NBINS-1] <= sink_phase;
		for (byte i = 0; i < NPEAKS; i++)
		begin
			if (PEAKSEP[i] <= buffer.bin && buffer.bin < PEAKSEP[i+1] && buffer.mag[LWIDTH] > peaks[i].mag[LWIDTH])
			begin
				peaks[i].bin	<= buffer.bin;
				peaks[i].mag	<= buffer.mag;
				peaks[i].phs	<= buffer.phs;
			end
		end
		sink_done		<= (buffer.bin >= PEAKSEP[NPEAKS]-1) ? 1'b1 : 1'b0;
	end
end

// Quinn's first estimator
//	Define:
//		r := x[k-1].mag
//		s := x[k].mag
//		t := x[k+1].mag
//		a := x[k-1].phs
//		b := x[k].phs
//		c := x[k+1].phs
//	Now:
//		am := r/s * cos(a-b)
//		dm := (r*cos(a-b)) / (s - r*cos(a-b))
//		ap := t/s * cos(c-b)
//		dp := (t*cos(c-b)) / (t*cos(c-b) - s)
// And:
// 	if (dp > 0) AND (dm > 0)
// 		d := dp
// 	else
// 		d := dm
// Finally:
// 	k’ := k + d

// processing logic control
always_ff @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		logic_done		<= 1'b0;
		for (byte i = 0; i < NPEAKS; i++)
		begin
			peaks[i].ifreq	<= 24'hxxxxxx;
			peaks[i].iphsA	<= 16'hxxxx;
			peaks[i].iphsB	<= 16'hxxxx;
		end
		wip[0]			<= 1'b1;
		wip[1]			<= 1'b0;
		wip[3:4]			<= '{default:{1'b0}};
		wip[6:9]			<= '{default:{1'b0}};
		mp[0]				<= 1'b1;
		mp[1]				<= 1'bx;
		mp[3:4]			<= '{default:{1'bx}};
		mp[6:9]			<= '{default:{1'bx}};
		pk[0]				<= {PWIDTH{1'b0}};
		pk[1]				<= {PWIDTH{1'bx}};
		pk[3:4]			<= '{default:{PWIDTH{1'bx}}};
		pk[6:9]			<= '{default:{PWIDTH{1'bx}}};
		cosin				<= 16'hxxxx;
		stcos				<= {WIDTH+16{1'bx}};
		numer				<= {2*WIDTH{1'bx}};
		denom				<= {WIDTH{1'bx}};
		dm					<= 16'hxxxx;
		dp					<= 16'hxxxx;
		delta[7:8]		<= '{default:16'hxxxx};
		diff				<= 16'hxxxx;
		addA				<= {33{1'bx}};
		addB				<= {33{1'bx}};
		fbin				<= 24'hxxxxxx;
		fbin_				<= {48-BWIDTH{1'bx}};
	end
	else if (sink_done && !logic_done)								// continue with processing
	begin
		begin																	// stage I
			if (wip[0])														// execute this pipeline step
			begin
				if (mp[0])													// cos(a-b)
				begin
					cosin				<= peaks[pk[0]].phs[LWIDTH-1] - peaks[pk[0]].phs[LWIDTH];
					wip[0]			<= 1'b1;
					mp[0]				<= 1'b0;
					pk[0]				<= pk[0];
				end
				else															// cos(c-b)
				begin
					cosin				<= peaks[pk[0]].phs[LWIDTH+1] - peaks[pk[0]].phs[LWIDTH];
					wip[0]			<= (pk[0] == NPEAKS-1) ? 1'b0 : 1'b1;
					mp[0]				<= (pk[0] < NPEAKS-1) ? 1'b1 : 1'bx;
					pk[0]				<= pk[0] + 1'b1;
				end
				mp[1]				<= mp[0];
				pk[1]				<= pk[0];
			end
			else																// do not execute this pipeline step
			begin
				cosin				<= 16'hxxxx;
				wip[0]			<= 1'b0;
				mp[0]				<= 1'bx;
				pk[0]				<= {PWIDTH{1'bx}};
				mp[1]				<= 1'bx;
				pk[1]				<= {PWIDTH{1'bx}};
			end
			wip[1]			<= wip[0];
		end
		begin																	// stages II - V
			// handled by cos and delay1
		end
		begin																	// stage VI
			if (wip[2])														// execute this pipeline step
			begin
				if (mp[2])													// r*cos(a-c)
					stcos				<= $signed({1'b0, peaks[pk[2]].mag[LWIDTH-1]}) * cosout;
				else															// t*cos(b-c)
					stcos				<= $signed({1'b0, peaks[pk[2]].mag[LWIDTH+1]}) * cosout;
				mp[3]				<= mp[2];
				pk[3]				<= pk[2];
			end
			else																// do not execute this pipeline step
			begin
				stcos				<= {WIDTH+16{1'bx}};
				mp[3]				<= 1'bx;
				pk[3]				<= {PWIDTH{1'bx}};
			end
			wip[3]			<= wip[2];
		end
		begin																	// stage VII
			if (wip[3])														// execute this pipeline step
			begin
				numer				<= stcos[WIDTH+14:15] << WIDTH;
				if (mp[3])													// s - r*cos(a-c)
					denom				<= peaks[pk[3]].mag[LWIDTH] - stcos[WIDTH+14:15];
				else															// t*cos(b-c) - s
					denom				<= stcos[WIDTH+14:15] - peaks[pk[3]].mag[LWIDTH];
				mp[4]				<= mp[3];
				pk[4]				<= pk[3];
			end
			else																// do not execute this pipeline step
			begin
				numer				<= {2*WIDTH{1'bx}};
				denom				<= {WIDTH{1'bx}};
				mp[4]				<= 1'bx;
				pk[4]				<= {PWIDTH{1'bx}};
			end
			wip[4]			<= wip[3];
		end
		begin																	// stages VIII - <2*WIDTH+8>
			// handled by div and delay2
		end
		begin																	// stage <2*WIDTH+9>
			if (wip[5])														// execute this pipeline step
			begin
				if (mp[5])													// calculate dm
				begin
					dm					<= z[WIDTH:WIDTH-15];
					dp					<= 16'hxxxx;
				end
				else															// calculate dp
				begin
					dm					<= dm;
					dp					<= z[WIDTH:WIDTH-15];
				end
				mp[6]				<= mp[5];
				pk[6]				<= pk[5];
			end
			else																// do not execute this pipeline step
			begin
				dm					<= 16'hxxxx;
				dp					<= 16'hxxxx;
				mp[6]				<= 1'bx;
				pk[6]				<= {PWIDTH{1'bx}};
			end
			wip[6]			<= wip[5];
		end
		begin																	// stage <2*WIDTH+10>
			if (wip[6])														// execute this pipeline step
			begin
				if (mp[6])													// wait for dp
					delta[7]			<= 16'hxxxx;
				else															// both dp and dm are available
				begin
					if (dp > 0 && dm > 0)
						delta[7]			<= dp;
					else
						delta[7]			<= dm;
				end
				mp[7]				<= mp[6];
				pk[7]				<= pk[6];
			end
			else																// do not execute this pipeline step
			begin
				delta[7]			<= 16'hxxxx;
				mp[7]				<= 1'bx;
				pk[7]				<= {PWIDTH{1'bx}};
			end
			wip[7]			<= wip[6];
		end
		begin																	// stage <2*WIDTH+11>
			if (wip[7])														// execute this pipeline step
			begin
				if (mp[7])													// wait for delta
				begin
					diff				<= 16'hxxxx;
					fbin				<= 24'hxxxxxx;
				end
				else															// delta is available
				begin
					if (delta[7] < 0)										// interpolate between first and middle bin
						diff				<= peaks[pk[7]].phs[LWIDTH-1] - peaks[pk[7]].phs[LWIDTH];
					else														// interpolate between middle and last bin
						diff				<= peaks[pk[7]].phs[LWIDTH+1] - peaks[pk[7]].phs[LWIDTH];
					fbin				<= $signed({1'b0, peaks[pk[7]].bin, {24-BWIDTH{1'b0}}}) + $signed(delta[7][15:(BWIDTH-9)]);
				end
				delta[8]			<= (delta[7] < 16'sh0000) ? -delta[7] : delta[7];
				mp[8]				<= mp[7];
				pk[8]				<= pk[7];
			end
			else																// do not execute this pipeline step
			begin
				diff				<= 16'hxxxx;
				fbin				<= 24'hxxxxxx;
				delta[8]			<= 16'hxxxx;
				mp[8]				<= 1'bx;
				pk[8]				<= {PWIDTH{1'bx}};
			end
			wip[8]			<= wip[7];
		end
		begin																	// stage <2*WIDTH+12>
			if (wip[8])														// execute this pipeline step
			begin
				if (mp[8])													// wait for diff
				begin
					addA				<= {33{1'bx}};
					addB				<= {33{1'bx}};
					fbin_				<= {48-BWIDTH{1'bx}};
				end
				else															// perform interpolation addition
				begin
					addA				<= $signed({1'b0, diff}) * delta[8];
					addB				<= $signed({1'b1, diff}) * delta[8];
					fbin_				<= fbin * BIN;
				end
				mp[9]				<= mp[8];
				pk[9]				<= pk[8];
			end
			else																// do not execute this pipeline step
			begin
				addA				<= {33{1'bx}};
				addB				<= {33{1'bx}};
				fbin_				<= {48-BWIDTH{1'bx}};
				mp[9]				<= 1'bx;
				pk[9]				<= {PWIDTH{1'bx}};
			end
			wip[9]			<= wip[8];
		end
		begin																	// stage <2*WIDTH+13>
			if (wip[9] && !mp[9])										// execute this pipeline step
			begin
				peaks[pk[9]].ifreq <= fbin_[47-BWIDTH:24-BWIDTH];
				peaks[pk[9]].iphsA <= peaks[pk[9]].phs[LWIDTH] + addA[30:15];
				peaks[pk[9]].iphsB <= peaks[pk[9]].phs[LWIDTH] + addB[30:15];
				logic_done		<= (pk[9] == NPEAKS-1) ? 1'b1 : 1'b0;
			end
		end
	end
	else
	begin
		mp[1]				<= 1'bx;
		mp[3:4]			<= '{default:{1'bx}};
		mp[6:9]			<= '{default:{1'bx}};
		pk[1]				<= {PWIDTH{1'bx}};
		pk[3:4]			<= '{default:{PWIDTH{1'bx}}};
		pk[6:9]			<= '{default:{PWIDTH{1'bx}}};
		cosin				<= 16'hxxxx;
		stcos				<= {WIDTH+16{1'bx}};
		numer				<= {2*WIDTH{1'bx}};
		denom				<= {WIDTH{1'bx}};
		dm					<= 16'hxxxx;
		dp					<= 16'hxxxx;
		delta[7:8]		<= '{default:16'hxxxx};
		diff				<= 16'hxxxx;
		addA				<= {33{1'bx}};
		addB				<= {33{1'bx}};
		fbin				<= 24'hxxxxxx;
		fbin_				<= {48-BWIDTH{1'bx}};
	end
end

// source control
always_ff @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		source_done		<= 1'b0;
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_data		<= 32'hxxxxxxxx;
		peak				<= {PWIDTH{1'b0}};
		ir					<= 1'b1;
		pos				<= {NBWIDTH{1'b0}};
	end
	else if (logic_done && !source_done)							// continue with output
	begin
		source_valid	<= 1'b1;
		source_sop		<= (peak == {PWIDTH{1'b0}}) ? 1'b1 : 1'b0;
		source_eop		<= (peak == NPEAKS-1'b1) ? 1'b1 : 1'b0;
		if (ir)																// write interpolated data
		begin
			if (pos == {NBWIDTH{1'b0}})								// write interpolated frequency
			begin
				source_data 	<= {8'h00, peaks[peak].ifreq};
				pos				<= pos + 1'b1;
			end
			else																// write interpolated phases
			begin
				source_data 	<= {peaks[peak].iphsA, peaks[peak].iphsB};
				pos				<= {NBWIDTH{1'b0}};
				ir					<= 1'b0;
			end
		end
		else																	// write raw data
		begin
			source_data		<= {peaks[peak].mag[pos][WIDTH-1:WIDTH-16], peaks[peak].phs[pos]};
			if (pos == NBINS-1)
			begin																// last bin
				peak				<= peak + 1'b1;
				ir					<= 1'b1;
				pos				<= {NBWIDTH{1'b0}};
				source_done		<= (peak == NPEAKS-1) ? 1'b1 : 1'b0;
			end
			else																// non-last bin
				pos				<= pos + 1'b1;
		end
	end
	else
	begin
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_data		<= 32'hxxxxxxxx;
	end
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// cosine
cos cos (
	.clk						(clk),
	.reset					(reset),
	.sink						(cosin),
	.source					(cosout)
);

// delay during cos
delay #(
	.WIDTH					(PWIDTH+2),
	.DELAY					(4)
) delay1 (
	.clk						(clk),
	.reset					(reset || sink_eop),
	.sink						({wip[1], mp[1], pk[1]}),
	.source					({wip[2], mp[2], pk[2]})
);

// division
lpm_divide #(
	.lpm_pipeline			(2*WIDTH),
	.lpm_widthn				(2*WIDTH),
	.lpm_widthd				(WIDTH),
	.lpm_nrepresentation	("SIGNED"),
	.lpm_drepresentation	("SIGNED")
) div (
	.clock					(clk),
	.clken					(1'b1),
	.aclr						(reset),
	.numer					(numer),
	.denom					(denom),
	.quotient				(z),
	.remain					()
);

// delay during division
delay #(
	.WIDTH					(PWIDTH+2),
	.DELAY					(2*WIDTH)
) delay2 (
	.clk						(clk),
	.reset					(reset || sink_eop),
	.sink						({wip[4], mp[4], pk[4]}),
	.source					({wip[5], mp[5], pk[5]})
);

endmodule

`endif
