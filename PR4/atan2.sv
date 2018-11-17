// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ LPM_DIVIDE (Intel IP)
//  ~ delay.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Approximate the atan2 of two given numbers. Result in radians.
//				Testing has shown that output is correct within 0.00025 radians for
//				sufficient large input.
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef ATAN2_SV
`define ATAN2_SV

`include "delay.sv"

module atan2 #(
	parameter WIDTH,														// input bus width
	parameter DELAY														// latency in clocktics
)(
	input		wire									clk,					// clock signal
	input		wire									reset,				// synchronous reset
	input		wire signed		[WIDTH-1:0]		sink_y,				// sink, y							Q<WIDTH>.0
	input		wire signed		[WIDTH-1:0]		sink_x,				// sink, x							Q<WIDTH>.0
	output	reg signed		[15:0]			source				// source, atan2(y,x)			Q3.13
);

/*----------------------------------------------------------------------------*/
/*- registers and lookup table -----------------------------------------------*/
/*----------------------------------------------------------------------------*/
// division related
reg unsigned	[2*WIDTH-3:0]	numer;								// numerator						UQ<WIDTH-1>.<WIDTH-1>
reg unsigned	[WIDTH-2:0]		denom;								// denominator						UQ<WIDTH-1>.0
wire unsigned	[2*WIDTH-3:0]	z;										// quotient							UQ<WIDTH-1>.<WIDTH-1>

// other
reg signed		[15:0]			out[0:3];							// output WIP						Q3.13
reg									add[0:3];							// add or substract stuff
reg unsigned	[15:0]			diff;									//										UQ3.13
reg unsigned	[WIDTH-7:0]		zp;									//										UQ-5.<WIDTH-1>
reg unsigned	[WIDTH+9:0]		frac;									//										UQ3.<WIDTH+7>

// lookup table
bit signed		[15:0]			lut[0:32] = '{
	16'h0000, 16'h0100, 16'h01FF, 16'h02FE,
	16'h03FB, 16'h04F6, 16'h05EF, 16'h06E4,
	16'h07D7, 16'h08C6, 16'h09B2, 16'h0A99,
	16'h0B7B, 16'h0C5A, 16'h0D33, 16'h0E07,
	16'h0ED7, 16'h0FA1, 16'h1066, 16'h1126,
	16'h11E0, 16'h1296, 16'h1346, 16'h13F2,
	16'h1498, 16'h1539, 16'h15D6, 16'h166E,
	16'h1701, 16'h1790, 16'h181A, 16'h18A0, 16'h1922};			// y = atan(x)						Q3.13

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always_ff @(posedge clk)
begin
	if (reset)																// reset all
	begin
		numer				<= {2*WIDTH-2{1'b0}};
		denom				<= {WIDTH-1{1'bx}};
		out[0]			<= 16'h0000;
		out[2]			<= 16'h0000;
		out[3]			<= 16'h0000;
		add[0]			<= 1'bx;
		add[2]			<= 1'bx;
		add[3]			<= 1'bx;
		diff				<= 16'hxxxx;
		zp					<= {WIDTH-5{1'b0}};
		frac				<= {WIDTH+11{1'b0}};
		source			<= 16'h0000;
	end
	else																		// approximate atan2
	begin
		begin																	// stage I
			if (sink_x == 0)
			begin
				out[0]			<= (sink_y >= 0) ? 16'h3244 : 16'hCDBC;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_y == 0)
			begin
				out[0]			<= (sink_x >= 0) ? 16'h0000 : 16'h6488;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_x == sink_y)
			begin
				out[0]			<= (sink_x >= 0) ? 16'h1922 : 16'hB49A;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_x == -sink_y)
			begin
				out[0]			<= (sink_x >= 0) ? 16'hE6DE : 16'h4B66;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_x > 0 && sink_y > 0 && sink_x > sink_y)
			begin
				out[0]			<= 16'h0000;
				add[0]			<= 1'b1;
				numer				<=	{sink_y, {WIDTH-1{1'b0}}};
				denom				<=	sink_x;
			end
			else if (sink_x > 0 && sink_y > 0 && sink_x < sink_y)
			begin
				out[0]			<= 16'h3244;
				add[0]			<= 1'b0;
				numer				<=	{sink_x, {WIDTH-1{1'b0}}};
				denom				<=	sink_y;
			end
			else if (sink_x < 0 && sink_y > 0 && -sink_x < sink_y)
			begin
				out[0]			<= 16'h3244;
				add[0]			<= 1'b1;
				numer				<=	{-sink_x, {WIDTH-1{1'b0}}};
				denom				<=	sink_y;
			end
			else if (sink_x < 0 && sink_y > 0 && -sink_x > sink_y)
			begin
				out[0]			<= 16'h6488;
				add[0]			<= 1'b0;
				numer				<=	{sink_y, {WIDTH-1{1'b0}}};
				denom				<=	-sink_x;
			end
			else if (sink_x < 0 && sink_y < 0 && -sink_x > -sink_y)
			begin
				out[0]			<= 16'h9B78;
				add[0]			<= 1'b1;
				numer				<=	{-sink_y, {WIDTH-1{1'b0}}};
				denom				<=	-sink_x;
			end
			else if (sink_x < 0 && sink_y < 0 && -sink_x < -sink_y)
			begin
				out[0]			<= 16'hCDBC;
				add[0]			<= 1'b0;
				numer				<=	{-sink_x, {WIDTH-1{1'b0}}};
				denom				<=	-sink_y;
			end
			else if (sink_x > 0 && sink_y < 0 && sink_x < -sink_y)
			begin
				out[0]			<= 16'hCDBC;
				add[0]			<= 1'b1;
				numer				<=	{sink_x, {WIDTH-1{1'b0}}};
				denom				<=	-sink_y;
			end
			else // (sink_x > 0 && sink_y < 0 && sink_x > -sink_y)
			begin
				out[0]			<= 16'h0000;
				add[0]			<= 1'b0;
				numer				<=	{-sink_y, {WIDTH-1{1'b0}}};
				denom				<=	sink_x;
			end
		end
		begin																	// stage DELAY-2
			out[2]			<= add[1] ? out[1] + lut[z[WIDTH-2:WIDTH-6]] : out[1] - lut[z[WIDTH-2:WIDTH-6]];
			add[2]			<= add[1];
			diff				<= lut[z[WIDTH-2:WIDTH-6] + 1] - lut[z[WIDTH-2:WIDTH-6]];
			zp					<= z[WIDTH-7:0];
		end
		begin																	// stage DELAY-1
			out[3]			<= out[2];
			add[3]			<= add[2];
			frac				<= zp * diff;
		end
		begin																	// stage DELAY
			source			<= add[3] ? out[3] + frac[WIDTH+9:WIDTH-6] : out[3] - frac[WIDTH+9:WIDTH-6];
		end
	end
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// division
lpm_divide #(
	.lpm_pipeline			(DELAY-4),
	.lpm_widthn				(2*WIDTH-2),
	.lpm_widthd				(WIDTH-1),
	.lpm_nrepresentation	("UNSIGNED"),
	.lpm_drepresentation	("UNSIGNED")
) div (
	.clock					(clk),
	.clken					(1'b1),
	.aclr						(reset),
	.numer					(numer),
	.denom					(denom),
	.quotient				(z),
	.remain					()
);

// delay lines
delay #(
	.WIDTH					(16+1),
	.DELAY					(DELAY-4)
) delay (
	.clk						(clk),
	.reset					(reset),
	.sink						({out[0], add[0]}),
	.source					({out[1], add[1]})
);

endmodule

`endif
