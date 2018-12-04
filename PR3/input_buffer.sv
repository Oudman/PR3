// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		input_buffer.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ ram.sv (Intel IP)
//  ~ delay.sv
// -----------------------------------------------------------------------------
// Type:		module
// Purpose:	Input buffer. Input is done parallel, output is done sequential.
// -----------------------------------------------------------------------------
// In order to distinguish signed, unsigned, integer and fractional represen-
// tation, the Q number format is used. The following definition is used:
// - Qn.m:  signed; n integer bits; m fractional bits
// - UQn.m: unsigned; n integer bits; m fractional bits
// Two examples:
// - Q32.0: 32 bit signed integer
// - UQ6.2: 8 bit unsigned number with [0,64) range and 0.25 resolution
// -----------------------------------------------------------------------------

`ifndef INPUT_BUFFER_SV
`define INPUT_BUFFER_SV

`include "delay.sv"

module input_buffer #(
	parameter NSINK,														// number of input buses
	parameter WIDTH,														// number of input bits per bus
	parameter LENGTH														// number of entries to store per run
)(
	input		wire									sink_clk,			// sink speed
	input		wire									source_clk,			// source speed
	input		wire									reset,				// synchronous reset
	input		wire									sink_start,			// start new run
	input		wire signed		[WIDTH-1:0]		sink_data[0:NSINK-1], // input data buses			Q<WIDTH>.0
	output	reg									source_valid,		// output is valid
	output	reg									source_sop,			// first output entry
	output	reg									source_eop,			// last output entry
	output	reg signed		[WIDTH-1:0]		source_data			//	output data bus				Q<WIDTH>.0
);

// more parameters
localparam AWIDTH = $clog2(LENGTH);
localparam BWIDTH = $clog2(NSINK);

/*----------------------------------------------------------------------------*/
/*- wires and registers ------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// state enum
typedef enum {IDLE, BUSY, DONE} state;

// sink control
state									sink_state = IDLE;				// input completed
reg									ram_wren;							// enable writing
reg unsigned	[AWIDTH-1:0]	ram_wraddr;							// write address

// source control
state								 	source_state = IDLE;				// output completed
reg									source_valid_p;					// source_valid signal to delay
reg									source_sop_p;						// source_valid signal to delay
reg									source_eop_p;						// source_valid signal to delay
reg unsigned	[BWIDTH-1:0]	ram_bank_p;							// ram bank select signal to delay
reg unsigned	[AWIDTH-1:0]	ram_rdaddr;							// read addres
wire unsigned	[BWIDTH-1:0]	ram_bank;							// ram bank select

// block ram
wire				[WIDTH-1:0]		ram_q[0:NSINK-1];					// read data

/*----------------------------------------------------------------------------*/
/*- code ---------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// sink control
always @(posedge sink_clk)
begin
	if (reset)																// reset all
	begin
		sink_state		<= IDLE;
		ram_wren			<= 1'bx;
		ram_wraddr		<= {AWIDTH{1'bx}};
	end
	else if (sink_start)													// prepare for new input
	begin
		sink_state		<= BUSY;
		ram_wren			<= 1'b1;
		ram_wraddr		<= {AWIDTH{1'b0}};
	end
	else if (sink_state == BUSY)										// continue with input
	begin
		if (ram_wraddr == LENGTH-1)									// last input entry
		begin
			sink_state		<= DONE;
			ram_wren			<= 1'b0;
			ram_wraddr		<= {AWIDTH{1'bx}};
		end
		else																	// non-last input entry
		begin
			ram_wren			<= 1'b1;
			ram_wraddr		<= ram_wraddr + 1'b1;
		end
	end
	else																		// wait for start signal
	begin
		if (source_state == BUSY)										// done signal has been retrieved by source control
			sink_state		<= IDLE;
		ram_wren			<= 1'b0;
		ram_wraddr		<= {AWIDTH{1'bx}};
	end
end

// source control
always @(posedge source_clk)
begin
	if (reset)																// reset all
	begin
		source_state	<= IDLE;
		source_valid_p	<= 1'b0;
		source_sop_p	<= 1'b0;
		source_eop_p	<= 1'b0;
		ram_rdaddr		<= {AWIDTH{1'bx}};
		ram_bank_p		<= {BWIDTH{1'bx}};
		source_data		<= {WIDTH{1'bx}};
	end
	else																		// continue with output
	begin
		begin																	// stage I
			if (source_state == BUSY)									// prepare output for next clock
			begin
				source_valid_p	<= 1'b1;
				source_sop_p	<= (ram_rdaddr == {AWIDTH{1'b0}}) ? 1'b1 : 1'b0;
				source_eop_p	<= (ram_rdaddr == LENGTH-1) ? 1'b1 : 1'b0;
				if (ram_rdaddr == LENGTH-1)							// last output entry of batch
				begin
					if (ram_bank_p == NSINK-1)							// last output entry of last batch
					begin
						source_state	<= IDLE;
						ram_rdaddr		<= {AWIDTH{1'bx}};
						ram_bank_p		<= {BWIDTH{1'bx}};
					end
					else														// last output entry of non-last batch
					begin
						ram_bank_p		<= ram_bank_p + 1'b1;
						ram_rdaddr		<= {AWIDTH{1'b0}};
					end
				end
				else															// non-last output entry of batch
				begin
					ram_rdaddr		<= ram_rdaddr + 1'b1;
				end
			end
			else																// next clock no output entry
			begin
				source_valid_p	<= 1'b0;
				source_sop_p	<= 1'b0;
				source_eop_p	<= 1'b0;
				if (sink_state == DONE)									// prepare for new batch
				begin
					source_state	<= BUSY;
					ram_bank_p		<= {BWIDTH{1'b0}};
					ram_rdaddr		<= {AWIDTH{1'b0}};
				end
				else															// don't prepare for new batch
				begin
					ram_bank_p		<= {BWIDTH{1'bx}};
					ram_rdaddr		<= {AWIDTH{1'bx}};
				end
			end
		end
		begin																	// stage II
		end
		begin																	// stage III
			source_data		<= ram_q[ram_bank];
		end
	end
end

/*----------------------------------------------------------------------------*/
/*- modules ------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
// block ram instances
genvar i;
generate for (i = 0; i < NSINK; i++)
	begin :gen
		altsyncram #(
			.operation_mode		("DUAL_PORT"),
			.width_a					(WIDTH),
			.widthad_a				(AWIDTH),
			.width_b					(WIDTH),
			.widthad_b				(AWIDTH),
			.outdata_reg_b			("CLOCK1")
		) blockram (
			.address_a				(ram_wraddr),
			.address_b				(ram_rdaddr),
			.clock0					(sink_clk),
			.clock1					(source_clk),
			.data_a					(sink_data[i]),
			.wren_a					(ram_wren),
			.q_b						(ram_q[i])
		);	
	end
endgenerate

// delay lines
delay #(
	.WIDTH					(3+BWIDTH),
	.DELAY					(2)
) delay (
	.clk						(source_clk),
	.reset					(reset),
	.sink						({source_valid_p, source_sop_p, source_eop_p, ram_bank_p}),
	.source					({source_valid, source_sop, source_eop, ram_bank})
);

endmodule

`endif
