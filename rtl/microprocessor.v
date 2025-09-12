`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: dff
// Description: 8-bit D-type flip-flop. On every rising edge of the clock, the
//              input is transferred to the output.
module dff(
    input clk,           // Clock signal
    input [7:0] in,      // 8-bit input data
    output reg [7:0] out // 8-bit registered output data
);
  always @(posedge clk) begin
      out = in; // On rising edge, load 'in' into 'out'
  end
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: tribuff_8_2to1
// Description: 8-bit tri-state buffer (2-to-1 style). When the select 's' is high,
//              the input 'a' is driven to the output; otherwise, the output is
//              high impedance (8'bz).
module tribuff_8_2to1 (
    input s,           // Select signal. When high, enable the driver.
    input [7:0] a,     // 8-bit data input
    output [7:0] out   // 8-bit output (tri-stated when s is low)
);
  assign out = s ? a : 8'bz;  // If 's' is high, drive 'a'; otherwise, output high impedance.
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: mux8_2to1
// Description: 8-bit 2-to-1 multiplexer. Selects between two 8-bit inputs 'a'
//              and 'b' based on the select signal 's'.
module mux8_2to1(
    input s,           // Select signal: when high, choose input 'a'; when low, choose 'b'
    input [7:0] a,     // 8-bit input 'a'
    input [7:0] b,     // 8-bit input 'b'
    output [7:0] out   // 8-bit output selected from 'a' or 'b'
);
  assign out = s ? a : b;  // If 's' is high, output 'a'; else, output 'b'.
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: decode3to8
// Description: 3-to-8 line decoder. Given a 3-bit input, one of the 8 outputs
//              will be high, provided that the enable 'en' is high.
module decode3to8 (
    input en,           // Enable signal for the decoder
    input [2:0] in,     // 3-bit input code
    output [7:0] out    // 8-bit one-hot output
);
  // Each bit of the output 'out' is high when 'en' is high and the corresponding
  // input pattern matches the index.
  assign
    out[0] = en & ~in[2] & ~in[1] & ~in[0], 
    out[1] = en & ~in[2] & ~in[1] &  in[0],
    out[2] = en & ~in[2] &  in[1] & ~in[0], 
    out[3] = en & ~in[2] &  in[1] &  in[0],
    out[4] = en &  in[2] & ~in[1] & ~in[0],
    out[5] = en &  in[2] & ~in[1] &  in[0],
    out[6] = en &  in[2] &  in[1] & ~in[0],
    out[7] = en &  in[2] &  in[1] &  in[0];
endmodule
  
//////////////////////////////////////////////////////////////////////////////////
// Module: add_sub
// Description: Performs either addition or subtraction between the accumulator 'A'
//              and the bus data, based on the instruction bit 'inst[5]'.
//              If inst[5] is high, subtract bus from A; otherwise, add bus to A.
module add_sub(
    input  inst_5,         // Instruction that controls add/subtract operation
    input [7:0] bus,          // 8-bit bus data
    input [7:0] A,            // 8-bit accumulator data
    output [7:0] add_sub_out  // 8-bit result of addition or subtraction
);
  // If inst[5] is '1', perform subtraction (A - bus); else, perform addition (A + bus)
  assign add_sub_out = inst_5 ? (A - bus) : (A + bus);
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: ALU
// Description: The Arithmetic Logic Unit (ALU) processes operations on the 
//              accumulator 'A' using the 'bus' data and an instruction word 'inst'.
//              It uses the add_sub module and then a multiplexer to select the result.
module ALU(
    input [7:0] inst, // 8-bit instruction controlling the operation
    input [7:0] bus,  // 8-bit bus data input
    input [7:0] A,    // 8-bit accumulator data input
    output [7:0] InA  // 8-bit output of the ALU operation
);
  wire [7:0] add_sub_out; // Intermediate result from add_sub module

  // Instantiate the add_sub module to perform addition or subtraction
  add_sub A_S (inst[5], bus, A, add_sub_out);
  
  // Use a multiplexer to choose between the add_sub result and bus value based on inst[6]
  // If inst[6] is high, select add_sub_out; otherwise, select the bus.
  mux8_2to1 for_add_sub (inst[6], add_sub_out, bus, InA);
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Module: micro
// Description: Represents a simplified microcontroller that integrates the ALU,
//              registers, decoders, and tri-state buffers. It supports loading
//              data from the bus, performing ALU operations, and writing data out.
//              The microcontroller uses the instruction word 'inst' to control the
//              data flow.
//////////////////////////////////////////////////////////////////////////////////
module micro(
    input clk,            // System clock
    input [7:0] inst,     // 8-bit instruction controlling operations
    input [7:0] data_in,  // 8-bit external data input
    output [7:0] data_out // 8-bit external data output
);

  // Internal buses and control signals
  wire [7:0] bus;      // Shared 8-bit bus
  wire [7:0] LD;       // Load enable signals decoded from inst[5:3]
  wire [7:0] OE;       // Output enable signals decoded from inst[2:0]
  wire [7:0] InA;      // Result from the ALU operation

  // ld_en is active low when either inst[7] or inst[6] is high
  wire ld_en = ~(inst[7] | inst[6]);
  
  // Constant parameter for output enable; always '1' in this design
  parameter oe_en = 1'b1;
  
  // 8-bit registers for A, B, C, D, E, and F (could be extended as needed)
  wire [7:0] A, B, C, D, E, F;
  // Intermediate wires for the next state of the registers
  wire [7:0] A1, B1, C1, D1, E1, F1;
  
  // LDA is a control signal that combines parts of the instruction and decoded load enable (LD[1])
  // It is high when the XOR of inst[7] and inst[6] is high or when LD[1] is high.
  wire LDA;
  assign LDA = (inst[7] ^ inst[6]) | LD[1];
  
  // Instantiate the ALU module. It takes the instruction, current bus value, and accumulator A.
  ALU alu1 (inst, bus, A, InA);
  
  // Decode the load enable and output enable signals from the instruction
  // LOAD_EN uses inst[5:3] and is enabled by ld_en
  decode3to8 LOAD_EN (ld_en, inst[5:3], LD);
  // OUTPUT_EN uses inst[2:0] and is always enabled (oe_en is '1')
  decode3to8 OUTPUT_EN (oe_en, inst[2:0], OE);
  
  // Tri-state buffers are used to connect various data sources to the shared bus.
  // Only one source should drive the bus at any given time based on the OE control.
  
  // Drive the bus with external data when OE[0] is active.
  tribuff_8_2to1 from_data_in (OE[0], data_in, bus);  
  // Drive the bus with data from register A when OE[1] is active.
  tribuff_8_2to1 from_A (OE[1], A, bus);
  // Similarly for registers B, C, D, E, and F:
  tribuff_8_2to1 from_B (OE[2], B, bus);
  tribuff_8_2to1 from_C (OE[3], C, bus);
  tribuff_8_2to1 from_D (OE[4], D, bus);
  tribuff_8_2to1 from_E (OE[5], E, bus);
  tribuff_8_2to1 from_F (OE[6], F, bus);
  
  // Use a tri-state buffer to drive external data output from the bus when LD[0] is active.
  tribuff_8_2to1 bus_to_data_out (LD[0], bus, data_out);
 
  // Register A is loaded using the ALU output InA via a multiplexer,
  // selecting between InA and the current value of A based on the LDA signal.
  mux8_2to1 load_in_a (LDA, InA, A, A1);
  dff dA (clk, A1, A); // D flip-flop to store the new value for register A.
  
  // Register B is loaded from the bus when LD[2] is active.
  mux8_2to1 bus_to_b (LD[2], bus, B, B1);
  dff dB (clk, B1, B); // D flip-flop for register B.
  
  // Register C is loaded from the bus when LD[3] is active.
  mux8_2to1 bus_to_c (LD[3], bus, C, C1);
  dff dC (clk, C1, C); // D flip-flop for register C.
  
  // Register D is loaded from the bus when LD[4] is active.
  mux8_2to1 bus_to_d (LD[4], bus, D, D1);
  dff dD (clk, D1, D); // D flip-flop for register D.
  
  // Register E is loaded from the bus when LD[5] is active.
  mux8_2to1 bus_to_e (LD[5], bus, E, E1);
  dff dE (clk, E1, E); // D flip-flop for register E.
  
  // Register F is loaded from the bus when LD[6] is active.
  mux8_2to1 bus_to_f (LD[6], bus, F, F1);
  dff dF (clk, F1, F); // D flip-flop for register F.
 
endmodule

