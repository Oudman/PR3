`include "fft/fft_int.sv"

module phase_extract #(
	parameter SINK_WIDTH = 14,											// number of bits per entry
	parameter FFT_DEPTH = 11,											// number of fft levels
	parameter RUNS	= 3													// number of runs
)(
	input		wire							clk,							// clock:	main clock
	input		wire							clk20,						// clock:	20MHz
	input		wire	[SINK_WIDTH-1:0]	sink							//				connected to antenna
);

// more parameters
localparam	FFT_LENGTH = 2**FFT_DEPTH;								// number of entries over which to apply fft
localparam	FFT_WIDTH = SINK_WIDTH + (FFT_DEPTH+1) / 2;		// number of bits of the fft output

/*----------------------------------------------------------------------------*/
/*- wire declarations --------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// time_buffer related
reg							time_reset;
wire							time_ready;
wire							time_start;
wire							time_clk;
wire	[SINK_WIDTH-1:0]	time_sink_data;
wire							time_fft_sop;
wire							time_fft_eop;
wire							time_fft_valid;
wire 	[SINK_WIDTH-1:0]	time_fft_re;
bit 	[SINK_WIDTH-1:0]	time_fft_im = 0;

// fft_int related
wire							fft_clk;
bit							fft_reset = 0;
wire							fft_freq_sop;
wire							fft_freq_eop;
wire							fft_freq_valid;
wire	[FFT_WIDTH-1:0]	fft_freq_re;
wire	[FFT_WIDTH-1:0]	fft_freq_im;
wire							fft_error;

// freq_buffer related

/*----------------------------------------------------------------------------*/
/*- wire assignments ---------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
assign time_clk = clk20;
assign time_sink_data = sink;
assign fft_clk = clk;

/*----------------------------------------------------------------------------*/
/*- module synchronization and control ---------------------------------------*/
/*----------------------------------------------------------------------------*/
// load time buffer
initial
begin
	@(posedge time_clk);
	time_reset = 1;
	@(posedge time_clk);
	time_reset = 0;
	@(posedge fft_clk);
	fft_reset = 1;
	@(posedge fft_clk);
	fft_reset = 0;
end

// load fft
assign time_start = time_ready; // assumes fft is always ready

/*----------------------------------------------------------------------------*/
/*- module instances ---------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// time domain buffer
time_buffer #(
	SINK_WIDTH,
	FFT_LENGTH,
	RUNS
) timebuff (
	.reset					(time_reset),
	.ready					(time_ready),
	.start					(time_start),
	.sink_clk				(time_clk),
	.sink_data				(time_sink_data),
	.source_clk				(fft_clk),
	.source_sop				(time_fft_sop),
	.source_eop				(time_fft_eop),
	.source_valid			(time_fft_valid),
	.source_data			(time_fft_re)
);

// fft operator
fft_int #(
	FFT_DEPTH,
	SINK_WIDTH,
	FFT_WIDTH
) fft (
	.clk						(fft_clk),
	.aclr						(fft_reset),
	.sink_sop				(time_fft_sop),
	.sink_eop				(time_fft_eop),
	.sink_valid				(time_fft_valid),
	.sink_Re					(time_fft_re),
	.sink_Im					(time_fft_im),
	.source_sop				(fft_freq_sop),
	.source_eop				(fft_freq_eop),
	.source_valid			(fft_freq_valid),
	.source_Re				(fft_freq_re),
	.source_Im				(fft_freq_im),
	.error					(fft_error)
);

// frequency domain buffer
freq_buffer #(
	FFT_WIDTH,
	FFT_LENGTH / 2
) freqbuff1 (
	.sink_clk				(fft_clk),
	.sink_sop				(fft_freq_sop),
	.sink_valid				(fft_freq_valid),
	.sink_re					(fft_freq_re),
	.sink_im					(fft_freq_im)
);

endmodule