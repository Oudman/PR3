// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		atan2.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Approximate the atan2 of two given numbers. Result in radians.
//				Testing has shown that output is correct within 0.0004 radians for
//				sufficient large input.
// Latency:	4 clockticks
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef ATAN_LIM_SV
`define ATAN_LIM_SV

module atan2 #(
	parameter WIDTH														// input bus width
)(
	input		wire									clk,					// clock signal
	input		wire		signed	[WIDTH-1:0]	sink_x,				// sink, x							Q<WIDTH>.0
	input		wire		signed	[WIDTH-1:0]	sink_y,				// sink, y							Q<WIDTH>.0
	output	shortint	signed					source				// source, atan2(Y,X)			Q3.13
);

// registers and such
shortint 	signed							out[0:2];				// output WIP						Q3.13
bit												add[0:2];				// add or substract stuff
bit			unsigned	[WIDTH-1:0]			z;							// ratio between x and y		UQ0.<WIDTH>
bit			unsigned	[WIDTH-5:0]			zp;						// 									UQ-4.<WIDTH>
shortint 	unsigned							diff;						//										UQ3.13
bit			unsigned	[WIDTH+11:0]		frac;						//										UQ3.<WIDTH+9>
const bit				[WIDTH-1:0]			zeros = 0;				// WIDTH concatenated zero's

// lookup table
shortint unsigned						lut[0:16] = '{
	16'h0000, 16'h0200, 16'h03FB, 16'h05EF, 16'h07D8, 16'h09B2,
	16'h0B7B, 16'h0D34, 16'h0ED7, 16'h1067, 16'h11E1, 16'h1347,
	16'h1499, 16'h15D7, 16'h1702, 16'h181B, 16'h1923};

// the (pipelined) code
always_ff @(posedge clk)
begin
	begin																		// stage I
		if (sink_x == 0)
		begin
			out[0]			<= (sink_y >= 0) ? 16'h3244 : 16'hCDBC;
			z					<= zeros;
		end
		else if (sink_y == 0)
		begin
			out[0]			<= (sink_x >= 0) ? 16'h0000 : 16'h6488;
			z					<= zeros;
		end
		else if (sink_x == sink_y)
		begin
			out[0]			<= (sink_x >= 0) ? 16'h1922 : 16'hB49A;
			z					<= zeros;
		end
		else if (sink_x == -sink_y)
		begin
			out[0]			<= (sink_x >= 0) ? 16'hE6DE : 16'h4B66;
			z					<= zeros;
		end
		else if (sink_x > 0 && sink_y > 0 && sink_x >= sink_y)
		begin
			out[0]			<= 16'h0000;
			add[0]			<= 1;
			z					<= {sink_y, zeros} / sink_x;
		end
		else if (sink_x > 0 && sink_y > 0 && sink_x < sink_y)
		begin
			out[0]			<= 16'h3244;
			add[0]			<= 0;
			z					<= {sink_x, zeros} / sink_y;
		end
		else if (sink_x < 0 && sink_y > 0 && -sink_x < sink_y)
		begin
			out[0]			<= 16'h3244;
			add[0]			<= 1;
			z					<= {-sink_x, zeros} / sink_y;
		end
		else if (sink_x < 0 && sink_y > 0 && -sink_x >= sink_y)
		begin
			out[0]			<= 16'h6488;
			add[0]			<= 0;
			z					<= {sink_y, zeros} / {-sink_x};
		end
		else if (sink_x < 0 && sink_y < 0 && -sink_x >= -sink_y)
		begin
			out[0]			<= 16'h9B78;
			add[0]			<= 1;
			z					<= {-sink_y, zeros} / {-sink_x};
		end
		else if (sink_x < 0 && sink_y < 0 && -sink_x < -sink_y)
		begin
			out[0]			<= 16'hCDBC;
			add[0]			<= 0;
			z					<= {-sink_x, zeros} / {-sink_y};
		end
		else if (sink_x > 0 && sink_y < 0 && sink_x < -sink_y)
		begin
			out[0]			<= 16'hCDBC;
			add[0]			<= 1;
			z					<= {sink_x, zeros} / {-sink_y};
		end
		else // (sink_x > 0 && sink_y < 0 && sink_x >= -sink_y)
		begin
			out[0]			<= 16'h0000;
			add[0]			<= 0;
			z					<= {-sink_y, zeros} / sink_x;
		end
	end
	begin																		// stage II
		out[1]			<= add[0] ? out[0] + lut[z[WIDTH-1:WIDTH-4]] : out[0] - lut[z[WIDTH-1:WIDTH-4]];
		add[1]			<= add[0];
		diff				<= lut[z[WIDTH-1:WIDTH-4] + 1] - lut[z[WIDTH-1:WIDTH-4]];
		zp					<= z[WIDTH-5:0];
	end
	begin																		// stage III
		out[2]			<= out[1];
		add[2]			<= add[1];
		frac				<= zp * diff;
	end
	begin																		// stage IV
		source			<= add[2] ? out[2] + frac[WIDTH+11:WIDTH-4] : out[2] - frac[WIDTH+11:WIDTH-4];
	end
end

endmodule

`endif
