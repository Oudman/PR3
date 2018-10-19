module input_buffer #(
	parameter BATCH_SIZE = 2048,										// number of entries per output batch
	parameter RUNS = 3,													// number of succeeding output batches
	parameter DATA_WIDTH = 14											// number of bits per entry
)(
	input		wire							sink_clk,					// clock:	input data speed
	input		wire							source_clk,					// clock:	output data speed
	input		wire							reset,						// high: 	synchronous reset, synced with sink_clk
	input		wire	[DATA_WIDTH-1:0]	sink_data,					//				input data bus, connected to antenna A2D
	output	reg							source_sop,					// high:		first output entry
	output	reg							source_eop,					// high:		last output entry
	output	reg							source_valid,				// high:		output is valid
	output	reg	[DATA_WIDTH-1:0]	source_data					//				output data bus, connected to fft
);

// more parameters
localparam TOT_SIZE = BATCH_SIZE + RUNS - 1;						// number of entries to allocate memory for

// internal variables
reg		[DATA_WIDTH-1:0]				buffer[0:TOT_SIZE-1];	// buffer data
reg		[$clog2(TOT_SIZE)-1:0]		sink_pos;					// sink entry position
reg		[$clog2(RUNS)-1:0]			source_offset;				// source entry position offset
reg		[$clog2(TOT_SIZE)-1:0]		source_pos;					// source entry position
reg											sink_done = 1;				// high:		buffer is fully loaded
reg											source_done = 1;			// high:		RUNS batches have been output

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