// conv3x3_laplacian_rgb.v
`timescale 1ns / 1ps

module conv3x3_laplacian_rgb #(
    parameter ACC_WIDTH = 19
)(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iEn,       // wEnClk
    input  wire        iValid,    // window3x3의 oValid
    input  wire        iLast,     // pixel_addr_ctrl의 oLast

    input  wire [23:0] iP00,
    input  wire [23:0] iP01,
    input  wire [23:0] iP02,
    input  wire [23:0] iP10,
    input  wire [23:0] iP11,
    input  wire [23:0] iP12,
    input  wire [23:0] iP20,
    input  wire [23:0] iP21,
    input  wire [23:0] iP22,

    output reg  [23:0] oPixel,    // ReLU 후 RGB888
    output reg         oValid,    // 결과 유효
    output reg         oLast      // 이 결과 픽셀이 프레임 마지막일 때 1
);

//kernel
localparam signed [7:0] K00 =   8'sd0;
localparam signed [7:0] K01 =  -8'sd1;
localparam signed [7:0] K02 =   8'sd0;
localparam signed [7:0] K10 =  -8'sd1;
localparam signed [7:0] K11 =   8'sd5;  
localparam signed [7:0] K12 =  -8'sd1;
localparam signed [7:0] K20 =   8'sd0;
localparam signed [7:0] K21 =  -8'sd1;
localparam signed [7:0] K22 =   8'sd0;

    // ReLU + 0~255 saturate
    function [7:0] relu_sat8;
        input signed [ACC_WIDTH-1:0] x;
        begin
            if (x[ACC_WIDTH-1]) begin
                relu_sat8 = 8'd0;
            end else if (|x[ACC_WIDTH-1:8]) begin
                relu_sat8 = 8'd255;
            end else begin
                relu_sat8 = x[7:0];
            end
        end
    endfunction

    // RGB 분리
    wire [7:0] R00 = iP00[23:16]; wire [7:0] G00 = iP00[15:8]; wire [7:0] B00 = iP00[7:0];
    wire [7:0] R01 = iP01[23:16]; wire [7:0] G01 = iP01[15:8]; wire [7:0] B01 = iP01[7:0];
    wire [7:0] R02 = iP02[23:16]; wire [7:0] G02 = iP02[15:8]; wire [7:0] B02 = iP02[7:0];
    wire [7:0] R10 = iP10[23:16]; wire [7:0] G10 = iP10[15:8]; wire [7:0] B10 = iP10[7:0];
    wire [7:0] R11 = iP11[23:16]; wire [7:0] G11 = iP11[15:8]; wire [7:0] B11 = iP11[7:0];
    wire [7:0] R12 = iP12[23:16]; wire [7:0] G12 = iP12[15:8]; wire [7:0] B12 = iP12[7:0];
    wire [7:0] R20 = iP20[23:16]; wire [7:0] G20 = iP20[15:8]; wire [7:0] B20 = iP20[7:0];
    wire [7:0] R21 = iP21[23:16]; wire [7:0] G21 = iP21[15:8]; wire [7:0] B21 = iP21[7:0];
    wire [7:0] R22 = iP22[23:16]; wire [7:0] G22 = iP22[15:8]; wire [7:0] B22 = iP22[7:0];

    // R 채널 conv
    wire signed [ACC_WIDTH-1:0] conv_R =
        $signed({1'b0,R00})*K00 + $signed({1'b0,R01})*K01 + $signed({1'b0,R02})*K02 +
        $signed({1'b0,R10})*K10 + $signed({1'b0,R11})*K11 + $signed({1'b0,R12})*K12 +
        $signed({1'b0,R20})*K20 + $signed({1'b0,R21})*K21 + $signed({1'b0,R22})*K22;

    // G 채널 conv
    wire signed [ACC_WIDTH-1:0] conv_G =
        $signed({1'b0,G00})*K00 + $signed({1'b0,G01})*K01 + $signed({1'b0,G02})*K02 +
        $signed({1'b0,G10})*K10 + $signed({1'b0,G11})*K11 + $signed({1'b0,G12})*K12 +
        $signed({1'b0,G20})*K20 + $signed({1'b0,G21})*K21 + $signed({1'b0,G22})*K22;

    // B 채널 conv
    wire signed [ACC_WIDTH-1:0] conv_B =
        $signed({1'b0,B00})*K00 + $signed({1'b0,B01})*K01 + $signed({1'b0,B02})*K02 +
        $signed({1'b0,B10})*K10 + $signed({1'b0,B11})*K11 + $signed({1'b0,B12})*K12 +
        $signed({1'b0,B20})*K20 + $signed({1'b0,B21})*K21 + $signed({1'b0,B22})*K22;

    // 출력 레지스터
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oPixel <= 24'd0;
            oValid <= 1'b0;
            oLast  <= 1'b0;
        end else if (iEn) begin
            if (iValid) begin
                oPixel[23:16] <= relu_sat8(conv_R);
                oPixel[15:8]  <= relu_sat8(conv_G);
                oPixel[7:0]   <= relu_sat8(conv_B);
                oValid        <= 1'b1;
                oLast         <= iLast;     // 마지막 유효 윈도우이면 1
            end else begin
                oValid <= 1'b0;
                oLast  <= 1'b0;
            end
        end
    end

endmodule
