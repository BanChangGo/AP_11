`timescale 1ns / 1ps

module conv3x3_laplacian_rgb #(
    parameter ACC_WIDTH = 20  // 연산 오버플로우 방지를 위해 넉넉하게 20비트
)(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iEn,
    input  wire        iValid,
    input  wire        iLast,
    
    // [추가] 모드 선택 신호 (0: Bypass, 1: Sharpen, 2: Edge Detect)
    input  wire [1:0]  iMode,

    input  wire [24*9-1:0] iWindow,

    output reg  [23:0] oPixel,
    output reg         oValid,
    output reg         oLast
);

    // 1. 데이터 언패킹 (Unpacking)
    wire [23:0] iP00, iP01, iP02;
    wire [23:0] iP10, iP11, iP12;
    wire [23:0] iP20, iP21, iP22;

    assign {iP00, iP01, iP02,
            iP10, iP11, iP12,
            iP20, iP21, iP22} = iWindow;

    //--------------------------------------------------------------------------
    // 2. [수정] 커널 계수 선택 로직 (MUX)
    //    localparam 대신 reg로 선언하여 iMode에 따라 값을 바꿉니다.
    //--------------------------------------------------------------------------
    reg signed [7:0] K00, K01, K02;
    reg signed [7:0] K10, K11, K12;
    reg signed [7:0] K20, K21, K22;

    always @(*) begin
        case (iMode)
            //------------------------------------------------------
            // Mode 0: Bypass (원본 그대로 출력)
            // 중심만 1, 나머지는 0
            //------------------------------------------------------
            2'b00: begin
                K00 = 0; K01 = 0; K02 = 0;
                K10 = 0; K11 = 1; K12 = 0;
                K20 = 0; K21 = 0; K22 = 0;
            end

            //------------------------------------------------------
            // Mode 1: Sharpening (선명하게)
            // 원본 색상을 유지하면서 엣지를 강조 (커널 합 = 1)
            // [ 0 -1  0]
            // [-1  5 -1]
            // [ 0 -1  0]
            //------------------------------------------------------
            2'b01: begin
                K00 =  0; K01 = -1; K02 =  0;
                K10 = -1; K11 =  5; K12 = -1;
                K20 =  0; K21 = -1; K22 =  0;
            end

            //------------------------------------------------------
            // Mode 2: Edge Detection (Laplacian)
            // 배경은 검게, 엣지만 색상 표시 (커널 합 = 0)
            // [-1 -1 -1]
            // [-1  9 -1]
            // [-1 -1 -1]
            //------------------------------------------------------
            2'b10: begin
                K00 =  -1; K01 = -1; K02 = -1;
                K10 = -1;  K11 =  9; K12 = -1;
                K20 =  -1; K21 = -1; K22 = -1;
            end

            // Default: Bypass
            default: begin
                K00 = 0; K01 = 0; K02 = 0;
                K10 = 0; K11 = 1; K12 = 0;
                K20 = 0; K21 = 0; K22 = 0;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // 3. RGB 채널 분리 및 Signed 확장 (기존과 동일)
    //--------------------------------------------------------------------------
    wire signed [8:0] R00={1'b0, iP00[23:16]}; wire signed [8:0] R01={1'b0, iP01[23:16]}; wire signed [8:0] R02={1'b0, iP02[23:16]};
    wire signed [8:0] R10={1'b0, iP10[23:16]}; wire signed [8:0] R11={1'b0, iP11[23:16]}; wire signed [8:0] R12={1'b0, iP12[23:16]};
    wire signed [8:0] R20={1'b0, iP20[23:16]}; wire signed [8:0] R21={1'b0, iP21[23:16]}; wire signed [8:0] R22={1'b0, iP22[23:16]};
    
    wire signed [8:0] G00={1'b0, iP00[15:8]};  wire signed [8:0] G01={1'b0, iP01[15:8]};  wire signed [8:0] G02={1'b0, iP02[15:8]};
    wire signed [8:0] G10={1'b0, iP10[15:8]};  wire signed [8:0] G11={1'b0, iP11[15:8]};  wire signed [8:0] G12={1'b0, iP12[15:8]};
    wire signed [8:0] G20={1'b0, iP20[15:8]};  wire signed [8:0] G21={1'b0, iP21[15:8]};  wire signed [8:0] G22={1'b0, iP22[15:8]};

    wire signed [8:0] B00={1'b0, iP00[7:0]};   wire signed [8:0] B01={1'b0, iP01[7:0]};   wire signed [8:0] B02={1'b0, iP02[7:0]};
    wire signed [8:0] B10={1'b0, iP10[7:0]};   wire signed [8:0] B11={1'b0, iP11[7:0]};   wire signed [8:0] B12={1'b0, iP12[7:0]};
    wire signed [8:0] B20={1'b0, iP20[7:0]};   wire signed [8:0] B21={1'b0, iP21[7:0]};   wire signed [8:0] B22={1'b0, iP22[7:0]};

    //--------------------------------------------------------------------------
    // 4. 컨볼루션 연산 (기존과 동일)
    //    위에서 선택된 Kxx 값들과 곱셈 수행
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
    // 5. Saturation 함수 (기존과 동일)
    //--------------------------------------------------------------------------
    function [7:0] sat_cast;
        input signed [ACC_WIDTH-1:0] val;
        begin
            if (val < 0) 
                sat_cast = 8'd0;
            else if (val > 255) 
                sat_cast = 8'd255;
            else 
                sat_cast = val[7:0];
        end
    endfunction

    //--------------------------------------------------------------------------
    // 6. 결과 출력 (기존과 동일)
    //--------------------------------------------------------------------------
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