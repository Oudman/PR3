// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		input_buffer.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	data input buffer with shifted repeated output
// -----------------------------------------------------------------------------
// Control:	sink_clk, source_clk, reset
// Sink:		data
// Source:	sop, eop, valid, data
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef INPUT_BUFFER_SV
`define INPUT_BUFFER_SV

module input_buffer #(
	parameter BATCH_SIZE,												// number of entries per output batch
	parameter RUNS,														// number of succeeding output batches
	parameter DATA_WIDTH													// number of bits per entry
)(
	input		wire							sink_clk,					// input data speed
	input		wire							source_clk,					// output data speed
	input		wire							reset,						// synchronous reset
	input		wire	[DATA_WIDTH-1:0]	sink_data,					//	input data bus					Q<DATA_WIDTH>.0
	output	reg							source_sop,					// first output entry
	output	reg							source_eop,					// last output entry
	output	reg							source_valid,				// output is valid
	output	reg	[DATA_WIDTH-1:0]	source_data					//	output data bus				Q<DATA_WIDTH>.0
);

// more parameters
localparam TOT_SIZE = BATCH_SIZE + RUNS - 1;						// number of entries to allocate memory for

// internal variables
reg		[DATA_WIDTH-1:0]				buffer[0:TOT_SIZE-1];	// buffer data 					Q<DATA_WIDTH>.0
reg		[$clog2(TOT_SIZE)-1:0]		sink_pos;					// sink entry position			UQ<lb(TOT_SIZE)>.0
reg		[$clog2(RUNS)-1:0]			source_offset;				// source entry pos offset		UQ<lb(RUNS)>.0
reg		[$clog2(TOT_SIZE)-1:0]		source_pos;					// source entry position		UQ<lb(TOT_SIZE)>.0
reg											sink_done = 1;				// buffer is fully loaded
reg											source_done = 1;			// RUNS batches have been output

// sink constrol
always @(posedge sink_clk)
begin
	if (reset)																// reset all
	begin
		sink_pos <= 0;
		sink_done <= 0;
	end
	else if (!sink_done)													// continue loading buffer
	begin
		buffer[sink_pos] <= sink_data;
		if (sink_pos == TOT_SIZE)										// buffer is completely loaded
			sink_done <= 1;
		else																	// continue loading buffer next clocktick
			sink_pos <= sink_pos + 1;
	end
end

// source control
always @(posedge source_clk)
begin
	if (reset)																// reset all
	begin
		source_offset <= 0;
		source_pos <= 0;
		source_done <= 0;
	end
	else if (sink_done && !source_done)								// continue output
	begin
		source_valid <= 1;
		source_sop <= (source_pos == source_offset) ? 1 : 0;
		source_eop <= (source_pos == source_offset + BATCH_SIZE - 1) ? 1 : 0;
		source_data <= buffer[source_pos];
		if (source_pos == source_offset + BATCH_SIZE - 1)		// last entry of batch
		begin
			if (source_offset == RUNS-1)								// last batch
				source_done <= 1;
			else																// prepare next batch
			begin
				source_pos <= source_offset + 1;
				source_offset <= source_offset + 1;
			end
		end
		else																	// non-last entry of batch
			source_pos <= source_pos + 1;
	end
	else
	begin
		source_valid <= 0;
		source_sop <= 0;
		source_eop <= 0;
	end
end

endmodule

`endif
