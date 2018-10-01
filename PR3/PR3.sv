module PR3 #(
	parameter DATA_WIDTH = 14											// number of input bits per antenna
)(
	input		wire							clk,							// clock:	50MHz
	input		wire							reset,						// posedge: reset
	input		wire	[DATA_WIDTH-1:0]	data1,						//				connected to antenna #1
	input		wire	[DATA_WIDTH-1:0]	data2,						//				connected to antenna #2
	input		wire	[DATA_WIDTH-1:0]	data3							//				connected to antenna #3
);

// wires
wire clk20;

// pll module to generate a 20MHz clock signal
pll pll (
	.refclk					(clk),										// clock:	50MHz input
	.rst						(reset),										// posedge:	reset
	.outclk_0 				(clk20)										// clock:	20MHz output
);

// phase extraction on antenna #1
phase_extract #(
	DATA_WIDTH,																// number of input bits
	11																			// fft over 2^11=2048 entris
) pe1 (
	.clk						(clk),										// clock:	main
	.clk20					(clk20),										// clock:	20MHz
	.reset					(reset),										// posedge:	reset all
	.sink						(data1)										//				connected to antenna #1
);


endmodule

