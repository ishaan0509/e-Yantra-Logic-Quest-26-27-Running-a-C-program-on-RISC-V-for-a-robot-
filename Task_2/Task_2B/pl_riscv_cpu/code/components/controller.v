
module controller (
    input  [6:0] op,
    input  [2:0] funct3,
    input        opb5,
    input        funct7b5,

    output [1:0] ResultSrc,
    output       MemWrite,
    output       Branch,
    output       ALUSrc,
    output       ALUSrcA,
    output       RegWrite,
    output       Jump,
    output       Jalr,
    output [2:0] ImmSrc,
    output [1:0] ALUOp
);

    main_decoder md (
        .op(op),
        .ResultSrc(ResultSrc),
        .MemWrite(MemWrite),
        .Branch(Branch),
        .ALUSrc(ALUSrc),
        .ALUSrcA(ALUSrcA),
        .RegWrite(RegWrite),
        .Jump(Jump),
        .Jalr(Jalr),
        .ImmSrc(ImmSrc),
        .ALUOp(ALUOp)
    );

endmodule
