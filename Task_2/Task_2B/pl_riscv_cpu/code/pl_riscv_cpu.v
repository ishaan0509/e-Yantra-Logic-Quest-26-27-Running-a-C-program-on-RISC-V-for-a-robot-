// pl_riscv_cpu.v - top level (ports unchanged) + riscv_cpu wrapper
//
// Changes vs. the previous version:
//   * instr_mem is now a synchronous ROM (block RAM) and receives the NEXT
//     fetch address (InstrAddr) instead of the current PC.
//   * data_mem returns its load data through the RAM output register, so
//     ReadData now appears in the Write-back stage of the load.  The
//     testbench never reads ReadData, and Result / PCW / ALUResultW /
//     WriteDataW / MemWrite / WriteData / DataAdr keep exactly the same
//     timing as before.

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
    wire [2:0]  funct3;
    wire        MemWrite_rv32;

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
        .funct3((Ext_MemWrite && reset) ? 3'b010 : funct3),
        .wr_addr(DataAdr),
        .wr_data(WriteData),
        .rd_data_mem(ReadData)
    );

    assign MemWrite = (Ext_MemWrite && reset)
                    ? 1'b1 : MemWrite_rv32;

    assign WriteData = (Ext_MemWrite && reset)
                     ? Ext_WriteData : WriteData_rv32;

    assign DataAdr = reset ? Ext_DataAdr : DataAdr_rv32;

endmodule

