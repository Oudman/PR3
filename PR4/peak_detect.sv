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
	parameter shortint PEAKSEP[0:NPEAKS]							// borders of peak ranges
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
	output	reg signed		[15:0]			source_phaseA,		// phase A output bus			Q1.15
	output	reg signed		[15:0]			source_phaseB		// phase B output bus			Q1.15
);

// more parameters
localparam BWIDTH = $clog2(PEAKSEP[NPEAKS]);						// bin address width
localparam PWIDTH = $clog2(NPEAKS);									// peak address width

/*----------------------------------------------------------------------------*/
/*- struct definition and registers ------------------------------------------*/
/*----------------------------------------------------------------------------*/
// struct definition
typedef struct {
	reg signed		[BWIDTH:0]		bin;								// central bin number			Q<BWIDTH+1>.0
	reg unsigned	[WIDTH-1:0]		mag[0:2];						// magnitude						UQ<WIDTH>.0
	reg signed		[15:0]			phs[0:2];						// phase								Q1.15
} chunk;

// peak data
chunk									peaks[0:NPEAKS-1];				// peak data

// sink related
reg									sink_done;							// input has been processed
chunk									buffer;								// input buffer

// source related
reg									source_done;						// output has been processed
reg									wip[0:7];							// execute pipeline step
reg									mp[0:7];								// switch between m and p
reg unsigned	[PWIDTH-1:0]	pk[0:7];								// peak on which to calculate	UQ<PWIDTH>.0
reg signed		[15:0]			cosin;								// cosine input					Q1.15
wire signed		[15:0]			cosout;								// cosine output					Q1.15
reg signed		[WIDTH+15:0]	stcos;								// 									Q<WIDTH+1>.15
reg signed		[2*WIDTH-1:0]	numer;								// division numerator			Q<WIDTH>.<WIDTH>
reg signed		[WIDTH-1:0]		denom;								// division denominator			Q<WIDTH>.0
wire signed		[2*WIDTH-1:0]	z;										// division quotient				Q<WIDTH>.<WIDTH>
reg signed		[15:0]			dm;									// delta m							Q1.15
reg signed		[15:0]			dp;									// delta p							Q1.15
reg signed		[15:0]			delta[5:6];							// delta								Q1.15
reg signed		[15:0]			diff;									// phase difference				Q1.15
reg signed		[32:0]			addA;									// 									Q3.30
reg signed		[32:0]			addB;									// 									Q3.30

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// sink control
always_ff @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		buffer.bin		<= -({BWIDTH+1{1'b0}} + 2'd2);
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
		buffer.mag		<= '{buffer.mag[1], buffer.mag[2], sink_mag};
		buffer.phs		<= '{buffer.phs[1], buffer.phs[2], sink_phase};
		for (byte i = 0; i < NPEAKS; i++)
			if (PEAKSEP[i] <= buffer.bin && buffer.bin < PEAKSEP[i+1] && buffer.mag[1] > peaks[i].mag[1])
				peaks[i]			<= buffer;
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

// source control
always_ff @(posedge clk)
begin
	if (reset || sink_eop)												// reset all
	begin
		source_done		<= 1'b0;
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_phaseA	<= 16'hxxxx;
		source_phaseB	<= 16'hxxxx;
		wip[0]			<= 1'b1;
		wip[2]			<= 1'b0;
		wip[4:7]			<= '{default:{1'b0}};
		mp[0]				<= 1'b0;
		mp[2]				<= 1'bx;
		mp[4:7]			<= '{default:{1'bx}};
		pk[0]				<= {PWIDTH{1'b0}};
		pk[2]				<= {PWIDTH{1'bx}};
		pk[4:7]			<= '{default:{PWIDTH{1'bx}}};
		cosin				<= 16'hxxxx;
		stcos				<= {WIDTH+16{1'bx}};
		numer				<= {2*WIDTH{1'bx}};
		denom				<= {WIDTH{1'bx}};
		dm					<= 16'hxxxx;
		dp					<= 16'hxxxx;
		delta[5:6]		<= '{default:16'hxxxx};
		diff				<= 16'hxxxx;
		addA				<= {33{1'bx}};
		addB				<= {33{1'bx}};
	end
	else if (sink_done && !source_done)								// continue with output
	begin
		begin																	// stage I
			if (wip[0])														// execute this pipeline step
			begin
				if (mp[0])													// cos(a-b)
				begin
					cosin				<= peaks[pk[0]].phs[0] - peaks[pk[0]].phs[1];
					pk[0]				<= pk[0];
					wip[0]			<= 1'b1;
				end
				else															// cos(b-c)
				begin
					cosin				<= peaks[pk[0]].phs[2] - peaks[pk[0]].phs[1];
					pk[0]				<= pk[0] + 1'b1;
					wip[0]			<= (pk[0] == NPEAKS-1) ? 1'b0 : 1'b1;
				end
				mp[0]				<= ~mp[0];
			end
			else																// do not execute this pipeline step
			begin
				wip[0]			<= 1'b0;
				mp[0]				<= 1'bx;
				pk[0]				<= {PWIDTH{1'bx}};
			end
		end
		begin																	// stages II - IV
			// handled by cos and delay1
		end
		begin																	// stage V
			if (wip[1])														// execute this pipeline step
			begin
				if (mp[1])													// r*cos(a-c)
					stcos				<= peaks[pk[1]].mag[0] * cosout;
				else															// t*cos(b-c)
					stcos				<= peaks[pk[1]].mag[2] * cosout;
				mp[2]				<= mp[1];
				pk[2]				<= pk[1];
			end
			else																// do not execute this pipeline step
			begin
				stcos				<= {WIDTH+16{1'bx}};
				mp[2]				<= 1'bx;
				pk[2]				<= {PWIDTH{1'bx}};
			end
			wip[2]			<= wip[1];
		end
		begin																	// stage VI
			if (wip[2])														// execute this pipeline step
			begin
				numer				<= stcos[WIDTH+14:WIDTH-1] << WIDTH;
				if (mp[2])													// s - r*cos(a-c)
					denom				<= peaks[pk[2]].mag[1] - stcos[WIDTH+14:WIDTH-1];
				else															// t*cos(b-c) - s
					denom				<= stcos[WIDTH+14:WIDTH-1] - peaks[pk[2]].mag[1];
			end
			else																// do not execute this pipeline step
			begin
				numer				<= {2*WIDTH{1'bx}};
				denom				<= {WIDTH{1'bx}};
			end
		end
		begin																	// stages VII - <2*WIDTH+5>
			// handled by div and delay2
		end
		begin																	// stage <2*WIDTH+6>
			if (wip[3])														// execute this pipeline step
			begin
				if (mp[3])													// calculate dm
				begin
					dm					<= z[WIDTH:WIDTH-15];
					dp					<= 16'hxxxx;
				end
				else															// calculate dp
				begin
					dm					<= dm;
					dp					<= z[WIDTH:WIDTH-15];
				end
				mp[4]				<= mp[3];
				pk[4]				<= pk[3];
			end
			else																// do not execute this pipeline step
			begin
				dm					<= 16'hxxxx;
				dp					<= 16'hxxxx;
				mp[4]				<= 1'bx;
				pk[4]				<= {PWIDTH{1'bx}};
			end
			wip[4]			<= wip[3];
		end
		begin																	// stage <2*WIDTH+7>
			if (wip[4])														// execute this pipeline step
			begin
				if (mp[4])													// wait for dp
					delta[5]			<= 16'hxxxx;
				else															// both dp and dm are available
				begin
					if (dp > 0 && dm > 0)
						delta[5]			<= dp;
					else
						delta[5]			<= dm;
				end
				mp[5]				<= mp[4];
				pk[5]				<= pk[4];
			end
			else																// do not execute this pipeline step
			begin
				delta[5]			<= 16'hxxxx;
				mp[5]				<= 1'bx;
				pk[5]				<= {PWIDTH{1'bx}};
			end
			wip[5]			<= wip[4];
		end
		begin																	// stage <2*WIDTH+8>
			if (wip[5])														// execute this pipeline step
			begin
				if (mp[5])													// wait for delta
					diff				<= 16'hxxxx;
				else															// delta is available
				begin
					if (delta[5] < 0)										// interpolate between first and middle bin
						diff				<= peaks[pk[5]].phs[0] - peaks[pk[5]].phs[1];
					else														// interpolate between middle and last bin
						diff				<= peaks[pk[5]].phs[2] - peaks[pk[5]].phs[1];
				end
				delta[6]			<= delta[5];
				mp[6]				<= mp[5];
				pk[6]				<= pk[5];
			end
			else																// do not execute this pipeline step
			begin
				diff				<= 16'hxxxx;
				delta[6]			<= 16'hxxxx;
				mp[6]				<= 1'bx;
				pk[6]				<= {PWIDTH{1'bx}};
			end
			wip[6]			<= wip[5];
		end
		begin																	// stage <2*WIDTH+9>
			if (wip[6])														// execute this pipeline step
			begin
				if (mp[6])													// wait for diff
				begin
					addA				<= {33{1'bx}};
					addB				<= {33{1'bx}};
				end
				else															// perform interpolation addition
				begin
					addA				<= {diff[15], diff[15:0]} * delta[6];
					addB				<= {~diff[15], diff[15:0]} * delta[6];
				end
				mp[7]				<= mp[6];
				pk[7]				<= pk[6];
			end
			else																// do not execute this pipeline step
			begin
				addA				<= {33{1'bx}};
				addB				<= {33{1'bx}};
				mp[7]				<= 1'bx;
				pk[7]				<= {PWIDTH{1'bx}};
			end
			wip[7]			<= wip[6];
		end
		begin																	// stage <2*WIDTH+10>
			if (wip[6] && !mp[7])										// execute this pipeline step
			begin
				source_valid	<= 1'b1;
				source_sop		<= (pk[7] == {PWIDTH{1'b0}}) ? 1'b1 : 1'b0;
				source_eop		<= (pk[7] == NPEAKS-1) ? 1'b1 : 1'b0;
				source_phaseA	<= peaks[pk[7]].phs[1] + addA[30:15];
				source_phaseB	<= peaks[pk[7]].phs[1] + addB[30:15];
				source_done		<= (pk[7] == NPEAKS-1) ? 1'b1 : 1'b0;
			end
			else																// do not execute this pipeline step
			begin
				source_valid	<= 1'b0;
				source_sop		<= 1'b0;
				source_eop		<= 1'b0;
				source_phaseA	<= 16'hxxxx;
				source_phaseB	<= 16'hxxxx;
			end
		end
	end
	else
	begin
		source_valid	<= 1'b0;
		source_sop		<= 1'b0;
		source_eop		<= 1'b0;
		source_phaseA	<= 16'hxxxx;
		source_phaseB	<= 16'hxxxx;
		wip[0]			<= 1'bx;
		wip[2]			<= 1'bx;
		wip[4:7]			<= '{default:{1'bx}};
		mp[0]				<= 1'bx;
		mp[2]				<= 1'bx;
		mp[4:7]			<= '{default:{1'bx}};
		pk[0]				<= {PWIDTH{1'bx}};
		pk[2]				<= {PWIDTH{1'bx}};
		pk[4:7]			<= '{default:{PWIDTH{1'bx}}};
		cosin				<= 16'hxxxx;
		stcos				<= {WIDTH+16{1'bx}};
		numer				<= {2*WIDTH{1'bx}};
		denom				<= {WIDTH{1'bx}};
		dm					<= 16'hxxxx;
		dp					<= 16'hxxxx;
		delta[5:6]		<= '{default:16'hxxxx};
		diff				<= 16'hxxxx;
		addA				<= {33{1'bx}};
		addB				<= {33{1'bx}};
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
	.sink						({wip[0], mp[0], pk[0]}),
	.source					({wip[1], mp[1], pk[1]})
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
	.WIDTH					(PWIDTH+1),
	.DELAY					(2*WIDTH)
) delay2 (
	.clk						(clk),
	.reset					(reset || sink_eop),
	.sink						({wip[2], mp[2], pk[2]}),
	.source					({wip[3], mp[3], pk[3]})
);

endmodule

`endif
