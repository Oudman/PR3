`timescale 1ns/1ns

module maxheap_tb();

// testing parameters
localparam DATA_WIDTH = 10;
localparam PRIO_WIDTH = 32;
localparam TOT_SIZE = 4;

// Declare inputs as regs and outputs as wires
bit reset, clk, valid;
bit signed [DATA_WIDTH-1:0] data = 0;
bit signed [PRIO_WIDTH-1:0] prio;

// clock generator(s)
always #(10ns) clk++; // F = 50.0MHz
always #(20ns) data++;

initial
begin
	reset = 0;
	valid = 0;
	prio = 0;
	#(30ns) reset = 1;
	#(30ns) reset = 0;
	valid = 1;
	#(20ns) prio = 90;
	#(20ns) prio = 30;
	#(20ns) prio = 70;
	#(20ns) prio = 50;
	#(20ns) prio = 40;
	#(20ns) prio = 70;
	#(20ns) prio = 70;
	#(20ns) prio = 95;
	
end

initial
begin
	#(1ms) $stop(2);
end

// Connect module(s) to test
maxheap #(
	.DATA_WIDTH				(DATA_WIDTH),
	.PRIO_WIDTH				(PRIO_WIDTH),
	.TOT_SIZE				(TOT_SIZE)
) mh (
	.reset					(reset),
	.sink_clk				(clk),
	.sink_valid				(valid),
	.sink_data				(data),
	.sink_prio				(prio)
);

endmodule
