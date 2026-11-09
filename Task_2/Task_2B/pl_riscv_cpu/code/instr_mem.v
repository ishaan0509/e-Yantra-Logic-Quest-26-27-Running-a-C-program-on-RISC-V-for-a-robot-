// instr_mem.v - Instruction memory (synchronous ROM -> block RAM)
//
// The address presented in cycle N is the address of the instruction that is
// delivered in cycle N+1 (the ROM output register IS the fetch stage output).
// The CPU therefore drives it with the next-PC value, which is exactly the
// value that PC_reg loads on the same clock edge.

module instr_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 512
) (
    input                   clk,
    input  [ADDR_WIDTH-1:0] instr_addr,
    output [DATA_WIDTH-1:0] instr
);

    localparam ADDR_BITS = $clog2(MEM_SIZE);

    (* ramstyle = "M9K" *) reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] instr_q;

    initial begin
        $readmemh("rv32i_test.hex", instr_ram);
    end

    // Byte-addressed; each instruction is 4 bytes.
    always @(posedge clk)
        instr_q <= instr_ram[instr_addr[ADDR_BITS+1:2]];

    assign instr = instr_q;

endmodule