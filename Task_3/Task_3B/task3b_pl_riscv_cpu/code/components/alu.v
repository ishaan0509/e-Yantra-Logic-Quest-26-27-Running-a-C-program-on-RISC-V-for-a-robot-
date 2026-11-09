// alu.v - RV32I ALU
//  * one 33-bit add/sub shared by ADD, SUB, SLT, SLTU and the branch compares
//  * one barrel shifter shared by SLL / SRL / SRA (left shift = reverse,
//    shift right, reverse)
//  * zero / lt / ltu flags are valid when alu_ctrl selects a subtraction
//    (SUB = 0001, used for branches)

module alu #(
    parameter WIDTH = 32
) (
    input      [WIDTH-1:0] a,
    input      [WIDTH-1:0] b,
    input      [3:0]       alu_ctrl,
    output reg [WIDTH-1:0] alu_out,
    output                 zero,
    output                 lt,
    output                 ltu
);

    // SUB, SLT and SLTU use a - b.
    wire is_sub = (alu_ctrl == 4'b0001) ||
                  (alu_ctrl == 4'b0101) ||
                  (alu_ctrl == 4'b0110);

    // 33-bit result: bit WIDTH of a-b is the unsigned borrow (a < b)
    wire [WIDTH:0]   sum   = is_sub ? ({1'b0, a} - {1'b0, b})
                                    : ({1'b0, a} + {1'b0, b});
    wire [WIDTH-1:0] arith = sum[WIDTH-1:0];

    assign zero = (arith == {WIDTH{1'b0}});
    assign ltu  = sum[WIDTH];
    assign lt   = (a[WIDTH-1] != b[WIDTH-1]) ? a[WIDTH-1] : sum[WIDTH-1];

    // ---------------- shared shifter ----------------
    wire left        = (alu_ctrl == 4'b0111);   // SLL
    wire arith_shift = (alu_ctrl == 4'b1001);   // SRA

    wire [WIDTH-1:0] a_rev;
    genvar gi;
    generate
        for (gi = 0; gi < WIDTH; gi = gi + 1) begin : REV_IN
            assign a_rev[gi] = a[WIDTH-1-gi];
        end
    endgenerate

    wire [WIDTH-1:0]       sh_in  = left ? a_rev : a;
    wire signed [WIDTH:0]  sh_ext = {arith_shift & a[WIDTH-1], sh_in};
    wire signed [WIDTH:0]  sh_res = sh_ext >>> b[4:0];
    wire [WIDTH-1:0]       sh_r   = sh_res[WIDTH-1:0];

    wire [WIDTH-1:0] sh_r_rev;
    generate
        for (gi = 0; gi < WIDTH; gi = gi + 1) begin : REV_OUT
            assign sh_r_rev[gi] = sh_r[WIDTH-1-gi];
        end
    endgenerate

    wire [WIDTH-1:0] sh_out = left ? sh_r_rev : sh_r;

    // ---------------- result select ----------------
    always @(*) begin
        case (alu_ctrl)
            4'b0000: alu_out = arith;                       // ADD
            4'b0001: alu_out = arith;                       // SUB
            4'b0010: alu_out = a & b;                       // AND
            4'b0011: alu_out = a | b;                       // OR
            4'b0100: alu_out = a ^ b;                       // XOR
            4'b0101: alu_out = {{(WIDTH-1){1'b0}}, lt};     // SLT
            4'b0110: alu_out = {{(WIDTH-1){1'b0}}, ltu};    // SLTU
            4'b0111: alu_out = sh_out;                      // SLL
            4'b1000: alu_out = sh_out;                      // SRL
            4'b1001: alu_out = sh_out;                      // SRA
            default: alu_out = {WIDTH{1'b0}};
        endcase
    end

endmodule
