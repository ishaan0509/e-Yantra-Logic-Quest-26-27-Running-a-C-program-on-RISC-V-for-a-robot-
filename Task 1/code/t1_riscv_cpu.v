// t1_riscv_cpu.v - Top Module to test riscv_cpu

module t1_riscv_cpu (
    input         clk, reset,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData, Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData, DataAdr, ReadData,
    output [31:0] PC, Result
);

wire [31:0] Instr;
wire [31:0] DataAdr_rv32, WriteData_rv32;
wire        MemWrite_rv32;

// instantiate processor
riscv_cpu rvcpu (
    .clk        (clk),
    .reset      (reset),
    .PC         (PC),
    .Instr      (Instr),
    .MemWrite   (MemWrite_rv32),
    .Mem_WrAddr (DataAdr_rv32),
    .Mem_WrData (WriteData_rv32),
    .ReadData   (ReadData),
    .Result     (Result)
);

// instantiate instruction memory
instr_mem instrmem (
    .instr_addr (PC),
    .instr      (Instr)
);

// instantiate data memory
data_mem datamem (
    .clk         (clk),
    .wr_en       (MemWrite),
    .wr_addr     (DataAdr),
    .wr_data     (WriteData),
    .rd_data_mem (ReadData)
);

// External memory interface has priority during reset
assign MemWrite  = (Ext_MemWrite && reset) ? 1'b1 : MemWrite_rv32;
assign WriteData = (Ext_MemWrite && reset) ? Ext_WriteData : WriteData_rv32;
assign DataAdr   = reset ? Ext_DataAdr : DataAdr_rv32;

endmodule