// data_mem.v - Data memory (byte-lane block RAM, synchronous read)
//
// * Four 8-bit lanes so that SB / SH / SW map onto per-lane write enables.
// * The read is registered inside the RAM.  The load-data formatting
//   (LB/LBU/LH/LHU/LW) is done AFTER the RAM output register, using the
//   funct3 / address bits that were registered on the same clock edge.
//   rd_data_mem is therefore valid in the cycle AFTER the access, i.e. in
//   the Write-back stage of the load.

module data_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 64
) (
    input  wire                  clk,
    input  wire                  wr_en,
    input  wire [2:0]            funct3,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire [DATA_WIDTH-1:0] rd_data_mem
);

    localparam ADDR_BITS = $clog2(MEM_SIZE);

    wire [ADDR_BITS-1:0] word_addr = wr_addr[ADDR_BITS+1:2];

    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram0 [0:MEM_SIZE-1];
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram1 [0:MEM_SIZE-1];
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram2 [0:MEM_SIZE-1];
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram3 [0:MEM_SIZE-1];

    // ------------------------------------------------------------
    // Store: lane enables + lane data
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
    // Synchronous RAM + registered access information
    // ------------------------------------------------------------
    reg [31:0] raw_q;
    reg [2:0]  funct3_q;
    reg [1:0]  lo_q;

    always @(posedge clk) begin
        if (be[0]) ram0[word_addr] <= d0;
        if (be[1]) ram1[word_addr] <= d1;
        if (be[2]) ram2[word_addr] <= d2;
        if (be[3]) ram3[word_addr] <= d3;

        raw_q    <= {ram3[word_addr], ram2[word_addr],
                     ram1[word_addr], ram0[word_addr]};
        funct3_q <= funct3;
        lo_q     <= wr_addr[1:0];
    end

    // ------------------------------------------------------------
    // Load formatting (after the RAM output register)
    // ------------------------------------------------------------
    wire        sgn  = ~funct3_q[2];                 // LB/LH signed, LBU/LHU unsigned
    wire        is_b = (funct3_q[1:0] == 2'b00);
    wire        is_h = (funct3_q[1:0] == 2'b01);

    wire [7:0]  byte_sel = lo_q[1] ? (lo_q[0] ? raw_q[31:24] : raw_q[23:16])
                                   : (lo_q[0] ? raw_q[15:8]  : raw_q[7:0]);
    wire [15:0] half_sel = lo_q[1] ? raw_q[31:16] : raw_q[15:0];

    assign rd_data_mem = is_b ? {{24{sgn & byte_sel[7]}},  byte_sel} :
                         is_h ? {{16{sgn & half_sel[15]}}, half_sel} :
                                raw_q;

endmodule
