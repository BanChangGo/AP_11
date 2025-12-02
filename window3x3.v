`timescale 1ns / 1ps

module window3x3 #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272,
    parameter DATA_WIDTH = 24
)(
    input  wire                    iClk,      // 메인 클럭 (100MHz)
    input  wire                    iRstn,
    input  wire                    iEn,       // Enable 신호 (6.25MHz 타이밍)
    input  wire [DATA_WIDTH-1:0]   iPixel,    // RGB888

    output reg [DATA_WIDTH-1:0]    oP00,
    output reg [DATA_WIDTH-1:0]    oP01,
    output reg [DATA_WIDTH-1:0]    oP02,
    output reg [DATA_WIDTH-1:0]    oP10,
    output reg [DATA_WIDTH-1:0]    oP11,
    output reg [DATA_WIDTH-1:0]    oP12,
    output reg [DATA_WIDTH-1:0]    oP20,
    output reg [DATA_WIDTH-1:0]    oP21,
    output reg [DATA_WIDTH-1:0]    oP22,

    output reg                     oValid
);

    // 라인버퍼 2개
    reg [DATA_WIDTH-1:0] linebuf0 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] linebuf1 [0:IMG_WIDTH-1];

    reg [DATA_WIDTH-1:0] lb0_dout;
    reg [DATA_WIDTH-1:0] lb1_dout;

    localparam COL_W = $clog2(IMG_WIDTH);
    localparam ROW_W = $clog2(IMG_HEIGHT);

    reg [COL_W-1:0] col;
    reg [ROW_W-1:0] row;

    // ---------------------------------------------------------
    // 1. 라인버퍼 Read/Write 및 Counter 제어
    // ---------------------------------------------------------
    // [수정] posedge iEn -> posedge iClk
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            col      <= {COL_W{1'b0}};
            row      <= {ROW_W{1'b0}};
            lb0_dout <= {DATA_WIDTH{1'b0}};
            lb1_dout <= {DATA_WIDTH{1'b0}};
        end else begin
            // [수정] Enable 신호가 1일 때만 동작하도록 감싸기
            if (iEn) begin
                // 읽기
                lb0_dout <= linebuf0[col];
                lb1_dout <= linebuf1[col];

                // 새 픽셀 쓰기
                linebuf1[col] <= linebuf0[col];
                linebuf0[col] <= iPixel;

                // 좌표 증가
                if (col == IMG_WIDTH-1) begin
                    col <= {COL_W{1'b0}};
                    if (row != IMG_HEIGHT-1)
                        row <= row + 1'b1;
                end else begin
                    col <= col + 1'b1;
                end
            end
        end
    end

    // ---------------------------------------------------------
    // 2. 3x3 윈도우 쉬프트
    // ---------------------------------------------------------
    // [수정] posedge iEn -> posedge iClk
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oP00 <= 0; oP01 <= 0; oP02 <= 0;
            oP10 <= 0; oP11 <= 0; oP12 <= 0;
            oP20 <= 0; oP21 <= 0; oP22 <= 0;
        end else begin
            // [수정] Enable 체크
            if (iEn) begin
                // 왼쪽으로 쉬프트
                oP00 <= oP01;  oP01 <= oP02;
                oP10 <= oP11;  oP11 <= oP12;
                oP20 <= oP21;  oP21 <= oP22;

                // 오른쪽 열에 새 데이터 채우기
                oP02 <= lb1_dout;   // 2라인 전 데이터
                oP12 <= lb0_dout;   // 1라인 전 데이터
                oP22 <= iPixel;     // 현재 라인 데이터
            end
        end
    end

    // ---------------------------------------------------------
    // 3. 유효 플래그 생성
    // ---------------------------------------------------------
    // [수정] posedge iEn -> posedge iClk
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oValid <= 1'b0;
        end else begin
            // [수정] Enable 체크
            if (iEn) begin
                // 2행 2열 이상 진행되었을 때 유효
                if ((row >= 2) && (col >= 2))
                    oValid <= 1'b1;
                else
                    oValid <= 1'b0;
            end
        end
    end

endmodule