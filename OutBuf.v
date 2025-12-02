`timescale 1ns/1ps

module OutBuf #(
    parameter IMG_WIDTH   = 480,
    parameter IMG_HEIGHT  = 272,
    parameter DATA_WIDTH  = 16,
    parameter ADDR_WIDTH  = 17
)(
    // Write side
    input  wire                    iClk_wr,     // 100MHz
    input  wire                    iRstn,       
    input  wire                    iEn_wr,      // 6.25MHz (Square Wave or Pulse)
    input  wire                    iValid_wr,   
    input  wire                    iLast_wr,    
    input  wire [DATA_WIDTH-1:0]   iPixel_wr,   

    output reg                     oFrameDone,  

    // Read side
    input  wire                    iClk_rd,     
    input  wire [ADDR_WIDTH-1:0]   iAddr_rd,    
    output reg  [DATA_WIDTH-1:0]   oData_rd     
);

    localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;

    //------------------------------------------------------------
    // 0. Enable 신호 Edge Detection (가장 중요!)
    //    사각파(Square)가 들어와도 딱 1클럭만 동작하게 만듭니다.
    //------------------------------------------------------------
    reg iEn_wr_prev;
    
    always @(posedge iClk_wr or negedge iRstn) begin
        if (!iRstn) iEn_wr_prev <= 1'b0;
        else        iEn_wr_prev <= iEn_wr;
    end

    // 현재는 1이고, 바로 직전은 0일 때가 '상승 에지'입니다.
    wire wEn_Pulse = (iEn_wr == 1'b1) && (iEn_wr_prev == 1'b0);


    //------------------------------------------------------------
    // 1. RGB565 파싱 및 데이터 조립
    //------------------------------------------------------------
    wire [4:0] R5 = iPixel_wr[15:11];
    wire [5:0] G6 = iPixel_wr[10:5];
    wire [4:0] B5 = iPixel_wr[4:0];

    wire [DATA_WIDTH-1:0] mem_wr_data = {B5, G6, R5};

    //------------------------------------------------------------
    // 2. Write Addr Control & Frame Done
    //------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] wr_addr;

    always @(posedge iClk_wr or negedge iRstn) begin
        if (!iRstn) begin
            wr_addr    <= 0;
            oFrameDone <= 0;
        end else begin
            oFrameDone <= 0; 

            // [수정] iEn_wr 대신 엣지 검출된 wEn_Pulse 사용!
            // 이러면 입력이 사각파여도 1번만 실행됩니다.
            if (wEn_Pulse) begin 
                if (iValid_wr) begin
                    if (wr_addr == TOTAL_PIX - 1) begin
                        wr_addr    <= 0;
                        oFrameDone <= 1'b1; 
                    end else begin
                        wr_addr    <= wr_addr + 1;
                    end
                end
            end
        end
    end

    //------------------------------------------------------------
    // 3. RAM Write (Port A)
    //------------------------------------------------------------
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:TOTAL_PIX-1];

    always @(posedge iClk_wr) begin
        // 여기도 wEn_Pulse 사용
        if (wEn_Pulse && iValid_wr)
            mem[wr_addr] <= mem_wr_data;
    end

    //------------------------------------------------------------
    // 4. RAM Read (Port B)
    //------------------------------------------------------------
    always @(posedge iClk_rd) begin
        oData_rd <= mem[iAddr_rd];
    end

endmodule