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
int											buff_th[0:TOT_SIZE-1];	// phase data (FP)
reg		[$clog2(TOT_SIZE)-1:0]		sink_pos;					// sink entry position

// sqrt approximation (max -35% and +65% deviation) (in: non-FP; out non-FP)
function int sqrt_h(longint s);
	//sqrt2 = 1;
	//for (byte i = 4; i <= 64; i += 2)
	//begin
	//	if (s[i-1] || s[i-2])
	//		sqrt2 = s >>> (i/2);
	//end
	for (byte i = 0; i < 32; i++)
		sqrt_h[i] = s[2*i+1] || s[2*i];
	//automatic longint tmp = s - 1;
	//while (tmp > 0)
	//begin
	//	tmp >>>= 2;
	//	s >>>= 1;
	//end
	//sqrt2 = s + 1;
endfunction

// sqrt approximation (max +-0.2% deviation) (in: non-FP; out non-FP)
function int sqrt(longint s);
	if (s < 2)
		sqrt = s;
	else
	begin
		int tmp;
		sqrt = sqrt_h(s);
		sqrt = (sqrt + s / sqrt) / 2;
		sqrt = (sqrt + s / sqrt) / 2;
	end
endfunction

// hypot approximation (in: non-FP; out: FP)
function int hypot(bit signed [DATA_WIDTH-1:0] x, y);
	hypot = sqrt(x*x + y*y) <<< 8;
endfunction

// arctan approximation (in: FP; out: FP)
// using https://math.stackexchange.com/questions/1098487/atan2-faster-approximation
function int arctan_h(int z);
	arctan_h = (z * (51472 - 70 * (z - 256))) >>> 16;
endfunction

function int arctan(int z);
	if (z >= 0)
	begin
		if (z > 256)
			arctan = 402 - arctan_h(65536/z);
		else
			arctan = arctan_h(z);
	end
	else
	begin
		if (z < -256)
			arctan = arctan_h(65536/-z) - 402;
		else
			arctan = -arctan_h(-z);
	end
endfunction

// atan2 approximation (in: non-FP; out: FP)
// using https://en.wikipedia.org/wiki/Atan2
function int atan2(bit signed [DATA_WIDTH-1:0] x, y);
	if (x == 0)
		atan2 = (y >= 0) ? 402 : -402;
	else
	begin
		automatic int z = (y <<< 8) / x; // FP
		if (x > 0)
			atan2 = arctan(z);
		else if (y >= 0)
			atan2 = arctan(z) + 804;
		else
			atan2 = arctan(z) - 804;
	end
endfunction

// sink constrol
always @(posedge sink_clk)
begin
	if (sink_valid)
	begin
		if (sink_sop)
			sink_pos = 0;
		buff_r[sink_pos] = hypot(sink_re, sink_im);
		buff_th[sink_pos] = atan2(sink_re, sink_im);
		if (sink_pos < TOT_SIZE-1)
			sink_pos++;
	end
end

endmodule