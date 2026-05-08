`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: California Polytechnic University, San Luis Obispo
// Engineer: Nathan Hernandez & Carlos Diaz & Garth
// Create Date: 02/23/2023 09:39:49 AM
// Module Name: CU_DCDR
//////////////////////////////////////////////////////////////////////////////////

module CU_BRANCH_DCDR (
    input logic [6:0] IR_OPCODE,
    input logic [2:0] IR_FUNCT,
    input logic BR_EQ,
    input logic BR_LT,
    input logic BR_LTU,
    output logic BRANCH_TAKEN
);

  always_comb begin
    BRANCH_TAKEN = 1'b0;  // default
    if (IR_OPCODE == 7'b1100011) begin  // only evaluate for BRANCH opcode
        case (IR_FUNCT)
            3'b000: if (BR_EQ)        BRANCH_TAKEN = 1'b1;
            3'b001: if (!BR_EQ)       BRANCH_TAKEN = 1'b1;
            3'b100: if (BR_LT)        BRANCH_TAKEN = 1'b1;
            3'b101: if (!BR_LT)       BRANCH_TAKEN = 1'b1;
            3'b110: if (BR_LTU)       BRANCH_TAKEN = 1'b1;
            3'b111: if (!BR_LTU)      BRANCH_TAKEN = 1'b1;
            default: BRANCH_TAKEN = 1'b0;
        endcase
    end
end
endmodule
