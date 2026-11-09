
// alu_decoder.v - logic for ALU decoder

module alu_decoder (
    input            opb5,
    input      [2:0] funct3,
    input            funct7b5,
    input      [1:0] ALUOp,
    output reg [3:0] ALUControl
);

always @(*) begin
    case (ALUOp)

        // Load/store and address calculations: ADD
        2'b00: ALUControl = 4'b0000;

        // Conditional branches: SUB
        2'b01: ALUControl = 4'b0001;

        // R-type and I-type ALU instructions
        default: begin
            case (funct3)

                3'b000: begin
                    if (opb5 && funct7b5)
                        ALUControl = 4'b0001; // SUB
                    else
                        ALUControl = 4'b0000; // ADD / ADDI
                end

                3'b001: begin
                    ALUControl = 4'b0111; // SLL / SLLI
                end

                3'b010: begin
                    ALUControl = 4'b0101; // SLT / SLTI
                end

                3'b011: begin
                    ALUControl = 4'b0110; // SLTU / SLTIU
                end

                3'b100: begin
                    ALUControl = 4'b0100; // XOR / XORI
                end

                3'b101: begin
                    if (funct7b5)
                        ALUControl = 4'b1001; // SRA / SRAI
                    else
                        ALUControl = 4'b1000; // SRL / SRLI
                end

                3'b110: begin
                    ALUControl = 4'b0011; // OR / ORI
                end

                3'b111: begin
                    ALUControl = 4'b0010; // AND / ANDI
                end

                default: begin
                    ALUControl = 4'b0000;
                end

            endcase
        end

    endcase
end

endmodule
