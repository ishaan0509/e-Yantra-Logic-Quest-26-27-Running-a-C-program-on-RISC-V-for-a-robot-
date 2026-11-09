// branching_unit.v - branch decision from the ALU compare flags
// The ALU already subtracts SrcA - SrcB for branches (ALUOp = 01), so the
// zero / signed-less-than / unsigned-less-than flags come for free.

module branching_unit (
    input  [2:0] funct3,
    input        zero,   // SrcA == SrcB
    input        lt,     // SrcA <  SrcB (signed)
    input        ltu,    // SrcA <  SrcB (unsigned)
    output reg   TakeBranch
);

always @(*) begin
    case (funct3)
        3'b000:  TakeBranch =  zero;  // BEQ
        3'b001:  TakeBranch = ~zero;  // BNE
        3'b100:  TakeBranch =  lt;    // BLT
        3'b101:  TakeBranch = ~lt;    // BGE
        3'b110:  TakeBranch =  ltu;   // BLTU
        3'b111:  TakeBranch = ~ltu;   // BGEU
        default: TakeBranch = 1'b0;
    endcase
end

endmodule
