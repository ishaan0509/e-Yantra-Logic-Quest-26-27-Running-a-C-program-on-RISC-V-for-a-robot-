
module reset_ff #(
    parameter WIDTH = 32
) (
    input                  clk,
    input                  rst,
    input                  clr,
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

initial begin
    q = {WIDTH{1'b0}};
end

always @(posedge clk) begin
    if (rst)
        q <= {WIDTH{1'b0}};
    else if (!clr)
        q <= d;
    // If clr = 1, hold the current value
end

endmodule
