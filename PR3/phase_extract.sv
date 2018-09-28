`include "fft/fft_int.sv"

module phase_extract #(
	parameter SINK_WIDTH = 14,								// number of bits per entry
	parameter FFT_DEPTH = 11								// number of fft levels
)(
	input		wire							clk,				// clock:	main clock
	input		wire							clk20,			// clock:	20MHz
	input		wire							reset,			// posedge: reset all
	input		wire	[SINK_WIDTH-1:0]	sink				//				connected to antenna
);

// more parameters
parameter	FFT_WIDTH = SINK_WIDTH + FFT_DEPTH;		// number of bits of the fft output

// wires
wire [SINK_WIDTH-1:0]	buff_fft_data;					// data bus between input buffer and fft
wire							buff_fft_sop;					// sop signal between input buffer and fft
wire							buff_fft_eop;					// eop signal between input buffer and fft
wire							buff_fft_valid;				// valid signal between input buffer and fft
wire [FFT_WIDTH-1:0]		fft_peak_re;					// real bus between fft and peak detection
wire [FFT_WIDTH-1:0]		fft_peak_im;					// imaginair bus between fft and peak detection

// buffer to process the antenna input in batches
raw_buffer #(
	SINK_WIDTH,													// number of bits per entry
	2**FFT_DEPTH,												// number of entries per output batch
	3																// number of succeeding output batches
) inpbuff (
	.reset			(),										// high:		reset all, then reload buffer
	.ready			(),										// high:		ready to output
	.sink_clk		(clk20),									// clock:	input data speed
	.sink_data		(sink),									//				input data bus, connected to antenna A2D
	.source_clk		(clk),									// clock:	output data speed
	.source_ready	(),										// high:		ready for output data
	.source_sop		(buff_fft_sop),						// high:		first output package
	.source_eop		(buff_fft_eop),						// high:		last output package
	.source_valid	(buff_fft_valid),						// high:		output is valid
	.source_data	(buff_fft_data)						//				output data bus, connected to fft
);

// fft operator
fft_int #(
	FFT_DEPTH,													// FFT length N = 2**POW
	SINK_WIDTH,													// input width
	FFT_WIDTH                                    	// output width
) fft (
	.clk				(clk),									// clock:	processing speed
	.aclr				(reset),									// high:		reset
	.sink_sop		(buff_fft_sop),						// high:		start of input packet, valid if sink_valid is high
	.sink_eop		(buff_fft_eop),						// high:		end of input packet
	.sink_valid		(buff_fft_valid),						// high:		input is valid
	.sink_Re			(buff_fft_data),						// 			real part of input
	.sink_Im			(),										// 			imaginair part of input
	.source_sop		(),										// high:		start of output packet, valid if source_valid is high
	.source_eop		(),										// high:		end of output packet
	.source_valid	(),										// high:		output is valid
	.source_Re		(fft_peak_re),							// 			real part of output
	.source_Im		(fft_peak_re),							// 			imaginair part of output
	.error			()											// high:		something is shit
);

endmodule