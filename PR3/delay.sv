// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		delay.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Outputs given input after a given delay.
// Latency:	DELAY clockticks
// -----------------------------------------------------------------------------

`ifndef DELAY_SV
`define DELAY_SV

module delay #(
	parameter WIDTH,														// input bus data width
	parameter DELAY														// number of clockticks to delay
)(
	input		wire									clk,					// clock signal
	input		wire			[WIDTH-1:0]			sink,					// sink
	output	bit			[WIDTH-1:0]			source				// source
);

generate
if (DELAY <= 1)
begin :gen1
	// the code
	always_ff @(posedge clk)
	begin
		begin																	// stage I
			source			<= sink;
		end
	end
end
else
begin :genX
	// registers and such
	bit	[WIDTH-1:0]						buff[0:DELAY-2];

	// the (pipelined) code
	always_ff @(posedge clk)
	begin
		begin																	// stage I
			buff[0]			<= sink;
		end
		begin																	// stages II - (n-1)
			for (byte i = 0; i < DELAY-2; i++)
				buff[i+1]		<= buff[i];
		end
		begin																	// stage n
			source			<= buff[DELAY-2];
		end
	end
end
endgenerate

endmodule

`endif
