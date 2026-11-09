// hazard_unit.v - forwarding, load-use stall and flushes
//
// Forwarding to the two ALU operands in Execute (ForwardAE, ForwardBE):
//   00 = register file value (RD1E / RD2E)
//   10 = ALUResultM: the instruction in Memory (not a load: its data is not ready yet)
//   01 = ResultW:    the instruction in Write-back
//   11 = ResultW_d:  the instruction one stage after Write-back. The register file is
//        written on the same rising edge as the read for Execute happens, so that read
//        still returns the old value; the value written is forwarded from here instead.
// The nearest older instruction that writes the register wins. x0 is never forwarded.
//
// Load-use stall: a load in Execute whose destination is a source of the instruction in
// Decode stalls Fetch and Decode for one cycle and puts a bubble into Execute. Loads are
// found by ResultSrcE = 01 (main_decoder gives every other instruction a defined ResultSrc).
//
// Taken branch / jump (PCSrcE, decided in Execute): flush Decode and Execute.

module hazard_unit (
    input      [6:0] opD,                       // opcode in Decode
    input      [4:0] Rs1D, Rs2D,
    input      [4:0] Rs1E, Rs2E, RdE,
    input      [1:0] ResultSrcE,
    input            PCSrcE,
    input      [4:0] RdM,
    input            RegWriteM,
    input      [1:0] ResultSrcM,
    input      [4:0] RdW,
    input            RegWriteW,
    input      [4:0] RdW_d,
    input            RegWriteW_d,

    output           StallF, StallD, FlushD, FlushE,
    output reg [1:0] ForwardAE, ForwardBE
);

// which source registers the instruction in Decode really reads
reg usesRs1D, usesRs2D;
always @(*) begin
    case (opD)
        7'b0110011: {usesRs1D, usesRs2D} = 2'b11;   // R-type
        7'b0010011: {usesRs1D, usesRs2D} = 2'b10;   // I-type ALU
        7'b0000011: {usesRs1D, usesRs2D} = 2'b10;   // loads
        7'b0100011: {usesRs1D, usesRs2D} = 2'b11;   // stores
        7'b1100011: {usesRs1D, usesRs2D} = 2'b11;   // branches
        7'b1100111: {usesRs1D, usesRs2D} = 2'b10;   // jalr
        default:    {usesRs1D, usesRs2D} = 2'b00;   // lui, auipc, jal, others
    endcase
end

wire fwdM = RegWriteM   && (ResultSrcM != 2'b01) && (RdM != 5'b0);
wire fwdW = RegWriteW   && (RdW   != 5'b0);
wire fwdD = RegWriteW_d && (RdW_d != 5'b0);

always @(*) begin
    if      (fwdM && (RdM   == Rs1E)) ForwardAE = 2'b10;
    else if (fwdW && (RdW   == Rs1E)) ForwardAE = 2'b01;
    else if (fwdD && (RdW_d == Rs1E)) ForwardAE = 2'b11;
    else                              ForwardAE = 2'b00;

    if      (fwdM && (RdM   == Rs2E)) ForwardBE = 2'b10;
    else if (fwdW && (RdW   == Rs2E)) ForwardBE = 2'b01;
    else if (fwdD && (RdW_d == Rs2E)) ForwardBE = 2'b11;
    else                              ForwardBE = 2'b00;
end

wire lwStall = (ResultSrcE == 2'b01) && (RdE != 5'b0) &&
               ((usesRs1D && (RdE == Rs1D)) || (usesRs2D && (RdE == Rs2D)));

assign StallF = lwStall;
assign StallD = lwStall;
assign FlushD = PCSrcE;
assign FlushE = lwStall || PCSrcE;

endmodule
