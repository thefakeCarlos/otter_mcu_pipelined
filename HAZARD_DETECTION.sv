`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Carlos Diaz and Nathan Hernandez
// Module Name: HAZARD_DETECTION
// Description: Generates hazard detection signals
//////////////////////////////////////////////////////////////////////////////////

module HAZARD_DETECTION (
    input logic IDEX_MemRead,
    input logic [4:0] IDEX_rt,
    input logic [31:0] IFID_rs,
    IFID_rt,
    output logic stall
);

  assign stall = (IDEX_MemRead && ((IDEX_rt == IFID_rs) || (IDEX_rt == IFID_rt)));

endmodule
