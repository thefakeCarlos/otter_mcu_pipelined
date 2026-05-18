`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Carlos Diaz and Nathan Hernandez
// Module Name: PIPELINED_OTTER_CPU
// Description: 5-stage pipelined RISC-V OTTER MCU (IF -> ID -> EX -> MEM -> WB)
//////////////////////////////////////////////////////////////////////////////////

// Enum for RISC-V base instruction opcodes
typedef enum logic [6:0] {
    LUI    = 7'b0110111,
    AUIPC  = 7'b0010111,
    JAL    = 7'b1101111,
    JALR   = 7'b1100111,
    BRANCH = 7'b1100011,
    LOAD   = 7'b0000011,
    STORE  = 7'b0100011,
    OP_IMM = 7'b0010011,
    OP     = 7'b0110011,
    SYSTEM = 7'b1110011
} opcode_t;

// Carries decoded instruction info through pipeline registers
typedef struct packed {
    opcode_t     opcode;
    logic [2:0]  ir_funct;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [4:0]  rd_addr;
    logic        rs1_used;
    logic        rs2_used;
    logic        rd_used;
    logic [3:0]  alu_fun;
    logic        memWrite;
    logic        memRead2;
    logic        regWrite;
    logic [1:0]  rf_wr_sel;
    logic [2:0]  mem_type;   // {sign, size[1:0]}
    logic        alu_srcA;
    logic [1:0]  alu_srcB;
    logic [31:0] pc;
    logic [2:0] pc_sel;
} instr_t;

module OTTER_MCU (
    input  logic        CLK,
    input  logic        RESET,
    input  logic [31:0] IOBUS_IN,
    output logic [31:0] IOBUS_OUT,
    output logic [31:0] IOBUS_ADDR,
    output logic        IOBUS_WR
);

    //==========================================================
    // Signal declarations
    //==========================================================

    wire [6:0]  opcode;
    wire [31:0] pc, next_pc, A, B,
                I_immed, S_immed, U_immed, J_immed, B_immed,
                aluBin, aluAin, aluResult,
                mem_data, jal, jalr, branch;
    logic [31:0] wd;
    logic [2:0]pc_branch_sel;
    wire [31:0] IR;
    wire [31:0] rs1, rs2;
    wire        memRead2;
    logic [13:0] addr1;
    wire        pcWrite, regWrite, memWrite;
    logic [2:0] pc_sel;
    wire [3:0]  alu_fun;
    wire        alu_srcA;
    wire [1:0]  alu_srcB;
    logic       br_lt, br_eq, br_ltu, branch_taken, stall, flush;
    logic [31:0] pc_mux_out, mem_wb_rs2;
    wire [1:0]  rf_wr_sel;
    logic [1:0] forwardA, forwardB;
    logic forwardC;
    logic [31:0] de_ex_opA_fwd, ex_mem_rs2_fwd, de_ex_rs2_fwd;
    logic [31:0] de_ex_rs2_store_fwd;
    // IF/DE pipeline registers
    logic [31:0] if_de_pc, if_de_next_pc, if_de_ir;
    // DE/EX pipeline registers
    logic [31:0] de_ex_opA, de_ex_rs2;
    logic [31:0] de_ex_I_immed, de_ex_S_immed, de_ex_U_immed,
                 de_ex_J_immed, de_ex_B_immed;
    instr_t      de_ex_inst, de_inst;

    // EX/MEM pipeline registers
    logic [31:0] ex_mem_aluResult, ex_mem_rs2;
    instr_t      ex_mem_inst;

    // MEM/WB pipeline registers
    logic [31:0] mem_wb_aluResult, mem_wb_mem_data;
    instr_t      mem_wb_inst;

    //==========================================================
    // Module instantiations
    //==========================================================

    ImmediateGenerator OTTER_IMGEN (
      .IR    (if_de_ir[31:7]),
      .U_TYPE(U_immed),
      .I_TYPE(I_immed),
      .S_TYPE(S_immed),
      .B_TYPE(B_immed),
      .J_TYPE(J_immed)
    );

    ALU ALU (
        .SRC_A  (de_ex_opA_fwd),
        .SRC_B  (de_ex_rs2_fwd),
        .ALU_FUN(de_ex_inst.alu_fun),
        .RESULT (aluResult)
    );

    BAG BAG (
        .RS1    (de_ex_opA_fwd),
        .I_TYPE (de_ex_I_immed),
        .J_TYPE (de_ex_J_immed),
        .B_TYPE (de_ex_B_immed),
        .FROM_PC(de_ex_inst.pc),
        .JAL    (jal),
        .JALR   (jalr),
        .BRANCH (branch)
    );

    BCG BCG (
        .RS1   (de_ex_opA_fwd),
        .RS2   (de_ex_rs2_fwd),
        .BR_EQ (br_eq),
        .BR_LT (br_lt),
        .BR_LTU(br_ltu)
    );

    CU_BRANCH_DCDR CU_BRANCH_DCDR (
      .IR_OPCODE(de_ex_inst.opcode),
      .IR_FUNCT(de_ex_inst.ir_funct),
      .BR_EQ(br_eq),
      .BR_LT(br_lt),
      .BR_LTU(br_ltu),
      .BRANCH_TAKEN(branch_taken)
      );

    always_comb begin
      case (branch_taken)
        1'b0: pc_branch_sel = de_ex_inst.pc_sel;
        1'b1: pc_branch_sel = 3'b010;
        default: pc_branch_sel = de_ex_inst.pc_sel;
      endcase
    end

    CU_DCDR CU_DCDR (
        .IR_30    (if_de_ir[30]),
        .IR_OPCODE(if_de_ir[6:0]),
        .IR_FUNCT (if_de_ir[14:12]),
        .ALU_FUN  (alu_fun),
        .ALU_SRCA (alu_srcA),
        .ALU_SRCB (alu_srcB),
        .RF_WR_SEL(rf_wr_sel),
        .BRANCH_TAKEN(pc_sel),
        .REG_WRITE(regWrite),
        .MEM_WE2  (memWrite),
        .MEM_RDEN2(memRead2)
    );

    Memory OTTER_MEMORY (
        .MEM_CLK  (CLK),
        .MEM_RDEN1(1'b1),
        .MEM_RDEN2(ex_mem_inst.memRead2),
        .MEM_WE2  (ex_mem_inst.memWrite),
        .MEM_ADDR1(addr1),
        .MEM_ADDR2(ex_mem_aluResult),
        .MEM_DIN2 (ex_mem_rs2_fwd),
        .MEM_SIZE (ex_mem_inst.mem_type[1:0]),
        .MEM_SIGN (ex_mem_inst.mem_type[2]),
        .IO_IN    (IOBUS_IN),
        .IO_WR    (IOBUS_WR),
        .MEM_DOUT1(IR),
        .MEM_DOUT2(mem_data)
    );

    PC PC (
        .CLK      (CLK),
        .RST      (RESET),
        .PC_WRITE (pcWrite),
        .PC_OUT   (pc),
        .PC_OUT_INC(next_pc),
        .PC_IN(pc_mux_out)
    );

    // Read in ID stage, written in WB stage
    REG_FILE REG_FILE (
        .CLK (CLK),
        .EN  (mem_wb_inst.regWrite),
        .ADR1(if_de_ir[19:15]),
        .ADR2(if_de_ir[24:20]),
        .WA  (mem_wb_inst.rd_addr),
        .WD  (wd),
        .RS1 (rs1),
        .RS2 (rs2)
    );

    TwoMux opAmux (
        .ALU_SRC_A(de_ex_inst.alu_srcA),
        .RS1      (de_ex_opA),
        .U_TYPE   (de_ex_U_immed),
        .SRC_A    (aluAin)
    );

    FourMux opBmux (
        .SEL  (de_ex_inst.alu_srcB),
        .ZERO (de_ex_rs2),
        .ONE  (de_ex_I_immed),
        .TWO  (de_ex_S_immed),
        .THREE(de_ex_inst.pc),
        .OUT  (aluBin)
    );

    // Forward mux for opA
    always_comb begin
      case (forwardA)
        2'b00: de_ex_opA_fwd = aluAin;
        2'b01: de_ex_opA_fwd = ex_mem_aluResult;
        2'b10: de_ex_opA_fwd = wd;
        default: de_ex_opA_fwd = aluAin;
      endcase
    end

    // Forward mux for opB (ALU operand) - STORE always uses S_immed for address calc
    always_comb begin
      if (de_ex_inst.opcode == STORE)
        de_ex_rs2_fwd = aluBin;
      else case (forwardB)
        2'b00: de_ex_rs2_fwd = aluBin;
        2'b01: de_ex_rs2_fwd = ex_mem_aluResult;
        2'b10: de_ex_rs2_fwd = wd;
        default: de_ex_rs2_fwd = aluBin;
      endcase
    end

    // Forward mux for store data - uses de_ex_rs2 as base, not aluBin
    always_comb begin
      case (forwardB)
        2'b00: de_ex_rs2_store_fwd = de_ex_rs2;
        2'b01: de_ex_rs2_store_fwd = ex_mem_aluResult;
        2'b10: de_ex_rs2_store_fwd = wd;
        default: de_ex_rs2_store_fwd = de_ex_rs2;
      endcase
    end

    // Forward mux for MEM stage store data (covers WB-stage hazard)
    always_comb begin
      case (forwardC)
        1'b0: ex_mem_rs2_fwd = ex_mem_rs2;
        1'b1: ex_mem_rs2_fwd = wd;
        default: ex_mem_rs2_fwd = ex_mem_rs2;
      endcase
    end

    HAZARD_DETECTION hd (
      .IDEX_MemRead(de_ex_inst.memRead2),
      .rs1_used    (de_ex_inst.rs1_used),
      .rs2_used    (de_ex_inst.rs2_used),
      .IDEX_rt     (de_ex_inst.rd_addr),
      .IFID_rs     (de_inst.rs1_addr),
      .IFID_rt     (de_inst.rs2_addr),
      .stall       (stall)
    );

    FORWARDING_UNIT FWD_UNIT (
      .de_ex_rs1addr  (de_ex_inst.rs1_addr),
      .de_ex_rs2addr  (de_ex_inst.rs2_addr),
      .ex_mem_rdaddr  (ex_mem_inst.rd_addr),
      .ex_mem_regwrite(ex_mem_inst.regWrite),
      .mem_wb_rdaddr  (mem_wb_inst.rd_addr),
      .mem_wb_regwrite(mem_wb_inst.regWrite),
      .ex_mem_rdused  (ex_mem_inst.rd_used),
      .mem_wb_rdused  (mem_wb_inst.rd_used),
      .de_ex_rs1used  (de_ex_inst.rs1_used),
      .de_ex_rs2used  (de_ex_inst.rs2_used),
      .ex_mem_rs2used (ex_mem_inst.rs2_used),
      .ex_mem_rs2addr (ex_mem_inst.rs2_addr),
      .regEnable      (mem_wb_inst.regWrite),
      .forwardA       (forwardA),
      .forwardB       (forwardB),
      .forwardC       (forwardC)
    );

    assign pcWrite = ~stall;
    assign flush = (de_ex_inst.pc_sel == 3'b001 || de_ex_inst.pc_sel == 3'b011 || branch_taken);
    assign addr1      = pc[15:2];
    assign opcode     = if_de_ir[6:0];
    assign IOBUS_ADDR = ex_mem_aluResult;
    assign IOBUS_OUT  = ex_mem_rs2_fwd;

    //Instantiate PC Multiplexer
    PC_MUX PCMUX (
      .PC_OUT_PLUS_FOUR(next_pc),
      .JALR(jalr),
      .BRANCH(branch),
      .JAL(jal),
      .BRANCH_TAKEN(pc_branch_sel),
      .PC_MUX_OUT(pc_mux_out)
    );

    //==========================================================
    //==== Instruction Fetch ====================================
    //==========================================================

    always_ff @(posedge CLK) begin
        if (RESET) begin
            if_de_ir      <= 32'h00000013;  // NOP
            if_de_pc      <= 32'b0;
            if_de_next_pc <= 32'b0;
        end
        else if (flush) begin
            if_de_ir      <= 32'h00000013;  // NOP
            if_de_pc      <= 32'b0;
            if_de_next_pc <= 32'b0;
        end
        else if (stall) begin
            if_de_ir      <= if_de_ir;
            if_de_pc      <= if_de_pc;
            if_de_next_pc <= if_de_next_pc;
        end
        else begin
            if_de_pc      <= pc;
            if_de_ir      <= IR;
            if_de_next_pc <= next_pc;
        end
    end

    //==========================================================
    //==== Instruction Decode ==================================
    //==========================================================

    opcode_t OPCODE;
    assign OPCODE = opcode_t'(if_de_ir[6:0]);

    assign de_inst.opcode    = OPCODE;
    assign de_inst.ir_funct  = if_de_ir[14:12];
    assign de_inst.rs1_addr  = if_de_ir[19:15];
    assign de_inst.rs2_addr  = if_de_ir[24:20];
    assign de_inst.rd_addr   = if_de_ir[11:7];
    assign de_inst.pc        = if_de_pc;
    assign de_inst.alu_fun   = alu_fun;
    assign de_inst.mem_type  = if_de_ir[14:12];

    assign de_inst.regWrite  = regWrite;
    assign de_inst.memWrite  = memWrite;
    assign de_inst.pc_sel    = pc_sel;

    assign de_inst.rf_wr_sel = rf_wr_sel;
    assign de_inst.memRead2  = memRead2;
    assign de_inst.alu_srcA  = alu_srcA;
    assign de_inst.alu_srcB  = alu_srcB;
    assign de_inst.rd_used   = regWrite && de_inst.rd_addr != 0;

    assign de_inst.rs1_used = de_inst.rs1_addr != 0
                           && de_inst.opcode != LUI
                           && de_inst.opcode != AUIPC
                           && de_inst.opcode != JAL;

    assign de_inst.rs2_used = de_inst.rs2_addr != 0
                           && (de_inst.opcode == BRANCH
                           ||  de_inst.opcode == OP
                           ||  de_inst.opcode == STORE);

    always_ff @(posedge CLK) begin
      if (RESET || flush || stall) begin
        de_ex_inst    <= 32'h00000013;
        de_ex_opA     <= 32'b0;
        de_ex_rs2     <= 32'b0;
        de_ex_I_immed <= 32'b0;
        de_ex_S_immed <= 32'b0;
        de_ex_U_immed <= 32'b0;
        de_ex_J_immed <= 32'b0;
        de_ex_B_immed <= 32'b0;
      end
      else begin
        de_ex_inst    <= de_inst;
        de_ex_opA     <= rs1;
        de_ex_rs2     <= rs2;
        de_ex_I_immed <= I_immed;
        de_ex_S_immed <= S_immed;
        de_ex_U_immed <= U_immed;
        de_ex_J_immed <= J_immed;
        de_ex_B_immed <= B_immed;
      end
    end

    //==========================================================
    //==== Execute =============================================
    //==========================================================

    always_ff @(posedge CLK) begin
        ex_mem_inst      <= de_ex_inst;
        ex_mem_aluResult <= aluResult;
        ex_mem_rs2       <= de_ex_rs2_store_fwd;
    end

    //==========================================================
    //==== Memory ==============================================
    //==========================================================

    always_ff @(posedge CLK) begin
        mem_wb_inst      <= ex_mem_inst;
        mem_wb_aluResult <= ex_mem_aluResult;
        mem_wb_rs2       <= ex_mem_rs2;
        mem_wb_mem_data  <= mem_data;
    end

    //==========================================================
    //==== Write Back ==========================================
    //==========================================================

    always_comb begin
        case (mem_wb_inst.rf_wr_sel)
            2'b00: wd = mem_wb_inst.pc + 4;  // JAL/JALR return address
            2'b01: wd = 32'b0;               // CSR, tied to 0 for now
            2'b10: wd = mem_wb_mem_data;
            2'b11: wd = mem_wb_aluResult;
        default:
            wd = mem_wb_inst.pc + 4;
        endcase
    end

endmodule