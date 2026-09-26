// datapath.v - Complete RV32I datapath

module datapath (
    input         clk, reset,
    input  [1:0]  ResultSrc,
    input         Branch,
    input         Jump,
    input         JALR,
    input         ALUSrc,
    input         ALUSrcA,
    input         RegWrite,
    input  [2:0]  ImmSrc,
    input  [3:0]  ALUControl,

    output [31:0] PC,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr,
    output [31:0] Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result
);

    wire [31:0] PCNext, PCPlus4, PCTarget, JALRTarget, PCTargetFinal;
    wire [31:0] ImmExt, SrcA, SrcB, WriteData, ALUResult, ALUSrcAData;
    wire        Zero;

    // ----------------------------------------------------
    // Branch Condition Evaluation
    // ----------------------------------------------------
    reg TakeBranch;
    always @(*) begin
        case (Instr[14:12]) // funct3
            3'b000: TakeBranch = (SrcA == WriteData);                          // BEQ
            3'b001: TakeBranch = (SrcA != WriteData);                          // BNE
            3'b100: TakeBranch = ($signed(SrcA) < $signed(WriteData));         // BLT
            3'b101: TakeBranch = ($signed(SrcA) >= $signed(WriteData));        // BGE
            3'b110: TakeBranch = (SrcA < WriteData);                           // BLTU
            3'b111: TakeBranch = (SrcA >= WriteData);                          // BGEU
            default: TakeBranch = 1'b0;
        endcase
    end

    wire PCSrc = (Branch & TakeBranch) | Jump | JALR;

    // ----------------------------------------------------
    // PC & Jump Logic
    // ----------------------------------------------------
    reset_ff #(32) pcreg (
        .clk(clk),
        .rst(reset),
        .d  (PCNext),
        .q  (PC)
    );

    adder pcadd4 (
        .a  (PC),
        .b  (32'd4),
        .sum(PCPlus4)
    );

    adder pcaddbranch (
        .a  (PC),
        .b  (ImmExt),
        .sum(PCTarget)
    );

    assign JALRTarget = {ALUResult[31:1], 1'b0};

    mux2 #(32) jalrmux (
        .d0 (PCTarget),
        .d1 (JALRTarget),
        .sel(JALR),
        .y  (PCTargetFinal)
    );

    mux2 #(32) pcmux (
        .d0 (PCPlus4),
        .d1 (PCTargetFinal),
        .sel(PCSrc),
        .y  (PCNext)
    );

    // ----------------------------------------------------
    // Register File & Immediate Generation
    // ----------------------------------------------------
    reg_file rf (
        .clk     (clk),
        .wr_en   (RegWrite),
        .rd_addr1(Instr[19:15]),
        .rd_addr2(Instr[24:20]),
        .wr_addr (Instr[11:7]),
        .wr_data (Result),
        .rd_data1(SrcA),
        .rd_data2(WriteData)
    );

    imm_extend ext (
        .instr (Instr[31:7]),
        .immsrc(ImmSrc),
        .immext(ImmExt)
    );

    // ALU input A: 0 = rs1, 1 = PC (AUIPC)
    mux2 #(32) srcamux (
        .d0 (SrcA),
        .d1 (PC),
        .sel(ALUSrcA),
        .y  (ALUSrcAData)
    );

    // ALU input B: 0 = rs2, 1 = Immediate
    mux2 #(32) srcbmux (
        .d0 (WriteData),
        .d1 (ImmExt),
        .sel(ALUSrc),
        .y  (SrcB)
    );

    alu alu_inst (
        .a       (ALUSrcAData),
        .b       (SrcB),
        .alu_ctrl(ALUControl),
        .alu_out (ALUResult),
        .zero    (Zero)
    );

    // ----------------------------------------------------
    // Load Extension (LB, LH, LW, LBU, LHU)
    // ----------------------------------------------------
    wire [1:0] byte_offset = ALUResult[1:0];
    reg [7:0]  selected_byte;
    reg [15:0] selected_half;
    reg [31:0] FormattedReadData;

    always @(*) begin
        case (byte_offset)
            2'b00: selected_byte = ReadData[7:0];
            2'b01: selected_byte = ReadData[15:8];
            2'b10: selected_byte = ReadData[23:16];
            2'b11: selected_byte = ReadData[31:24];
        endcase

        case (byte_offset[1])
            1'b0: selected_half = ReadData[15:0];
            1'b1: selected_half = ReadData[31:16];
        endcase

        case (Instr[14:12]) // funct3
            3'b000: FormattedReadData = {{24{selected_byte[7]}}, selected_byte};   // LB
            3'b001: FormattedReadData = {{16{selected_half[15]}}, selected_half}; // LH
            3'b010: FormattedReadData = ReadData;                                  // LW
            3'b100: FormattedReadData = {24'b0, selected_byte};                    // LBU
            3'b101: FormattedReadData = {16'b0, selected_half};                    // LHU
            default: FormattedReadData = ReadData;
        endcase
    end

    // Direct connection to data memory
    assign Mem_WrData = WriteData;
    assign Mem_WrAddr = ALUResult;

    // ----------------------------------------------------
    // Writeback Mux
    // ----------------------------------------------------
    mux4 #(32) resultmux (
        .d0 (ALUResult),
        .d1 (FormattedReadData),
        .d2 (PCPlus4),
        .d3 (ImmExt),
        .sel(ResultSrc),
        .y  (Result)
    );

endmodule