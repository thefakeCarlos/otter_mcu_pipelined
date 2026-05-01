module FORWARDING_UNIT( 
      input logic [31:0] de_ex_rs1addr
      input logic [31:0] de_ex_rs2addr
      input logic [31:0] ex_mem_rdaddr
      input logic ex_mem_regwrite
      input logic [31:0] ex_mem_aluresult
      input logic [31:0] mem_wb_rdaddr
      input logic mem_wb_regwrite
      input logic ex_mem_rdused
      input logic mem_wb_rdused
      input logic de_ex_rs1used
      input logic de_ex_rs1used
      output logic [1:0] fowardA
      output logic [1:0] fowardB
  );

   always_comb begin
    // Forward A
    if (ex_mem_rdused && (ex_mem_rdaddr == de_ex_rs1addr) && de_ex_rs1used && ex_mem_regwrite && (de_ex_rs1addr != 0) )
        forwardA = 2'b01;
    else if (mem_wb_rdused && mem_wb_rdaddr == de_ex_rs1addr && de_ex_rs1used && mem_wb_regwrite && (de_ex_rs1addr != 0))
        forwardA = 2'b10;
    else
        forwardA = 2'b00;

    // Forward B
    if (ex_mem_rdused && ex_mem_rdaddr == de_ex_rs2addr && de_ex_rs2used && ex_mem_regwrite && (de_ex_rs2addr != 0))
        forwardB = 2'b01;
    else if (mem_wb_rdused && mem_wb_rdaddr == de_ex_rs2addr && de_ex_rs2used && mem_wb_regwrite && (de_ex_rs1addr != 0))
        forwardB = 2'b10;
    else
        forwardB = 2'b00;

end


end module
