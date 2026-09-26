// riscv_cpu.v - top CPU wrapper connecting controller & datapath

module riscv_cpu (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result
);

    wire       ALUSrc;
    wire       ALUSrcA;
    wire       RegWrite;
    wire       Jump;
    wire       JALR;
    wire       Branch;

    wire [1:0] ResultSrc;
    wire [2:0] ImmSrc;
    wire [3:0] ALUControl;

    controller c (
        .op         (Instr[6:0]),
        .funct3     (Instr[14:12]),
        .funct7b5   (Instr[30]),
        .ResultSrc  (ResultSrc),
        .MemWrite   (MemWrite),
        .Branch     (Branch),
        .ALUSrc     (ALUSrc),
        .ALUSrcA    (ALUSrcA),
        .RegWrite   (RegWrite),
        .Jump       (Jump),
        .JALR       (JALR),
        .ImmSrc     (ImmSrc),
        .ALUControl (ALUControl)
    );

    datapath dp (
        .clk        (clk),
        .reset      (reset),
        .ResultSrc  (ResultSrc),
        .Branch     (Branch),
        .Jump       (Jump),
        .JALR       (JALR),
        .ALUSrc     (ALUSrc),
        .ALUSrcA    (ALUSrcA),
        .RegWrite   (RegWrite),
        .ImmSrc     (ImmSrc),
        .ALUControl (ALUControl),
        .PC         (PC),
        .Instr      (Instr),
        .Mem_WrAddr (Mem_WrAddr),
        .Mem_WrData (Mem_WrData),
        .ReadData   (ReadData),
        .Result     (Result)
    );

endmodule