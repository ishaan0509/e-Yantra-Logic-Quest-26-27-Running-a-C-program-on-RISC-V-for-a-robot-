// pl_reg_de.v - ID/EX pipeline register (Decode -> Execute)
//
// reset clears every field. flush (a load-use stall or a taken branch / jump) turns the
// instruction into a bubble: all its control bits (and its PC) are cleared, so it writes
// nothing and changes nothing; its data fields are then unused.
// The two source register values (RD1E, RD2E) are not here: they are the register file's
// read registers (see reg_file.v).

module pl_reg_de #(
    parameter PCB = 12
) (
    input                clk,
    input                reset,
    input                flush,

    // Decode stage
    input      [PCB-1:0] PCD,
    input      [31:0]    ImmExtD,
    input      [4:0]     Rs1D, Rs2D, RdD,
    input      [2:0]     funct3D,
    input                opb5D, funct7b5D,
    input      [1:0]     ALUOpD,
    input                ALUSrcAD,
    input      [1:0]     ResultSrcD,
    input                RegWriteD, MemWriteD, BranchD, ALUSrcD, LuiD, JumpD, JalrD,

    // Execute stage
    output reg [PCB-1:0] PCE,
    output reg [31:0]    ImmExtE,
    output reg [4:0]     Rs1E, Rs2E, RdE,
    output reg [2:0]     funct3E,
    output reg           opb5E, funct7b5E,
    output reg [1:0]     ALUOpE,
    output reg           ALUSrcAE,
    output reg [1:0]     ResultSrcE,
    output reg           RegWriteE, MemWriteE, BranchE, ALUSrcE, LuiE, JumpE, JalrE
);

initial begin
    PCE = 0; ImmExtE = 0; Rs1E = 0; Rs2E = 0; RdE = 0; funct3E = 0; opb5E = 0; funct7b5E = 0;
    ALUOpE = 0; ALUSrcAE = 0; ResultSrcE = 0; RegWriteE = 0; MemWriteE = 0; BranchE = 0;
    ALUSrcE = 0; LuiE = 0; JumpE = 0; JalrE = 0;
end

// data fields: cleared by reset only
always @(posedge clk) begin
    if (reset) begin
        ImmExtE   <= 32'b0;
        Rs1E      <= 5'b0;
        Rs2E      <= 5'b0;
        RdE       <= 5'b0;
        funct3E   <= 3'b0;
        opb5E     <= 1'b0;
        funct7b5E <= 1'b0;
        ALUOpE    <= 2'b0;
        ALUSrcAE  <= 1'b0;
    end
    else begin
        ImmExtE   <= ImmExtD;
        Rs1E      <= Rs1D;
        Rs2E      <= Rs2D;
        RdE       <= RdD;
        funct3E   <= funct3D;
        opb5E     <= opb5D;
        funct7b5E <= funct7b5D;
        ALUOpE    <= ALUOpD;
        ALUSrcAE  <= ALUSrcAD;
    end
end

// control fields and PC: cleared by reset and by flush
always @(posedge clk) begin
    if (reset || flush) begin
        PCE        <= {PCB{1'b0}};
        ResultSrcE <= 2'b00;
        RegWriteE  <= 1'b0;
        MemWriteE  <= 1'b0;
        BranchE    <= 1'b0;
        ALUSrcE    <= 1'b0;
        LuiE       <= 1'b0;
        JumpE      <= 1'b0;
        JalrE      <= 1'b0;
    end
    else begin
        PCE        <= PCD;
        ResultSrcE <= ResultSrcD;
        RegWriteE  <= RegWriteD;
        MemWriteE  <= MemWriteD;
        BranchE    <= BranchD;
        ALUSrcE    <= ALUSrcD;
        LuiE       <= LuiD;
        JumpE      <= JumpD;
        JalrE      <= JalrD;
    end
end

endmodule
