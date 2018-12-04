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
// Purpose:	Approximate the atan2 of two given numbers. Result in pi radians.
//				Testing has shown that output is correct within 0.0001 radians.
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
	input		wire signed		[WIDTH-1:0]		sink_y,				// sink: y							Q<WIDTH>.0
	input		wire signed		[WIDTH-1:0]		sink_x,				// sink: x							Q<WIDTH>.0
	output	reg signed		[15:0]			source				// source							Q1.15
);

/*----------------------------------------------------------------------------*/
/*- registers and lookup table -----------------------------------------------*/
/*----------------------------------------------------------------------------*/
// division related
reg unsigned	[2*WIDTH-3:0]	numer;								// numerator						UQ<WIDTH-1>.<WIDTH-1>
reg unsigned	[WIDTH-2:0]		denom;								// denominator						UQ<WIDTH-1>.0
wire unsigned	[2*WIDTH-3:0]	z;										// quotient							UQ<WIDTH-1>.<WIDTH-1>

// other
reg signed		[15:0]			out[0:3];							// output WIP						Q1.15
reg									add[0:3];							// add or substract stuff
reg unsigned	[15:0]			diff;									//										UQ1.15
reg unsigned	[WIDTH-7:0]		zp;									//										UQ-5.<WIDTH-1>
reg unsigned	[WIDTH+9:0]		frac;									//										UQ1.<WIDTH+9>

// lookup table
bit unsigned	[15:0]			lut[0:32] = '{
	16'h0000, 16'h0146, 16'h028B, 16'h03CF,
	16'h0511, 16'h0651, 16'h078E, 16'h08C7,
	16'h09FC, 16'h0B2C, 16'h0C58, 16'h0D7E,
	16'h0E9F, 16'h0FBA, 16'h10CE, 16'h11DD,
	16'h12E5, 16'h13E6, 16'h14E1, 16'h15D5,
	16'h16C3, 16'h17AA, 16'h188B, 16'h1965,
	16'h1A39, 16'h1B06, 16'h1BCD, 16'h1C8F,
	16'h1D4A, 16'h1E00, 16'h1EB0, 16'h1F5B,
	16'h2000
};																				// y = atan(x)						UQ1.15

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
		zp					<= {WIDTH-6{1'b0}};
		frac				<= {WIDTH+10{1'b0}};
		source			<= 16'h0000;
	end
	else																		// approximate atan2
	begin
		begin																	// stage I
			if (sink_x == 0)
			begin
				out[0]			<= (sink_y >= 0) ? 16'h4000 : 16'hC000;
				add[0]			<= 1'bx;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_y == 0)
			begin
				out[0]			<= (sink_x >= 0) ? 16'h0000 : 16'h8000;
				add[0]			<= 1'bx;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_x == sink_y)
			begin
				out[0]			<= (sink_x >= 0) ? 16'h2000 : 16'hA000;
				add[0]			<= 1'bx;
				numer				<=	{2*WIDTH-2{1'b0}};
				denom				<=	{WIDTH-1{1'bx}};
			end
			else if (sink_x == -sink_y)
			begin
				out[0]			<= (sink_x >= 0) ? 16'hE000 : 16'h6000;
				add[0]			<= 1'bx;
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
				out[0]			<= 16'h4000;
				add[0]			<= 1'b0;
				numer				<=	{sink_x, {WIDTH-1{1'b0}}};
				denom				<=	sink_y;
			end
			else if (sink_x < 0 && sink_y > 0 && -sink_x < sink_y)
			begin
				out[0]			<= 16'h4000;
				add[0]			<= 1'b1;
				numer				<=	{-sink_x, {WIDTH-1{1'b0}}};
				denom				<=	sink_y;
			end
			else if (sink_x < 0 && sink_y > 0 && -sink_x > sink_y)
			begin
				out[0]			<= 16'h8000;
				add[0]			<= 1'b0;
				numer				<=	{sink_y, {WIDTH-1{1'b0}}};
				denom				<=	-sink_x;
			end
			else if (sink_x < 0 && sink_y < 0 && -sink_x > -sink_y)
			begin
				out[0]			<= 16'h8000;
				add[0]			<= 1'b1;
				numer				<=	{-sink_y, {WIDTH-1{1'b0}}};
				denom				<=	-sink_x;
			end
			else if (sink_x < 0 && sink_y < 0 && -sink_x < -sink_y)
			begin
				out[0]			<= 16'hC000;
				add[0]			<= 1'b0;
				numer				<=	{-sink_x, {WIDTH-1{1'b0}}};
				denom				<=	-sink_y;
			end
			else if (sink_x > 0 && sink_y < 0 && sink_x < -sink_y)
			begin
				out[0]			<= 16'hC000;
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
