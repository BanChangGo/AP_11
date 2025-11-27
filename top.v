`timescale 1ns / 1ps

module cnn_laplacian_tft_top #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272
)(
    input  wire        iClk_100,
    input  wire        iRstn,

    output wire        lcd_clk,     // LCD�� ������ ������ Ŭ�� (Square Wave)
    output wire        LCD_hsync_o,
    output wire        LCD_vsync_o,
    output             LCD_de_o,
    output wire [4:0]  LCD_R_o,
    output wire [5:0]  LCD_G_o,
    output wire [4:0]  LCD_B_o,
    output wire        TFT_BACKLIGHT
);

    // -------------------------------------------------------------------------
    // 1) Clock Generation
    // -------------------------------------------------------------------------
    wire wEnClk;       // ������ (Pulse) - �ý��� ��ü ����ȭ Ŭ��
    wire wLCD_Clk_sq;  // LCD ��¿� (Square Wave) - �ܺ� �������̽���

    clk_en_gen #(
        .DIV(16)
    ) u_clk_en_gen (
        .iClk       (iClk_100),
        .iRstn      (iRstn),
        .wEnClk     (wEnClk),
        .oLCD_Clk_sq(wLCD_Clk_sq) 
    );

    // -------------------------------------------------------------------------
    // 2) pixel_addr_ctrl
    // -------------------------------------------------------------------------
    localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;

    reg [16:0] src_addr;
    reg        src_last;

    always @(posedge iClk_100 or negedge iRstn) begin
        if (!iRstn) begin
            src_addr <= 17'd0;
            src_last <= 1'b0;
        end else if (wEnClk) begin
            if (src_addr == TOTAL_PIX - 1) begin
                src_addr <= 17'd0;
                src_last <= 1'b1;
            end else begin
                src_addr <= src_addr + 1'b1;
                src_last <= 1'b0;
            end
        end else begin
            src_last <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 3) InBuf
    // -------------------------------------------------------------------------
    wire [23:0] src_pixel;

    InBuf #(
        .IMG_WIDTH  (IMG_WIDTH), .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (24), .ADDR_WIDTH (17)
    ) u_inbuf (
        .iClk(iClk_100), .iRstn(iRstn), .iEn(wEnClk), 
        .iAddr(src_addr), .oPixel(src_pixel)
    );

    // -------------------------------------------------------------------------
    // 4) window3x3
    // -------------------------------------------------------------------------
    wire [23:0] wP00, wP01, wP02, wP10, wP11, wP12, wP20, wP21, wP22;
    wire wWinValid;

    window3x3 #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DATA_WIDTH(24)
    ) u_window3x3 (
        .iClk(iClk_100), .iRstn(iRstn), .iEn(wEnClk), .iPixel(src_pixel),
        .oP00(wP00), .oP01(wP01), .oP02(wP02),
        .oP10(wP10), .oP11(wP11), .oP12(wP12),
        .oP20(wP20), .oP21(wP21), .oP22(wP22),
        .oValid(wWinValid)
    );

    // -------------------------------------------------------------------------
    // 5) conv3x3
    // -------------------------------------------------------------------------
    wire [23:0] conv_pixel;
    wire conv_valid, conv_last;

    conv3x3_laplacian_rgb #(.ACC_WIDTH(19)) u_conv3x3 (
        .iClk(iClk_100), .iRstn(iRstn), .iEn(wEnClk),
        .iValid(wWinValid), .iLast(src_last),
        .iP00(wP00), .iP01(wP01), .iP02(wP02),
        .iP10(wP10), .iP11(wP11), .iP12(wP12),
        .iP20(wP20), .iP21(wP21), .iP22(wP22),
        .oPixel(conv_pixel), .oValid(conv_valid), .oLast(conv_last)
    );

    // -------------------------------------------------------------------------
    // 6) pixel_conv
    // -------------------------------------------------------------------------
    wire [15:0] pix565;
    wire pix_valid, pix_last;

    pixel_conv_rgb888_to_rgb565_round u_pixconv (
        .iClk(iClk_100), .iRstn(iRstn), .iEn(wEnClk),
        .iValid(conv_valid), .iLast(conv_last), .iPixel(conv_pixel),
        .oPixel565(pix565), .oValid(pix_valid), .oLast(pix_last)
    );

    // -------------------------------------------------------------------------
    // 7) OutBuf : Clock Domain ���� (�߿�!)
    //    - Write: wEnClk
    //    - Read : wEnClk (�� wLCD_Clk_sq ��� wEnClk ���)
    // -------------------------------------------------------------------------
    wire [16:0] ram_rd_addr;
    wire [15:0] ram_rd_data;
    wire        frame_done;

    OutBuf #(
        .IMG_WIDTH  (IMG_WIDTH), .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (16), .ADDR_WIDTH (17)
    ) u_outbuf (
        // Write side
        .iClk_wr   (iClk_100),
        .iRstn     (iRstn),
        .iEn_wr    (wEnClk),
        .iValid_wr (pix_valid),
        .iLast_wr  (pix_last),
        .iPixel_wr (pix565),
        .oFrameDone(frame_done),

        // Read side
        .iClk_rd   (wEnClk), // �� ��ũ �и� �ذ�: ���� Enable Ŭ�� ���
        .iAddr_rd  (ram_rd_addr),
        .oData_rd  (ram_rd_data)
    );

    

    // -------------------------------------------------------------------------
    // 8) ram_to_lcd : ������ ������ wEnClk, ������ Ŭ�� ����� wLCD_Clk_sq
    // -------------------------------------------------------------------------
    reg lcd_enable;

    always @(posedge iClk_100 or negedge iRstn) begin
        if (!iRstn)
            lcd_enable <= 1'b0;
        else if (frame_done)
            lcd_enable <= 1'b1;
    end

    ram_to_lcd u_ram_to_lcd (
        .clk_i        (wEnClk),       // �� ���� ������ wEnClk�� ���� (������ ������ Ȯ��)
        .iEnable      (lcd_enable),

        .ram_rd_addr_o(ram_rd_addr),
        .ram_rd_data_i(ram_rd_data),

        //.oLCD_Clk     (lcd_clk),      // �� ��Ʈ�� ������� �ʰ�, �Ʒ����� ���� �Ҵ�
        .LCD_hsync_o  (LCD_hsync_o),
        .LCD_vsync_o  (LCD_vsync_o),
        .LCD_de_o     (LCD_de_o),
        .LCD_R_o      (LCD_R_o),
        .LCD_G_o      (LCD_G_o),
        .LCD_B_o      (LCD_B_o)
    );

    // �� �ٽ�: LCD ���� �ɿ��� �簢�� ���� Ŭ���� ���� ����
    // �����ʹ� wEnClk�� ���� �غ������, LCD�� wLCD_Clk_sq�� ���� ������
    assign lcd_clk = wLCD_Clk_sq; 

    assign TFT_BACKLIGHT = 1'b1;

endmodule