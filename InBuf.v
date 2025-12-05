module InBuf #(
    parameter IMG_WIDTH   = 480,
    parameter IMG_HEIGHT  = 272,
    parameter DATA_WIDTH  = 24,
    parameter ADDR_WIDTH  = 17
)(
    input  wire                    iClk,     // 100MHz
    input  wire                    iRstn,
    input  wire                    iEn,      // <= wEnClk
    input  wire [ADDR_WIDTH-1:0]   iAddr,
    output reg  [DATA_WIDTH-1:0]   oPixel
);

    wire [DATA_WIDTH-1:0] bram_dout;

    // ✅ wEnClk(iEn)가 1일 때만 픽셀 갱신
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn)
            oPixel <= {DATA_WIDTH{1'b0}};
        else if (iEn)
            oPixel <= bram_dout;
        else
            oPixel <= oPixel;   // 유지
    end

    // ✅ Block Memory Generator IP (BRAM)
    // simple RAM 24 * 131072
    InputMemory_RGB888 u_InputMemory_RGB888 (
        .clka  (iClk),           // 항상 100MHz
        .ena   (1'b1),            // <= wEnClk
        .wea   (1'b0),
        .addra (iAddr),
        .dina  ({DATA_WIDTH{1'b0}}),
        .douta (bram_dout)
    );

endmodule
