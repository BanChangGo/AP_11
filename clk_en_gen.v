module clk_gen2(
    input   clk_i,
    input   iRstn,            // <--- add reset (active low)
    input   [15:0]  count_i,
    output  clk_o
);
    reg [15:0] sig_count;
    reg        sig_clk_out;

    always @(posedge clk_i or negedge iRstn) begin
        if (!iRstn) begin
            sig_count   <= 16'd0;
            sig_clk_out <= 1'b0;
        end else begin
            if (sig_count == count_i) begin
                sig_count <= 0;
                sig_clk_out <= ~sig_clk_out;
            end else begin
                sig_count <= sig_count + 1'b1;
            end
        end
    end

    assign clk_o = sig_clk_out;
endmodule
