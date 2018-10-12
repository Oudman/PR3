module peak_detect #(
	parameter BATCH_SIZE	= 1024,										// number of entries per input batch
	parameter DATA_WIDTH	= 20											// number of bits per entry
)(
	input		wire							clk,							// clock:	input data speed
	input		wire							reset,						// high:		synchronous reset
	input		wire							sink_sop,					// high: 	first input entry
	input		wire							sink_eop,					// high:		last input entry
	input		wire							sink_valid,					// high:		input is valid
	input		wire	[DATA_WIDTH-1:0]	sink_re,						//				real part of input data
	input		wire	[DATA_WIDTH-1:0]	sink_im,						//				imaginair part of input data
	output	bit							source_sop,					// high:		first output entry
	output	bit							source_eop,					// high:		last output entry
	output	bit							source_valid,				// high:		output is valid
	output	int							source_freq,				// 			frequency of peak (FP)
	output	int							source_mag,					// 			magnitude of peak (FP)
	output	int							source_phase				// 			phase of peak (FP)
);

// Fixed point notation (FP) is reguarly used in this module:
// - 32 bit two's complement
// - the lower 8 bits represent the fractional part

// more parameters
localparam PEAKS = 4;													// number of peaks to detect
localparam ADDR_WIDTH = $clog2(BATCH_SIZE);						// memory address width


/*----------------------------------------------------------------------------*/
/*- wire/logic declarations --------------------------------------------------*/
/*----------------------------------------------------------------------------*/
int											sink_r;						// radius of complex input
int											sink_th;						// phase of complex input
int											buff_r[0:BATCH_SIZE-1];	// magnitude data (FP)
int											buff_th[0:BATCH_SIZE-1];// phase data in degrees (FP)
bit		[ADDR_WIDTH-1:0]				maxheap[0:PEAKS-1];		// indices of peaks
bit		[$clog2(BATCH_SIZE)-1:0]	sink_pos;					// sink entry position
bit											sink_done;					// high:		buffer is fully loaded
bit		[$clog2(PEAKS)-1:0]			source_pos;					// source entry position
bit											source_done;				// high:		peaks have all been output

/*----------------------------------------------------------------------------*/
/*- functions and tasks ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// sqrt approximation (max -42.3% and +73.2% deviation) (in: non-FP; out non-FP)
function automatic int sqrt_h(const ref longint s);
	for (byte i = 0; i < 32; i++)
		sqrt_h[i] = s[2*i+1] || s[2*i];
endfunction

// sqrt approximation (max 0.005% deviation, excluding rounding errors) (in: non-FP; out non-FP)
function int sqrt(longint s);
	if (s < 2)
		sqrt = s;
	else
	begin
		int tmp;
		sqrt = sqrt_h(s);
		sqrt = (sqrt + s / sqrt) / 2; // max 15% deviation
		sqrt = (sqrt + s / sqrt) / 2; // max 1% deviation
		sqrt = (sqrt + s / sqrt) / 2; // max 0.005% deviation
	end
endfunction

// hypot approximation (in: non-FP; out: FP)
function int hypot(bit signed [DATA_WIDTH-1:0] x, y);
	hypot = sqrt(x*x + y*y) <<< 8;
endfunction

// arctan approximation (max 0.22deg deviation in range [0,1]) (in: FP; out: FP)
// using https://math.stackexchange.com/questions/1098487/atan2-faster-approximation
function int arctan_h(int z);
	arctan_h = (z * (2949120 - 4009 * (z - 256))) >>> 16;
endfunction

// arctan approximation (max 0.22deg deviation) (in: FP; out: FP)
function automatic int arctan(const ref int z);
	if (z >= 0)
	begin
		if (z > 256)
			arctan = 23040 - arctan_h(65536/z);
		else
			arctan = arctan_h(z);
	end
	else
	begin
		if (z < -256)
			arctan = arctan_h(65536/-z) - 23040;
		else
			arctan = -arctan_h(-z);
	end
endfunction

// atan2 approximation (in: non-FP; out: FP)
// using https://en.wikipedia.org/wiki/Atan2
function int atan2(bit signed [DATA_WIDTH-1:0] x, y);
	if (x == 0)
		atan2 = (y >= 0) ? 23040 : -23040;
	else
	begin
		automatic int z = (y <<< 8) / x; // FP
		if (x > 0)
			atan2 = arctan(z);
		else if (y >= 0)
			atan2 = arctan(z) + 46080;
		else
			atan2 = arctan(z) - 46080;
	end
endfunction

// resets the maxheap
task maxheap_reset();
	for (bit [$clog2(PEAKS+1)-1:0] i = 0; i < PEAKS; i++)
		maxheap[i] <= 0;
endtask

// updates the maxheap
task maxheap_update();
	if (sink_r > buff_r[maxheap[0]])
		buff_r[0] <= sink_pos;
	for (bit [$clog2(PEAKS+1)-1:0] i = 1; i < PEAKS; i++)
		if (sink_r > buff_r[maxheap[i]])
			maxheap[i] <= (sink_r > buff_r[maxheap[i-1]]) ? maxheap[i-1] : sink_pos;
endtask

/*----------------------------------------------------------------------------*/
/*- main code ----------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
assign sink_r = hypot(sink_re, sink_im);
assign sink_th = atan2(sink_re, sink_im);

always @(posedge clk)
begin
	if (reset)																// reset all
	begin
		maxheap_reset();
		sink_pos <= 0;
		sink_done <= 0;
		source_pos <= 0;
		source_done <= 0;
	end
	else if (!sink_done && sink_valid)								// continue loading of buffer
	begin
		maxheap_update();
		buff_r[sink_pos] <= sink_r;
		buff_th[sink_pos] <= sink_th;
		sink_done <= (sink_pos == BATCH_SIZE - 1) ? 1 : 0;
		sink_pos <= sink_pos + 1;
	end
	else if (sink_done && !source_done)								// continue export of data
	begin
		
	end
end

endmodule