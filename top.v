`timescale 1ns / 1ps

module cnn_laplacian_tft_top #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272
)(
    input  wire        iClk_100,
    input  wire        iRstn,

    output wire        lcd_clk,     // LCDï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ Å¬ï¿½ï¿½ (Square Wave)
    output wire        LCD_hsync_o,
    output wire        LCD_vsync_o,
    output             LCD_de_o,
    output wire [4:0]  LCD_R_o,
    output wire [5:0]  LCD_G_o,
    output wire [4:0]  LCD_B_o,
    output wire        TFT_BACKLIGHT


    
);
    // VIO ?ï¿½ï¿½?ï¿½ï¿½ ?ï¿½ï¿½ï¿??? ?ï¿½ï¿½ï¿????ï¿½ï¿½?ï¿½ï¿½ ?ï¿½ï¿½?ï¿½ï¿½

    wire [15:0] h_sync_w;
    wire [15:0] h_back_p;
    wire [15:0] h_front_p;
    wire [15:0] h_active;
    wire [15:0] v_sync_w;
    wire [15:0] v_back_p;
    wire [15:0] v_active;
    wire [15:0] v_front_p;


    vio_0 u_vio(
        .clk(iClk_100),
        .probe_out0(h_sync_w),
        .probe_out1(h_back_p),
        .probe_out2(h_active),
        .probe_out3(v_sync_w),
        .probe_out4(v_back_p),
        .probe_out5(v_active),
        .probe_out6(v_front_p),
        .probe_out7(h_front_p)
        
    );
    // -------------------------------------------------------------------------
    // 1) Clock Generation
    // -------------------------------------------------------------------------
    wire wEnClk;       // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ (Pulse) - ï¿½Ã½ï¿½ï¿½ï¿½ ï¿½ï¿½Ã¼ ï¿½ï¿½ï¿½ï¿½È­ Å¬ï¿½ï¿½

    clk_gen2 CLK_GEN_TFTLCD(
        .clk_i(iClk_100),
        .iRstn(iRstn),      // <- ï¿½ï¿½ï¿½ï¿½
        .count_i(16'd7),
        .clk_o(wEnClk)
    );
    

    // 100MHz -> 6.25MHz enable pulse ?ƒ?„±
    reg [3:0] cnt_6p25;   // 16ë¶„ì£¼?š© 4bit ì¹´ìš´?„°
    reg       wEnClk_pulse;

    always @(posedge iClk_100 or negedge iRstn) begin
        if (!iRstn) begin
            cnt_6p25      <= 4'd0;
            wEnClk_pulse  <= 1'b0;
        end else begin
            if (cnt_6p25 == 4'd15) begin
                cnt_6p25     <= 4'd0;
                wEnClk_pulse <= 1'b1;  // 1?´?Ÿ­ ?„?Š¤ ë°œìƒ
            end else begin
                cnt_6p25     <= cnt_6p25 + 1'b1;
                wEnClk_pulse <= 1'b0;
            end
        end
    end


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
        end else if (wEnClk_pulse) begin
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
    wire [215:0] wWindowData;
    wire wWinValid;

    window3x3 #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DATA_WIDTH(24)
    ) u_window3x3 (
        .iClk(iClk_100), .iRstn(iRstn), .iEn(wEnClk), .iPixel(src_pixel),
        .oWindow (wWindowData),
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
        .iWindow (wWindowData),
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
    // 7) OutBuf : Clock Domain ï¿½ï¿½ï¿½ï¿½ (ï¿½ß¿ï¿½!)
    //    - Write: wEnClk
    //    - Read : wEnClk (ï¿½ï¿½ wLCD_Clk_sq ï¿½ï¿½ï¿??? wEnClk ï¿½ï¿½ï¿???)
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
        .iClk_rd   (wEnClk), // ï¿½ï¿½ ï¿½ï¿½Å© ï¿½Ğ¸ï¿½ ï¿½Ø°ï¿½: ï¿½ï¿½ï¿½ï¿½ Enable Å¬ï¿½ï¿½ ï¿½ï¿½ï¿???
        .iAddr_rd  (ram_rd_addr),
        .oData_rd  (ram_rd_data)
    );
    


    // -------------------------------------------------------------------------
    // 8) ram_to_lcd : ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ wEnClk, ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ Å¬ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿??? wLCD_Clk_sq
    // -------------------------------------------------------------------------
    
    /*reg lcd_enable;

    always @(posedge iClk_100 or negedge iRstn) begin
        if (!iRstn)
            lcd_enable <= 1'b0;
        else if (frame_done)
            lcd_enable <= 1'b1;
    end
    */

    ram_to_lcd #(
       /* .H_SYNC_W_D(40),
        .H_BACK_P_D(2),
        .H_ACTIVE_D(480),
        .V_SYNC_W_D(10),
        .V_BACK_P_D(2),
        .V_ACTIVE_D(272),
        .H_FRONT_P_D(2),
        .V_FRONT_P_D(2)*/
    ) u_ram_to_lcd (
        .clk_i(wEnClk_pulse),
        //.iEnable(1'b1),

        .ram_rd_addr_o(ram_rd_addr),
        .ram_rd_data_i(ram_rd_data),

        .LCD_hsync_o(LCD_hsync_o),
        .LCD_vsync_o(LCD_vsync_o),
        .LCD_R_o(LCD_R_o),
        .LCD_G_o(LCD_G_o),
        .LCD_B_o(LCD_B_o)
        /*
        .h_sync_w(h_sync_w),
        .h_back_p(h_back_p),
        .h_active(h_active),
        .h_front_p(h_front_p),

        .v_sync_w(v_sync_w),
        .v_back_p(v_back_p),
        .v_active(v_active),
        .v_front_p(v_front_p)
        */
    );

    // ï¿½ï¿½ ï¿½Ù½ï¿½: LCD ï¿½ï¿½ï¿½ï¿½ ï¿½É¿ï¿½ï¿½ï¿½ ï¿½ç°¢ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ Å¬ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½
    // ï¿½ï¿½ï¿½ï¿½ï¿½Í´ï¿½ wEnClkï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ ï¿½Øºï¿½ï¿½ï¿½ï¿½ï¿½ï¿???, LCDï¿½ï¿½ wLCD_Clk_sqï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
    assign lcd_clk = wEnClk; 

    assign TFT_BACKLIGHT = 1'b1;

    assign LCD_de_o = 1'b1;

endmodule