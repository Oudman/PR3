`timescale 1ns/1ns

module phase_extract_tb();

// testing parameters
localparam SINK_WIDTH = 14;
localparam FFT_DEPTH = 11;
localparam RUNS = 3;

// Declare inputs as regs and outputs as wires
bit signed [4:0] cnt = 42;	// 2^5=32 ticks period
wire [SINK_WIDTH-1:0] sin, data;
bit clk50 = 0, clk20 = 0;

// clock generator(s)
always #(10ns) clk50++; // F = 50.0MHz
always #(25ns) clk20++; // F = 20.0MHz

// sine approx generator
always #(10ns) cnt++; // F = 100MHz / 32 = 3.13MHz = 15.6% of 20MHz
assign sin = (cnt < 0) ? (512 * cnt + 32 * cnt * cnt) : (512 * cnt - 32 * cnt * cnt);
assign data = sin;

initial
begin
	#(1ms) $stop(2);
end

// Connect module(s) to test
phase_extract #(
	SINK_WIDTH,																// number of bits per entry
	FFT_DEPTH,																// number of fft levels
	RUNS																		// number of runs
) pe (
	.clk						(clk50),										// clock:	main clock
	.clk20					(clk20),										// clock:	20MHz
	.sink						(data)										//				connected to antenna
);

endmodule
