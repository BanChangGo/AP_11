module CNN_Flow_Controller (
    input wire clk,
    input wire rst_n,

    // [입력] 제어 신호
    input wire [1:0] i_imode,       // 0:Bypass, 1:Sharp, 2:Edge, 3:User(AXI)
    input wire i_frame_done, 
    
    // [입력] AXI 레지스터에서 온 사용자 커널 값 (32bit signed)
    input wire signed [31:0] i_axi_k0, input wire signed [31:0] i_axi_k1, input wire signed [31:0] i_axi_k2,
    input wire signed [31:0] i_axi_k3, input wire signed [31:0] i_axi_k4, input wire signed [31:0] i_axi_k5,
    input wire signed [31:0] i_axi_k6, input wire signed [31:0] i_axi_k7, input wire signed [31:0] i_axi_k8,

    // [출력] Top Logic 제어
    output reg o_core_start,   
    output reg o_is_active,    
    
    // [출력] Conv 모듈로 들어갈 최종 결정된 커널 값 (8bit signed)
    output wire signed [7:0] o_safe_k0, output wire signed [7:0] o_safe_k1, output wire signed [7:0] o_safe_k2,
    output wire signed [7:0] o_safe_k3, output wire signed [7:0] o_safe_k4, output wire signed [7:0] o_safe_k5,
    output wire signed [7:0] o_safe_k6, output wire signed [7:0] o_safe_k7, output wire signed [7:0] o_safe_k8
);

    localparam S_IDLE    = 2'd0;
    localparam S_START   = 2'd1;
    localparam S_RUNNING = 2'd2;
    localparam S_CHECK   = 2'd3; 

    reg [1:0] state, next_state;

    // 최종 선택된 커널을 저장할 레지스터
    reg signed [7:0] r_k0, r_k1, r_k2;
    reg signed [7:0] r_k3, r_k4, r_k5;
    reg signed [7:0] r_k6, r_k7, r_k8;

    // --- 1. Kernel Selection & Update Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            // 리셋 시 기본값: Bypass
            r_k0 <= 0; r_k1 <= 0; r_k2 <= 0;
            r_k3 <= 0; r_k4 <= 1; r_k5 <= 0;
            r_k6 <= 0; r_k7 <= 0; r_k8 <= 0;
        end else begin
            state <= next_state;
            
            // [중요] 안전한 타이밍(IDLE/CHECK)에만 커널 값 업데이트
            if (state == S_IDLE || state == S_CHECK) begin
                case (i_imode)
                    // Mode 0: Bypass
                    2'b00: begin
                        r_k0 <= 0; r_k1 <= 0; r_k2 <= 0;
                        r_k3 <= 0; r_k4 <= 1; r_k5 <= 0;
                        r_k6 <= 0; r_k7 <= 0; r_k8 <= 0;
                    end
                    // Mode 1: Sharpening
                    2'b01: begin
                        r_k0 <=  0; r_k1 <= -1; r_k2 <=  0;
                        r_k3 <= -1; r_k4 <=  5; r_k5 <= -1;
                        r_k6 <=  0; r_k7 <= -1; r_k8 <=  0;
                    end
                    // Mode 2: Edge Detection
                    2'b10: begin
                        r_k0 <= -1; r_k1 <= -1; r_k2 <= -1;
                        r_k3 <= -1; r_k4 <=  9; r_k5 <= -1;
                        r_k6 <= -1; r_k7 <= -1; r_k8 <= -1;
                    end
                    // Mode 3: User Programmable (AXI 값 사용)
                    2'b11: begin
                        r_k0 <= i_axi_k0[7:0]; r_k1 <= i_axi_k1[7:0]; r_k2 <= i_axi_k2[7:0];
                        r_k3 <= i_axi_k3[7:0]; r_k4 <= i_axi_k4[7:0]; r_k5 <= i_axi_k5[7:0];
                        r_k6 <= i_axi_k6[7:0]; r_k7 <= i_axi_k7[7:0]; r_k8 <= i_axi_k8[7:0];
                    end
                endcase
            end
        end
    end
    
    assign o_safe_k0 = r_k0; assign o_safe_k1 = r_k1; assign o_safe_k2 = r_k2;
    assign o_safe_k3 = r_k3; assign o_safe_k4 = r_k4; assign o_safe_k5 = r_k5;
    assign o_safe_k6 = r_k6; assign o_safe_k7 = r_k7; assign o_safe_k8 = r_k8;

    // --- 2. FSM Logic (기존 유지) ---
    always @(*) begin
        next_state = state;
        o_core_start = 1'b0;
        o_is_active = 1'b0;

        case (state)
            S_IDLE: begin
                // 여기서 별도 시작 트리거가 없다면 자동 시작
                next_state = S_START; 
            end
            S_START: begin
                o_core_start = 1'b1;
                o_is_active = 1'b1;
                next_state = S_RUNNING;
            end
            S_RUNNING: begin
                o_is_active = 1'b1;
                if (i_frame_done) next_state = S_CHECK;
                else next_state = S_RUNNING;
            end
            S_CHECK: begin
                o_is_active = 1'b0;
                next_state = S_START; 
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule