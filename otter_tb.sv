`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: otter_tb
// Description: Testbench for pipelined OTTER MCU
//              Tests: addi, lui, addi, addi, or, sw with NOPs to avoid hazards
//              Expected result: LEDS = 0x000F (7 | 10 = 15)
//              CLK drives 2x clock divider in wrapper, so clk_50 = CLK/2
//////////////////////////////////////////////////////////////////////////////////
module otter_tb ();

  logic        clk = 0;
  logic        btnc;
  logic [15:0] switches = 16'h0000;
  logic [15:0] leds;
  logic [ 7:0] segs;
  logic [ 3:0] an;

  OTTER_Wrapper dut (
      .CLK     (clk),
      .BTNC    (btnc),
      .SWITCHES(switches),
      .LEDS    (leds),
      .CATHODES(segs),
      .ANODES  (an)
  );

  // 40ns CLK period so clk_50 runs at 20ns
  initial begin
    repeat (88) #20 clk = ~clk;
  end

  // Reset pulse
  initial begin
    btnc = 1;
    #40;
    btnc = 0;
  end

  // Check result at 1750ns
  initial begin
    #1750;
    if (leds == 16'h000F) $display("PASS: LEDS = %h (expected 000F)", leds);
    else $display("FAIL: LEDS = %h (expected 000F)", leds);
    $finish;
  end

endmodule

