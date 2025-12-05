module InBuf #(
    parameter IMG_WIDTH   = 480,
    parameter IMG_HEIGHT  = 272,
    parameter DATA_WIDTH  = 24,
    parameter ADDR_WIDTH  = 17
)(
    // --------------------------------------------------------
    // Port A: Write Side (데이터 입력 - 나중에 CAM 연결)
    // --------------------------------------------------------
    input  wire                    iClk_wr,    // 쓰기 클럭
    input  wire                    iWe_wr,     // 쓰기 Enable
    input  wire [ADDR_WIDTH-1:0]   iAddr_wr,   // 쓰기 주소
    input  wire [DATA_WIDTH-1:0]   iData_wr,   // 쓰기 데이터

    // --------------------------------------------------------
    // Port B: Read Side (데이터 출력 - CNN 연결)
    // --------------------------------------------------------
    input  wire                    iClk_rd,    // 읽기 클럭
    input  wire                    iRstn,      // 리셋 추가 (레지스터 초기화용)
    input  wire                    iEn_rd,     // 읽기 Enable (기존 iEn 역할)
    input  wire [ADDR_WIDTH-1:0]   iAddr_rd,   // 읽기 주소
    output reg  [DATA_WIDTH-1:0]   oPixel      // 읽은 데이터 (Register Output)
);

    wire [DATA_WIDTH-1:0] bram_dout_b;

    // ✅ [복원됨] 출력 레지스터 로직
    // BRAM에서 데이터가 나와도, iEn_rd가 1일 때만 oPixel을 갱신합니다.
    // 이는 이전 코드의 동작과 동일하게 타이밍을 맞춰줍니다.
    always @(posedge iClk_rd or negedge iRstn) begin
        if (!iRstn)
            oPixel <= {DATA_WIDTH{1'b0}};
        else if (iEn_rd)
            oPixel <= bram_dout_b;
        else
            oPixel <= oPixel;   // Enable이 없으면 값 유지
    end

    // ✅ Block Memory Generator IP (Simple Dual Port RAM)
    // Port A: Write, Port B: Read
    InputMemory_RGB888 u_InputMemory_RGB888 (
        // Port A (Write)
        .clka  (iClk_wr),
        .wea   (iWe_wr),
        .addra (iAddr_wr),
        .dina  (iData_wr),
        
        // Port B (Read)
        .clkb  (iClk_rd),
        .addrb (iAddr_rd),
        .doutb (bram_dout_b)   // BRAM 출력 -> 내부 와이어로 연결
    );

endmodule