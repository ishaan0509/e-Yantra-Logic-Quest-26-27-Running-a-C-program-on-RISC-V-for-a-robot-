// pl_reg_mw.v - MEM/WB pipeline register (Memory -> Write-back)
//
// reset clears every field. The load data is not here: data_mem registers it inside the
// RAM, and it comes out in the Write-back stage (see data_mem.v).

module pl_reg_mw #(
    parameter PCB = 12
) (
    input                clk,
    input                reset,

    // Memory stage
    input      [31:0]    ALUResultM,
    input      [31:0]    WriteDataM,
    input      [4:0]     RdM,
    input      [PCB-1:0] PCM,
    input      [1:0]     ResultSrcM,
    input                RegWriteM,

    // Write-back stage
    output reg [31:0]    ALUResultW,
    output reg [31:0]    WriteDataW,
    output reg [4:0]     RdW,
    output reg [PCB-1:0] PCW,
    output reg [1:0]     ResultSrcW,
    output reg           RegWriteW
);

initial begin
    ALUResultW = 0; WriteDataW = 0; RdW = 0; PCW = 0; ResultSrcW = 0; RegWriteW = 0;
end

always @(posedge clk) begin
    if (reset) begin
        ALUResultW <= 32'b0;
        WriteDataW <= 32'b0;
        RdW        <= 5'b0;
        PCW        <= {PCB{1'b0}};
        ResultSrcW <= 2'b00;
        RegWriteW  <= 1'b0;
    end
    else begin
        ALUResultW <= ALUResultM;
        WriteDataW <= WriteDataM;
        RdW        <= RdM;
        PCW        <= PCM;
        ResultSrcW <= ResultSrcM;
        RegWriteW  <= RegWriteM;
    end
end

endmodule
