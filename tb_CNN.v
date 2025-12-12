`timescale 1ns / 1ps

module cnn_laplacian_tft_top_tb;
    // -----------------------------------------------------------
    // 1. Parameters & Signals
    // -----------------------------------------------------------
    parameter IMG_WIDTH  = 480;
    parameter IMG_HEIGHT = 272;

    // FPGA System Inputs
    reg           PL_CLK_100MHZ;
    reg           iRstn;

    // Camera Interface
    reg           CAMERA_PCLK;
    reg           CAMERA_HSYNC;
    reg           CAMERA_VSYNC;
    reg [7:0]     CAMERA_DATA;
    
    // Inout Ports (I2C)
    wire          CAMERA_SCCB_SCL;
    wire          CAMERA_SCCB_SDA;

    // Outputs
    wire          CAMERA_RESETn;
    wire          CAMERA_PWDN;
    wire          CAMERA_MCLK;
    wire [4:0]    TFT_R_DATA;
    wire [5:0]    TFT_G_DATA;
    wire [4:0]    TFT_B_DATA;
    wire          TFT_DCLK;
    wire          TFT_BACKLIGHT;
    wire          TFT_DE;
    wire          TFT_HSYNC;
    wire          TFT_VSYNC;
    
    // Control Signals
    reg [1:0]     iMode; // 0:Bypass, 1:Sharp, 2:Edge, 3:AXI User
    
    // AXI Registers (Simulated as Regs for now)
    reg signed [31:0] i_Kernel_value_0;
    reg signed [31:0] i_Kernel_value_1;
    reg signed [31:0] i_Kernel_value_2;
    reg signed [31:0] i_Kernel_value_3;
    reg signed [31:0] i_Kernel_value_4;
    reg signed [31:0] i_Kernel_value_5;
    reg signed [31:0] i_Kernel_value_6;
    reg signed [31:0] i_Kernel_value_7;
    reg signed [31:0] i_Kernel_value_8;
    
    // I2C Pull-ups
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
        .iMode           (iMode),
        
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
        .CAMERA_MCLK     (CAMERA_MCLK),
        
        // AXI Inputs
        .i_Kernel_value_0(i_Kernel_value_0), .i_Kernel_value_1(i_Kernel_value_1), .i_Kernel_value_2(i_Kernel_value_2),
        .i_Kernel_value_3(i_Kernel_value_3), .i_Kernel_value_4(i_Kernel_value_4), .i_Kernel_value_5(i_Kernel_value_5),
        .i_Kernel_value_6(i_Kernel_value_6), .i_Kernel_value_7(i_Kernel_value_7), .i_Kernel_value_8(i_Kernel_value_8)
    );

    // -----------------------------------------------------------
    // 3. Clock Generation
    // -----------------------------------------------------------
    initial PL_CLK_100MHZ = 0;
    always #5 PL_CLK_100MHZ = ~PL_CLK_100MHZ; // 100MHz

    initial CAMERA_PCLK = 0;
    always #20 CAMERA_PCLK = ~CAMERA_PCLK;    // 25MHz

    // -----------------------------------------------------------
    // 4. Tasks (Helper Functions)
    // -----------------------------------------------------------
    
    // [Task] AXI 레지스터 쓰기 모사 (순차적 업데이트)
    // CPU가 AXI Bus를 통해 하나씩 값을 쓰는 것을 흉내냅니다.
    task update_axi_kernel_emboss;
    begin
        $display("[AXI-MOCK] Start Writing Kernel Registers (Emboss Filter)...");
        // Emboss Filter: [-2 -1 0], [-1 1 1], [0 1 2]
        @(posedge PL_CLK_100MHZ); i_Kernel_value_0 <= -2;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_1 <= -1;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_2 <=  0;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_3 <= -1;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_4 <=  1;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_5 <=  1;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_6 <=  0;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_7 <=  1;
        @(posedge PL_CLK_100MHZ); i_Kernel_value_8 <=  2;
        $display("[AXI-MOCK] Kernel Registers Updated.");
    end
    endtask

    // -----------------------------------------------------------
    // 5. Test Stimulus
    // -----------------------------------------------------------
    integer h, v;
    integer frame_idx;
    reg [15:0] pixel_pattern; 
    
    localparam CAM_H_ACT   = IMG_WIDTH;  
    localparam CAM_V_ACT   = IMG_HEIGHT; 
    
    initial begin
        // Init
        iRstn = 0;
        CAMERA_VSYNC = 0; CAMERA_HSYNC = 0; CAMERA_DATA  = 0;
        iMode = 0; // Start with Bypass
        
        // AXI Default (Identity)
        i_Kernel_value_0=0; i_Kernel_value_1=0; i_Kernel_value_2=0;
        i_Kernel_value_3=0; i_Kernel_value_4=1; i_Kernel_value_5=0;
        i_Kernel_value_6=0; i_Kernel_value_7=0; i_Kernel_value_8=0;
        
        // Reset Release
        #100 iRstn = 1;
        #200;

        $display("==================================================");
        $display(" Simulation Start ");
        $display("==================================================");

        // -------------------------------------------------------
        // Camera Frame Loop (7 Frames)
        // -------------------------------------------------------
        for (frame_idx = 1; frame_idx <= 7; frame_idx = frame_idx + 1) begin
            
            // [Test Scenario]
            if (frame_idx == 1) begin
                $display("\n[TEST] Frame 1: Mode 0 (Bypass)");
                iMode = 2'b00;
            end
            else if (frame_idx == 3) begin
                $display("\n[TEST] Frame 3: Mode 2 (Edge Detection)");
                iMode = 2'b10;
            end
            else if (frame_idx == 5) begin
                $display("\n[TEST] Frame 5: Switch to Mode 3 (AXI User Mode)");
                // 1. 먼저 AXI 레지스터 값을 업데이트 (Emboss)
                update_axi_kernel_emboss();
                // 2. 모드 변경 (이 시점부터 Flow Controller가 다음 Blank 구간에 값을 캡처함)
                #100; 
                iMode = 2'b11; 
            end

            // --- VSYNC Start ---
            CAMERA_VSYNC = 1;
            repeat (10) @(posedge CAMERA_PCLK); 
            CAMERA_VSYNC = 0;

            // V Back Porch
            repeat (20) @(posedge CAMERA_PCLK);
            
            // --- Active Lines ---
            for (v = 0; v < CAM_V_ACT; v = v + 1) begin
                CAMERA_HSYNC = 1; 

                // Color Bar Pattern
                for (h = 0; h < CAM_H_ACT; h = h + 1) begin
                    if (v < 50)       pixel_pattern = 16'hF800; // Red
                    else if (v < 100) pixel_pattern = 16'h07E0; // Green
                    else if (v < 150) pixel_pattern = 16'h001F; // Blue
                    else if (v < 200) pixel_pattern = 16'hFFFF; // White
                    else              pixel_pattern = 16'h0000; // Black

                    CAMERA_DATA = pixel_pattern[15:8]; 
                    @(posedge CAMERA_PCLK);
                    
                    CAMERA_DATA = pixel_pattern[7:0];
                    @(posedge CAMERA_PCLK);
                end

                CAMERA_HSYNC = 0; 
                CAMERA_DATA = 8'h00;
                repeat (20) @(posedge CAMERA_PCLK); // H Blank
            end

            // V Front Porch
            repeat (100) @(posedge CAMERA_PCLK);

            $display("Frame %0d Sent at time %t.", frame_idx, $time);
        end

        #5000;
        $display("Simulation Finished Successfully.");
        $finish;
    end
    
    // -----------------------------------------------------------
    // [Monitoring]
    // -----------------------------------------------------------
    // Monitor Internal Signals
    wire mon_wr_sel = uut.u_buf_ctrl.o_wr_sel;
    wire mon_rd_sel = uut.u_buf_ctrl.o_rd_sel;
    // Monitor the actual kernel being used in Conv module
    wire signed [7:0] mon_k4 = uut.u_flow_ctrl.r_k4;

    always @(mon_k4) begin
        $display("[MONITOR] Time: %t | Active Center Kernel (k4) Changed to: %d", $time, mon_k4);
    end

    always @(posedge CAMERA_VSYNC) begin
        $display("[MONITOR] Time: %t | VSYNC Start", $time);
    end

endmodule