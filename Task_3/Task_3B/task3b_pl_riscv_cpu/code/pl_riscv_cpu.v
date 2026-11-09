
// pl_riscv_cpu.v - Top Module to test riscv_cpu (ports unchanged)
//
// * instr_mem is a synchronous ROM (block RAM) with 1024 words. It gets the address of
//   the NEXT instruction (InstrAddr), so its output is always the instruction at PC.
// * data_mem (128 words) returns load data through its RAM output register, so ReadData
//   is valid in the Write-back stage of the load, where the CPU uses it.
// * While reset is 1, data memory is written only through Ext_MemWrite (the testbench
//   writes the inputs); the CPU itself does not write while reset is 1.

module pl_riscv_cpu (
    input         clk,
    input         reset,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData,
    input  [31:0] Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData,
    output [31:0] DataAdr,
    output [31:0] ReadData,
    output [31:0] PCW,
    output [31:0] Result,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW
);

    wire [31:0] Instr;
    wire [31:0] PC;
    wire [31:0] InstrAddr;
    wire [31:0] DataAdr_rv32;
    wire [31:0] WriteData_rv32;
    wire [2:0]  Store, funct3;
    wire        MemWrite_rv32;

    // instantiate processor and memories
    riscv_cpu rvcpu (
        .clk(clk),
        .reset(reset),
        .PC(PC),
        .InstrAddr(InstrAddr),
        .Instr(Instr),
        .MemWrite(MemWrite_rv32),
        .Mem_WrAddr(DataAdr_rv32),
        .Mem_WrData(WriteData_rv32),
        .ReadData(ReadData),
        .Result(Result),
        .funct3(funct3),
        .PCW(PCW),
        .ALUResultW(ALUResultW),
        .WriteDataW(WriteDataW)
    );

    instr_mem instrmem (
        .clk(clk),
        .instr_addr(InstrAddr),
        .instr(Instr)
    );

    data_mem datamem (
        .clk(clk),
        .wr_en(MemWrite),
        .funct3(Store),
        .wr_addr(DataAdr),
        .wr_data(WriteData),
        .rd_data_mem(ReadData)
    );

    assign Store     = (Ext_MemWrite && reset) ? 3'b010 : funct3;
    assign MemWrite  = (Ext_MemWrite && reset) ? 1'b1 : MemWrite_rv32;
    assign WriteData = (Ext_MemWrite && reset) ? Ext_WriteData : WriteData_rv32;
    assign DataAdr   = reset ? Ext_DataAdr : DataAdr_rv32;

endmodule
