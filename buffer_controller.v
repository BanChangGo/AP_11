`timescale 1ns / 1ps

module buffer_controller (
    input  wire clk,
    input  wire rstn,
    input  wire i_cam_vsync,    // 카메라 VSYNC (Frame Start)
    input  wire i_read_done,    // CNN 읽기 완료
    
    output reg  o_wr_sel,       // 0 or 1
    output reg  o_rd_sel        // 0 or 1
);

    // 1. VSYNC Edge Detect
    reg prev_vsync;
    wire vsync_rising;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) prev_vsync <= 1'b0;
        else       prev_vsync <= i_cam_vsync;
    end
    
    assign vsync_rising = (prev_vsync == 1'b0 && i_cam_vsync == 1'b1);

    // 2. VSYNC Counter (첫 프레임 구분용)
    // 0: 리셋 직후
    // 1: 첫 번째 VSYNC 도착 (Frame 0 작성 시작) -> 이때는 스위칭하면 안 됨!
    // 2 이상: 두 번째 VSYNC 이후 (Frame 1 작성 시작) -> 이때부터 스위칭
    reg [1:0] vsync_cnt;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_cnt <= 2'd0;
        end else if (vsync_rising) begin
            if (vsync_cnt < 2'd2)
                vsync_cnt <= vsync_cnt + 1'b1;
        end
    end

    // ---------------------------------------------------------------------
    // 3. Write Select Control
    // ---------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_wr_sel <= 1'b0; 
        end else if (vsync_rising) begin
            // [수정된 로직]
            if (vsync_cnt == 2'd0) begin
                // 첫 번째 VSYNC (Frame 0 시작): 
                // 아직 0번 버퍼에 써야 함. 바꾸지 말고 0 유지.
                o_wr_sel <= 1'b0; 
            end else begin
                // 두 번째 VSYNC (Frame 1 시작) 부터:
                // 이제 진짜로 Reader를 피해서 도망가야 함.
                // 현재 Reader가 읽고 있는 버퍼(rd_sel)의 반대편을 선택
                o_wr_sel <= ~o_rd_sel; 
            end
        end
    end

    // ---------------------------------------------------------------------
    // 4. Read Select Control
    // ---------------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_rd_sel <= 1'b0; // 초기값 0 (Write와 같이 시작)
        end else if (i_read_done) begin
            // 읽기가 끝나면, Writer가 현재 쓰고 있는(혹은 막 다 쓴) 쪽을 따라감
            o_rd_sel <= o_wr_sel; 
        end
    end

endmodule