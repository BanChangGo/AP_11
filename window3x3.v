`timescale 1ns / 1ps

module window3x3 #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272,
    parameter DATA_WIDTH = 24
)(
    input  wire                   iClk,      // 100MHz System Clock
    input  wire                   iRstn,     // Active Low Reset
    input  wire                   iEn,       // 6.25MHz Data Enable
    input  wire [DATA_WIDTH-1:0]  iPixel,    // Input Pixel (RGB888)

    // [���] 9���� �ȼ��� �ϳ��� ���� ���� (24bit * 9 = 216bit)
    output wire [DATA_WIDTH*9-1:0] oWindow, 
    
    // [���] ������ ��ȿ ��ȣ
    output reg                    oValid
);

    // -------------------------------------------------------------------------
    // 1. ���� ���� �� �޸� ����
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] linebuf0 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] linebuf1 [0:IMG_WIDTH-1];

    reg [DATA_WIDTH-1:0] lb0_dout;
    reg [DATA_WIDTH-1:0] lb1_dout;
    reg [DATA_WIDTH-1:0] iPixel_d; 

    localparam COL_W = $clog2(IMG_WIDTH);
    localparam ROW_W = $clog2(IMG_HEIGHT);
    reg [COL_W-1:0] col;
    reg [ROW_W-1:0] row;

    reg [DATA_WIDTH-1:0] rP00, rP01, rP02;
    reg [DATA_WIDTH-1:0] rP10, rP11, rP12;
    reg [DATA_WIDTH-1:0] rP20, rP21, rP22;

    reg [DATA_WIDTH-1:0] tP00, tP01, tP02;
    reg [DATA_WIDTH-1:0] tP10, tP11, tP12;
    reg [DATA_WIDTH-1:0] tP20, tP21, tP22;

    reg warmup_done;      
    reg [2:0] valid_sr;   

    // -------------------------------------------------------------------------
    // 2. Edge Detection
    // -------------------------------------------------------------------------
    reg iEn_prev;
    wire wEnRising;

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) iEn_prev <= 1'b0;
        else        iEn_prev <= iEn;
    end
    assign wEnRising = iEn & ~iEn_prev; 

    // -------------------------------------------------------------------------
    // ? [����] Valid ���� ���̾� ���� (Always ���� ������ �̵�)
    // -------------------------------------------------------------------------
    wire raw_valid;
    assign raw_valid = (row >= 1 || warmup_done);

    // -------------------------------------------------------------------------
    // 3. ���ι��� ���� �� ��ǥ ����
    // -------------------------------------------------------------------------
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            col      <= 0;
            row      <= 0;
            lb0_dout <= 0;
            lb1_dout <= 0;
            iPixel_d <= 0;
            warmup_done <= 0;
        end else begin
            if (wEnRising) begin
                iPixel_d <= iPixel;
                lb0_dout <= linebuf0[col];
                lb1_dout <= linebuf1[col];

                // ����� ���� �� �� ���� iPixel ���
                linebuf1[col] <= linebuf0[col];
                linebuf0[col] <= iPixel;

                if (col == IMG_WIDTH-1) begin
                    col <= 0;
                    if (row == IMG_HEIGHT-1) row <= 0;
                    else                     row <= row + 1;
                    
                    if (row == 0) warmup_done <= 1'b1;
                end else begin
                    col <= col + 1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 4. ������ ���� & Zero Padding & Valid ����
    // -------------------------------------------------------------------------
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            rP00 <= 0; rP01 <= 0; rP02 <= 0;
            rP10 <= 0; rP11 <= 0; rP12 <= 0;
            rP20 <= 0; rP21 <= 0; rP22 <= 0;
            oValid <= 0;
            valid_sr <= 3'b000;
        end else begin
            if (wEnRising) begin
                
                // ? [����] 3��Ʈ Shift Register�� ���� (raw_valid�� �ۿ��� ����)
                valid_sr <= {valid_sr[1:0], raw_valid};
                
                // 3Ŭ�� ������ ���� ���� ���
                oValid <= valid_sr[2];

                // [1�ܰ�: ������ ����Ʈ �� ������ �ε�]
                tP00 = rP01; tP01 = rP02; tP02 = lb1_dout; // Top
                tP10 = rP11; tP11 = rP12; tP12 = lb0_dout; // Mid
                tP20 = rP21; tP21 = rP22; tP22 = iPixel_d; // Bot

                // [2�ܰ�: 4���� Zero Padding]
                // 1. Left Padding
                if (col == 2) begin
                    tP00 = 0; tP10 = 0; tP20 = 0;
                end

                // 2. Right Padding
                if (col == 1) begin
                     tP02 = 0; tP12 = 0; tP22 = 0;
                end
                
                // 3. Top Padding
                if (row == 1) begin 
                    tP00 = 0; tP01 = 0; tP02 = 0;
                end

                // 4. Bottom Padding
                if (row == 0 && warmup_done) begin
                    tP20 = 0; tP21 = 0; tP22 = 0;
                end

                // [3�ܰ�: �������� ������Ʈ]
                rP00 <= tP00; rP01 <= tP01; rP02 <= tP02;
                rP10 <= tP10; rP11 <= tP11; rP12 <= tP12;
                rP20 <= tP20; rP21 <= tP21; rP22 <= tP22;

            end else begin
                oValid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 5. ������ ��ŷ
    // -------------------------------------------------------------------------
    assign oWindow = {rP00, rP01, rP02, 
                      rP10, rP11, rP12, 
                      rP20, rP21, rP22};

endmodule