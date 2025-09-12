`timescale 1ns/1ps

module micro_tb;

  reg clk;
  reg [7:0] inst;
  reg [7:0] data_in;
  wire [7:0] data_out;

  // Instantiate DUT
  micro dut (
    .clk(clk),
    .inst(inst),
    .data_in(data_in),
    .data_out(data_out)
  );

  // Clock generation: 10ns period
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Task to apply an instruction
  task apply_inst;
    input [7:0] i;
    input [7:0] din;
    begin
      inst = i;
      data_in = din;
      @(posedge clk); // wait for clock
      #1;             // allow settle
    end
  endtask

  initial begin
    // VCD dump for GTKWave
    $dumpfile("micro_tb.vcd");
    $dumpvars(0, micro_tb);

    $display("===== MICRO TESTBENCH START =====");

    // Reset inputs
    inst = 8'h00;
    data_in = 8'h00;
    repeat(2) @(posedge clk);

    // Test 1: Load external data into Register B (LD[2] active)
    $display("Load 0x55 into Register B");
    apply_inst(8'b00010010, 8'h55); // inst[5:3]=010 selects B, inst[2:0]=010 selects OE[2]
    // Now data_in should be driven onto bus and captured by Reg B

    // Test 2: Output Register B to data_out
    $display("Output Register B to data_out");
    apply_inst(8'b00000010, 8'h00); // inst[2:0]=010 activates OE[2] → B drives bus → data_out

    // Test 3: Load external data into Accumulator A
    $display("Load 0x0A into Accumulator A");
    apply_inst(8'b00001000, 8'h0A); // inst[5:3]=001 → LD[1] active → load A

    // Test 4: Add B to Accumulator A
    $display("Add B to A (0x0A + 0x55)");
    apply_inst(8'b01001000, 8'h00); // inst[6]=1 → ALU enabled, inst[5]=0 → add
    // Expect A = 0x5F

    // Test 5: Subtract B from A
    $display("Subtract B from A (0x5F - 0x55)");
    apply_inst(8'b01101000, 8'h00); // inst[6]=1, inst[5]=1 → subtract
    // Expect A = 0x0A

    // Test 6: Drive A to data_out
    $display("Output A to data_out");
    apply_inst(8'b00000001, 8'h00); // OE[1] active → A drives bus → data_out

    // End test
    $display("===== MICRO TESTBENCH END =====");
    #20 $finish;
  end

endmodule
