`timescale 1ns / 1ps
module REG_FILE(
    input  logic        CLK,
    input  logic        EN,
    input  logic [4:0]  ADR1,
    input  logic [4:0]  ADR2,
    input  logic [4:0]  WA,
    input  logic [31:0] WD,
    output logic [31:0] RS1,
    output logic [31:0] RS2
);
    logic [31:0] ram[0:31];
    
    initial begin
        for (int i = 0; i < 32; i++) ram[i] = 0;
    end
    
    // Async reads with hardwired x0 = 0
    assign RS1 = (ADR1 == 5'd0) ? 32'b0 : ram[ADR1];
    assign RS2 = (ADR2 == 5'd0) ? 32'b0 : ram[ADR2];
   
    // Write on negedge (your existing approach for WB->DE same-cycle read)
    // x0 is hardwired to 0, never written
    always_ff @(negedge CLK) begin
        if (EN && WA != 5'd0) begin
            ram[WA] <= WD;
        end
    end 
endmodule