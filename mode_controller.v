module CNN_Flow_Controller (
    input wire clk,
    input wire rst_n,

    // [입력]
    input wire [1:0] i_imode, 
    input wire i_frame_done, 

    // [출력]
    output reg o_core_start,   
    output reg o_is_active,    
    
    // [수정] assign으로 연결할 것이므로 reg를 빼고 wire(기본값)로 선언
    output wire [1:0] o_safe_mode 
);

    // ... (상태 정의 localparam 등은 기존과 동일) ...
    localparam S_IDLE      = 2'd0;
    localparam S_START     = 2'd1;
    localparam S_RUNNING   = 2'd2;
    localparam S_CHECK     = 2'd3; 

    reg [1:0] state, next_state;
    reg [1:0] safe_mode_reg; // 실제 값을 저장하는 내부 레지스터

    // --- 1. State & Mode Update ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            safe_mode_reg <= 2'b00;
        end else begin
            state <= next_state;
            
            // IDLE이거나 CHECK 상태일 때만 모드 값을 업데이트
            if (state == S_IDLE || state == S_CHECK) begin
                safe_mode_reg <= i_imode;
            end
        end
    end
    
    // [수정] 이제 o_safe_mode가 wire이므로 assign 사용 가능
    assign o_safe_mode = safe_mode_reg;

    // --- 2. Next State Logic (기존과 동일) ---
    always @(*) begin
        // ... (이전 코드와 동일) ...
        next_state = state;
        o_core_start = 1'b0;
        o_is_active = 1'b0;

        case (state)
            S_IDLE: begin
                if (i_imode != 2'b11) next_state = S_START;
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
                if (i_imode == 2'b11) next_state = S_IDLE;
                else next_state = S_START; 
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule