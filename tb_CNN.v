`timescale 1ns / 1ps

module cnn_laplacian_tft_top_tb;

    // -----------------------------------------------------------
    // 1. Parameters & Signals
    // -----------------------------------------------------------
    parameter IMG_WIDTH  = 480;
    parameter IMG_HEIGHT = 272;

    // FPGA System Inputs
    reg         PL_CLK_100MHZ;
    reg         iRstn;

    // Camera Interface (Input to FPGA)
    reg         CAMERA_PCLK;
    reg         CAMERA_HSYNC;
    reg         CAMERA_VSYNC;
    reg [7:0]   CAMERA_DATA;
    
    // Inout Ports (I2C)
    wire        CAMERA_SCCB_SCL;
    wire        CAMERA_SCCB_SDA;

    // Camera Control Outputs (From FPGA)
    wire        CAMERA_RESETn;
    wire        CAMERA_PWDN;
    wire        CAMERA_MCLK;

    // TFT LCD Outputs (From FPGA)
    wire [4:0]  TFT_R_DATA;
    wire [5:0]  TFT_G_DATA;
    wire [4:0]  TFT_B_DATA;
    wire        TFT_DCLK;
    wire        TFT_BACKLIGHT;
    wire        TFT_DE;
    wire        TFT_HSYNC;
    wire        TFT_VSYNC;

    // SCCB Pull-ups (I2C Simulation)
    assign (weak1, weak0) CAMERA_SCCB_SCL = 1'b1;
    assign (weak1, weak0) CAMERA_SCCB_SDA = 1'b1;

    // -----------------------------------------------------------
    // 2. DUT Instance (Device Under Test)
    // -----------------------------------------------------------
    cnn_laplacian_tft_top #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) uut (
        .PL_CLK_100MHZ   (PL_CLK_100MHZ),
        .iRstn           (iRstn),

        // TFT LCD Interface
        .TFT_R_DATA      (TFT_R_DATA),
        .TFT_G_DATA      (TFT_G_DATA),
        .TFT_B_DATA      (TFT_B_DATA),
        .TFT_DCLK        (TFT_DCLK),
        .TFT_BACKLIGHT   (TFT_BACKLIGHT),
        .TFT_DE          (TFT_DE),
        .TFT_HSYNC       (TFT_HSYNC),
        .TFT_VSYNC       (TFT_VSYNC),

        // Camera Interface
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
    // FPGA System Clock: 100MHz (Period 10ns)
    initial PL_CLK_100MHZ = 0;
    always #5 PL_CLK_100MHZ = ~PL_CLK_100MHZ;

    // Camera Pixel Clock: 24MHz ~ 25MHz (Period ~40ns) - 모사
    // PCLK는 FPGA가 주는게 아니라 카메라가 주는 것(Master Mode 기준)
    initial CAMERA_PCLK = 0;
    always #20 CAMERA_PCLK = ~CAMERA_PCLK; 

    // -----------------------------------------------------------
    // 4. VIO Signal Force (Simulation Only)
    // -----------------------------------------------------------
    initial begin
        // VIO가 시뮬레이션에서 'Z'로 뜨는 것을 방지
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
    // 5. Test Stimulus (Camera Data Generation)
    // -----------------------------------------------------------
    integer h, v;
    
    // Camera Timing Parameters (Simulation용)
    localparam CAM_H_SYNC  = 10;
    localparam CAM_H_BACK  = 10;
    localparam CAM_H_ACT   = IMG_WIDTH;  // 480
    localparam CAM_H_FRONT = 10;
    localparam CAM_H_TOTAL = CAM_H_SYNC + CAM_H_BACK + CAM_H_ACT + CAM_H_FRONT;

    localparam CAM_V_SYNC  = 2;
    localparam CAM_V_BACK  = 2;
    localparam CAM_V_ACT   = IMG_HEIGHT; // 272
    localparam CAM_V_FRONT = 2;
    // localparam CAM_V_TOTAL = CAM_V_SYNC + CAM_V_BACK + CAM_V_ACT + CAM_V_FRONT;

    initial begin
        // 초기화
        iRstn = 0;
        CAMERA_VSYNC = 0;
        CAMERA_HSYNC = 0;
        CAMERA_DATA  = 0;

        // Reset Release
        #100 iRstn = 1;
        #1000;

        // -------------------------------------------------------
        // Camera Frame Loop
        // -------------------------------------------------------
        repeat (3) begin // 3 프레임 전송 시뮬레이션
            
            // 1. VSYNC Start (Active High)
            CAMERA_VSYNC = 1;
            repeat (CAM_V_SYNC * CAM_H_TOTAL) @(posedge CAMERA_PCLK); 
            CAMERA_VSYNC = 0;

            // 2. V Back Porch
            repeat (CAM_V_BACK * CAM_H_TOTAL) @(posedge CAMERA_PCLK);

            // 3. Active Lines
            for (v = 0; v < CAM_V_ACT; v = v + 1) begin
                
                // HSYNC (Active High)
                CAMERA_HSYNC = 1;
                repeat (CAM_H_SYNC) @(posedge CAMERA_PCLK);
                CAMERA_HSYNC = 0;

                // H Back Porch
                repeat (CAM_H_BACK) @(posedge CAMERA_PCLK);

                // ** Active Pixel Data Sending **
                // [중요 수정] camera_to_ram 모듈은 2 Cycle을 1 Pixel로 인식합니다. (RGB565)
                // 따라서 3번 보내는게 아니라 2번 보내야 합니다.
                for (h = 0; h < CAM_H_ACT; h = h + 1) begin
                    
                    // [Cycle 1] High Byte (R5 G3)
                    // 예: R=Red, G=Green -> 붉은색과 초록색이 섞인 패턴
                    CAMERA_DATA = 8'hF8; // Red Max
                    @(posedge CAMERA_PCLK);
                    
                    // [Cycle 2] Low Byte (G3 B5)
                    CAMERA_DATA = 8'h1F; // Blue Max
                    @(posedge CAMERA_PCLK);
                    
                end

                // Data Invalid zone
                CAMERA_DATA = 8'h00;

                // H Front Porch
                repeat (CAM_H_FRONT) @(posedge CAMERA_PCLK);
            end

            // 4. V Front Porch
            repeat (CAM_V_FRONT * CAM_H_TOTAL) @(posedge CAMERA_PCLK);

            $display("Frame Sent at time %t", $time);
        end

        #10000;
        $finish;
    end

endmodule