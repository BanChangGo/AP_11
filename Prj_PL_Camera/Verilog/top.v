`timescale 1ns / 10ps

module top(
input  wire                 clk_in              ,
inout  wire                 CAM_SCCB_SCL        ,
inout  wire                 CAM_SCCB_SDA        ,
output wire  [ 4:0]         TFT_RGB_B           ,
output wire  [ 5:0]         TFT_RGB_G           ,
output wire  [ 4:0]         TFT_RGB_R           ,
output wire                 TFT_DCLK            ,
output wire                 TFT_BACKLIGHT       ,
output wire                 TFT_DE              ,
output wire                 TFT_HSYNC           ,
output wire                 TFT_VSYNC           ,
input  wire                 CAM_PCLK            ,
input  wire  [ 7:0]         CAM_DATA            ,
output wire                 CAM_RESETn          ,
input  wire                 CAM_HSYNC           ,
input  wire                 CAM_VSYNC           ,
output wire                 CAM_PWDN            ,
output wire                 CAM_MCLK        
    );

wire                        clk_w               ;
wire                        clk_campower        ;

wire            cam_wr_en_w                     ;
wire    [15:0]  cam_wr_data_w                   ;
wire    [16:0]  cam_wr_addr_w                   ;

wire    [15:0]  lcd_rd_data_w                   ;
wire    [16:0]  lcd_rd_addr_w                   ;



clk_gen2    CLK_GEN_MAIN(
    .clk_i                      (clk_in         ),
    .count_i                    (16'h0001       ),
    .clk_o                      (CAM_MCLK       )
);//25MHz


clk_gen2    I2C_RESET(
    .clk_i                      (CAM_MCLK       ),
    .count_i                    (16'h0064       ),
    .clk_o                      (clk_campower   )
    );

clk_gen2    CLK_GEN_TFTLCD(
    .clk_i                      (CAM_MCLK       ),
    .count_i                    (16'h0001       ),
    .clk_o                      (TFT_DCLK       )
);


          

cam_i2c CAM_SETUP_SCCB(
    .clk_i                      (clk_campower   ),
    .sw                         (1'b1           ),
    .cam_rst_no                 (CAM_RESETn     ),
    .cam_pwdn                   (CAM_PWDN       ),
    .cam_scl                    (CAM_SCCB_SCL   ),
    .cam_sda                    (CAM_SCCB_SDA   )      
    );

     
 

camera_to_ram CAMEARA_TO_RAM(
    .clk_i                      (CAM_PCLK       ),
    .sw_i                       (1'b1           ),
    .cam_vsync_i                (CAM_VSYNC      ),
    .cam_hsync_i                (CAM_HSYNC      ),
    .cam_data_i                 (CAM_DATA       ),
    .ram_wr_en_o                (cam_wr_en_w    ),
    .ram_wr_addr_o              (cam_wr_addr_w  ),
    .ram_wr_data_o              (cam_wr_data_w  )
);

RAM_CAMERA  RAM_CAMERA(
    .clka                       (CAM_PCLK       ),
    .ena                        (1'b1           ),
    .wea                        (cam_wr_en_w    ),
    .addra                      (cam_wr_addr_w  ),
    .dina                       (cam_wr_data_w  ),
    
    .clkb                       (TFT_DCLK       ),
    .enb                        (1'b1           ),
    .addrb                      (lcd_rd_addr_w  ),
    .doutb                      (lcd_rd_data_w  )
);

ram_to_lcd  RAM_TO_LCD(
    .clk_i                      (TFT_DCLK       ),
    .ram_rd_addr_o              (lcd_rd_addr_w  ),
    .ram_rd_data_i              (lcd_rd_data_w  ),
    .LCD_hsync_o                (TFT_HSYNC      ),
    .LCD_vsync_o                (TFT_VSYNC      ),
    .LCD_R_o                    (TFT_RGB_R      ),
    .LCD_G_o                    (TFT_RGB_G      ),
    .LCD_B_o                    (TFT_RGB_B      )
);


assign      TFT_BACKLIGHT   =   1'b1            ;
assign      TFT_DE          =   1'b1            ;
    
    
    
endmodule
