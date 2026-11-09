// reg_file.v - RV32I register file (block RAM, synchronous read)
//
// * Two identical RAM copies give two read ports; one write port.
// * Reads are synchronous: the data for rd_addrN appears in the NEXT cycle.
//   The CPU uses that output register as the ID/EX operand register
//   (RD1E / RD2E), so no extra pipeline flops are needed.
// * Writes happen on the rising edge (WB stage).  A value written on the same
//   edge as a read of the same register is NOT seen by that read - the
//   datapath forwards it from its "WB+1" register (see datapath.v).
// * x0 is never written and the array is zero-initialised, so it reads 0.

module reg_file #(
    parameter DATA_WIDTH = 32
) (
    input                       clk,
    input                       wr_en,
    input      [4:0]            rd_addr1,
    input      [4:0]            rd_addr2,
    input      [4:0]            wr_addr,
    input      [DATA_WIDTH-1:0] wr_data,
    output reg [DATA_WIDTH-1:0] rd_data1,
    output reg [DATA_WIDTH-1:0] rd_data2
);

    (* ramstyle = "M9K, no_rw_check" *) reg [DATA_WIDTH-1:0] rf1 [0:31];
    (* ramstyle = "M9K, no_rw_check" *) reg [DATA_WIDTH-1:0] rf2 [0:31];

    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            rf1[i] = {DATA_WIDTH{1'b0}};
            rf2[i] = {DATA_WIDTH{1'b0}};
        end
    end

    wire we = wr_en && (wr_addr != 5'd0);

    always @(posedge clk) begin
        if (we) begin
            rf1[wr_addr] <= wr_data;
            rf2[wr_addr] <= wr_data;
        end
        rd_data1 <= rf1[rd_addr1];
        rd_data2 <= rf2[rd_addr2];
    end

endmodule
