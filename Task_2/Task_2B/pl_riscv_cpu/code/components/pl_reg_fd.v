// pl_reg_fd.v - IF/ID pipeline register
// PCPlus4 is no longer carried (it is recomputed in Write-back when needed).

module pl_reg_fd #(
    parameter PCB = 11
) (
    input                clk,
    input                en,
    input                clr,
    input      [31:0]    InstrF,
    input      [PCB-1:0] PCF,
    output reg [31:0]    InstrD,
    output reg [PCB-1:0] PCD
);

always @(posedge clk) begin
    if (clr) begin
        // Flush: insert a NOP (addi x0,x0,0) into the decode stage
        InstrD <= 32'h00000013;
        PCD    <= {PCB{1'b0}};
    end
    else if (en) begin
        InstrD <= InstrF;
        PCD    <= PCF;
    end
    // If en = 0, retain the current values during a stall
end

endmodule