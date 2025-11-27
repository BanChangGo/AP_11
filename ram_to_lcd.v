`timescale 1ns / 10ps

module ram_to_lcd(
    input   wire        clk_i,          // 6.25MHz (Pixel Clock)
    input   wire        iEnable,        // Frame Done (Active High)

    output  wire [16:0] ram_rd_addr_o,
    input   wire [15:0] ram_rd_data_i,

    output  wire        oLCD_Clk,       // LCD Pixel Clock
    output  wire        LCD_hsync_o,
    output  wire        LCD_vsync_o,
    output  wire        LCD_de_o,       // Data Enable (중요!)
    output  wire [4:0]  LCD_R_o,
    output  wire [5:0]  LCD_G_o,
    output  wire [4:0]  LCD_B_o
    );

    // ------------------------------------------------------------
    // 1. 타이밍 파라미터 (480x272 해상도 기준)
    // ------------------------------------------------------------
    // Horizontal: Sync(40) + Back(2) + Active(480) = 522
    localparam H_SYNC_W = 40;
    localparam H_BACK_P = 2;
    localparam H_ACTIVE = 480;
    localparam H_TOTAL  = 522;

    // Vertical: Sync(10) + Back(2) + Active(272) = 284
    localparam V_SYNC_W = 10;
    localparam V_BACK_P = 2;
    localparam V_ACTIVE = 272;
    localparam V_TOTAL  = 284;

    // ------------------------------------------------------------
    // 2. 카운터 (Counter)
    // ------------------------------------------------------------
    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk_i) begin
        if (!iEnable) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            // H Counter
            if (h_count < H_TOTAL - 1)
                h_count <= h_count + 1;
            else begin
                h_count <= 0;
                // V Counter
                if (v_count < V_TOTAL - 1)
                    v_count <= v_count + 1;
                else
                    v_count <= 0;
            end
        end
    end

    // ------------------------------------------------------------
    // 3. 신호 생성 (Sync & Active Area)
    // ------------------------------------------------------------
    // Sync는 해당 구간(0~Sync폭)에서 Low(0) 또는 High(1)
    // 여기서는 Active Low 방식(Low일 때 Sync)으로 가정
    wire h_sync_curr = (h_count < H_SYNC_W) ? 1'b0 : 1'b1;
    wire v_sync_curr = (v_count < V_SYNC_W) ? 1'b0 : 1'b1;

    // Active Area: Sync와 Back Porch를 지난 진짜 화면 구간
    wire h_act = (h_count >= (H_SYNC_W + H_BACK_P)) && (h_count < (H_SYNC_W + H_BACK_P + H_ACTIVE));
    wire v_act = (v_count >= (V_SYNC_W + V_BACK_P)) && (v_count < (V_SYNC_W + V_BACK_P + V_ACTIVE));
    wire active_area = h_act && v_act;

    // ------------------------------------------------------------
    // 4. RAM 주소 생성
    // ------------------------------------------------------------
    reg [16:0] r_addr;

    always @(posedge clk_i) begin
        if (!iEnable) begin
            r_addr <= 0;
        end else if (v_count == 0 && h_count == 0) begin
            r_addr <= 0; // 매 프레임 시작시 리셋
        end else if (active_area) begin
            r_addr <= r_addr + 1; // 화면 유효 구간에서만 주소 증가
        end
    end

    assign ram_rd_addr_o = r_addr;

    // ------------------------------------------------------------
    // 5. 출력 파이프라인 (Delay Pipeline) - 중요!
    // ------------------------------------------------------------
    // RAM은 주소를 주고 데이터가 나오는데 1클럭(또는 2클럭) 걸림.
    // 따라서 Sync 신호와 DE 신호도 똑같이 늦춰줘야 화면이 밀리지 않음.
    
    reg hsync_d, vsync_d, de_d;
    reg [15:0] data_d;

    always @(posedge clk_i) begin
        hsync_d <= h_sync_curr;
        vsync_d <= v_sync_curr;
        de_d    <= active_area;     // ★ 여기서 Active 구간 정보를 저장
        data_d  <= ram_rd_data_i;   // RAM 데이터 래치
    end

    // ------------------------------------------------------------
    // 6. 최종 출력 할당
    // ------------------------------------------------------------
    assign oLCD_Clk     = clk_i;    // 클럭 출력
    assign LCD_hsync_o  = hsync_d;
    assign LCD_vsync_o  = vsync_d;
    assign LCD_de_o     = 1;     // ★ 계산된 DE 신호 출력 (무조건 1 아님!)

    // DE가 1일 때(화면 구간)만 데이터 출력, 아니면 0 (Black)
    assign LCD_R_o = (de_d) ? data_d[4:0]   : 5'd0;
    assign LCD_G_o = (de_d) ? data_d[10:5]  : 6'd0;
    assign LCD_B_o = (de_d) ? data_d[15:11] : 5'd0;

endmodule