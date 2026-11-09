// datapath.v - 5-stage pipelined RV32I datapath (Fetch, Decode, Execute, Memory, Write-back)
//
// Pipeline registers: pl_reg_fd (IF/ID), pl_reg_de (ID/EX), pl_reg_em (EX/MEM),
// pl_reg_mw (MEM/WB). Forwarding, the load-use stall and the flushes: hazard_unit.
//
// Reset: while reset is 1, the PC loads 0 and every pipeline register is cleared (IF/ID
// holds a NOP), so after a reset the CPU starts again from address 0 with an empty
// pipeline, and data memory is never written while reset is 1.
//
// Area:
//   * the register file, data memory and instruction memory are block RAM (M9K)
//   * the PC is PCB = 12 bits wide: 1024 words = 4096 bytes of instruction memory
//   * PCPlus4 is not pipelined: Write-back recomputes PC + 4 for the jal / jalr link
//   * lui runs in the ALU as 0 + imm, so the immediate does not travel past Execute
//   * RD1E / RD2E are the register file's read registers (no extra flops)
//   * the register file is written on the rising edge; a value written on the same edge
//     as it is read is forwarded in Execute from the WB+1 register (ResultW_d)
//   * the branch compare and the jalr target reuse the ALU

module datapath (
    input         clk,
    input         reset,
    output [31:0] PC,             // PC of the instruction in Fetch
    output [31:0] InstrAddr,      // address for the synchronous instr_mem: the next PC
    input  [31:0] Instr,          // instruction at PC (instr_mem output register)
    output        MemWrite,
    output [31:0] Mem_WrAddr,
    output [31:0] Mem_WrData,
    input  [31:0] ReadData,       // formatted load data, valid in Write-back
    output [31:0] Result,
    output [2:0]  funct3,
    output [31:0] PCW,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW
);

    // PC width: log2(1024 words) + 2 byte-address bits
    localparam PCB = 12;
    localparam [PCB-1:0] FOUR = 4;

    // hazard unit
    wire       StallF, StallD, FlushD, FlushE;
    wire [1:0] ForwardAE, ForwardBE;
    wire       PCSrcE;

    // =========================================================
    // FETCH
    // =========================================================

    reg  [PCB-1:0] PC_reg;
    wire [PCB-1:0] PCPlus4F;
    wire [PCB-1:0] PCNext;
    wire [PCB-1:0] PCFetchNext;     // the value PC_reg loads = instr_mem address

    initial PC_reg = 0;

    assign PC = {{(32-PCB){1'b0}}, PC_reg};

    adder #(PCB) pcadd4 (
        .a(PC_reg),
        .b(FOUR),
        .y(PCPlus4F)
    );

    assign PCFetchNext = reset  ? {PCB{1'b0}} :
                         StallF ? PC_reg      : PCNext;

    always @(posedge clk)
        PC_reg <= PCFetchNext;

    // instr_mem registers its output on the same edge PC_reg loads, so Instr is
    // always the instruction at PC_reg, as with an asynchronous read.
    assign InstrAddr = {{(32-PCB){1'b0}}, PCFetchNext};

    // =========================================================
    // IF/ID
    // =========================================================

    wire [31:0]    InstrD;
    wire [PCB-1:0] PCD;

    pl_reg_fd #(.PCB(PCB)) plfd (
        .clk(clk),
        .en(~StallD),
        .clr(FlushD | reset),
        .InstrF(Instr),
        .PCF(PC_reg),
        .InstrD(InstrD),
        .PCD(PCD)
    );

    // =========================================================
    // DECODE
    // =========================================================

    wire [1:0] ResultSrcD;
    wire       MemWriteD;
    wire       BranchD;
    wire       ALUSrcD;
    wire       ALUSrcAD;
    wire       RegWriteD;
    wire       JumpD;
    wire       JalrD;
    wire [2:0] ImmSrcD;
    wire [1:0] ALUOpD;

    controller ctrl (
        .op(InstrD[6:0]),
        .funct3(InstrD[14:12]),
        .opb5(InstrD[5]),
        .funct7b5(InstrD[30]),
        .ResultSrc(ResultSrcD),
        .MemWrite(MemWriteD),
        .Branch(BranchD),
        .ALUSrc(ALUSrcD),
        .ALUSrcA(ALUSrcAD),
        .RegWrite(RegWriteD),
        .Jump(JumpD),
        .Jalr(JalrD),
        .ImmSrc(ImmSrcD),
        .ALUOp(ALUOpD)
    );

    wire [4:0] Rs1D = InstrD[19:15];
    wire [4:0] Rs2D = InstrD[24:20];
    wire [4:0] RdD  = InstrD[11:7];

    wire [31:0] ImmExtD;
    wire [31:0] RD1E, RD2E;         // register file read registers = ID/EX operands
    wire [31:0] ResultW;
    wire [4:0]  RdW;
    wire        RegWriteW;

    reg_file rf (
        .clk(clk),
        .wr_en(RegWriteW),
        .rd_addr1(Rs1D),
        .rd_addr2(Rs2D),
        .wr_addr(RdW),
        .wr_data(ResultW),
        .rd_data1(RD1E),
        .rd_data2(RD2E)
    );

    imm_extend ext (
        .instr(InstrD[31:7]),
        .immsrc(ImmSrcD),
        .immext(ImmExtD)
    );

    // lui: main_decoder marks it with ResultSrc = 11. It runs in the ALU as 0 + imm
    // (ALUSrc = 1, operand A = 0) and writes back the ALU result (ResultSrc = 00).
    wire LuiD = (ResultSrcD == 2'b11);

    // =========================================================
    // ID/EX
    // =========================================================

    wire [PCB-1:0] PCE;
    wire [31:0]    ImmExtE;
    wire [4:0]     Rs1E, Rs2E, RdE;
    wire [2:0]     funct3E;
    wire           opb5E, funct7b5E;
    wire [1:0]     ALUOpE;
    wire           ALUSrcAE;
    wire [1:0]     ResultSrcE;
    wire           RegWriteE, MemWriteE, BranchE, ALUSrcE, LuiE, JumpE, JalrE;

    pl_reg_de #(.PCB(PCB)) plde (
        .clk(clk),
        .reset(reset),
        .flush(FlushE),
        .PCD(PCD),
        .ImmExtD(ImmExtD),
        .Rs1D(Rs1D), .Rs2D(Rs2D), .RdD(RdD),
        .funct3D(InstrD[14:12]),
        .opb5D(InstrD[5]), .funct7b5D(InstrD[30]),
        .ALUOpD(ALUOpD),
        .ALUSrcAD(ALUSrcAD),
        .ResultSrcD(LuiD ? 2'b00 : ResultSrcD),
        .RegWriteD(RegWriteD), .MemWriteD(MemWriteD), .BranchD(BranchD),
        .ALUSrcD(ALUSrcD | LuiD), .LuiD(LuiD), .JumpD(JumpD), .JalrD(JalrD),
        .PCE(PCE),
        .ImmExtE(ImmExtE),
        .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
        .funct3E(funct3E),
        .opb5E(opb5E), .funct7b5E(funct7b5E),
        .ALUOpE(ALUOpE),
        .ALUSrcAE(ALUSrcAE),
        .ResultSrcE(ResultSrcE),
        .RegWriteE(RegWriteE), .MemWriteE(MemWriteE), .BranchE(BranchE),
        .ALUSrcE(ALUSrcE), .LuiE(LuiE), .JumpE(JumpE), .JalrE(JalrE)
    );

    // =========================================================
    // HAZARD UNIT
    // =========================================================

    wire [4:0]  RdM;
    wire        RegWriteM;
    wire [1:0]  ResultSrcM;

    reg  [31:0] ResultW_d;          // WB+1: what the register file received last edge
    reg  [4:0]  RdW_d;
    reg         RegWriteW_d;

    hazard_unit hu (
        .opD(InstrD[6:0]),
        .Rs1D(Rs1D), .Rs2D(Rs2D),
        .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
        .ResultSrcE(ResultSrcE),
        .PCSrcE(PCSrcE),
        .RdM(RdM), .RegWriteM(RegWriteM), .ResultSrcM(ResultSrcM),
        .RdW(RdW), .RegWriteW(RegWriteW),
        .RdW_d(RdW_d), .RegWriteW_d(RegWriteW_d),
        .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE),
        .ForwardAE(ForwardAE), .ForwardBE(ForwardBE)
    );

    // =========================================================
    // EXECUTE
    // =========================================================

    wire [31:0] ALUResultM;

    wire [31:0] ForwardedA = (ForwardAE == 2'b10) ? ALUResultM :
                             (ForwardAE == 2'b01) ? ResultW    :
                             (ForwardAE == 2'b11) ? ResultW_d  : RD1E;

    wire [31:0] ForwardedB = (ForwardBE == 2'b10) ? ALUResultM :
                             (ForwardBE == 2'b01) ? ResultW    :
                             (ForwardBE == 2'b11) ? ResultW_d  : RD2E;

    wire [31:0] SrcAE = ALUSrcAE ? {{(32-PCB){1'b0}}, PCE} :    // auipc
                        LuiE     ? 32'b0                    :    // lui
                                   ForwardedA;
    wire [31:0] SrcBE = ALUSrcE  ? ImmExtE : ForwardedB;

    wire [3:0]  ALUControlE;
    wire [31:0] ALUResultE;
    wire        ZeroE, LtE, LtuE;
    wire        TakeBranchE;

    alu_decoder alu_dec (
        .ALUOp(ALUOpE),
        .funct3(funct3E),
        .opb5(opb5E),
        .funct7b5(funct7b5E),
        .ALUControl(ALUControlE)
    );

    alu alu_unit (
        .a(SrcAE),
        .b(SrcBE),
        .alu_ctrl(ALUControlE),
        .alu_out(ALUResultE),
        .zero(ZeroE),
        .lt(LtE),
        .ltu(LtuE)
    );

    branching_unit bu (
        .funct3(funct3E),
        .zero(ZeroE),
        .lt(LtE),
        .ltu(LtuE),
        .TakeBranch(TakeBranchE)
    );

    wire [PCB-1:0] PCTargetE;

    adder #(PCB) pctarget (
        .a(PCE),
        .b(ImmExtE[PCB-1:0]),
        .y(PCTargetE)
    );

    // jalr: rs1 + imm is computed by the ALU (ALUOp = 00); bit 0 is cleared
    wire [PCB-1:0] JalrTargetE = {ALUResultE[PCB-1:1], 1'b0};

    assign PCSrcE = (BranchE && TakeBranchE) || JumpE || JalrE;
    assign PCNext = PCSrcE ? (JalrE ? JalrTargetE : PCTargetE) : PCPlus4F;

    // =========================================================
    // EX/MEM
    // =========================================================

    wire [31:0]    WriteDataM;
    wire [2:0]     funct3M;
    wire [PCB-1:0] PCM;
    wire           MemWriteM;

    pl_reg_em #(.PCB(PCB)) plem (
        .clk(clk),
        .reset(reset),
        .ALUResultE(ALUResultE),
        .WriteDataE(ForwardedB),
        .RdE(RdE),
        .funct3E(funct3E),
        .PCE(PCE),
        .ResultSrcE(ResultSrcE),
        .RegWriteE(RegWriteE),
        .MemWriteE(MemWriteE),
        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .RdM(RdM),
        .funct3M(funct3M),
        .PCM(PCM),
        .ResultSrcM(ResultSrcM),
        .RegWriteM(RegWriteM),
        .MemWriteM(MemWriteM)
    );

    // =========================================================
    // MEMORY (data_mem is outside; its load data arrives in Write-back)
    // =========================================================

    assign MemWrite   = MemWriteM & ~reset;     // never write data memory during reset
    assign Mem_WrAddr = ALUResultM;
    assign Mem_WrData = WriteDataM;
    assign funct3     = funct3M;

    // =========================================================
    // MEM/WB
    // =========================================================

    wire [31:0]    ALUResultW_reg;
    wire [31:0]    WriteDataW_reg;
    wire [PCB-1:0] PCW_reg;
    wire [1:0]     ResultSrcW;

    pl_reg_mw #(.PCB(PCB)) plmw (
        .clk(clk),
        .reset(reset),
        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .RdM(RdM),
        .PCM(PCM),
        .ResultSrcM(ResultSrcM),
        .RegWriteM(RegWriteM),
        .ALUResultW(ALUResultW_reg),
        .WriteDataW(WriteDataW_reg),
        .RdW(RdW),
        .PCW(PCW_reg),
        .ResultSrcW(ResultSrcW),
        .RegWriteW(RegWriteW)
    );

    // =========================================================
    // WRITE-BACK
    // =========================================================

    wire [PCB-1:0] PCPlus4W;

    adder #(PCB) pcadd4w (
        .a(PCW_reg),
        .b(FOUR),
        .y(PCPlus4W)
    );

    assign ResultW = ResultSrcW[1] ? {{(32-PCB){1'b0}}, PCPlus4W} :   // jal, jalr: PC + 4
                     ResultSrcW[0] ? ReadData                     :   // loads
                                     ALUResultW_reg;                  // ALU, lui, auipc

    assign Result     = ResultW;
    assign PCW        = {{(32-PCB){1'b0}}, PCW_reg};
    assign ALUResultW = ALUResultW_reg;
    assign WriteDataW = WriteDataW_reg;

    // WB+1: what the register file received on the previous edge (forwarded by the
    // hazard unit as ForwardXE = 11). Cleared by reset like the pipeline registers.
    initial begin
        ResultW_d = 0; RdW_d = 0; RegWriteW_d = 0;
    end

    always @(posedge clk) begin
        if (reset) begin
            ResultW_d   <= 32'b0;
            RdW_d       <= 5'b0;
            RegWriteW_d <= 1'b0;
        end
        else begin
            ResultW_d   <= ResultW;
            RdW_d       <= RdW;
            RegWriteW_d <= RegWriteW;
        end
    end

endmodule
