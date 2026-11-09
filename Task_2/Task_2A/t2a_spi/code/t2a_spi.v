
module t2a_spi
#(
    parameter CPOL            = 1'b0,
    parameter CPHA            = 1'b0,
    parameter LSB_FIRST       = 1'b0,
    parameter SPI_WORD_LENGTH = 8,
    parameter HALF_PERIOD     = 25
)
(
    input wire clk_50MHz,
    input wire rst_n,

    input wire start,
    input wire [SPI_WORD_LENGTH-1:0] tx_data,
    input wire miso_input,

    output reg sclk_out,
    output reg cs_out,
    output reg mosi_output,

    output reg [SPI_WORD_LENGTH-1:0] rx_data,
    output reg busy
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

// Narrow counters to reduce register usage.
reg [$clog2(HALF_PERIOD+1)-1:0] half_count;
reg [$clog2(SPI_WORD_LENGTH+1)-1:0] bit_count;

reg [SPI_WORD_LENGTH-1:0] tx_shift;
reg [SPI_WORD_LENGTH-1:0] rx_shift;

always @(posedge clk_50MHz or negedge rst_n) begin
    if (!rst_n) begin
        sclk_out    <= 1'b0;
        cs_out      <= 1'b1;
        mosi_output <= 1'b0;
        rx_data     <= {SPI_WORD_LENGTH{1'b0}};
        busy        <= 1'b0;

        half_count  <= 0;
        bit_count   <= 0;
        tx_shift    <= 0;
        rx_shift    <= 0;
    end
    else begin
        if (!busy) begin
            sclk_out   <= 1'b0;
            cs_out     <= 1'b1;
            half_count <= 0;
            bit_count  <= 0;

            if (start) begin
                tx_shift <= tx_data;
                rx_shift <= 0;

                if (LSB_FIRST)
                    mosi_output <= tx_data[0];
                else
                    mosi_output <= tx_data[SPI_WORD_LENGTH-1];

                cs_out <= 1'b0;
                busy   <= 1'b1;
            end
        end
        else begin
            // First SCLK edge occurs HALF_PERIOD+1 clocks
            // after start. Later edges are HALF_PERIOD clocks apart.
            if (half_count == HALF_PERIOD) begin
                // Preload 1 so subsequent transitions are
                // separated by exactly HALF_PERIOD clocks.
                half_count <= 1;

                if (sclk_out == 1'b0) begin
                    // Rising edge: sample MISO.
                    sclk_out <= 1'b1;

                    if (LSB_FIRST) begin
                        rx_shift <= rx_shift |
                            ({{(SPI_WORD_LENGTH-1){1'b0}},
                              miso_input} << bit_count);
                    end
                    else begin
                        rx_shift <= (rx_shift << 1) | miso_input;
                    end

                    bit_count <= bit_count + 1'b1;
                end
                else begin
                    // Falling edge.
                    sclk_out <= 1'b0;

                    if (bit_count == SPI_WORD_LENGTH) begin
                        // Finish on the final falling edge.
                        cs_out  <= 1'b1;
                        busy    <= 1'b0;
                        rx_data <= rx_shift;
                    end
                    else begin
                        // Advance MOSI only on falling edges.
                        if (LSB_FIRST) begin
                            mosi_output <= tx_shift[1];
                            tx_shift <= tx_shift >> 1;
                        end
                        else begin
                            mosi_output <= tx_shift[SPI_WORD_LENGTH-2];
                            tx_shift <= tx_shift << 1;
                        end
                    end
                end
            end
            else begin
                half_count <= half_count + 1'b1;
            end
        end
    end
end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule
