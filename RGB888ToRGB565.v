// pixel_conv_rgb888_to_rgb565_round.v
`timescale 1ns / 1ps
module pixel_conv_rgb888_to_rgb565_round (
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iEn,         // wEnClk
    input  wire        iValid,
    input  wire        iLast,
    input  wire [23:0] iPixel,      // RGB888

    output reg  [15:0] oPixel565,   // RGB565
    output reg         oValid,
    output reg         oLast
);
    wire [7:0] R_in = iPixel[23:16];
    wire [7:0] G_in = iPixel[15:8];
    wire [7:0] B_in = iPixel[7:0];

    // --- R 채널 : 8bit -> 5bit (반올림) ---
    wire [8:0] R_add = {1'b0, R_in} + 9'd4;  // + 0.5 LSB (8 단위)
    wire [7:0] R_sat = (R_add > 9'd255) ? 8'd255 : R_add[7:0];
    wire [4:0] R5    = R_sat[7:3];

    // --- G 채널 : 8bit -> 6bit (반올림) ---
    wire [8:0] G_add = {1'b0, G_in} + 9'd2;  // + 0.5 LSB (4 단위)
    wire [7:0] G_sat = (G_add > 9'd255) ? 8'd255 : G_add[7:0];
    wire [5:0] G6    = G_sat[7:2];

    // --- B 채널 : 8bit -> 5bit (반올림) ---
    wire [8:0] B_add = {1'b0, B_in} + 9'd4;
    wire [7:0] B_sat = (B_add > 9'd255) ? 8'd255 : B_add[7:0];
    wire [4:0] B5    = B_sat[7:3];

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oPixel565 <= 16'd0;
            oValid    <= 1'b0;
            oLast     <= 1'b0;
        end else if (iEn) begin
            if (iValid) begin
                oPixel565 <= {R5, G6, B5};
                oValid    <= 1'b1;
                oLast     <= iLast;
            end else begin
                oValid    <= 1'b0;
                oLast     <= 1'b0;
            end
        end
    end

endmodule
