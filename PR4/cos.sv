// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		cos.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Cosine approximation. Input in pi radians. Testing has shown that
// 			the output is correct within 0.0001.
// Latency: 4 clockticks
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef COS_SV
`define COS_SV

module cos (
	input		wire									clk,					// clock signal
	input		wire									reset,				// synchronous reset
	input		wire signed		[15:0]			sink,					// sink								Q1.15
	output	reg signed		[15:0]			source				// source							Q1.15
);

/*----------------------------------------------------------------------------*/
/*- registers and lookup table -----------------------------------------------*/
/*----------------------------------------------------------------------------*/
// registers
reg signed		[15:0]			out[1:2];							// output WIP						Q1:15
reg									add[0:2];							// add or substract stuff
reg unsigned	[13:0]			z;										//										UQ-1:15
reg unsigned	[15:0]			diff;									//										UQ1:15
reg unsigned	[7:0]				zp;									//										UQ-8:15
reg unsigned	[23:0]			frac;									//										UQ1:23

// lookup table
bit unsigned	[15:0]			lut[0:64] = '{
	16'h7FFF, 16'h7FF8, 16'h7FDA, 16'h7FA9,
	16'h7F64, 16'h7F0B, 16'h7E9F, 16'h7E1F,
	16'h7D8C, 16'h7CE5, 16'h7C2C, 16'h7B5F,
	16'h7A7F, 16'h798C, 16'h7886, 16'h776E,
	16'h7643, 16'h7506, 16'h73B7, 16'h7257,
	16'h70E4, 16'h6F61, 16'h6DCC, 16'h6C26,
	16'h6A6F, 16'h68A8, 16'h66D1, 16'h64EA,
	16'h62F3, 16'h60EE, 16'h5ED9, 16'h5CB5,
	16'h5A84, 16'h5844, 16'h55F7, 16'h539C,
	16'h5135, 16'h4EC1, 16'h4C41, 16'h49B5,
	16'h471E, 16'h447C, 16'h41CF, 16'h3F18,
	16'h3C58, 16'h398E, 16'h36BB, 16'h33E0,
	16'h30FC, 16'h2E12, 16'h2B20, 16'h2827,
	16'h2529, 16'h2224, 16'h1F1A, 16'h1C0C,
	16'h18F9, 16'h15E2, 16'h12C8, 16'h0FAB,
	16'h0C8C, 16'h096B, 16'h0648, 16'h0324,
	16'h0000
};																				// y = cos(x)						UQ1.15

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
always_ff @(posedge clk)
begin
	if (reset)																// reset all
	begin
		out				<= '{default:16'h0000};
		add				<= '{default:1'bx};
		z					<= 16'h0000;
		diff				<= 16'hxxxx;
		zp					<= 8'h00;
		frac				<= 24'h000000;
		source			<= 16'h0000;
	end
	else																		// approximate cos
	begin
		begin																	// stage I
			if (sink == 16'h4000 || sink == 16'hC000)
			begin
				add[0]			<= 1'bx;
				z					<= 16'h0000;
			end
			else if (sink > 16'hC000 || sink < 16'h4000)
			begin
				add[0]			<= 1'b1;
				z					<= sink[15] ? -sink : sink;
			end
			else // (sink > 16'h4000 && sink < 16'hC000)
			begin
				add[0]			<= 1'b0;
				z					<= sink[15] ? sink : -sink;
			end
		end
		begin																	// stage II
			out[1]			<= add[0] ? lut[z[13:8]] : -lut[z[13:8]];
			add[1]			<= add[0];
			diff				<= lut[z[13:8]] - lut[z[13:8] + 1];
			zp					<= z[7:0];
		end
		begin																	// stage III
			out[2]			<= out[1];
			add[2]			<= add[1];
			frac				<= zp * diff;
		end
		begin																	// stage IV
			source			<= add[2] ? out[2] - frac[23:8] : out[2] + frac[23:8];
		end
	end
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/

endmodule

`endif
