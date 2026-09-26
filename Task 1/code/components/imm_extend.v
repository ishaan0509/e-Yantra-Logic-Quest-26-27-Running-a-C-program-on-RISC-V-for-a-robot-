// imm_extend.v - logic for immediate extension (32-bit aligned)

module imm_extend (
    input      [31:7] instr,
    input      [2:0]  immsrc,
    output reg [31:0] immext
);

always @(*) begin
    case(immsrc)

        // I-type: 12-bit immediate -> 20 sign bits + 12 bits = 32 bits
        3'b000:
            immext = {{20{instr[31]}}, instr[31:20]};

        // S-type: 12-bit immediate -> 20 sign bits + 7 bits + 5 bits = 32 bits
        3'b001:
            immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};

        // B-type: 13-bit branch offset -> 20 sign bits + 1 + 6 + 4 + 1 = 32 bits
        3'b010:
            immext = {{20{instr[31]}},
                      instr[7],
                      instr[30:25],
                      instr[11:8],
                      1'b0};

        // J-type: 21-bit jump target -> 12 sign bits + 8 + 1 + 10 + 1 = 32 bits
        3'b011:
            immext = {{12{instr[31]}},
                      instr[19:12],
                      instr[20],
                      instr[30:21],
                      1'b0};

        // U-type (LUI / AUIPC): 20 upper bits + 12 zero bits = 32 bits
        3'b100:
            immext = {instr[31:12], 12'b0};

        default:
            immext = 32'b0;

    endcase
end

endmodule