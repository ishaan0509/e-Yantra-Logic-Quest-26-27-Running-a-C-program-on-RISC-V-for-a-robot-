
// instr_mem.v - instruction memory
//
// 1024 words (4 KB), loaded from program.hex (the testbench also loads code/program.hex
// into instr_ram directly).
//
// The read is synchronous, so Quartus builds this memory from block RAM (M9K) instead of
// logic elements. The CPU gives it the address of the NEXT instruction (the value its PC
// register loads on the same clock edge), so the word that comes out in a cycle is always
// the instruction at the current PC, just as with an asynchronous read.

module instr_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 1024) (
    input                   clk,
    input  [ADDR_WIDTH-1:0] instr_addr,
    output [DATA_WIDTH-1:0] instr
);

localparam ADDR_BITS = $clog2(MEM_SIZE);   // 10 bits of word address

// array of 1024 32-bit words or instructions (4 KB)
(* ramstyle = "M9K" *) reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];
reg [DATA_WIDTH-1:0] instr_q;

initial begin
    $readmemh("program.hex", instr_ram);
    // $readmemh("rv32i_test.hex", instr_ram);
end

// word-aligned memory access, registered read
always @(posedge clk)
    instr_q <= instr_ram[instr_addr[ADDR_BITS+1:2]];

assign instr = instr_q;

endmodule
