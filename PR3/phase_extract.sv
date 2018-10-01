`include "fft/fft_int.sv"

module phase_extract #(
	parameter SINK_WIDTH = 14,											// number of bits per entry
	parameter FFT_DEPTH = 11											// number of fft levels
)(
	input		wire							clk,							// clock:	main clock
	input		wire							clk20,						// clock:	20MHz
	input		wire							reset,						// posedge: reset all
	input		wire	[SINK_WIDTH-1:0]	sink							//				connected to antenna
);

// more parameters
localparam	FFT_LENGTH = 2**FFT_DEPTH;								// number of entries over which to apply fft
localparam	FFT_WIDTH = SINK_WIDTH + (FFT_DEPTH+1) / 2;		// number of bits of the fft output
localparam	FFT_PASSES = 3;											// number of fft passes

// wires
wire											time_fft_sop;				// sop signal from time buffer and fft
wire											time_fft_eop;				// eop signal from time buffer and fft
wire											time_fft_valid;			// valid signal from time buffer and fft
wire 		[SINK_WIDTH-1:0]				time_fft_re;				// data bus from time buffer and fft
wire											fft_freq_sop;				// sop signal from fft to frequency buffer
wire											fft_freq_eop;				// sop signal from fft to frequency buffer
wire											fft_freq_valid;			// sop signal from fft to frequency buffer
wire		[FFT_WIDTH-1:0]				fft_freq_re;				// real bus from fft and frequency buffer
wire		[FFT_WIDTH-1:0]				fft_freq_im;				// imaginair bus from fft and frequency buffer

// time domain buffer
time_buffer #(
	SINK_WIDTH,																// number of bits per entry
	FFT_LENGTH,																// number of entries per output batch
	FFT_PASSES																// number of succeeding output batches
) timebuff (
	.reset					(),											// high:		reset all, then reload buffer
	.ready					(),											// high:		ready to output
	.sink_clk				(clk20),										// clock:	input data speed
	.sink_data				(sink),										//				input data bus, connected to antenna A2D
	.source_clk				(clk),										// clock:	output data speed
	.source_ready			(),											// high:		ready for output data
	.source_sop				(time_fft_sop),							// high:		first output package
	.source_eop				(time_fft_eop),							// high:		last output package
	.source_valid			(time_fft_valid),							// high:		output is valid
	.source_data			(time_fft_re)								//				output data bus, connected to fft
);

// fft operator
fft_int #(
	FFT_DEPTH,																// FFT length N = 2**POW
	SINK_WIDTH,																// input width
	FFT_WIDTH                                    				// output width
) fft (
	.clk						(clk),										// clock:	processing speed
	.aclr						(reset),										// high:		reset
	.sink_sop				(time_fft_sop),							// high:		start of input packet, valid if sink_valid is high
	.sink_eop				(time_fft_eop),							// high:		end of input packet
	.sink_valid				(time_fft_valid),							// high:		input is valid
	.sink_Re					(time_fft_re),								// 			real part of input
	.sink_Im					(),											// 			imaginair part of input
	.source_sop				(fft_freq_sop),							// high:		start of output packet, valid if source_valid is high
	.source_eop				(fft_freq_eop),							// high:		end of output packet
	.source_valid			(fft_freq_valid),							// high:		output is valid
	.source_Re				(fft_peak_re),								// 			real part of output
	.source_Im				(fft_peak_im),								// 			imaginair part of output
	.error					()												// high:		something is shit
);

// frequency domain buffer
freq_buffer #(
	FFT_WIDTH, 																// number of bits per entry
	FFT_LENGTH																// number of entries
) freqbuff1 (
	.sink_clk				(clk),										// clock:	input data speed
	.sink_sop				(fft_freq_sop),							// high:		first input entry
	.sink_eop				(fft_freq_eop),							// high:		last input entry
	.sink_valid				(fft_freq_valid),							// high:		input is valid
	.sink_re					(fft_peak_re),								//				input real data bus
	.sink_im					(fft_peak_im)								//				input imaginair data bus
);

endmodule