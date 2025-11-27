`timescale 1ns/1ps

module OutBuf #(
    parameter IMG_WIDTH   = 480,
    parameter IMG_HEIGHT  = 272,
    parameter DATA_WIDTH  = 16,
    parameter ADDR_WIDTH  = 17
)(
    // Write side
    input  wire                    iClk_wr,     
    input  wire                    iRstn,       
    input  wire                    iEn_wr,      
    input  wire                    iValid_wr,   
    input  wire                    iLast_wr,    
    input  wire [DATA_WIDTH-1:0]   iPixel_wr,   

    output reg                     oFrameDone,  

    // Read side
    input  wire                    iClk_rd,     
    input  wire [ADDR_WIDTH-1:0]   iAddr_rd,    
    output reg  [DATA_WIDTH-1:0]   oData_rd     // ★ wire -> reg로 복구
);

    localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;

    //------------------------------------------------------------
    // RGB565 파싱
    //------------------------------------------------------------
    wire [4:0] R5 = iPixel_wr[15:11];
    wire [5:0] G6 = iPixel_wr[10:5];
    wire [4:0] B5 = iPixel_wr[4:0];

    // RAM에 쓸 데이터 조립
    wire [DATA_WIDTH-1:0] mem_wr_data = {B5, G6, R5};

    //------------------------------------------------------------
    // Write Addr Control & Frame Done
    //------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] wr_addr;

    always @(posedge iClk_wr or negedge iRstn) begin
        if (!iRstn) begin
            wr_addr    <= 0;
            oFrameDone <= 0;
        end else if (iEn_wr) begin
            oFrameDone <= 0; // Pulse는 1클럭만 유지

            // iValid_wr를 직접 확인
            if (iValid_wr) begin
                // 마지막 픽셀인지 확인 (TOTAL_PIX - 1)
                if (wr_addr == TOTAL_PIX - 1) begin
                    wr_addr    <= 0;
                    oFrameDone <= 1'b1; // Frame Done 발생
                end else begin
                    wr_addr    <= wr_addr + 1;
                end
            end
        end
    end

    //------------------------------------------------------------
    // Inferred Dual-port RAM (Block Memory)
    //------------------------------------------------------------
    // Vivado가 자동으로 BRAM으로 합성하도록 유도합니다.
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:TOTAL_PIX-1];

    // [WRITE] Port A
    always @(posedge iClk_wr) begin
        if (iEn_wr && iValid_wr)
            mem[wr_addr] <= mem_wr_data;
    end

    // [READ] Port B
    always @(posedge iClk_rd) begin
        oData_rd <= mem[iAddr_rd];
    end

endmodule