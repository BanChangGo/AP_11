`timescale 1ns / 1ps

module cnn_laplacian_tft_top_tb;

    // Parameters
    parameter IMG_WIDTH  = 480;
    parameter IMG_HEIGHT = 272;
    
    // Testbench Signals
    reg         iClk_100;         // 100MHz clock
    reg         iRstn;            // Active-low reset
    wire        lcd_clk;
    wire        LCD_hsync_o;
    wire        LCD_vsync_o;
    wire        LCD_de_o;
    wire [4:0]  LCD_R_o;
    wire [5:0]  LCD_G_o;
    wire [4:0]  LCD_B_o;
    wire        TFT_BACKLIGHT;

    // Timing registers (drive into uut)
    reg [15:0] h_sync_w;
    reg [15:0] h_back_p;
    reg [15:0] h_active;
    reg [15:0] v_sync_w;
    reg [15:0] v_back_p;
    reg [15:0] v_active;
    reg [15:0] v_front_p;
    reg [15:0] h_front_p;

    // -------------------------
    // Clock generation (100MHz)
    // -------------------------
    initial iClk_100 = 0;
    always #5 iClk_100 = ~iClk_100;  // Toggle every 5ns → 100MHz


    // -------------------------
    // DUT Instance
    // -------------------------
    cnn_laplacian_tft_top #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) uut (
        .iClk_100(iClk_100),
        .iRstn(iRstn),
        .lcd_clk(lcd_clk),
        .LCD_hsync_o(LCD_hsync_o),
        .LCD_vsync_o(LCD_vsync_o),
        .LCD_de_o(LCD_de_o),
        .LCD_R_o(LCD_R_o),
        .LCD_G_o(LCD_G_o),
        .LCD_B_o(LCD_B_o),
        .TFT_BACKLIGHT(TFT_BACKLIGHT)
    );


    // -------------------------
    // Testbench Initial Block
    // -------------------------
    initial begin
        // Initialize reset
        iRstn = 0;

        // Setup TFT timing (예: 480x272 기본값)
        h_sync_w = 5;      // 사용자 설정 가능
        h_back_p = 40;
        h_active = IMG_WIDTH;
        

        v_sync_w = 10;
        v_back_p = 8;
        v_active = IMG_HEIGHT;
        h_front_p = 2;
        v_front_p = 2;

        // Release reset
        #20 iRstn = 1;

        // Monitor
        $monitor("t=%t | lcd_clk=%b | R=%h G=%h B=%h",
            $time, lcd_clk, LCD_R_o, LCD_G_o, LCD_B_o);

        // Simulation time
        #1_000_000_000;   // 1 second

        $finish;
    end

endmodule
