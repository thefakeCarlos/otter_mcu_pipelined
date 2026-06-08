`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: otter_tb
// Description: Testbench for pipelined OTTER MCU
//              Tests: addi, lui, addi, addi, or, sw with NOPs to avoid hazards
//              Expected result: LEDS = 0x000F (7 | 10 = 15)
//              CLK drives 2x clock divider in wrapper, so clk_50 = CLK/2
//////////////////////////////////////////////////////////////////////////////////
module otter_tb();
    logic        clk = 0;
    logic        btnc;
    logic [15:0] switches = 16'h0000;
    logic [15:0] leds;
    logic [7:0]  segs;
    logic [3:0]  an;

    // Clock cycle counter (counts rising edges of clk after reset is released)
    longint unsigned cycle_count = 0;

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
        repeat(1000000000) #20 clk = ~clk;
    end

    // Reset pulse
    initial begin
        btnc = 1;
        #40;
        btnc = 0;
    end

    // Count clock cycles (only after reset is released)
    always_ff @(posedge clk) begin
        if (!btnc)
            cycle_count <= cycle_count + 1;
    end

    // Check result at 1750ns
    initial begin
        #1750000;
        $display("Total clock cycles: %0d", cycle_count);
        if (leds == 16'h1)
            $display("PASS: LEDS = %h (expected 1)", leds);
        else
            $display("FAIL: LEDS = %h (expected 1)", leds);
        $finish;
    end
endmodule