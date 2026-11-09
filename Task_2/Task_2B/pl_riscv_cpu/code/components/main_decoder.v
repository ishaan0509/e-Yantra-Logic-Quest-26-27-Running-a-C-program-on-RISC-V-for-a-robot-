
module main_decoder (
    input  [6:0] op,

    output reg [1:0] ResultSrc,
    output reg       MemWrite,
    output reg       Branch,
    output reg       ALUSrc,
    output reg       ALUSrcA,
    output reg       RegWrite,
    output reg       Jump,
    output reg       Jalr,
    output reg [2:0] ImmSrc,
    output reg [1:0] ALUOp
);

always @(*) begin
    // Default control values
    ResultSrc = 2'b00;
    MemWrite  = 1'b0;
    Branch    = 1'b0;
    ALUSrc    = 1'b0;
    ALUSrcA   = 1'b0;
    RegWrite  = 1'b0;
    Jump      = 1'b0;
    Jalr      = 1'b0;
    ImmSrc    = 3'b000;
    ALUOp     = 2'b00;

    case (op)
        // Loads: LB, LH, LW, LBU, LHU
        7'b0000011: begin
            RegWrite  = 1'b1;
            ResultSrc = 2'b01;
            ALUSrc    = 1'b1;
            ImmSrc    = 3'b000;
            ALUOp     = 2'b00;
        end

        // Stores: SB, SH, SW
        7'b0100011: begin
            MemWrite = 1'b1;
            ALUSrc   = 1'b1;
            ImmSrc   = 3'b001;
            ALUOp    = 2'b00;
        end

        // R-type arithmetic and logic
        7'b0110011: begin
            RegWrite = 1'b1;
            ALUOp    = 2'b10;
        end

        // Conditional branches
        7'b1100011: begin
            Branch = 1'b1;
            ImmSrc = 3'b010;
            ALUOp  = 2'b01;
        end

        // I-type arithmetic and logic
        7'b0010011: begin
            RegWrite = 1'b1;
            ALUSrc   = 1'b1;
            ImmSrc   = 3'b000;
            ALUOp    = 2'b10;
        end

        // JAL
        7'b1101111: begin
            RegWrite  = 1'b1;
            ResultSrc = 2'b10;
            Jump      = 1'b1;
            ImmSrc    = 3'b011;
        end

        // JALR
        7'b1100111: begin
            RegWrite  = 1'b1;
            ResultSrc = 2'b10;
            ALUSrc    = 1'b1;
            Jalr      = 1'b1;
            ImmSrc    = 3'b000;
        end

        // LUI
        7'b0110111: begin
            RegWrite  = 1'b1;
            ResultSrc = 2'b11;
            ImmSrc    = 3'b100;
        end

        // AUIPC: PC + U-type immediate
        7'b0010111: begin
            RegWrite = 1'b1;
            ALUSrc   = 1'b1;
            ALUSrcA  = 1'b1;
            ImmSrc   = 3'b100;
            ALUOp    = 2'b00;
        end

        default: begin
            // Safe defaults for unsupported instructions
        end
    endcase
end

endmodule
