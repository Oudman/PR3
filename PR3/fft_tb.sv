`timescale 1ns/1ns

module fft_tb();

// testing parameters
localparam FFT_DEPTH = 11;
localparam SINK_WIDTH = 14;
localparam FFT_WIDTH = SINK_WIDTH + (FFT_DEPTH+1) / 2;

// Declare inputs as regs and outputs as wires
bit signed [4:0] cnt = 42;	// 2^5=32 ticks period
wire [SINK_WIDTH-1:0] sin, time_fft_re;
bit signed [SINK_WIDTH-1:0] time_fft_im = 0;
bit clk = 0, reset = 0, time_fft_sop = 0, time_fft_eop = 0, time_fft_valid = 0;
wire fft_freq_sop, fft_freq_eop, fft_freq_valid, error;
wire signed [FFT_WIDTH-1:0] fft_peak_re, fft_peak_im;
shortreal fft_peak_r, fft_peak_theta;

// clock generator(s)
always #(25ns) clk++; // F = 20.0MHz

// sine approx generator
always #(10ns) cnt++; // F = 100MHz / 32 = 3.13MHz = 15.6% of 20MHz
assign sin = (cnt < 0) ? (512 * cnt + 32 * cnt * cnt) : (512 * cnt - 32 * cnt * cnt);
assign time_fft_re = sin;

assign fft_peak_r = $hypot(shortreal'(fft_peak_re), shortreal'(fft_peak_im));
assign fft_peak_theta = $atan2(fft_peak_im, fft_peak_re);

initial
begin
	#(100ns) reset = 1;
	#(100ns) reset = 0;
	#(100ns) time_fft_valid = 1;
	forever
	begin
		time_fft_sop = 1;
		repeat(1) @(posedge clk);
		time_fft_sop = 0;
		repeat(2**FFT_DEPTH-2) @(posedge clk);
		time_fft_eop = 1;
		repeat(1) @(posedge clk);
		time_fft_eop = 0;
	end
end

initial
begin
	#(1ms) $stop(2);
end

// Connect module(s) to test
fft_int #(
	.POW						(FFT_DEPTH),								// FFT length N = 2**POW
	.DATA_WIDTH				(SINK_WIDTH),								// input width
	.RES_WIDTH				(FFT_WIDTH)									// output width
) fft (
	.clk						(clk),										// clock:	processing speed
	.aclr						(reset),										// high:		reset
	.sink_sop				(time_fft_sop),							// high:		start of input packet, valid if sink_valid is high
	.sink_eop				(time_fft_eop),							// high:		end of input packet
	.sink_valid				(time_fft_valid),							// high:		input is valid
	.sink_Re					(time_fft_re),								// 			real part of input
	.sink_Im					(time_fft_im),								// 			imaginair part of input
	.source_sop				(fft_freq_sop),							// high:		start of output packet, valid if source_valid is high
	.source_eop				(fft_freq_eop),							// high:		end of output packet
	.source_valid			(fft_freq_valid),							// high:		output is valid
	.source_Re				(fft_peak_re),								// 			real part of output
	.source_Im				(fft_peak_im),								// 			imaginair part of output
	.error					(error)										// high:		something is shit
);

endmodule
