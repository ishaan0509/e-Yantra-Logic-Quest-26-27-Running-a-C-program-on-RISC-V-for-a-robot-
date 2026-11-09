
// data_mem.v - data memory
//
// 128 words (512 bytes): 0x02000000 .. 0x020001FF. The word address wraps round every
// MEM_SIZE words. Stores: sb, sh, sw. Loads: lb, lh, lw, lbu, lhu.
//
// * The memory is four 8-bit lanes (block RAM), so sb / sh / sw are per-lane write enables.
// * The read is registered inside the RAM. The load formatting (lb/lh/lw/lbu/lhu) is done
//   after the RAM output register, with funct3 and the address bits registered on the same
//   clock edge, so rd_data_mem is valid in the cycle after the access: the Write-back stage
//   of the load, where the CPU uses it.
// * data_ram is the same memory as 32-bit words, for the testbench, which reads the message
//   and the inputs for the next run from uut.datamem.data_ram. It is written exactly like
//   the four lanes and is only for simulation (Quartus skips it: translate_off).

module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 128) (
    input                   clk, wr_en,
    input       [2:0]       funct3,
    input  [ADDR_WIDTH-1:0] wr_addr, wr_data,
    output [DATA_WIDTH-1:0] rd_data_mem
);

// word address, wrapping round every MEM_SIZE words
wire [ADDR_WIDTH-1:0] word_addr = wr_addr[DATA_WIDTH-1:2] % MEM_SIZE;

// array of 128 32-bit data, as four 8-bit lanes
(* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram0 [0:MEM_SIZE-1];   // bits  7..0
(* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram1 [0:MEM_SIZE-1];   // bits 15..8
(* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram2 [0:MEM_SIZE-1];   // bits 23..16
(* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram3 [0:MEM_SIZE-1];   // bits 31..24

integer k;
initial begin
    for (k = 0; k < MEM_SIZE; k = k + 1) begin
        ram0[k] = 8'd0; ram1[k] = 8'd0; ram2[k] = 8'd0; ram3[k] = 8'd0;
    end
end

// ------------------------------------------------------------
// Store: lane enables and lane data
// ------------------------------------------------------------
wire is_sb = (funct3 == 3'b000);
wire is_sh = (funct3 == 3'b001);
wire is_sw = (funct3 == 3'b010);

wire [3:0] be;
assign be[0] = wr_en & ((is_sb & (wr_addr[1:0] == 2'b00)) | (is_sh & ~wr_addr[1]) | is_sw);
assign be[1] = wr_en & ((is_sb & (wr_addr[1:0] == 2'b01)) | (is_sh & ~wr_addr[1]) | is_sw);
assign be[2] = wr_en & ((is_sb & (wr_addr[1:0] == 2'b10)) | (is_sh &  wr_addr[1]) | is_sw);
assign be[3] = wr_en & ((is_sb & (wr_addr[1:0] == 2'b11)) | (is_sh &  wr_addr[1]) | is_sw);

wire [7:0] d0 = wr_data[7:0];
wire [7:0] d1 = is_sb ? wr_data[7:0]   : wr_data[15:8];
wire [7:0] d2 = is_sw ? wr_data[23:16] : wr_data[7:0];
wire [7:0] d3 = is_sw ? wr_data[31:24] :
                is_sb ? wr_data[7:0]   : wr_data[15:8];

// ------------------------------------------------------------
// Synchronous write and read, and the registered access information
// ------------------------------------------------------------
reg [31:0] raw_q;
reg [2:0]  funct3_q;
reg [1:0]  lo_q;

always @(posedge clk) begin
    if (be[0]) ram0[word_addr] <= d0;
    if (be[1]) ram1[word_addr] <= d1;
    if (be[2]) ram2[word_addr] <= d2;
    if (be[3]) ram3[word_addr] <= d3;

    raw_q    <= {ram3[word_addr], ram2[word_addr], ram1[word_addr], ram0[word_addr]};
    funct3_q <= funct3;
    lo_q     <= wr_addr[1:0];
end

// ------------------------------------------------------------
// Load formatting (after the RAM output register)
// ------------------------------------------------------------
wire        sgn  = ~funct3_q[2];                 // lb / lh sign-extend, lbu / lhu do not
wire        is_b = (funct3_q[1:0] == 2'b00);     // lb, lbu
wire        is_h = (funct3_q[1:0] == 2'b01);     // lh, lhu

wire [7:0]  byte_sel = lo_q[1] ? (lo_q[0] ? raw_q[31:24] : raw_q[23:16])
                               : (lo_q[0] ? raw_q[15:8]  : raw_q[7:0]);
wire [15:0] half_sel = lo_q[1] ? raw_q[31:16] : raw_q[15:0];

assign rd_data_mem = is_b ? {{24{sgn & byte_sel[7]}},  byte_sel} :
                     is_h ? {{16{sgn & half_sel[15]}}, half_sel} :
                            raw_q;                                  // lw

// ------------------------------------------------------------
// The same memory as 32-bit words, for the testbench (simulation only)
// ------------------------------------------------------------
// synthesis translate_off
reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

initial begin
    for (k = 0; k < MEM_SIZE; k = k + 1) data_ram[k] = 0;
end

always @(posedge clk) begin
    if (be[0]) data_ram[word_addr][ 7: 0] <= d0;
    if (be[1]) data_ram[word_addr][15: 8] <= d1;
    if (be[2]) data_ram[word_addr][23:16] <= d2;
    if (be[3]) data_ram[word_addr][31:24] <= d3;
end
// synthesis translate_on

endmodule
