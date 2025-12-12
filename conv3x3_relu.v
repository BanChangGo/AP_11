`timescale 1ns / 1ps

module conv3x3_programmable_rgb #(
    parameter ACC_WIDTH = 20  
)(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iEn,
    input  wire        iValid,
    input  wire        iLast,
    
    // [입력] 결정된 커널 값 9개 (Flow Controller에서 옴)
    input  wire signed [7:0] iK00, input wire signed [7:0] iK01, input wire signed [7:0] iK02,
    input  wire signed [7:0] iK10, input wire signed [7:0] iK11, input wire signed [7:0] iK12,
    input  wire signed [7:0] iK20, input wire signed [7:0] iK21, input wire signed [7:0] iK22,

    input  wire [24*9-1:0] iWindow,

    output reg  [23:0] oPixel,
    output reg         oValid,
    output reg         oLast
);

    // 1. Data Unpacking
    wire [23:0] iP00, iP01, iP02, iP10, iP11, iP12, iP20, iP21, iP22;
    assign {iP00, iP01, iP02, iP10, iP11, iP12, iP20, iP21, iP22} = iWindow;

    // 2. RGB Separation & Sign Extension
    wire signed [8:0] R00={1'b0, iP00[23:16]}; wire signed [8:0] R01={1'b0, iP01[23:16]}; wire signed [8:0] R02={1'b0, iP02[23:16]};
    wire signed [8:0] R10={1'b0, iP10[23:16]}; wire signed [8:0] R11={1'b0, iP11[23:16]}; wire signed [8:0] R12={1'b0, iP12[23:16]};
    wire signed [8:0] R20={1'b0, iP20[23:16]}; wire signed [8:0] R21={1'b0, iP21[23:16]}; wire signed [8:0] R22={1'b0, iP22[23:16]};
    // (G, B 채널도 동일하게 확장...)
    wire signed [8:0] G00={1'b0, iP00[15:8]};  wire signed [8:0] G01={1'b0, iP01[15:8]};  wire signed [8:0] G02={1'b0, iP02[15:8]};
    wire signed [8:0] G10={1'b0, iP10[15:8]};  wire signed [8:0] G11={1'b0, iP11[15:8]};  wire signed [8:0] G12={1'b0, iP12[15:8]};
    wire signed [8:0] G20={1'b0, iP20[15:8]};  wire signed [8:0] G21={1'b0, iP21[15:8]};  wire signed [8:0] G22={1'b0, iP22[15:8]};

    wire signed [8:0] B00={1'b0, iP00[7:0]};   wire signed [8:0] B01={1'b0, iP01[7:0]};   wire signed [8:0] B02={1'b0, iP02[7:0]};
    wire signed [8:0] B10={1'b0, iP10[7:0]};   wire signed [8:0] B11={1'b0, iP11[7:0]};   wire signed [8:0] B12={1'b0, iP12[7:0]};
    wire signed [8:0] B20={1'b0, iP20[7:0]};   wire signed [8:0] B21={1'b0, iP21[7:0]};   wire signed [8:0] B22={1'b0, iP22[7:0]};

    // 3. Convolution Calculation
    reg signed [ACC_WIDTH-1:0] sum_r, sum_g, sum_b;

    always @(*) begin
        sum_r = (R00 * iK00) + (R01 * iK01) + (R02 * iK02) +
                (R10 * iK10) + (R11 * iK11) + (R12 * iK12) +
                (R20 * iK20) + (R21 * iK21) + (R22 * iK22);

        sum_g = (G00 * iK00) + (G01 * iK01) + (G02 * iK02) +
                (G10 * iK10) + (G11 * iK11) + (G12 * iK12) +
                (G20 * iK20) + (G21 * iK21) + (G22 * iK22);

        sum_b = (B00 * iK00) + (B01 * iK01) + (B02 * iK02) +
                (B10 * iK10) + (B11 * iK11) + (B12 * iK12) +
                (B20 * iK20) + (B21 * iK21) + (B22 * iK22);
    end

    // 4. Saturation
    function [7:0] sat_cast;
        input signed [ACC_WIDTH-1:0] val;
        begin
            if (val < 0) sat_cast = 8'd0;
            else if (val > 255) sat_cast = 8'd255;
            else sat_cast = val[7:0];
        end
    endfunction

    // 5. Output Logic
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oPixel <= 24'd0;
            oValid <= 1'b0;
            oLast  <= 1'b0;
        end else if (iEn) begin
            if (iValid) begin
                oPixel[23:16] <= sat_cast(sum_r);
                oPixel[15:8]  <= sat_cast(sum_g);
                oPixel[7:0]   <= sat_cast(sum_b);
                oValid        <= 1'b1;
                oLast         <= iLast;
            end else begin
                oValid        <= 1'b0;
                oLast         <= 1'b0;
            end
        end
    end

endmodule