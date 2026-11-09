// pl_reg_em.v - EX/MEM pipeline register (Execute -> Memory)
//
// reset clears every field.

module pl_reg_em #(
    parameter PCB = 12
) (
    input                clk,
    input                reset,

    // Execute stage
    input      [31:0]    ALUResultE,
    input      [31:0]    WriteDataE,
    input      [4:0]     RdE,
    input      [2:0]     funct3E,
    input      [PCB-1:0] PCE,
    input      [1:0]     ResultSrcE,
    input                RegWriteE, MemWriteE,

    // Memory stage
    output reg [31:0]    ALUResultM,
    output reg [31:0]    WriteDataM,
    output reg [4:0]     RdM,
    output reg [2:0]     funct3M,
    output reg [PCB-1:0] PCM,
    output reg [1:0]     ResultSrcM,
    output reg           RegWriteM, MemWriteM
);

initial begin
    ALUResultM = 0; WriteDataM = 0; RdM = 0; funct3M = 0; PCM = 0;
    ResultSrcM = 0; RegWriteM = 0; MemWriteM = 0;
end

always @(posedge clk) begin
    if (reset) begin
        ALUResultM <= 32'b0;
        WriteDataM <= 32'b0;
        RdM        <= 5'b0;
        funct3M    <= 3'b0;
        PCM        <= {PCB{1'b0}};
        ResultSrcM <= 2'b00;
        RegWriteM  <= 1'b0;
        MemWriteM  <= 1'b0;
    end
    else begin
        ALUResultM <= ALUResultE;
        WriteDataM <= WriteDataE;
        RdM        <= RdE;
        funct3M    <= funct3E;
        PCM        <= PCE;
        ResultSrcM <= ResultSrcE;
        RegWriteM  <= RegWriteE;
        MemWriteM  <= MemWriteE;
    end
end

endmodule
