module freq_buffer #(
	parameter DATA_WIDTH = 20,											// number of bits per entry
	parameter TOT_SIZE = 2048											// number of entries
)(
	input		wire							sink_clk,					// clock:	input data speed
	input		wire							sink_sop,					// high:		first input entry
	input		wire							sink_eop,					// high:		last input entry
	input		wire							sink_valid,					// high:		input is valid
	input		wire	[DATA_WIDTH-1:0]	sink_re,						//				input real data bus
	input		wire	[DATA_WIDTH-1:0]	sink_im						//				input imaginair data bus
);

// internal variables
reg		[DATA_WIDTH-1:0]				buff_re[0:TOT_SIZE-1];	// real data
reg		[DATA_WIDTH-1:0]				buff_im[0:TOT_SIZE-1];	// imaginair data
reg		[$clog2(TOT_SIZE)-1:0]		sink_pos;					// sink entry position

// sink constrol
always @(posedge sink_clk)
begin
	if (sink_valid)
	begin
		if (sink_sop)
			sink_pos = 0;
		buff_re[sink_pos] = sink_re;
		buff_im[sink_pos] = sink_im;
		if (!sink_eop)
			sink_pos++;
	end
end

endmodule