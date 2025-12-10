`timescale 1ns / 1ps

module buffer_controller (
    input  wire clk,
    input  wire rstn,
    input  wire i_cam_vsync,   
    input  wire i_read_done,    // 이제 src_last가 직접 들어옴 (Long Pulse)
    
    output reg  o_wr_sel,       
    output reg  o_rd_sel        
);

    // 1. VSYNC Rising Edge Detect
    reg prev_vsync;
    wire vsync_start;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) prev_vsync <= 1'b0;
        else       prev_vsync <= i_cam_vsync;
    end
    assign vsync_start = (prev_vsync == 1'b0 && i_cam_vsync == 1'b1);


    // -----------------------------------------------------------
    // [추가] Read Done Rising Edge Detect (핵심!)
    // src_last가 16사이클 동안 켜져 있어도, 딱 한 번만 트리거하기 위함
    // -----------------------------------------------------------
    reg prev_read_done;
    wire read_done_edge;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) prev_read_done <= 1'b0;
        else       prev_read_done <= i_read_done;
    end

    // 0이었다가 1이 되는 순간만 포착
    assign read_done_edge = (prev_read_done == 1'b0 && i_read_done == 1'b1);


    // -----------------------------------------------------------
    // 2. Read Select Control (Master)
    // -----------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_rd_sel <= 1'b0; 
        end else if (read_done_edge) begin // [수정] i_read_done 대신 edge 사용
            o_rd_sel <= ~o_rd_sel; 
        end
    end


    // -----------------------------------------------------------
    // 3. Write Select Control (Slave)
    // -----------------------------------------------------------
    reg is_first_frame; 

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_wr_sel <= 1'b0;
            is_first_frame <= 1'b1;
        end else if (vsync_start) begin
            if (is_first_frame) begin
                o_wr_sel <= 1'b0;
                is_first_frame <= 1'b0; 
            end else begin
                // Read가 있는 곳의 반대를 선택
                o_wr_sel <= ~o_rd_sel; 
            end
        end
    end

endmodule