`timescale 1ns/1ps

module OutBuf #(
    parameter IMG_WIDTH   = 480,
    parameter IMG_HEIGHT  = 272,
    parameter DATA_WIDTH  = 16,
    parameter ADDR_WIDTH  = 17
)(
    // Write side
    input  wire                   iClk_wr,      // 100MHz
    input  wire                   iRstn,        
    input  wire                   iEn_wr,       // (사용 안 함)
    input  wire                   iValid_wr,    // CNN Valid 신호
    input  wire                   iLast_wr,     
    input  wire [DATA_WIDTH-1:0]  iPixel_wr,    // CNN Data

    output reg                    oFrameDone,   

    // Read side
    input  wire                   iClk_rd,      
    input  wire [ADDR_WIDTH-1:0]  iAddr_rd,     
    output reg  [DATA_WIDTH-1:0]  oData_rd      
);

    localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;

    // ------------------------------------------------------------
    // 1. Valid 신호 Edge Detection (핵심 수정!)
    //    iValid_wr가 아무리 길게 들어와도, 시작하는 순간 딱 1번만 동작하게 만듭니다.
    // ------------------------------------------------------------
    reg iValid_prev;
    always @(posedge iClk_wr or negedge iRstn) begin
        if (!iRstn) iValid_prev <= 1'b0;
        else        iValid_prev <= iValid_wr;
    end

    // 상승 에지(Rising Edge) 검출: 0이었다가 1이 된 순간
    wire wValid_Pulse = iValid_wr & ~iValid_prev;


    // ------------------------------------------------------------
    // 2. 데이터 조립
    // ------------------------------------------------------------
    wire [4:0] R5 = iPixel_wr[15:11];
    wire [5:0] G6 = iPixel_wr[10:5];
    wire [4:0] B5 = iPixel_wr[4:0];
    wire [DATA_WIDTH-1:0] mem_wr_data = {B5, G6, R5};

    // ------------------------------------------------------------
    // 3. Write Addr Control
    // ------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] wr_addr;

    always @(posedge iClk_wr or negedge iRstn) begin
        if (!iRstn) begin
            wr_addr    <= 0;
            oFrameDone <= 0;
        end else begin
            oFrameDone <= 0; 
            
            // [수정] iValid_wr 대신 wValid_Pulse 사용!
            // 이제 Valid 신호가 길어져도 주소는 딱 1칸만 증가합니다.
            if (wValid_Pulse) begin
                if (wr_addr == TOTAL_PIX - 1) begin
                    wr_addr    <= 0;
                    oFrameDone <= 1'b1; 
                end else begin
                    wr_addr    <= wr_addr + 1;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // 4. RAM Write
    // ------------------------------------------------------------
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:TOTAL_PIX-1];

    // 시뮬레이션용 초기화
    integer i;
    initial begin
        for (i=0; i<TOTAL_PIX; i=i+1) mem[i] = 0;
    end

    always @(posedge iClk_wr) begin
        // [수정] 여기도 wValid_Pulse 사용
        if (wValid_Pulse)
            mem[wr_addr] <= mem_wr_data;
    end

    // ------------------------------------------------------------
    // 5. RAM Read
    // ------------------------------------------------------------
    always @(posedge iClk_rd) begin
        oData_rd <= mem[iAddr_rd];
    end

endmodule