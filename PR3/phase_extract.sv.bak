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
/*- wire/reg declarations ----------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// input_buffer related
bit											time_reset;
wire											time_fft_sop;
wire											time_fft_eop;
wire											time_fft_valid;
wire 			[SINK_WIDTH-1:0]			time_fft_re;

// fft_int related
bit											fft_reset;
wire											fft_peak_sop;
wire											fft_peak_eop;
wire											fft_peak_valid;
wire			[FFT_WIDTH-1:0]			fft_peak_re;
wire			[FFT_WIDTH-1:0]			fft_peak_im;
wire											fft_error;					// unused

// peak_detect related
bit											peak_reset;
wire											peak_sop;
wire											peak_eop;
wire											peak_valid;
wire signed	[31:0]						peak_freq;
wire signed	[31:0]						peak_mag;
wire signed	[31:0]						peak_phase;


/*----------------------------------------------------------------------------*/
/*- module synchronization and control ---------------------------------------*/
/*----------------------------------------------------------------------------*/
// load time buffer
initial
begin
	@(posedge clk20);
	time_reset = 1;
	@(posedge clk20);
	time_reset = 0;
end

// load fft
initial
begin
	@(posedge clk);
	fft_reset = 1;
	@(posedge clk);
	fft_reset = 0;
end

/*----------------------------------------------------------------------------*/
/*- module instances ---------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// input buffer
input_buffer #(
	.BATCH_SIZE				(FFT_LENGTH),
	.RUNS						(RUNS),
	.DATA_WIDTH				(SINK_WIDTH)
) buff (
	.sink_clk				(clk20),
	.source_clk				(clk),
	.reset					(time_reset),
	.sink_data				(sink),
	.source_sop				(time_fft_sop),
	.source_eop				(time_fft_eop),
	.source_valid			(time_fft_valid),
	.source_data			(time_fft_re)
);

// fft operator
fft_int #(
	.POW						(FFT_DEPTH),
	.DATA_WIDTH				(SINK_WIDTH),
	.RES_WIDTH				(FFT_WIDTH)
) fft (
	.clk						(clk),
	.aclr						(fft_reset),
	.sink_sop				(time_fft_sop),
	.sink_eop				(time_fft_eop),
	.sink_valid				(time_fft_valid),
	.sink_Re					(time_fft_re),
	.sink_Im					(0),
	.source_sop				(fft_peak_sop),
	.source_eop				(fft_peak_eop),
	.source_valid			(fft_peak_valid),
	.source_Re				(fft_peak_re),
	.source_Im				(fft_peak_im),
	.error					(fft_error)
);

// peak detection
peak_detect #(
	.BATCH_SIZE				(FFT_LENGTH/2),
	.DATA_WIDTH				(FFT_WIDTH)
) pd (
	.clk						(clk),
	.reset					(peak_reset),
	.sink_sop				(fft_peak_sop),
	.sink_eop				(fft_peak_eop),
	.sink_valid				(fft_peak_valid),
	.sink_re					(fft_peak_re),
	.sink_im					(fft_peak_im),
	.source_sop				(peak_sop),
	.source_eop				(peak_eop),
	.source_valid			(peak_valid),
	.source_freq			(peak_freq),
	.source_mag				(peak_mag),
	.source_phase			(peak_phase)
);

endmodule