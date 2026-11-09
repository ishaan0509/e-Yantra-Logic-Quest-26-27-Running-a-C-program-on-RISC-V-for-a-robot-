// pl_reg_fd.v - IF/ID pipeline register (Fetch -> Decode)
//
// clr (reset, or a taken branch / jump) puts a NOP (addi x0,x0,0) into Decode.
// en = 0 holds the register during a load-use stall.
// PCPlus4 is not carried: Write-back recomputes PC + 4 when a jump needs it.

module pl_reg_fd #(
    parameter PCB = 12              // PC bits: 1024 words of instruction memory = 4096 bytes
) (
    input                clk,
    input                en,
    input                clr,
    input      [31:0]    InstrF,
    input      [PCB-1:0] PCF,
    output reg [31:0]    InstrD,
    output reg [PCB-1:0] PCD
);

initial begin
    InstrD = 32'h00000013;
    PCD    = {PCB{1'b0}};
end

always @(posedge clk) begin
    if (clr) begin
        InstrD <= 32'h00000013;     // NOP
        PCD    <= {PCB{1'b0}};
    end
    else if (en) begin
        InstrD <= InstrF;
        PCD    <= PCF;
    end
    // en = 0: keep the current values during a stall
end

endmodule
