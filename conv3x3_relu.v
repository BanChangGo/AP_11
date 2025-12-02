`timescale 1ns / 1ps

module conv3x3_laplacian_rgb #(
    parameter ACC_WIDTH = 20  // 연산 오버플로우 방지를 위해 넉넉하게 20비트
)(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iEn,       // wEnClk
    input  wire        iValid,    // window3x3의 oValid
    input  wire        iLast,     // pixel_addr_ctrl의 oLast

    input  wire [23:0] iP00, iP01, iP02,
    input  wire [23:0] iP10, iP11, iP12,
    input  wire [23:0] iP20, iP21, iP22,

    output reg  [23:0] oPixel,    // Result RGB888
    output reg         oValid,    // 결과 유효
    output reg         oLast      // 프레임 끝
);

    //--------------------------------------------------------------------------
    // 1. 커널 계수 정의 (Sharpening / Laplacian)
    //    중심이 9, 주변이 -1 (합계 1) -> 밝기 유지하며 선명하게
    //--------------------------------------------------------------------------
    localparam signed [7:0] K00 = 8'sd0;
    localparam signed [7:0] K01 = -8'sd1;
    localparam signed [7:0] K02 = 8'sd0;
    localparam signed [7:0] K10 = -8'sd1;
    localparam signed [7:0] K11 =  8'sd5;  
    localparam signed [7:0] K12 = -8'sd1;
    localparam signed [7:0] K20 = 8'sd0;
    localparam signed [7:0] K21 = -8'sd1;
    localparam signed [7:0] K22 = 8'sd0;

    //--------------------------------------------------------------------------
    // 2. RGB 채널 분리 및 Signed 확장
    //    Unsigned 8bit 입력 앞에 0을 붙여 9bit Signed 양수로 만듭니다.
    //--------------------------------------------------------------------------
    // Red
    wire signed [8:0] R00={1'b0, iP00[23:16]}; wire signed [8:0] R01={1'b0, iP01[23:16]}; wire signed [8:0] R02={1'b0, iP02[23:16]};
    wire signed [8:0] R10={1'b0, iP10[23:16]}; wire signed [8:0] R11={1'b0, iP11[23:16]}; wire signed [8:0] R12={1'b0, iP12[23:16]};
    wire signed [8:0] R20={1'b0, iP20[23:16]}; wire signed [8:0] R21={1'b0, iP21[23:16]}; wire signed [8:0] R22={1'b0, iP22[23:16]};
    
    // Green
    wire signed [8:0] G00={1'b0, iP00[15:8]};  wire signed [8:0] G01={1'b0, iP01[15:8]};  wire signed [8:0] G02={1'b0, iP02[15:8]};
    wire signed [8:0] G10={1'b0, iP10[15:8]};  wire signed [8:0] G11={1'b0, iP11[15:8]};  wire signed [8:0] G12={1'b0, iP12[15:8]};
    wire signed [8:0] G20={1'b0, iP20[15:8]};  wire signed [8:0] G21={1'b0, iP21[15:8]};  wire signed [8:0] G22={1'b0, iP22[15:8]};

    // Blue
    wire signed [8:0] B00={1'b0, iP00[7:0]};   wire signed [8:0] B01={1'b0, iP01[7:0]};   wire signed [8:0] B02={1'b0, iP02[7:0]};
    wire signed [8:0] B10={1'b0, iP10[7:0]};   wire signed [8:0] B11={1'b0, iP11[7:0]};   wire signed [8:0] B12={1'b0, iP12[7:0]};
    wire signed [8:0] B20={1'b0, iP20[7:0]};   wire signed [8:0] B21={1'b0, iP21[7:0]};   wire signed [8:0] B22={1'b0, iP22[7:0]};

    //--------------------------------------------------------------------------
    // 3. 컨볼루션 연산 (Combinational Logic)
    //    곱셈과 덧셈을 수행합니다.
    //--------------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] sum_r, sum_g, sum_b;

    always @(*) begin
        sum_r = (R00 * K00) + (R01 * K01) + (R02 * K02) +
                (R10 * K10) + (R11 * K11) + (R12 * K12) +
                (R20 * K20) + (R21 * K21) + (R22 * K22);

        sum_g = (G00 * K00) + (G01 * K01) + (G02 * K02) +
                (G10 * K10) + (G11 * K11) + (G12 * K12) +
                (G20 * K20) + (G21 * K21) + (G22 * K22);

        sum_b = (B00 * K00) + (B01 * K01) + (B02 * K02) +
                (B10 * K10) + (B11 * K11) + (B12 * K12) +
                (B20 * K20) + (B21 * K21) + (B22 * K22);
    end

    //--------------------------------------------------------------------------
    // 4. Saturation (Clamping) 함수 - [가장 중요]
    //    비트 연산 대신 비교 연산자를 사용하여 가독성과 안정성을 높였습니다.
    //--------------------------------------------------------------------------
    function [7:0] sat_cast;
        input signed [ACC_WIDTH-1:0] val;
        begin
            if (val < 0) 
                sat_cast = 8'd0;       // 음수(Underflow) -> 0 (검은색)
            else if (val > 255) 
                sat_cast = 8'd255;     // 255 초과(Overflow) -> 255 (흰색)
            else 
                sat_cast = val[7:0];   // 정상 범위 -> 하위 8비트 사용
        end
    endfunction

    //--------------------------------------------------------------------------
    // 5. 결과 출력 (Sequential Logic)
    //--------------------------------------------------------------------------
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oPixel <= 24'd0;
            oValid <= 1'b0;
            oLast  <= 1'b0;
        end else if (iEn) begin
            // Valid가 High일 때만 계산 결과 업데이트
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