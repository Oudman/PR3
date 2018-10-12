`timescale 1ns/1ns

module phase_extract_tb();

// testing parameters
localparam SINK_WIDTH = 14;
localparam FFT_DEPTH = 11;
localparam RUNS = 3;

// Declare inputs as regs and outputs as wires
byte cnt2 = -314, cnt4 = -42, cnt6 = 42, cnt8 = 314;
wire [SINK_WIDTH-1:0] sin2, sin4, sin6, sin8, data;
bit clk50 = 0, clk20 = 0;

// clock generator(s)
always #(10ns) clk50++; // F = 50.0MHz
always #(25ns) clk20++; // F = 20.0MHz

// sine approx generator
always #(5ns) cnt2 = (cnt2 > 49) ? cnt2-99 : cnt2+1; // 200MHz / 100 steps = 2MHz = 10% of 20MHz
always #(5ns) cnt4 = (cnt4 > 48) ? cnt4-98 : cnt4+2; // 200MHz / 50 steps = 4MHz = 20% of 20MHz
always #(5ns) cnt6 = (cnt6 > 47) ? cnt6-97 : cnt6+3; // 200MHz / 33 steps = 6MHz = 30% of 20MHz
always #(5ns) cnt8 = (cnt8 > 46) ? cnt8-96 : cnt8+4; // 200MHz / 25 steps = 8MHz = 40% of 20MHz

assign sin2 = (cnt2 < 0) ? (100 * cnt2 + 2 * cnt2 * cnt2) : (100 * cnt2 - 2 * cnt2 * cnt2);
assign sin4 = (cnt4 < 0) ? (100 * cnt4 + 2 * cnt4 * cnt4) : (100 * cnt4 - 2 * cnt4 * cnt4);
assign sin6 = (cnt6 < 0) ? (100 * cnt6 + 2 * cnt6 * cnt6) : (100 * cnt6 - 2 * cnt6 * cnt6);
assign sin8 = (cnt8 < 0) ? (100 * cnt8 + 2 * cnt8 * cnt8) : (100 * cnt8 - 2 * cnt8 * cnt8);
assign data = sin2 + sin4 + sin6 + sin8;

initial
begin
	#(1ms) $stop(2);
end

// Connect module(s) to test
phase_extract #(
	.SINK_WIDTH				(SINK_WIDTH),								// number of bits per entry
	.FFT_DEPTH				(FFT_DEPTH),								// number of fft levels
	.RUNS						(RUNS)										// number of runs
) pe (
	.clk						(clk50),										// clock:	main clock
	.clk20					(clk20),										// clock:	20MHz
	.sink						(data)										//				connected to antenna
);

endmodule
