`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: otter_tb
// Description: Testbench for pipelined OTTER MCU
//              Runs long enough to execute 4064 instructions
//              CLK drives 2x clock divider in wrapper, so clk_50 = CLK/2
//              Each instruction takes ~1 clk_50 cycle (80ns)
//              4064 instructions * 80ns + margin = ~400,000ns total
//////////////////////////////////////////////////////////////////////////////////
module otter_tb();

    logic        clk = 0;
    logic        btnc;
    logic [15:0] switches = 16'h0000;
    logic [15:0] leds;
    logic [7:0]  segs;
    logic [3:0]  an;

    OTTER_Wrapper dut (
        .CLK     (clk),
        .BTNC    (btnc),
        .SWITCHES(switches),
        .LEDS    (leds),
        .CATHODES(segs),
        .ANODES  (an)
    );

    // 40ns CLK period so clk_50 runs at 80ns
    always #20 clk = ~clk;

    // Reset pulse
    initial begin
        btnc = 1;
        #40;
        btnc = 0;
    end

    // Run for enough time to execute 4064 instructions then stop
    initial begin
        #400000;
        $display("Simulation complete at %0t ns", $time);
        $finish;
    end

endmodule