`timescale 1ns/1ns

module input_buffer_tb();

// testing parameters
localparam DATA_WIDTH = 14;
localparam BATCH_SIZE = 2048;
localparam RUNS = 3;
localparam time CLKIN_PERIOD = 50ns;
localparam time CLKOUT_PERIOD = 20ns;

// Declare inputs as regs and outputs as wires
bit reset = 0, sink_clk = 0, source_clk = 0;
bit signed [5:0] cnt1 = 314;
bit signed [3:0] cnt2 = 42;
wire [DATA_WIDTH-1:0] sin1, sin2, dataIn;
wire source_sop, source_eop, source_valid;
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
	forever begin
		reset = 1;
		#(10ns);
		reset = 0;
		#(1990ns);
	end
end


initial
begin
	#(2ms) $stop(2);
end

// Connect module(s) to test
input_buffer #(
	.DATA_WIDTH		(DATA_WIDTH),
	.BATCH_SIZE		(BATCH_SIZE),
	.RUNS				(RUNS)
) buff (
	.reset			(reset),
	.sink_clk		(sink_clk),
	.sink_data		(dataIn),
	.source_clk		(source_clk),
	.source_sop		(source_sop),
	.source_eop		(source_eop),
	.source_valid	(source_valid),
	.source_data	(dataOut)
);

endmodule
