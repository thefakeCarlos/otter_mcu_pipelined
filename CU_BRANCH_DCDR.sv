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
    if (IR_OPCODE == 7'b1100011) BRANCH_TAKEN = 1'b0;
    case (IR_FUNCT)
      3'b000: begin
        if (BR_EQ == 1'b1) BRANCH_TAKEN = 1'b1;
      end
      3'b001: begin
        if (BR_EQ == 1'b0) BRANCH_TAKEN = 1'b1;
      end
      3'b100: begin
        if (BR_LT == 1'b1) BRANCH_TAKEN = 1'b1;
      end
      3'b101: begin
        if (BR_LT == 1'b0) BRANCH_TAKEN = 1'b1;
      end
      3'b110: begin
        if (BR_LTU == 1'b1) BRANCH_TAKEN = 1'b1;
      end
      3'b111: begin
        if (BR_LTU == 1'b0) BRANCH_TAKEN = 1'b1;
      end
      default: begin
        BRANCH_TAKEN = 1'b0;
      end
    endcase
  end
endmodule
