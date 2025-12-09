`timescale 1ns / 1ps

module cnn_laplacian_tft_top #(
    parameter IMG_WIDTH  = 480,
    parameter IMG_HEIGHT = 272
)(
    input  wire        PL_CLK_100MHZ,
    input  wire        iRstn,


    output wire [4:0]  TFT_R_DATA,
    output wire [5:0]  TFT_G_DATA,
    output wire [4:0]  TFT_B_DATA,
    output wire        TFT_DCLK,     // LCD�� ������ ������ Ŭ�� (Square Wave)
    output wire        TFT_BACKLIGHT,
    output wire        TFT_DE,

    output wire        TFT_HSYNC,
    output wire        TFT_VSYNC,


    inout  wire            CAMERA_SCCB_SCL,
    inout  wire            CAMERA_SCCB_SDA,
    input  wire            CAMERA_PCLK,
    input  wire  [ 7:0]    CAMERA_DATA,

    output wire            CAMERA_RESETn,

    input  wire            CAMERA_HSYNC,
    input  wire            CAMERA_VSYNC,

    output wire            CAMERA_PWDN,
    output wire            CAMERA_MCLK
);
    // VIO ?��?�� ?���??? ?���????��?�� ?��?��

    wire [15:0] h_sync_w;
    wire [15:0] h_back_p;
    wire [15:0] h_front_p;
    wire [15:0] h_active;
    wire [15:0] v_sync_w;
    wire [15:0] v_back_p;
    wire [15:0] v_active;
    wire [15:0] v_front_p;

    wire    cam_wr_en_w;

    wire    [23:0]    cam_wr_data_w;
    wire    [16:0]    cam_wr_addr_w;


    vio_0 u_vio(
        .clk(PL_CLK_100MHZ),
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
    wire wEnClk;       // ������ (Pulse) - �ý��� ��ü ����ȭ Ŭ��

    clk_gen2 CLK_GEN_TFTLCD(
        .clk_i(PL_CLK_100MHZ),
        .iRstn(iRstn),      // <- ����
        .count_i(16'd7),
        .clk_o(wEnClk)
    );
    clk_gen2    CLK_GEN_MAIN(
        .clk_i(PL_CLK_100MHZ),
        .count_i(16'h0001),
        .iRstn(iRstn),
        .clk_o(CAMERA_MCLK)
    );//25MHz

    //// CAM PL
    wire                        clk_campower        ;
    
    clk_gen2    I2C_RESET(
        .clk_i                      (CAMERA_MCLK       ),
        .count_i                    (16'h0064       ),
        .iRstn(iRstn),
        .clk_o                      (clk_campower   )
    );
    
    cam_i2c CAM_SETUP_SCCB(
        .clk_i                      (clk_campower   ),
        .sw                         (1'b1           ),
        .cam_rst_no                 (CAMERA_RESETn     ),
        .cam_pwdn                   (CAMERA_PWDN       ),
        .cam_scl                    (CAMERA_SCCB_SCL   ),
        .cam_sda                    (CAMERA_SCCB_SDA   )      
    );

    // 100MHz -> 6.25MHz enable pulse ?��?��
    reg [3:0] cnt_6p25;   // 16분주?�� 4bit 카운?��
    reg       wEnClk_pulse;

    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            cnt_6p25      <= 4'd0;
            wEnClk_pulse  <= 1'b0;
        end else begin
            if (cnt_6p25 == 4'd15) begin
                cnt_6p25     <= 4'd0;
                wEnClk_pulse <= 1'b1;  // 1?��?�� ?��?�� 발생
            end else begin
                cnt_6p25     <= cnt_6p25 + 1'b1;
                wEnClk_pulse <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // [수정] Processing Start Control (VSYNC 감지)
    // -------------------------------------------------------------------------
    // 리셋 직후 바로 읽지 않고, 카메라가 첫 프레임(VSYNC)을 시작하면 그때부터 읽기를 허용합니다.
    reg start_processing;
    // 이후 FSM 으로  수정할 수 있는 신호 
    
    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            start_processing <= 1'b0;
        end else begin
            // 카메라 VSYNC(프레임 시작 신호)가 한번이라도 들어오면 시작 플래그를 1로 고정
            if (cam_wr_addr_w) 
                start_processing <= 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // 2) pixel_addr_ctrl (수정됨)
    // -------------------------------------------------------------------------
    localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;

    reg [16:0] src_addr;
    reg        src_last;

    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn) begin
            src_addr <= 17'd0;
            src_last <= 1'b0;
        end else if (wEnClk_pulse && start_processing) begin // [수정] start_processing 조건 추가
            if (src_addr == TOTAL_PIX - 1) begin
                src_addr <= 17'd0;
                src_last <= 1'b1;
            end else begin
                src_addr <= src_addr + 1'b1;
                src_last <= 1'b0;
            end
        end else begin
            src_last <= 1'b0;
            // start_processing이 0일 때는 src_addr이 0에서 대기
        end
    end
    // -------------------------------------------------------------------------
    // 3) InBuf
    // -------------------------------------------------------------------------
    wire [23:0] src_pixel;

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


    InBuf #(
        .IMG_WIDTH  (IMG_WIDTH), .IMG_HEIGHT (IMG_HEIGHT),
        .DATA_WIDTH (24), .ADDR_WIDTH (17)
    ) u_inbuf (
        // Port A: Write Side (나중에 CAM 연결)
        .iClk_wr   (CAMERA_PCLK),
        .iWe_wr    (cam_wr_en_w),
        .iAddr_wr  (cam_wr_addr_w),
        .iData_wr  (cam_wr_data_w),

        // Port B: Read Side (CNN 연결 - 기존 로직 유지)
        .iClk_rd   (PL_CLK_100MHZ),
        .iRstn     (iRstn),
        .iEn_rd    (wEnClk),     // wEnClk (Clock Divider 출력)
        .iAddr_rd  (src_addr),
        .oPixel    (src_pixel)
    );

    // -------------------------------------------------------------------------
    // 4) window3x3
    // -------------------------------------------------------------------------
    wire [215:0] wWindowData;
    wire wWinValid;

    window3x3 #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DATA_WIDTH(24)
    ) u_window3x3 (
        .iClk(PL_CLK_100MHZ), .iRstn(iRstn), .iEn(wEnClk), .iPixel(src_pixel),
        .oWindow (wWindowData),
        .oValid(wWinValid)
    );

    // -------------------------------------------------------------------------
    // 5) conv3x3
    // -------------------------------------------------------------------------
    wire [23:0] conv_pixel;
    wire conv_valid, conv_last;

    conv3x3_laplacian_rgb #(.ACC_WIDTH(19)) u_conv3x3 (
        .iClk(PL_CLK_100MHZ), .iRstn(iRstn), .iEn(wEnClk),
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
        .iClk(PL_CLK_100MHZ), .iRstn(iRstn), .iEn(wEnClk),
        .iValid(conv_valid), .iLast(conv_last), .iPixel(conv_pixel),
        .oPixel565(pix565), .oValid(pix_valid), .oLast(pix_last)
    );

    // -------------------------------------------------------------------------
    // 7) OutBuf : Clock Domain ���� (�߿�!)
    //    - Write: wEnClk
    //    - Read : wEnClk (�� wLCD_Clk_sq ���??? wEnClk ���???)
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
        .iClk_rd   (wEnClk), // �� ��ũ �и� �ذ�: ���� Enable Ŭ�� ���???
        .iAddr_rd  (ram_rd_addr),
        .oData_rd  (ram_rd_data)
    );
    


    // -------------------------------------------------------------------------
    // 8) ram_to_lcd : ������ ������ wEnClk, ������ Ŭ�� �����??? wLCD_Clk_sq
    // -------------------------------------------------------------------------
    
    /*reg lcd_enable;

    always @(posedge PL_CLK_100MHZ or negedge iRstn) begin
        if (!iRstn)
            lcd_enable <= 1'b0;
        else if (frame_done)
            lcd_enable <= 1'b1;
    end
    */

    ram_to_lcd u_ram_to_lcd (
        .clk_i(wEnClk_pulse),
        //.iEnable(1'b1),

        .ram_rd_addr_o(ram_rd_addr),
        .ram_rd_data_i(ram_rd_data),

        .LCD_hsync_o(TFT_HSYNC),
        .LCD_vsync_o(TFT_VSYNC),
        .LCD_R_o(TFT_R_DATA),
        .LCD_G_o(TFT_G_DATA),
        .LCD_B_o(TFT_B_DATA)

         
    );

    // �� �ٽ�: LCD ���� �ɿ��� �簢�� ���� Ŭ���� ���� ����
    // �����ʹ� wEnClk�� ���� �غ������???, LCD�� wLCD_Clk_sq�� ���� ������
    assign TFT_DCLK = wEnClk; 

    assign TFT_BACKLIGHT = 1'b1;

    assign TFT_DE = 1'b1;

endmodule