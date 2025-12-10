`timescale 1ns / 1ps

module cnn_laplacian_tft_top_tb;
    // -----------------------------------------------------------
    // 1. Parameters & Signals
    // -----------------------------------------------------------
    parameter IMG_WIDTH  = 480;
    parameter IMG_HEIGHT = 272;

    // FPGA System Inputs
    reg          PL_CLK_100MHZ;
    reg          iRstn;

    // Camera Interface (Input to FPGA)
    reg          CAMERA_PCLK;
    reg          CAMERA_HSYNC;
    reg          CAMERA_VSYNC;
    reg [7:0]    CAMERA_DATA;
    
    // Inout Ports (I2C)
    wire         CAMERA_SCCB_SCL;
    wire         CAMERA_SCCB_SDA;

    // Camera Control Outputs (From FPGA)
    wire         CAMERA_RESETn;
    wire         CAMERA_PWDN;
    wire         CAMERA_MCLK;

    // TFT LCD Outputs (From FPGA)
    wire [4:0]   TFT_R_DATA;
    wire [5:0]   TFT_G_DATA;
    wire [4:0]   TFT_B_DATA;
    wire         TFT_DCLK;
    wire         TFT_BACKLIGHT;
    wire         TFT_DE;
    wire         TFT_HSYNC;
    wire         TFT_VSYNC;
    
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
        // VIO가 시뮬레이션에서 'Z'로 뜨는 것을 방지하기 위해 강제 할당
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
    // 5. Test Stimulus (Internal Pattern Generator)
    // -----------------------------------------------------------
    integer h, v;
    reg [15:0] pixel_pattern; // 임의 생성된 16bit(RGB565) 픽셀 값
    
    localparam CAM_H_ACT   = IMG_WIDTH;  // 480
    localparam CAM_V_ACT   = IMG_HEIGHT; // 272
    
    initial begin
        // 초기화
        iRstn = 0;
        CAMERA_VSYNC = 0;
        CAMERA_HSYNC = 0;
        CAMERA_DATA  = 0;

        // Reset Release
        #100 iRstn = 1;
        #200;

        // -------------------------------------------------------
        // Camera Frame Loop
        // -------------------------------------------------------
        repeat (7) begin // 3 프레임 전송 시뮬레이션
            
            // 1. VSYNC Start (Pulse)
            CAMERA_VSYNC = 1;
            repeat (10) @(posedge CAMERA_PCLK); 
            CAMERA_VSYNC = 0;

            // 2. V Back Porch
            repeat (20) @(posedge CAMERA_PCLK);
            
            // 3. Active Lines Loop
            for (v = 0; v < CAM_V_ACT; v = v + 1) begin
                
                // HSYNC Start (Active High during data valid)
                CAMERA_HSYNC = 1; 

                // ** Active Pixel Data Generation **
                // 1 Pixel = 2 Bytes (RGB565)
                // ** Active Pixel Data Generation (Color Bar) **
                for (h = 0; h < CAM_H_ACT; h = h + 1) begin
                    
                    // [쉬운 패턴] 행(v)의 위치에 따라 색깔을 다르게 쏘기
                    if (v < 50) begin
                        // 0 ~ 49라인: RED (11111 000000 00000)
                        pixel_pattern = 16'hF800; 
                    end else if (v < 100) begin
                        // 50 ~ 99라인: GREEN (00000 111111 00000)
                        pixel_pattern = 16'h07E0;
                    end else if (v < 150) begin
                        // 100 ~ 149라인: BLUE (00000 000000 11111)
                        pixel_pattern = 16'h001F;
                    end else if (v < 200) begin
                        // 150 ~ 199라인: WHITE (11111 111111 11111)
                        pixel_pattern = 16'hFFFF;
                    end else begin
                        // 나머지: BLACK (00000 000000 00000)
                        pixel_pattern = 16'h0000;
                    end

                    // ---------------------------------------------
                    // 아래는 기존 전송 로직과 동일
                    // ---------------------------------------------

                    // [Cycle 1] High Byte Sending
                    CAMERA_DATA = pixel_pattern[15:8]; 
                    @(posedge CAMERA_PCLK);
                    
                    // [Cycle 2] Low Byte Sending
                    CAMERA_DATA = pixel_pattern[7:0];
                    @(posedge CAMERA_PCLK);
                    
                end

                // 라인 종료: HSYNC Low
                CAMERA_HSYNC = 0;
                
                // Data Invalid zone
                CAMERA_DATA = 8'h00;

                // H Front/Back Porch (Simulate horizontal blanking)
                repeat (20) @(posedge CAMERA_PCLK);
            end

            // 4. V Front Porch
            repeat (100) @(posedge CAMERA_PCLK);

            $display("Frame Sent at time %t.", $time);
            
        end

        #2000;
        $display("Simulation Finished Successfully.");
        $finish;
    end
    
    // -----------------------------------------------------------
    // [Monitoring] Double Buffer & VSYNC Debug
    // -----------------------------------------------------------
    
    // 내부 신호 모니터링 (계층 구조가 맞는지 확인 필요)
    wire mon_wr_sel = uut.u_buf_ctrl.o_wr_sel;
    wire mon_rd_sel = uut.u_buf_ctrl.o_rd_sel;
    //wire [1:0] mon_vsync_cnt = uut.u_buf_ctrl.vsync_cnt;

    // VSYNC 로그
    always @(posedge CAMERA_VSYNC) begin
        $display("\n===================================================================");
        $display("[TB-LOG] Time: %t | Camera VSYNC RISING! (New Frame Start)", $time);
        //$display("[TB-LOG] Current Internal VSYNC Count: %d", mon_vsync_cnt);
        $display("===================================================================\n");
    end

    // Write Buffer 변경 감지
    always @(mon_wr_sel) begin
        $display("[TB-LOG] Time: %t | >>>> WRITE Buffer Switched to: [%d]", $time, mon_wr_sel);
        // Reset 구간 이후, Read/Write 포인터 충돌 경고
        if ($time > 1000 && mon_wr_sel == mon_rd_sel) begin
            $display("[TB-WARNING] Conflict? Write and Read are using same buffer [%d]!", mon_wr_sel);
        end
    end

    // Read Buffer 변경 감지
    always @(mon_rd_sel) begin
        $display("[TB-LOG] Time: %t | <<<< READ  Buffer Switched to: [%d]", $time, mon_rd_sel);
    end

    // CNN/LCD 처리 완료 감지 (uut 내부 신호)
    always @(posedge uut.src_last) begin
         $display("[TB-LOG] Time: %t | Processing (Read) Done for current frame.", $time);
    end

endmodule