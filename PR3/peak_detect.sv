module peak_detect #(
	parameter BATCH_SIZE	= 1024,										// number of entries per input batch
	parameter DATA_WIDTH	= 20											// number of bits per entry
)(
	input		wire							clk,							// clock:	input data speed
	input		wire							reset,						// high:		synchronous reset
	input		wire							sink_sop,					// high: 	first input entry
	input		wire							sink_eop,					// high:		last input entry
	input		wire							sink_valid,					// high:		input is valid
	input		wire	[DATA_WIDTH-1:0]	sink_re,						//				real part of input data
	input		wire	[DATA_WIDTH-1:0]	sink_im,						//				imaginair part of input data
	output	reg							source_sop,					// high:		first output entry
	output	reg							source_eop,					// high:		last output entry
	output	reg							source_valid,				// high:		output is valid
	output	int							source_freq,				// 			frequency of peak (FP)
	output	int							source_mag,					// 			magnitude of peak (FP)
	output	int							source_phase				// 			phase of peak (FP)
);

// Fixed point notation (FP) is reguarly used in this module:
// - 32 bit two's complement
// - the lower 8 bits represent the fractional part

endmodule