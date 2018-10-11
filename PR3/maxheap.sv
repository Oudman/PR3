module maxheap #(
	parameter DATA_WIDTH = 10,											// data bits per entry
	parameter PRIO_WIDTH = 32,											// data bits per priority
	parameter TOT_SIZE = 4												// maximal number of entries
)(
	input		wire							reset,						// high: 	reset all
	input		wire							sink_clk,					// clock:	input data speed
	input		wire							sink_valid,					// high:		input is valid
	input		wire	[DATA_WIDTH-1:0]	sink_data,					//				input data bus
	input		wire	[PRIO_WIDTH-1:0]	sink_prio					//				input priority bus
);

// internal variables
reg		[DATA_WIDTH-1:0]				heap_data[0:TOT_SIZE-1];// heap data
reg		[PRIO_WIDTH-1:0]				heap_prio[0:TOT_SIZE-1];// heap priorities



// sink constrol
always @(posedge sink_clk)
begin
	if (reset)
	begin
		for (byte i = 0; i < TOT_SIZE; i++)
		begin
			heap_data[i] <= 0;
			heap_prio[i] <= 0;
		end
	end
	else if (sink_valid)
	begin
		if (sink_prio > heap_prio[0])
		begin
			heap_data[0] <= sink_data;
			heap_prio[0] <= sink_prio;
		end
		for (byte i = 1; i < TOT_SIZE; i++)
		begin
			if (sink_prio > heap_prio[i])
			begin
				heap_data[i] <= (sink_prio > heap_prio[i-1]) ? heap_data[i-1] : sink_data;
				heap_prio[i] <= (sink_prio > heap_prio[i-1]) ? heap_prio[i-1] : sink_prio;
			end
		end
	end
end

endmodule