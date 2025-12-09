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

    // Camera Pixel Clock: ~25MHz (Period 40ns)
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
    // 5. Image Data Memory Load
    // -----------------------------------------------------------
    // 최대 크기: 480 * 272 * 2 Bytes (RGB565 = 2Bytes/Pixel)
    // 넉넉하게 300,000 바이트 정도 잡습니다.
    reg [7:0] cam_mem [0:IMG_WIDTH*IMG_HEIGHT*2 - 1]; 
    integer addr_ptr;

    initial begin
        // 파이썬으로 만든 .mem 파일을 읽어옵니다.
        // 시뮬레이션 실행 경로에 파일이 있어야 합니다.
        $readmemh("cam_input_data.mem", cam_mem);
    end

    // -----------------------------------------------------------
    // 6. Test Stimulus (FAST MODE & HREF FIXED)
    // -----------------------------------------------------------
    integer h, v;
    
    localparam CAM_H_ACT   = IMG_WIDTH;  // 480
    localparam CAM_V_ACT   = IMG_HEIGHT; // 272

    initial begin
        // 초기화
        iRstn = 0;
        CAMERA_VSYNC = 0;
        CAMERA_HSYNC = 0;
        CAMERA_DATA  = 0;
        addr_ptr = 0;

        // Reset Release
        #100 iRstn = 1;
        #200;

        // -------------------------------------------------------
        // Camera Frame Loop
        // -------------------------------------------------------
        repeat (2) begin // 2 프레임 전송 시뮬레이션
            
            // 1. VSYNC Start (Pulse)
            CAMERA_VSYNC = 1;
            repeat (10) @(posedge CAMERA_PCLK); 
            CAMERA_VSYNC = 0;

            // 2. V Back Porch (Fast Sim: 짧게 대기)
            repeat (10) @(posedge CAMERA_PCLK);
            
            // 프레임 시작 시 메모리 포인터 초기화 (동일 이미지 반복)
            addr_ptr = 0; 

            // 3. Active Lines Loop
            for (v = 0; v < CAM_V_ACT; v = v + 1) begin
                
                // [수정 핵심] HSYNC(HREF)는 데이터 유효 구간 동안 계속 High여야 함!
                CAMERA_HSYNC = 1; 

                // ** Active Pixel Data Sending from File **
                // camera_to_ram 모듈은 2 Cycle을 1 Pixel(RGB565)로 인식
                for (h = 0; h < CAM_H_ACT; h = h + 1) begin
                    
                    // [Cycle 1] High Byte
                    CAMERA_DATA = cam_mem[addr_ptr]; 
                    addr_ptr = addr_ptr + 1;
                    @(posedge CAMERA_PCLK);
                    
                    // [Cycle 2] Low Byte
                    CAMERA_DATA = cam_mem[addr_ptr];
                    addr_ptr = addr_ptr + 1;
                    @(posedge CAMERA_PCLK);
                    
                end

                // 라인 종료: HSYNC Low
                CAMERA_HSYNC = 0;
                
                // Data Invalid zone
                CAMERA_DATA = 8'h00;

                // H Front/Back Porch (Fast Sim: 짧게 대기)
                repeat (10) @(posedge CAMERA_PCLK);
            end

            // 4. V Front Porch (Fast Sim: 짧게 대기)
            repeat (10) @(posedge CAMERA_PCLK);

            $display("Frame Sent at time %t. Last Addr Ptr: %d", $time, addr_ptr);
        end

        #1000;
        $finish;
    end

endmodule