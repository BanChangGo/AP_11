`timescale 1ns / 1ps

module cnn_laplacian_tft_top_tb;

    // -----------------------------------------------------------
    // 1. Parameters & Signals
    // -----------------------------------------------------------
    parameter IMG_WIDTH  = 480;
    parameter IMG_HEIGHT = 272;

    reg         PL_CLK_100MHZ;
    reg         iRstn;

    reg         CAMERA_PCLK;
    reg         CAMERA_HSYNC;
    reg         CAMERA_VSYNC;
    reg [7:0]   CAMERA_DATA;
    
    wire        CAMERA_SCCB_SCL;
    wire        CAMERA_SCCB_SDA;
    wire        CAMERA_RESETn;
    wire        CAMERA_PWDN;
    wire        CAMERA_MCLK;

    wire [4:0]  TFT_R_DATA;
    wire [5:0]  TFT_G_DATA;
    wire [4:0]  TFT_B_DATA;
    wire        TFT_DCLK;
    wire        TFT_BACKLIGHT;
    wire        TFT_DE;
    wire        TFT_HSYNC;
    wire        TFT_VSYNC;

    assign (weak1, weak0) CAMERA_SCCB_SCL = 1'b1;
    assign (weak1, weak0) CAMERA_SCCB_SDA = 1'b1;

    // -----------------------------------------------------------
    // 2. DUT Instance
    // -----------------------------------------------------------
    cnn_laplacian_tft_top #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) uut (
        .PL_CLK_100MHZ   (PL_CLK_100MHZ),
        .iRstn           (iRstn),
        .TFT_R_DATA      (TFT_R_DATA),
        .TFT_G_DATA      (TFT_G_DATA),
        .TFT_B_DATA      (TFT_B_DATA),
        .TFT_DCLK        (TFT_DCLK),
        .TFT_BACKLIGHT   (TFT_BACKLIGHT),
        .TFT_DE          (TFT_DE),
        .TFT_HSYNC       (TFT_HSYNC),
        .TFT_VSYNC       (TFT_VSYNC),
        .CAMERA_SCCB_SCL (CAMERA_SCCB_SCL),
        .CAMERA_SCCB_SDA (CAMERA_SCCB_SDA),
        .CAMERA_PCLK     (CAMERA_PCLK),
        .CAMERA_DATA     (CAMERA_DATA),
        .CAMERA_RESETn   (CAMERA_RESETn),
        .CAMERA_HSYNC    (CAMERA_HSYNC),
        .CAMERA_VSYNC    (CAMERA_VSYNC),
        .CAMERA_PWDN     (CAMERA_PWDN),
        .CAMERA_MCLK     (CAMERA_MCLK)
    );

    // -----------------------------------------------------------
    // 3. Clock Generation
    // -----------------------------------------------------------
    initial PL_CLK_100MHZ = 0;
    always #5 PL_CLK_100MHZ = ~PL_CLK_100MHZ;

    initial CAMERA_PCLK = 0;
    always #20 CAMERA_PCLK = ~CAMERA_PCLK; 

    // -----------------------------------------------------------
    // 4. VIO Signal Force (Simulation Only)
    // -----------------------------------------------------------
    initial begin
        force uut.h_sync_w = 16'd0;
        force uut.h_back_p = 16'd0;
        force uut.h_active = 16'd0;
        force uut.h_front_p= 16'd0;
        force uut.v_sync_w = 16'd0;
        force uut.v_back_p = 16'd0;
        force uut.v_active = 16'd0;
        force uut.v_front_p= 16'd0;
    end

    // -----------------------------------------------------------
    // 5. Test Stimulus (FAST MODE)
    // -----------------------------------------------------------
    integer h, v;
    
    // [수정] Active 영역(480x272)은 건드리면 안 되지만,
    // Sync나 Back Porch는 시뮬레이션에서 '기다리는 시간'일 뿐이므로 최소화합니다.
    
    localparam CAM_H_ACT   = IMG_WIDTH;  // 480
    localparam CAM_V_ACT   = IMG_HEIGHT; // 272

    initial begin
        // 초기화
        iRstn = 0;
        CAMERA_VSYNC = 0;
        CAMERA_HSYNC = 0;
        CAMERA_DATA  = 0;

        // Reset Release (빠르게)
        #100 iRstn = 1;
        #200; // 조금만 대기

        // -------------------------------------------------------
        // Camera Frame Loop
        // -------------------------------------------------------
        repeat (2) begin // 2 프레임만 확인
            
            // 1. VSYNC Start 
            // [수정] 실제 스펙(수천 클럭) 대신 10클럭만 유지해도 FPGA는 인식함
            CAMERA_VSYNC = 1;
            repeat (10) @(posedge CAMERA_PCLK); 
            CAMERA_VSYNC = 0;

            // 2. V Back Porch (Blanking)
            // [수정] 10클럭만 대기 (바로 데이터 쏘기 위해)
            repeat (10) @(posedge CAMERA_PCLK);

            // 3. Active Lines
            for (v = 0; v < CAM_V_ACT; v = v + 1) begin
                
                // HSYNC (Active High)
                // [수정] 라인 시작 알림도 짧게
                CAMERA_HSYNC = 1;
                repeat (5) @(posedge CAMERA_PCLK);
                CAMERA_HSYNC = 0;

                // H Back Porch
                // [수정] 짧게 대기
                repeat (5) @(posedge CAMERA_PCLK);

                // ** Active Pixel Data Sending **
                // (RGB565 2-Cycle Mode)
                for (h = 0; h < CAM_H_ACT; h = h + 1) begin
                    
                    // [Cycle 1] High Byte
                    CAMERA_DATA = 8'hF8; // Red Pattern
                    @(posedge CAMERA_PCLK);
                    
                    // [Cycle 2] Low Byte
                    CAMERA_DATA = 8'h1F; // Blue Pattern
                    @(posedge CAMERA_PCLK);
                end

                // Data Invalid zone
                CAMERA_DATA = 8'h00;

                // H Front Porch (짧게)
                repeat (5) @(posedge CAMERA_PCLK);
            end

            // 4. V Front Porch (짧게)
            repeat (10) @(posedge CAMERA_PCLK);

            $display("Frame Sent at time %t", $time);
        end

        #1000;
        $finish;
    end

endmodule