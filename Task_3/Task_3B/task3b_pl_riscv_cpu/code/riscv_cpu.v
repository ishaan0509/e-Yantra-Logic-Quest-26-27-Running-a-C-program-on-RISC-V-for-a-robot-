module riscv_cpu (
    input         clk,
    input         reset,
    output [31:0] PC,
    output [31:0] InstrAddr,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr,
    output [31:0] Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result,
    output [2:0]  funct3,
    output [31:0] PCW,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW
);

    datapath dp (
        .clk(clk),
        .reset(reset),
        .PC(PC),
        .InstrAddr(InstrAddr),
        .Instr(Instr),
        .MemWrite(MemWrite),
        .Mem_WrAddr(Mem_WrAddr),
        .Mem_WrData(Mem_WrData),
        .ReadData(ReadData),
        .Result(Result),
        .funct3(funct3),
        .PCW(PCW),
        .ALUResultW(ALUResultW),
        .WriteDataW(WriteDataW)
    );

endmodule
