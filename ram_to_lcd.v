`timescale 1ns / 10ps

module ram_to_lcd #(
    // 旮半掣臧? (480x272)
    parameter H_SYNC_W_D = 41,   // 40 -> 41 (?嵃?澊?劙?嫓?姼 ?憸欷?)
    parameter H_BACK_P_D = 2,
    parameter H_ACTIVE_D = 478,
    parameter H_FRONT_P_D = 4,   // ?槄 於旉??惃

    parameter V_SYNC_W_D = 10,
    parameter V_BACK_P_D = 2,
    parameter V_ACTIVE_D = 272,
    parameter V_FRONT_P_D = 2    // ?槄 於旉??惃
)(
    input  wire        clk_i,
    input  wire        iEnable,

    output wire [16:0] ram_rd_addr_o,
    input  wire [15:0] ram_rd_data_i,

    output wire        LCD_hsync_o,
    output wire        LCD_vsync_o,
    output wire [4:0]  LCD_R_o,
    output wire [5:0]  LCD_G_o,
    output wire [4:0]  LCD_B_o,

    // >>>>>>>>>>>>>>>>  ?煙? VIO 搿? ?嫟?嫓臧? ?瀰?牓氚涬姅 Timing Ports  <<<<<<<<<<<<<<<<<<
    input  wire [15:0] h_sync_w,
    input  wire [15:0] h_back_p,
    input  wire [15:0] h_active,

    input  wire [15:0] v_sync_w,
    input  wire [15:0] v_back_p,
    input  wire [15:0] v_active,
    input  wire [15:0] h_front_p,
    input  wire [15:0] v_front_p
);

    // --------------------------
    // ?嫟?牅 ?偓?毄?悹 ???澊氚? 臧? ?劆?儩
    // --------------------------
    wire [15:0] H_SYNC_W = (h_sync_w  == 0) ? H_SYNC_W_D : h_sync_w;
    wire [15:0] H_BACK_P = (h_back_p  == 0) ? H_BACK_P_D : h_back_p;
    wire [15:0] H_ACTIVE = (h_active  == 0) ? H_ACTIVE_D : h_active;
    // ?槄 Front Porch 於旉? 氚? Total 瓿勳偘 ?垬?爼
    wire [15:0] H_FRONT_P = (h_front_p == 0) ? H_FRONT_P_D : h_front_p; 
    wire [15:0] H_TOTAL   = H_SYNC_W + H_BACK_P + H_ACTIVE + H_FRONT_P; 

    wire [15:0] V_SYNC_W = (v_sync_w  == 0) ? V_SYNC_W_D : v_sync_w;
    wire [15:0] V_BACK_P = (v_back_p  == 0) ? V_BACK_P_D : v_back_p;
    wire [15:0] V_ACTIVE = (v_active  == 0) ? V_ACTIVE_D : v_active;
    // ?槄 Front Porch 於旉? 氚? Total 瓿勳偘 ?垬?爼
    wire [15:0] V_FRONT_P = (v_front_p == 0) ? V_FRONT_P_D : v_front_p;
    wire [15:0] V_TOTAL   = V_SYNC_W + V_BACK_P + V_ACTIVE + V_FRONT_P;

    // --------------------------
    // Counter
    // --------------------------
    reg [15:0] h_count = 0;
    reg [15:0] v_count = 0;

    reg hsync = 0;
    reg vsync = 0;

    // --------------------------
    // Horizontal / Vertical Counter
    // --------------------------
    always @(posedge clk_i) begin
        if (!iEnable) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count < H_TOTAL - 1) begin
                h_count <= h_count + 1;
            end else begin
                h_count <= 0;

                if (v_count < V_TOTAL - 1)
                    v_count <= v_count + 1;
                else
                    v_count <= 0;
            end
        end
    end

    // --------------------------
    // HSYNC / VSYNC ?儩?劚
    // --------------------------
    always @(posedge clk_i) begin
        hsync <= (h_count < H_SYNC_W) ? 0 : 1;
        vsync <= (v_count < V_SYNC_W) ? 0 : 1;
    end

    reg hsync_d1, hsync_d2;
    reg vsync_d1, vsync_d2;

    always @(negedge clk_i) begin
        hsync_d1 <= hsync;
        hsync_d2 <= hsync_d1;

        vsync_d1 <= vsync;
        vsync_d2 <= vsync_d1;
    end

    assign LCD_hsync_o = hsync_d2;
    assign LCD_vsync_o = vsync_d2;

    // --------------------------
    // RAM READ ADDRESS
    // --------------------------
    reg [16:0] ram_rd_addr = 0;
    localparam LATENCY_OFFSET = 2;

    always @(posedge clk_i) begin
        if (v_count < (V_SYNC_W + V_BACK_P)) begin
            ram_rd_addr <= 0;
        end else begin
            // ≮ 荐沥: Active 备埃 矫累焊促 LATENCY_OFFSET 父怒 "固府" 林家甫 刘啊矫诺聪促.
            if ((h_count >= (H_SYNC_W + H_BACK_P - LATENCY_OFFSET)) && 
                (h_count <  (H_SYNC_W + H_BACK_P + H_ACTIVE - LATENCY_OFFSET)) &&
                (v_count >= (V_SYNC_W + V_BACK_P)) &&
                (v_count <  (V_SYNC_W + V_BACK_P + V_ACTIVE))) begin
                    
                    ram_rd_addr <= ram_rd_addr + 1;
            end
        end
    end

    assign ram_rd_addr_o = ram_rd_addr;

    // --------------------------
    // Data Latching
    // --------------------------
    reg [15:0] pix_data;

    always @(posedge clk_i) begin
        pix_data <= ram_rd_data_i;
    end

    reg [4:0] lcd_r;
    reg [5:0] lcd_g;
    reg [4:0] lcd_b;

    always @(negedge clk_i) begin
    lcd_r <= pix_data[15:11]; // Red甫 惑困厚飘俊辑 波晨
    lcd_g <= pix_data[10:5];  // Green
    lcd_b <= pix_data[4:0];   // Blue甫 窍困厚飘俊辑 波晨
    end

    assign LCD_R_o = lcd_r;
    assign LCD_G_o = lcd_g;
    assign LCD_B_o = lcd_b;

endmodule