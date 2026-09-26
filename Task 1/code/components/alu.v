// alu.v - Complete RV32I ALU module

module alu #(parameter WIDTH = 32) (
    input      [WIDTH-1:0] a, b,
    input      [3:0]       alu_ctrl,
    output reg [WIDTH-1:0] alu_out,
    output                 zero
);

    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_ctrl)
            4'b0000: alu_out = a + b;                                             // ADD / ADDI
            4'b0001: alu_out = a - b;                                             // SUB
            4'b0010: alu_out = a & b;                                             // AND / ANDI
            4'b0011: alu_out = a | b;                                             // OR / ORI
            4'b0100: alu_out = a ^ b;                                             // XOR / XORI
            4'b0101: alu_out = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;         // SLT / SLTI (signed)
            4'b0110: alu_out = (a < b) ? 32'd1 : 32'd0;                           // SLTU / SLTIU (unsigned)
            4'b0111: alu_out = a << shamt;                                        // SLL / SLLI
            4'b1000: alu_out = a >> shamt;                                        // SRL / SRLI (logical)
            4'b1001: alu_out = $signed(a) >>> shamt;                              // SRA / SRAI (arithmetic)
            default: alu_out = 32'd0;
        endcase
    end

    assign zero = (alu_out == 32'd0);

endmodule