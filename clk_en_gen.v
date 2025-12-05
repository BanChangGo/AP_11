/*********************************************************************************
  - Project          : AP CNN Project
  - File name        : clk_en_gen.v (Module: clk_gen2)
  - Description      : Clock Divider / Generator
                       Generates a slower clock (50% duty cycle) from clk_i.
                       The output toggles whenever the internal counter reaches count_i.
  - Timing           : 
       1. Toggle Interval : (count_i + 1) cycles of clk_i
       2. Output Period   : 2 * (count_i + 1) cycles of clk_i
       3. Output Freq     : F_clk_i / ( 2 * (count_i + 1) )
       [Example] If clk_i = 100MHz, count_i = 49
                 -> Toggle every 50 cycles (0.5us)
                 -> Period = 100 cycles (1.0us)
                 -> clk_o = 1MHz
  - Revision history : 1) 2025.12.05 - Initial Release (Added Active-Low Reset)
*********************************************************************************/
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
