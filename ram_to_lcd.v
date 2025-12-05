`timescale 1ns / 10ps

module ram_to_lcd #(
    // ê¸°ë³¸ê°? (480x272)
    parameter H_SYNC_W_D = 41,   // 40 -> 41 (?°?´?„°?‹œ?Š¸ ?‘œì¤?)
    parameter H_BACK_P_D = 2,
    parameter H_ACTIVE_D = 478,
    parameter H_FRONT_P_D = 4,   // ?˜… ì¶”ê??¨

    parameter V_SYNC_W_D = 10,
    parameter V_BACK_P_D = 2,
    parameter V_ACTIVE_D = 272,
    parameter V_FRONT_P_D = 2    // ?˜… ì¶”ê??¨
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

    // >>>>>>>>>>>>>>>>  ?ŸŸ? VIO ë¡? ?‹¤?‹œê°? ?ž…? ¥ë°›ëŠ” Timing Ports  <<<<<<<<<<<<<<<<<<
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
    // ?‹¤? œ ?‚¬?š©?  ???´ë°? ê°? ?„ ?ƒ
    // --------------------------
    wire [15:0] H_SYNC_W = (h_sync_w  == 0) ? H_SYNC_W_D : h_sync_w;
    wire [15:0] H_BACK_P = (h_back_p  == 0) ? H_BACK_P_D : h_back_p;
    wire [15:0] H_ACTIVE = (h_active  == 0) ? H_ACTIVE_D : h_active;
    // ?˜… Front Porch ì¶”ê? ë°? Total ê³„ì‚° ?ˆ˜? •
    wire [15:0] H_FRONT_P = (h_front_p == 0) ? H_FRONT_P_D : h_front_p; 
    wire [15:0] H_TOTAL   = H_SYNC_W + H_BACK_P + H_ACTIVE + H_FRONT_P; 

    wire [15:0] V_SYNC_W = (v_sync_w  == 0) ? V_SYNC_W_D : v_sync_w;
    wire [15:0] V_BACK_P = (v_back_p  == 0) ? V_BACK_P_D : v_back_p;
    wire [15:0] V_ACTIVE = (v_active  == 0) ? V_ACTIVE_D : v_active;
    // ?˜… Front Porch ì¶”ê? ë°? Total ê³„ì‚° ?ˆ˜? •
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
    // HSYNC / VSYNC ?ƒ?„±
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
            // ¡Ú ¼öÁ¤: Active ±¸°£ ½ÃÀÛº¸´Ù LATENCY_OFFSET ¸¸Å­ "¹Ì¸®" ÁÖ¼Ò¸¦ Áõ°¡½ÃÅµ´Ï´Ù.
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
    lcd_r <= pix_data[15:11]; // Red¸¦ »óÀ§ºñÆ®¿¡¼­ ²¨³¿
    lcd_g <= pix_data[10:5];  // Green
    lcd_b <= pix_data[4:0];   // Blue¸¦ ÇÏÀ§ºñÆ®¿¡¼­ ²¨³¿
    end

    assign LCD_R_o = lcd_r;
    assign LCD_G_o = lcd_g;
    assign LCD_B_o = lcd_b;

endmodule
