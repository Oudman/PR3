// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		sqrt.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Approximate the square root of a given longint. Testing has shown
//				a maximum deviation of 0.5 bit 99.8% of the time. The other 0.2%
//				consists of output being off by slightly more than half a bit. Note 
//				that the output bus width is one	bit wider than half of the input
//				data bus.
// Latency:	4 clockticks
// -----------------------------------------------------------------------------

`ifndef SQRT_M_SV
`define SQRT_M_SV

module sqrt #(
	parameter WIDTH														// input bus data width
)(
	input		wire									clk,					// clock signal
	input		wire			[WIDTH-1:0]			sink,					// sink (unsigned!)
	output	bit			[WIDTH/2:0]			source				// source (unsigned!)
);

// registers and such
bit	[WIDTH-1:0]						s[0:3];
bit	[WIDTH/2+1:0]					sqrt[0:3];

// the (pipelined) code
always_ff @(posedge clk)
begin
	begin																		// stage I
		for (byte i = 0; i < WIDTH/2; i++)
			sqrt[0][i]		<= sink[2*i] || sink[2*i+1];
		s[0]				<= sink;
	end
	begin																		// stage II
		s[1]				<= (s[0] > 1) ? s[0] - 1 : s[0];
		sqrt[1]			<= (1 + sqrt[0] + s[0] / sqrt[0]) / 2;
	end
	begin																		// stage III
		s[2]				<= s[1];
		sqrt[2]			<= (1 + sqrt[1] + s[1] / sqrt[1]) / 2;
	end
	begin																		// stage IV
		source			<= (1 + sqrt[2] + s[2] / sqrt[2]) / 2;
	end
end

endmodule

`endif
