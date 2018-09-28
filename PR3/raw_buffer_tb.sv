`timescale 1ns/1ns

module raw_buffer_tb();

// testing parameters
localparam DATA_WIDTH = 14;
localparam BATCH_SIZE = 2048;
localparam RUNS = 3;
localparam time CLKIN_PERIOD = 50ns;
localparam time CLKOUT_PERIOD = 20ns;

// Declare inputs as regs and outputs as wires
bit reset = 0, sink_clk = 0, source_clk = 0, source_ready = 0;
bit signed [5:0] cnt1 = 314;
bit signed [3:0] cnt2 = 42;
wire [DATA_WIDTH-1:0] sin1, sin2, dataIn;
wire ready, source_sop, source_eop, source_valid;
wire [DATA_WIDTH-1:0] dataOut;

// clock generator(s)
always #(CLKIN_PERIOD/2) sink_clk++;
always #(CLKOUT_PERIOD/2) source_clk++;

// sine approx generator
always #(11ns) cnt1++;
always #(13ns) cnt2++;
assign sin1 = (cnt1 < 0) ? (256 * cnt1 + 8 * cnt1 * cnt1) : (256 * cnt1 - 8 * cnt1 * cnt1);
assign sin2 = (cnt2 < 0) ? (256 * cnt2 + 32 * cnt2 * cnt2) : (256 * cnt2 - 32 * cnt2 * cnt2);
assign dataIn = sin1 + sin2;

initial
begin
	#(100ns) reset = 1;
	#(100ns) reset = 0;
	#(500us) $stop(2);
end

byte count = 0;
always @(posedge ready or posedge source_eop)
begin
	if (source_eop)
	begin
		#1 source_ready = 0;
		#(2us) source_ready = 1;
		#1 count++;
		if (count == 3)
		begin
			#1 reset = 1;
			#1 reset = 0;
			#1 count = 0;
		end
	end
	else
	begin
		source_ready = 1;
	end
end

// Connect module(s) to test
raw_buffer #(
	DATA_WIDTH,
	BATCH_SIZE,
	RUNS
) buff (
	.reset			(reset),
	.ready			(ready),
	.sink_clk		(sink_clk),
	.sink_data		(dataIn),
	.source_clk		(source_clk),
	.source_ready	(source_ready),
	.source_sop		(source_sop),
	.source_eop		(source_eop),
	.source_valid	(source_valid),
	.source_data	(dataOut)
);

endmodule
