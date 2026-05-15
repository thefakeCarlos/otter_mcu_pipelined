`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Carlos Diaz and Nathan Hernandez
// Module Name: HAZARD_DETECTION
// Description: Generates hazard detection signals
//////////////////////////////////////////////////////////////////////////////////

module HAZARD_DETECTION (
    input logic IDEX_MemRead,
    input logic rs1_used,
    input logic rs2_used,
    input logic [4:0] IDEX_rt,
    input logic [4:0] IFID_rs,
    IFID_rt,
    output logic stall
);

  assign stall = (IDEX_MemRead && ((rs1_used && (IDEX_rt == IFID_rs)) || (rs2_used && (IDEX_rt == IFID_rt))));

endmodule
