// main_decoder.v - logic for main decoder

module main_decoder (
    input      [6:0] op,
    output reg [1:0] ResultSrc,
    output reg       MemWrite,
    output reg       Branch,
    output reg       ALUSrc,
    output reg       ALUSrcA,
    output reg       RegWrite,
    output reg       Jump,
    output reg       JALR,
    output reg [2:0] ImmSrc,
    output reg [1:0] ALUOp
);

always @(*) begin
    ResultSrc = 2'b00;
    MemWrite  = 1'b0;
    Branch    = 1'b0;
    ALUSrc    = 1'b0;
    ALUSrcA   = 1'b0;
    RegWrite  = 1'b0;
    Jump      = 1'b0;
    JALR      = 1'b0;
    ImmSrc    = 3'b000;
    ALUOp     = 2'b00;

    case (op)
        // LW
        7'b0000011: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b000;
            ALUSrc    = 1'b1;
            ResultSrc = 2'b01;
            ALUOp     = 2'b00;
        end

        // SW
        7'b0100011: begin
            ImmSrc   = 3'b001;
            ALUSrc   = 1'b1;
            MemWrite = 1'b1;
            ALUOp    = 2'b00;
        end

        // R-type
        7'b0110011: begin
            RegWrite = 1'b1;
            ALUSrc   = 1'b0;
            ALUOp    = 2'b10;
        end

        // BEQ
        7'b1100011: begin
            ImmSrc = 3'b010;
            Branch = 1'b1;
            ALUOp  = 2'b01;
        end

        // I-type ALU
        7'b0010011: begin
            RegWrite = 1'b1;
            ImmSrc   = 3'b000;
            ALUSrc   = 1'b1;
            ALUOp    = 2'b10;
        end

        // JAL
        7'b1101111: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b011;
            ResultSrc = 2'b10;   // PC + 4
            Jump      = 1'b1;
            ALUOp     = 2'b00;
        end

        // LUI: rd = U-immediate directly
        7'b0110111: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b100;
            ResultSrc = 2'b11;   // ImmExt
        end

        // AUIPC: rd = PC + U-immediate
        7'b0010111: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b100;
            ALUSrc    = 1'b1;
            ALUSrcA   = 1'b1;    // PC
            ResultSrc = 2'b00;   // ALUResult
            ALUOp     = 2'b00;   // ADD
        end

        // JALR: PC = rs1 + imm, rd = PC + 4
        7'b1100111: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b000;
            ALUSrc    = 1'b1;    // ImmExt
            ALUSrcA   = 1'b0;    // rs1
            ResultSrc = 2'b10;   // PC + 4
            JALR      = 1'b1;
            ALUOp     = 2'b00;   // ADD
        end

        default: ;
    endcase
end

endmodule