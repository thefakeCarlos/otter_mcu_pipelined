`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: J. Callenes
// Adapted for OTTER RV32I CPU interface
//
// Module Name: Memory
// Description: 64k Memory, dual access read single access write.
//              OTTER_mem_byte logic adapted to Memory interface ports.
//              ADDR1 is a 14-bit word address, connect to PC[15:2].
//              ADDR2 is byte addressable (32-bit).
//              MEM_SIZE: 0-Byte, 1-Half, 2-Word
//              MEM_SIGN: 1-unsigned, 0-signed
//
// Memory OTTER_MEMORY (
//    .MEM_CLK   (),
//    .MEM_RDEN1 (),
//    .MEM_RDEN2 (),
//    .MEM_WE2   (),
//    .MEM_ADDR1 (),   // Connect to PC[15:2]
//    .MEM_ADDR2 (),
//    .MEM_DIN2  (),
//    .MEM_SIZE  (),
//    .MEM_SIGN  (),
//    .IO_IN     (),
//    .IO_WR     (),
//    .MEM_DOUT1 (),
//    .MEM_DOUT2 () );
//
//////////////////////////////////////////////////////////////////////////////////

module Memory (
    input MEM_CLK,
    input MEM_RDEN1,            // read enable Instruction
    input MEM_RDEN2,            // read enable data
    input MEM_WE2,              // write enable
    input [13:0] MEM_ADDR1,     // Instruction Memory word Addr (Connect to PC[15:2])
    input [31:0] MEM_ADDR2,     // Data Memory Addr (byte addressable)
    input [31:0] MEM_DIN2,      // Data to save
    input [1:0]  MEM_SIZE,      // 0-Byte, 1-Half, 2-Word
    input MEM_SIGN,             // 1-unsigned 0-signed
    input [31:0] IO_IN,         // Data from IO
    output logic IO_WR,         // IO 1-write 0-read
    output logic [31:0] MEM_DOUT1,  // Instruction
    output logic [31:0] MEM_DOUT2); // Data

    parameter NUM_COL   = 4;
    parameter COL_WIDTH = 8;

    wire [13:0] memAddr2;
    logic memWrite2;
    logic [31:0] memOut2;
    logic [31:0] ioIn_buffer = 0;
    logic [NUM_COL-1:0] weA;

    // saved signals for post-processing (BRAM read data arrives one cycle later)
    logic saved_mem_sign;
    logic [1:0]  saved_mem_size;
    logic [31:0] saved_mem_addr2;

    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [31:0] memory [0:16383];

    initial begin
        $readmemh("dump.mem", memory, 0, 16383);
    end

    // word address for data port (drop byte offset bits)
    assign memAddr2 = MEM_ADDR2[15:2];

    // generate byte-enable mask based on MEM_SIZE and byte offset
    always_comb begin
        case (MEM_SIZE)
            2'd0:    weA = 4'b0001 << MEM_ADDR2[1:0];  // sb
            2'd1:    weA = 4'b0011 << MEM_ADDR2[1:0];  // sh
            2'd2:    weA = 4'b1111;                     // sw
            default: weA = 4'b0000;
        endcase
    end

    // buffer IO input synchronously
    always_ff @(posedge MEM_CLK)
        if (MEM_RDEN2)
            ioIn_buffer <= IO_IN;

    // BRAM synchronous read and write
    integer i, j;
    always_ff @(posedge MEM_CLK) begin

        // PORT 2 - Data write
        if (memWrite2) begin
            j = 0;
            for (i = 0; i < NUM_COL; i = i + 1) begin
                if (weA[i]) begin
                    case (MEM_SIZE)
                        2'd0: memory[memAddr2][i*COL_WIDTH +: COL_WIDTH] <= MEM_DIN2[7:0];              // sb
                        2'd1: begin
                                  memory[memAddr2][i*COL_WIDTH +: COL_WIDTH] <= MEM_DIN2[j*COL_WIDTH +: COL_WIDTH]; // sh
                                  j = j + 1;
                              end
                        2'd2: memory[memAddr2][i*COL_WIDTH +: COL_WIDTH] <= MEM_DIN2[i*COL_WIDTH +: COL_WIDTH];     // sw
                        default: memory[memAddr2][i*COL_WIDTH +: COL_WIDTH] <= MEM_DIN2[i*COL_WIDTH +: COL_WIDTH];
                    endcase
                end
            end
        end

        // PORT 2 - Data read
        if (MEM_RDEN2)
            memOut2 <= memory[memAddr2];

        // PORT 1 - Instruction read (MEM_ADDR1 is already a 14-bit word address)
        if (MEM_RDEN1)
            MEM_DOUT1 <= memory[MEM_ADDR1];

        // save signals so they align with BRAM output next cycle
        saved_mem_size  <= MEM_SIZE;
        saved_mem_sign  <= MEM_SIGN;
        saved_mem_addr2 <= MEM_ADDR2;
    end

    // Post-processing: slice and sign-extend using saved signals
    logic [31:0] memOut2_sliced;

    always_comb begin
        memOut2_sliced = 32'b0;
        case ({saved_mem_sign, saved_mem_size})
            // signed byte (lb)
            3'b000: case (saved_mem_addr2[1:0])
                        2'd3: memOut2_sliced = {{24{memOut2[31]}}, memOut2[31:24]};
                        2'd2: memOut2_sliced = {{24{memOut2[23]}}, memOut2[23:16]};
                        2'd1: memOut2_sliced = {{24{memOut2[15]}}, memOut2[15:8]};
                        2'd0: memOut2_sliced = {{24{memOut2[7]}},  memOut2[7:0]};
                    endcase
            // signed half (lh)
            3'b001: case (saved_mem_addr2[1:0])
                        2'd3: memOut2_sliced = {{16{memOut2[31]}}, memOut2[31:24]};  // spans word, unsupported
                        2'd2: memOut2_sliced = {{16{memOut2[31]}}, memOut2[31:16]};
                        2'd1: memOut2_sliced = {{16{memOut2[23]}}, memOut2[23:8]};
                        2'd0: memOut2_sliced = {{16{memOut2[15]}}, memOut2[15:0]};
                    endcase
            // word (lw)
            3'b010: memOut2_sliced = memOut2;
            // unsigned byte (lbu)
            3'b100: case (saved_mem_addr2[1:0])
                        2'd3: memOut2_sliced = {24'd0, memOut2[31:24]};
                        2'd2: memOut2_sliced = {24'd0, memOut2[23:16]};
                        2'd1: memOut2_sliced = {24'd0, memOut2[15:8]};
                        2'd0: memOut2_sliced = {24'd0, memOut2[7:0]};
                    endcase
            // unsigned half (lhu)
            3'b101: case (saved_mem_addr2[1:0])
                        2'd3: memOut2_sliced = {16'd0, memOut2[31:16]};  // spans word, unsupported
                        2'd2: memOut2_sliced = {16'd0, memOut2[31:16]};
                        2'd1: memOut2_sliced = {16'd0, memOut2[23:8]};
                        2'd0: memOut2_sliced = {16'd0, memOut2[15:0]};
                    endcase
            default: memOut2_sliced = 32'b0;
        endcase
    end

    // IO_WR and memWrite2 - uses current ADDR2 to control this cycle's write
    always_comb begin
        IO_WR = 0;
        if (MEM_ADDR2 >= 32'h00010000) begin
            if (MEM_WE2) IO_WR = 1;
            memWrite2 = 0;
        end
        else begin
            memWrite2 = MEM_WE2;
        end
    end

    // MEM_DOUT2 - uses saved_mem_addr2 to align with one-cycle-delayed BRAM read
    always_comb begin
        if (saved_mem_addr2 >= 32'h00010000)
            MEM_DOUT2 = ioIn_buffer;
        else
            MEM_DOUT2 = memOut2_sliced;
    end

endmodule