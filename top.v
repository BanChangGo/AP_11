`timescale 1ns / 1ps

module cnn_laplacian_tft_top #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272
)(
    input  wire        PL_CLK_100MHZ,
    input  wire        iRstn,
    input  wire [1:0]  iMode,  // 0:Bypass, 1:Sharp, 2:Edge, 3:AXI User Kernel

    // TFT LCD Interface
    output wire [4:0]  TFT_R_DATA,
    output wire [5:0]  TFT_G_DATA,
    output wire [4:0]  TFT_B_DATA,
    output wire        TFT_DCLK,     
    output wire        TFT_BACKLIGHT,
    output wire        TFT_DE,
    output wire        TFT_HSYNC,
    output wire        TFT_VSYNC,

    // Camera Interface

    input  wire            CAMERA_PCLK,
    input  wire  [ 7:0]    CAMERA_DATA,
    output wire            CAMERA_RESETn,
    input  wire            CAMERA_HSYNC,
    input  wire            CAMERA_VSYNC,
    output wire            CAMERA_PWDN,
    output wire            CAMERA_MCLK,

    // [추가] AXI Register Inputs (From S_AXI_LITE_REG_CNN)
    input wire signed [31:0]  i_Kernel_value_0,
    input wire signed [31:0]  i_Kernel_value_1,
    input wire signed [31:0]  i_Kernel_value_2,
    input wire signed [31:0]  i_Kernel_value_3,
    input wire signed [31:0]  i_Kernel_value_4,
    input wire signed [31:0]  i_Kernel_value_5,
    input wire signed [31:0]  i_Kernel_value_6,
    input wire signed [31:0]  i_Kernel_value_7,
    input wire signed [31:0]  i_Kernel_value_8
);
    wire    cam_wr_en_w;
    wire    [15:0]    cam_wr_data_w;
    wire    [16:0]    cam_wr_addr_w;
    
    // [중요] 외부 입력 iMode가 있으면 그것을 우선, 없으면 VIO 사용 (현재는 iMode 포트 사용)
    // 만약 VIO로 제어하고 싶으면 아래 wire [1:0] iMode = mode_w; 로 변경 필요
    // 현재 코드에서는 포트로 받은 iMode를 그대로 사용합니다.
    
    localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT; 

    reg [16:0] src_addr;
    reg        src_last;

    // -------------------------------------------------------------------------
    // 1) Clock Generation
    // -------------------------------------------------------------------------
    wire wEnClk;       // 6.25MHz Pixel Clock (Square Wave for LCD)

    clk_gen2 CLK_GEN_TFTLCD(
        .clk_i(PL_CLK_100MHZ),
        .iRstn(iRstn),      
        .count_i(16'd7),
        .clk_o(wEnClk)
    );

    clk_gen2    CLK_GEN_MAIN(
        .clk_i(PL_CLK_100MHZ),
        .count_i(16'h0001),
        .iRstn(iRstn),
        .clk_o(CAMERA_MCLK)
    ); // 25MHz for Camera XCLK

   

    // -------------------------------------------------------------------------
    // Pulse Generation (100MHz domain enable signal)
    // -------------------------------------------------------------------------
    reg [3:0] cnt_6p25;   
    reg       wEnClk_pulse;

    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            cnt_6p25      <= 4'd0;
            wEnClk_pulse  <= 1'b0;
        end else begin
            if (cnt_6p25 == 4'd15) begin
                cnt_6p25     <= 4'd0;
                wEnClk_pulse <= 1'b1;  
            end else begin
                cnt_6p25     <= cnt_6p25 + 1'b1;
                wEnClk_pulse <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // [수정] FSM Controller Instance (Hybrid Mode Support)
    // -------------------------------------------------------------------------
    wire w_core_start_trigger; 
    wire w_is_active;          
    
    // [추가] 안전하게 동기화된 9개의 커널 값 (Flow Controller -> Conv)
    wire signed [7:0] w_safe_k0, w_safe_k1, w_safe_k2;
    wire signed [7:0] w_safe_k3, w_safe_k4, w_safe_k5;
    wire signed [7:0] w_safe_k6, w_safe_k7, w_safe_k8;
    
    CNN_Flow_Controller u_flow_ctrl (
        .clk         (PL_CLK_100MHZ),
        .rst_n       (iRstn),
        
        // Control Inputs
        .i_imode     (iMode),      // 0:Bypass, 1:Sharp, 2:Edge, 3:AXI User
        .i_frame_done(src_last),   
        
        // AXI Kernel Inputs (32-bit signed)
        .i_axi_k0(i_Kernel_value_0), .i_axi_k1(i_Kernel_value_1), .i_axi_k2(i_Kernel_value_2),
        .i_axi_k3(i_Kernel_value_3), .i_axi_k4(i_Kernel_value_4), .i_axi_k5(i_Kernel_value_5),
        .i_axi_k6(i_Kernel_value_6), .i_axi_k7(i_Kernel_value_7), .i_axi_k8(i_Kernel_value_8),

        // Control Outputs
        .o_core_start(w_core_start_trigger),
        .o_is_active (w_is_active), 
        
        // Safe Kernel Outputs (8-bit signed)
        .o_safe_k0(w_safe_k0), .o_safe_k1(w_safe_k1), .o_safe_k2(w_safe_k2),
        .o_safe_k3(w_safe_k3), .o_safe_k4(w_safe_k4), .o_safe_k5(w_safe_k5),
        .o_safe_k6(w_safe_k6), .o_safe_k7(w_safe_k7), .o_safe_k8(w_safe_k8)
    );

    // -------------------------------------------------------------------------
    // Processing Status & Start Control
    // -------------------------------------------------------------------------
    wire is_processing_active = w_is_active;

    reg start_processing;

    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            start_processing <= 1'b0;
        end else begin
            // 카메라 VSYNC(프레임 시작 신호)가 한번이라도 들어오면 시작 플래그를 1로 고정
            if (cam_wr_addr_w > 0) 
                start_processing <= 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // 2) pixel_addr_ctrl
    // -------------------------------------------------------------------------
    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            src_addr <= 17'd0;
            src_last <= 1'b0;
        end 
        else if (wEnClk_pulse && start_processing && is_processing_active) begin 
            if (src_addr == TOTAL_PIX - 1) begin
                src_addr <= 17'd0;
                src_last <= 1'b1; 
            end else begin
                src_addr <= src_addr + 1'b1;
                src_last <= 1'b0;
            end
        end else begin
            src_last <= 1'b0;
            if (!is_processing_active) src_addr <= 17'd0; 
        end
    end

    // -------------------------------------------------------------------------
    // 3) InBuf (Double Buffering)
    // -------------------------------------------------------------------------
    wire db_wr_sel; 
    wire db_rd_sel; 
    
    buffer_controller u_buf_ctrl (
        .clk        (PL_CLK_100MHZ),
        .rstn       (iRstn),
        .i_cam_vsync(CAMERA_VSYNC),        
        .i_read_done(src_last), 
        .o_wr_sel   (db_wr_sel),
        .o_rd_sel   (db_rd_sel)
    );

    // Camera Logic
    camera_to_ram CAMEARA_TO_RAM(
        .clk_i(CAMERA_PCLK),
        .sw_i(1'b1),
        .cam_vsync_i(CAMERA_VSYNC),
        .cam_hsync_i(CAMERA_HSYNC),
        .cam_data_i(CAMERA_DATA),
        .ram_wr_en_o(cam_wr_en_w),
        .ram_wr_addr_o(cam_wr_addr_w),
        .ram_wr_data_o(cam_wr_data_w)
    );

    wire we_0, we_1;
    assign we_0 = (db_wr_sel == 1'b0) ? cam_wr_en_w : 1'b0;
    assign we_1 = (db_wr_sel == 1'b1) ? cam_wr_en_w : 1'b0;

    wire [15:0] src_pixel_0;
    wire [15:0] src_pixel_1;
    wire [15:0] src_pixel_raw; 
    
    assign src_pixel_raw = (db_rd_sel == 1'b0) ? src_pixel_0 : src_pixel_1;

    InBuf #(
        .IMG_WIDTH (IMG_WIDTH), .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (16), .ADDR_WIDTH (17) 
    ) u_inbuf_0 (
        .iClk_wr   (CAMERA_PCLK),
        .iWe_wr    (we_0),
        .iAddr_wr  (cam_wr_addr_w),
        .iData_wr  (cam_wr_data_w), 
        .iClk_rd   (PL_CLK_100MHZ),
        .iRstn     (iRstn),
        .iEn_rd    (wEnClk),
        .iAddr_rd  (src_addr),
        .oPixel    (src_pixel_0)    
    );

    InBuf #(
        .IMG_WIDTH (IMG_WIDTH), .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (16), .ADDR_WIDTH (17) 
    ) u_inbuf_1 (
        .iClk_wr   (CAMERA_PCLK),
        .iWe_wr    (we_1),
        .iAddr_wr  (cam_wr_addr_w),
        .iData_wr  (cam_wr_data_w), 
        .iClk_rd   (PL_CLK_100MHZ),
        .iRstn     (iRstn),
        .iEn_rd    (wEnClk),
        .iAddr_rd  (src_addr),
        .oPixel    (src_pixel_1)    
    );

    // 16-bit RGB565 to 24-bit RGB888 Expansion
    wire [23:0] src_pixel_expanded;
    assign src_pixel_expanded = {
        src_pixel_raw[15:11], 3'b000, // Red
        src_pixel_raw[10:5],  2'b00,  // Green
        src_pixel_raw[4:0],   3'b000  // Blue
    };

    // -------------------------------------------------------------------------
    // 4) window3x3 
    // -------------------------------------------------------------------------
    wire [215:0] wWindowData;
    wire wWinValid;
    
    wire w_ram_read_active;
    assign w_ram_read_active = wEnClk_pulse && start_processing && is_processing_active;

    reg [8:0] r_en_delay_chain; 
    wire      w_window_en_delayed_9clk;
    
    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            r_en_delay_chain <= 9'd0;
        end else begin
            r_en_delay_chain <= {r_en_delay_chain[7:0], w_ram_read_active};
        end
    end

    assign w_window_en_delayed_9clk = r_en_delay_chain[8];

    window3x3 #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DATA_WIDTH(24)
    ) u_window3x3 (
        .iClk(PL_CLK_100MHZ), 
        .iRstn(iRstn), 
        .iEn(w_window_en_delayed_9clk), 
        .iPixel(src_pixel_expanded),
        .oWindow (wWindowData),
        .oValid(wWinValid)
    );

    // -------------------------------------------------------------------------
    // 5) conv3x3_programmable_rgb [수정됨]
    // -------------------------------------------------------------------------
    wire [23:0] conv_pixel;
    wire conv_valid, conv_last;

    // 기존 conv3x3 대신 programmable 버전을 사용
    conv3x3_programmable_rgb #(.ACC_WIDTH(19)) u_conv3x3 (
        .iClk(PL_CLK_100MHZ), .iRstn(iRstn), .iEn(wEnClk),
        .iValid(wWinValid), .iLast(src_last),
        .iWindow (wWindowData),
        
        // [연결] Flow Controller가 주는 안전한 커널 값들
        .iK00(w_safe_k0), .iK01(w_safe_k1), .iK02(w_safe_k2),
        .iK10(w_safe_k3), .iK11(w_safe_k4), .iK12(w_safe_k5),
        .iK20(w_safe_k6), .iK21(w_safe_k7), .iK22(w_safe_k8),
        
        .oPixel(conv_pixel), .oValid(conv_valid), .oLast(conv_last)
    );

    // -------------------------------------------------------------------------
    // 6) pixel_conv (24bit -> 16bit)
    // -------------------------------------------------------------------------
    wire [15:0] pix565;
    wire pix_valid, pix_last;

    pixel_conv_rgb888_to_rgb565_round u_pixconv (
        .iClk(PL_CLK_100MHZ), .iRstn(iRstn), .iEn(wEnClk),
        .iValid(conv_valid), .iLast(conv_last), .iPixel(conv_pixel),
        .oPixel565(pix565), .oValid(pix_valid), .oLast(pix_last)
    );

    // -------------------------------------------------------------------------
    // 7) OutBuf
    // -------------------------------------------------------------------------
    wire [16:0] ram_rd_addr;
    wire [15:0] ram_rd_data;
    wire        frame_done;

    OutBuf #(
        .IMG_WIDTH  (IMG_WIDTH), .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (16), .ADDR_WIDTH (17)
    ) u_outbuf (
        // Write side
        .iClk_wr   (PL_CLK_100MHZ),
        .iRstn     (iRstn),
        .iEn_wr    (wEnClk),
        .iValid_wr (pix_valid),
        .iLast_wr  (pix_last),
        .iPixel_wr (pix565),
        .oFrameDone(frame_done),

        // Read side
        .iClk_rd   (wEnClk), 
        .iAddr_rd  (ram_rd_addr),
        .oData_rd  (ram_rd_data)
    );

    // -------------------------------------------------------------------------
    // 8) ram_to_lcd
    // -------------------------------------------------------------------------
    ram_to_lcd u_ram_to_lcd (
        .clk_i(wEnClk_pulse),
        .ram_rd_addr_o(ram_rd_addr),
        .ram_rd_data_i(ram_rd_data),
        .LCD_hsync_o(TFT_HSYNC),
        .LCD_vsync_o(TFT_VSYNC),
        .LCD_R_o(TFT_R_DATA),
        .LCD_G_o(TFT_G_DATA),
        .LCD_B_o(TFT_B_DATA)
    );

    assign TFT_DCLK = wEnClk; 
    assign TFT_BACKLIGHT = 1'b1;
    assign TFT_DE = 1'b1;

endmodule