`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : clk_en_gen
// Description : 100MHz iClk?„ ê¸°ì??œ¼ë¡? 6.25MHz ?“±ê°??˜ clock enable(wEnClk) ?ƒ?„±
//               - ?‚´ë¶??Š” 0~15ê¹Œì? ì¹´ìš´?„°
//               - ì¹´ìš´?„°ê°? 15ê°? ?˜?Š” ?ˆœê°? 1?´?Ÿ­ ?™?•ˆë§? wEnClk = 1 (ê·? ?™¸?—?Š” 0)
//               - iRstn : Active Low ë¹„ë™ê¸? ë¦¬ì…‹
//////////////////////////////////////////////////////////////////////////////////
module clk_en_gen #(
    parameter DIV = 16                // ë¶„ì£¼ ë¹„ìœ¨ (100MHz / 16 = 6.25MHz)
)(
    input  wire iClk,                 // 100MHz ?…? ¥ ?´?Ÿ­
    input  wire iRstn,                // Active Low reset
    output reg  wEnClk                // 6.25MHz ?“±ê°??˜ clock enable ?„?Š¤
);

    // DIV=16 ?´ë¯?ë¡? 4bit ì¹´ìš´?„°ë©? ì¶©ë¶„ (0~15)
    reg [$clog2(DIV)-1:0] cnt;

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            cnt    <= {($clog2(DIV)){1'b0}};
            wEnClk <= 1'b0;
        end else begin
            if (cnt == (DIV-1)) begin
                cnt    <= {($clog2(DIV)){1'b0}};
                wEnClk <= 1'b1;        // ?´ ?´?Ÿ­?—?„œë§? enable = 1
            end else begin
                cnt    <= cnt + 1'b1;
                wEnClk <= 1'b0;        // ?‚˜ë¨¸ì? 15?´?Ÿ­ ?™?•ˆ?? 0
            end
        end
    end

endmodule
