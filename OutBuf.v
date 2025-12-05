`timescale 1ns/1ps
/*********************************************************************************
  - Project          : AP CNN Project
  - File name        : OutBuf.v
  - Description      : Frame Buffer (Dual Port RAM) for RGB565 video data.
                       - Write Port : Converts {R5,G6,B5} to {B5,G6,R5} for LCD.
                       - Read Port  : Standard memory read for Display.
  - Timing (CRITICAL): 
       1. Write Trigger : Data is written ONLY on the RISING EDGE of iValid_wr.
                          (Logic: wValid_Pulse = iValid_wr & ~iValid_prev)
       2. Data Sequence : To write multiple pixels, iValid_wr must toggle.
                          (Sequence: High -> Low -> High -> Low ...)
       3. Max Throughput: 1 Pixel per 2 Clocks (Due to toggle requirement).
                          * Continuous 'High' on iValid_wr will write only ONCE.
       4. Frame Reset   : Automatically resets address when (IMG_WIDTH * IMG_HEIGHT)
                          pixels are written. External 'iLast_wr' is IGNORED.
  - Revision history : 1) 2025.12.05 - Modified to Edge-Sensitive Write Logic
*********************************************************************************/

module OutBuf #(
    parameter IMG_WIDTH   = 480,
    parameter IMG_HEIGHT  = 272,
    parameter DATA_WIDTH  = 16,
    parameter ADDR_WIDTH  = 17
)(
    // Write side
    input  wire                   iClk_wr,      // 100MHz
    input  wire                   iRstn,        
    input  wire                   iEn_wr,       // (��� �� ��)
    input  wire                   iValid_wr,    // CNN Valid ��ȣ
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
    // 1. Valid ��ȣ Edge Detection (�ٽ� ����!)
    //    iValid_wr�� �ƹ��� ��� ���͵�, �����ϴ� ���� �� 1���� �����ϰ� ����ϴ�.
    // ------------------------------------------------------------
    reg iValid_prev;
    always @(posedge iClk_wr or negedge iRstn) begin
        if (!iRstn) iValid_prev <= 1'b0;
        else        iValid_prev <= iValid_wr;
    end

    // ��� ����(Rising Edge) ����: 0�̾��ٰ� 1�� �� ����
    wire wValid_Pulse = iValid_wr & ~iValid_prev;


    // ------------------------------------------------------------
    // 2. ������ ����
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
            
            // [����] iValid_wr ��� wValid_Pulse ���!
            // ���� Valid ��ȣ�� ������� �ּҴ� �� 1ĭ�� �����մϴ�.
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

    // �ùķ��̼ǿ� �ʱ�ȭ
    integer i;
    initial begin
        for (i=0; i<TOTAL_PIX; i=i+1) mem[i] = 0;
    end

    always @(posedge iClk_wr) begin
        // [����] ���⵵ wValid_Pulse ���
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