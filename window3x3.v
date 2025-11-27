// window3x3.v
`timescale 1ns / 1ps

module window3x3 #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272,
    parameter DATA_WIDTH = 24
)(
    input  wire                    iClk,
    input  wire                    iRstn,
    input  wire                    iEn,       // wEnClk
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

    integer i;

    // 라인버퍼 read/write + row/col 카운터
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            col      <= {COL_W{1'b0}};
            row      <= {ROW_W{1'b0}};
            lb0_dout <= {DATA_WIDTH{1'b0}};
            lb1_dout <= {DATA_WIDTH{1'b0}};
        end else if (iEn) begin
            // 읽기
            lb0_dout <= linebuf0[col];
            lb1_dout <= linebuf1[col];

            // 새 픽셀 쓰기 (row-1 -> linebuf1, 현재 -> linebuf0)
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

    // 3x3 윈도우 쉬프트
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            {oP00,oP01,oP02,
             oP10,oP11,oP12,
             oP20,oP21,oP22} <= {(9*DATA_WIDTH){1'b0}};
        end else if (iEn) begin
            // 왼쪽으로 쉬프트
            oP00 <= oP01;  oP01 <= oP02;
            oP10 <= oP11;  oP11 <= oP12;
            oP20 <= oP21;  oP21 <= oP22;

            // 오른쪽 열에 새 데이터
            oP02 <= lb1_dout;   // row-2
            oP12 <= lb0_dout;   // row-1
            oP22 <= iPixel;     // 현재 row
        end
    end

    // 윈도우 유효 플래그
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oValid <= 1'b0;
        end else if (iEn) begin
            // non-blocking 때문에 이전 cycle의 row/col 기준
            if ((row >= 2) && (col >= 2))
                oValid <= 1'b1;
            else
                oValid <= 1'b0;
        end
    end

endmodule
