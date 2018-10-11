module freq_buffer #(
	parameter DATA_WIDTH = 20,											// data bits per entry
	parameter TOT_SIZE = 1024											// number of entries
)(
	input		wire							sink_clk,					// clock:	input data speed
	input		wire							sink_sop,					// high:		first input entry
	input		wire							sink_valid,					// high:		input is valid
	input		wire	[DATA_WIDTH-1:0]	sink_re,						//				input real data bus
	input		wire	[DATA_WIDTH-1:0]	sink_im						//				input imaginair data bus
);

// Fixed point notation (FP) is reguarly used in this module:
// - 32 bit two's complement
// - the lower 8 bits represent the fractional part

// internal variables
int											buff_r[0:TOT_SIZE-1];	// magnitude data (FP)
int											buff_th[0:TOT_SIZE-1];	// phase data, in degrees (FP)
reg		[$clog2(TOT_SIZE)-1:0]		sink_pos;					// sink entry position

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

// sink constrol
always @(posedge sink_clk)
begin
	if (sink_sop)
		sink_pos = 0;
	if (sink_valid && sink_pos < TOT_SIZE - 1)
	begin
		buff_r[sink_pos] = hypot(sink_re, sink_im);
		buff_th[sink_pos] = atan2(sink_re, sink_im);
		sink_pos++;
	end
end

endmodule