// datapath.v - 5-stage pipelined RV32I datapath (area-optimised)
//
// Area savings vs. the previous version (all invisible to the testbench):
//   * register file + data memory + instruction memory live in block RAM
//   * PC is only PCB (=11) bits wide: the instruction memory has 512 words
//   * PCPlus4 is no longer pipelined; WB recomputes PCW+4 for JAL/JALR links
//   * LUI is executed by the ALU (0 + imm) -> no ImmExt in EX/MEM, MEM/WB
//   * RD1E/RD2E are the register-file RAM output registers (no extra flops)
//   * the register file is written on the rising edge, so a value written
//     on the same edge as it is read is forwarded in EX from the WB+1 stage
//   * only control signals (and PC, used by the testbench) are reset/flushed
//   * branch compare + JALR target reuse the ALU (no extra comparators/adder)

module datapath (
    input         clk,
    input         reset,
    output [31:0] PC,             // PC of the instruction currently in IF (as in the original design)
    output [31:0] InstrAddr,      // address for the synchronous instr_mem (next PC)
    input  [31:0] Instr,          // instruction in IF (instr_mem output reg)
    output        MemWrite,
    output [31:0] Mem_WrAddr,
    output [31:0] Mem_WrData,
    input  [31:0] ReadData,       // formatted load data, valid in WB
    output [31:0] Result,
    output [2:0]  funct3,
    output [31:0] PCW,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW
);

    // PC width: log2(512 words) + 2 byte bits
    localparam PCB = 11;
    localparam [PCB-1:0] FOUR = 4;

    // =========================================================
    // DECLARATIONS
    // =========================================================

    // EX/MEM
    reg [31:0]    ALUResultM;
    reg [31:0]    WriteDataM;
    reg [PCB-1:0] PCM;
    reg [4:0]     RdM;
    reg [2:0]     funct3M;
    reg [1:0]     ResultSrcM;
    reg           RegWriteM;
    reg           MemWriteM;

    // MEM/WB
    reg [31:0]    ALUResultW_reg;
    reg [31:0]    WriteDataW_reg;
    reg [PCB-1:0] PCW_reg;
    reg [4:0]     RdW;
    reg [1:0]     ResultSrcW;
    reg           RegWriteW;

    // WB+1 (value written to the register file on the previous edge)
    reg [31:0]    ResultW_d;
    reg [4:0]     RdW_d;
    reg           RegWriteW_d;

    // ID/EX (RD1E / RD2E are inside reg_file)
    reg [PCB-1:0] PCE;
    reg [31:0]    ImmExtE;
    reg [4:0]     Rs1E, Rs2E, RdE;
    reg [2:0]     funct3E;
    reg           opb5E;
    reg           funct7b5E;
    reg [1:0]     ResultSrcE;
    reg [1:0]     ALUOpE;
    reg           RegWriteE;
    reg           MemWriteE;
    reg           BranchE;
    reg           ALUSrcE;
    reg           ALUSrcAE;
    reg           LuiE;
    reg           JumpE;
    reg           JalrE;

    wire [31:0] RD1E;
    wire [31:0] RD2E;

    wire StallD;
    wire FlushD;
    wire FlushE;

    // Power-up values (free in the FPGA): keeps simulation free of X at t=0
    initial begin
        PCE = 0; ResultSrcE = 0; RegWriteE = 0; MemWriteE = 0; BranchE = 0;
        ALUSrcE = 0; LuiE = 0; JumpE = 0; JalrE = 0;
        PCM = 0; ResultSrcM = 0; RegWriteM = 0; MemWriteM = 0;
        PCW_reg = 0; ResultSrcW = 0; RegWriteW = 0; RegWriteW_d = 0;
    end

    // =========================================================
    // IF STAGE
    // =========================================================

    reg  [PCB-1:0] PC_reg;
    wire [PCB-1:0] PCPlus4F;
    wire [PCB-1:0] PCNext;
    wire [PCB-1:0] PCFetchNext;     // value PC_reg loads / ROM address

    initial PC_reg = 0;

    assign PC = {{(32-PCB){1'b0}}, PC_reg};

    adder #(PCB) pcadd4 (
        .a(PC_reg),
        .b(FOUR),
        .y(PCPlus4F)
    );

    assign PCFetchNext = reset   ? {PCB{1'b0}} :
                         StallD  ? PC_reg      : PCNext;

    always @(posedge clk)
        PC_reg <= PCFetchNext;

    // The ROM registers its output on the same edge PC_reg loads, so
    // Instr always belongs to PC_reg, exactly like an asynchronous ROM.
    assign InstrAddr = {{(32-PCB){1'b0}}, PCFetchNext};

    // =========================================================
    // IF/ID PIPELINE REGISTER
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
    // ID STAGE
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
    wire [31:0] ResultW;

    // Read data comes out one cycle later = RD1E / RD2E
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

    reg UsesRs1D;
    reg UsesRs2D;

    always @(*) begin
        case (InstrD[6:0])
            7'b0110011: {UsesRs1D, UsesRs2D} = 2'b11;
            7'b0010011: {UsesRs1D, UsesRs2D} = 2'b10;
            7'b0000011: {UsesRs1D, UsesRs2D} = 2'b10;
            7'b0100011: {UsesRs1D, UsesRs2D} = 2'b11;
            7'b1100011: {UsesRs1D, UsesRs2D} = 2'b11;
            7'b1100111: {UsesRs1D, UsesRs2D} = 2'b10;
            default:    {UsesRs1D, UsesRs2D} = 2'b00;
        endcase
    end

    // LUI: the main decoder marks it with ResultSrc = 11.  Execute it in the
    // ALU as 0 + imm so the immediate never has to travel down the pipeline.
    wire LuiD = (ResultSrcD == 2'b11);

    // =========================================================
    // ID/EX PIPELINE REGISTER
    //   control bits + PCE are cleared on reset/flush; pure data fields
    //   are simply loaded (a bubble has all its control bits at 0).
    // =========================================================

    always @(posedge clk) begin
        ImmExtE   <= ImmExtD;
        Rs1E      <= Rs1D;
        Rs2E      <= Rs2D;
        RdE       <= RdD;
        funct3E   <= InstrD[14:12];
        opb5E     <= InstrD[5];
        funct7b5E <= InstrD[30];
        ALUOpE    <= ALUOpD;
        ALUSrcAE  <= ALUSrcAD;
    end

    always @(posedge clk) begin
        if (reset || FlushE) begin
            PCE        <= {PCB{1'b0}};
            ResultSrcE <= 2'b00;
            RegWriteE  <= 1'b0;
            MemWriteE  <= 1'b0;
            BranchE    <= 1'b0;
            ALUSrcE    <= 1'b0;
            LuiE       <= 1'b0;
            JumpE      <= 1'b0;
            JalrE      <= 1'b0;
        end
        else begin
            PCE        <= PCD;
            ResultSrcE <= LuiD ? 2'b00 : ResultSrcD;
            RegWriteE  <= RegWriteD;
            MemWriteE  <= MemWriteD;
            BranchE    <= BranchD;
            ALUSrcE    <= ALUSrcD | LuiD;
            LuiE       <= LuiD;
            JumpE      <= JumpD;
            JalrE      <= JalrD;
        end
    end

    // =========================================================
    // HAZARD DETECTION & FORWARDING
    //   ForwardXE: 00 = register file, 01 = ResultW (WB),
    //              10 = ALUResultM (MEM), 11 = ResultW_d (WB+1)
    // =========================================================

    reg       StallLoadUse;
    reg [1:0] ForwardAE;
    reg [1:0] ForwardBE;

    always @(*) begin
        StallLoadUse = 1'b0;
        ForwardAE    = 2'b00;
        ForwardBE    = 2'b00;

        if (RegWriteM && (ResultSrcM != 2'b01) && (RdM != 5'b0) && (RdM == Rs1E))
            ForwardAE = 2'b10;
        else if (RegWriteW && (RdW != 5'b0) && (RdW == Rs1E))
            ForwardAE = 2'b01;
        else if (RegWriteW_d && (RdW_d != 5'b0) && (RdW_d == Rs1E))
            ForwardAE = 2'b11;

        if (RegWriteM && (ResultSrcM != 2'b01) && (RdM != 5'b0) && (RdM == Rs2E))
            ForwardBE = 2'b10;
        else if (RegWriteW && (RdW != 5'b0) && (RdW == Rs2E))
            ForwardBE = 2'b01;
        else if (RegWriteW_d && (RdW_d != 5'b0) && (RdW_d == Rs2E))
            ForwardBE = 2'b11;

        if ((ResultSrcE == 2'b01) && (RdE != 5'b0) &&
            ((UsesRs1D && (RdE == Rs1D)) || (UsesRs2D && (RdE == Rs2D))))
            StallLoadUse = 1'b1;
    end

    wire PCSrcE;

    assign StallD = StallLoadUse;
    assign FlushD = PCSrcE;
    assign FlushE = StallLoadUse || PCSrcE;

    // =========================================================
    // EX STAGE
    // =========================================================

    wire [31:0] ForwardedA = (ForwardAE == 2'b10) ? ALUResultM :
                             (ForwardAE == 2'b01) ? ResultW    :
                             (ForwardAE == 2'b11) ? ResultW_d  : RD1E;

    wire [31:0] ForwardedB = (ForwardBE == 2'b10) ? ALUResultM :
                             (ForwardBE == 2'b01) ? ResultW    :
                             (ForwardBE == 2'b11) ? ResultW_d  : RD2E;

    wire [31:0] SrcAE = ALUSrcAE ? {{(32-PCB){1'b0}}, PCE} :
                        LuiE     ? 32'b0                    : ForwardedA;
    wire [31:0] SrcBE = ALUSrcE  ? ImmExtE                  : ForwardedB;

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

    // JALR: rs1 + imm is already computed by the ALU (ALUOp = 00)
    wire [PCB-1:0] JalrTargetE = {ALUResultE[PCB-1:1], 1'b0};

    assign PCSrcE = (BranchE && TakeBranchE) || JumpE || JalrE;
    assign PCNext = PCSrcE ? (JalrE ? JalrTargetE : PCTargetE) : PCPlus4F;

    // =========================================================
    // EX/MEM PIPELINE REGISTER
    // =========================================================

    always @(posedge clk) begin
        ALUResultM <= ALUResultE;
        WriteDataM <= ForwardedB;
        RdM        <= RdE;
        funct3M    <= funct3E;
    end

    always @(posedge clk) begin
        if (reset) begin
            PCM        <= {PCB{1'b0}};
            ResultSrcM <= 2'b00;
            RegWriteM  <= 1'b0;
            MemWriteM  <= 1'b0;
        end
        else begin
            PCM        <= PCE;
            ResultSrcM <= ResultSrcE;
            RegWriteM  <= RegWriteE;
            MemWriteM  <= MemWriteE;
        end
    end

    // =========================================================
    // MEM STAGE (data_mem is outside; its read data arrives in WB)
    // =========================================================

    assign MemWrite   = MemWriteM;
    assign Mem_WrAddr = ALUResultM;
    assign Mem_WrData = WriteDataM;
    assign funct3     = funct3M;

    // =========================================================
    // MEM/WB PIPELINE REGISTER
    // =========================================================

    always @(posedge clk) begin
        ALUResultW_reg <= ALUResultM;
        WriteDataW_reg <= WriteDataM;
        RdW            <= RdM;
    end

    always @(posedge clk) begin
        if (reset) begin
            PCW_reg    <= {PCB{1'b0}};
            ResultSrcW <= 2'b00;
            RegWriteW  <= 1'b0;
        end
        else begin
            PCW_reg    <= PCM;
            ResultSrcW <= ResultSrcM;
            RegWriteW  <= RegWriteM;
        end
    end

    // =========================================================
    // WB STAGE
    // =========================================================

    wire [PCB-1:0] PCPlus4W;

    adder #(PCB) pcadd4w (
        .a(PCW_reg),
        .b(FOUR),
        .y(PCPlus4W)
    );

    assign ResultW = ResultSrcW[1] ? {{(32-PCB){1'b0}}, PCPlus4W} :
                     ResultSrcW[0] ? ReadData                     : ALUResultW_reg;

    assign Result     = ResultW;
    assign PCW        = {{(32-PCB){1'b0}}, PCW_reg};
    assign ALUResultW = ALUResultW_reg;
    assign WriteDataW = WriteDataW_reg;

    // WB+1 stage: what the register file received on the previous edge
    always @(posedge clk) begin
        ResultW_d <= ResultW;
        RdW_d     <= RdW;
        if (reset)
            RegWriteW_d <= 1'b0;
        else
            RegWriteW_d <= RegWriteW;
    end

endmodule
