`timescale 1ns / 1ps

module cnn_laplacian_tft_top_tb;

    // Parameters
    parameter IMG_WIDTH  = 480;
    parameter IMG_HEIGHT = 272;
    
    // Testbench Signals
    reg         iClk_100;         // 100MHz clock
    reg         iRstn;            // Active-low reset
    wire        lcd_clk;          // LCD clock
    wire        LCD_hsync_o;      // LCD hsync signal
    wire        LCD_vsync_o;      // LCD vsync signal
    wire        LCD_de_o;         // LCD data enable signal
    wire [4:0]  LCD_R_o;          // LCD Red data
    wire [5:0]  LCD_G_o;          // LCD Green data
    wire [4:0]  LCD_B_o;          // LCD Blue data
    wire        TFT_BACKLIGHT;    // TFT Backlight signal

    // Clock generation
    always begin
        #5 iClk_100 = ~iClk_100;  // 100MHz clock
    end

    // Instantiate the cnn_laplacian_tft_top module
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

    // Initial block to apply test vectors
    initial begin
        // Initialize signals
        iClk_100 = 0;
        iRstn = 0;

        // Apply reset
        #20 iRstn = 1;

        // Add test stimulus here, such as simulating the InBuf's data
        // For example, we can load the COE file data directly to InBuf if possible

        // Monitor outputs
        $monitor("At time %t, lcd_clk = %b, LCD_R_o = %h, LCD_G_o = %h, LCD_B_o = %h",
                 $time, lcd_clk, LCD_R_o, LCD_G_o, LCD_B_o);

        // Test sequence: Provide inputs and monitor outputs
        // A typical test will involve checking the LCD outputs after a few cycles.

        #1000000000; // Simulate for 100000ns (100ms) for the image processing to complete

        // Finish simulation
        $finish;
    end

endmodule
