`timescale 1 ns / 10 ps

module S_AXI_LITE_REG_CNN #(
  parameter C_S_AXI_DATA_WIDTH = 32,
  parameter C_S_AXI_ADDR_WIDTH = 32
)
(
  // Clock & Reset
  input  wire                               S_AXI_ACLK,
  input  wire                               S_AXI_ARESETN,

  // Write Address channel
  input  wire                               S_AXI_AWVALID,
  input  wire [2:0]                         S_AXI_AWPROT,
  input  wire [C_S_AXI_ADDR_WIDTH-1:0]      S_AXI_AWADDR,
  output wire                               S_AXI_AWREADY,

  // Write channel
  input  wire [C_S_AXI_DATA_WIDTH-1:0]      S_AXI_WDATA,
  input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]  S_AXI_WSTRB,
  input  wire                               S_AXI_WVALID,
  output wire                               S_AXI_WREADY,

  // Response channel
  output wire                               S_AXI_BVALID,
  output wire [1:0]                         S_AXI_BRESP,
  input  wire                               S_AXI_BREADY,

  // Read Address channel
  input  wire                               S_AXI_ARVALID,
  input  wire [2:0]                         S_AXI_ARPROT,
  input  wire [C_S_AXI_ADDR_WIDTH-1:0]      S_AXI_ARADDR,
  output wire                               S_AXI_ARREADY,

  // Read channel
  output wire                               S_AXI_RVALID,
  output wire [1:0]                         S_AXI_RRESP,
  output wire [C_S_AXI_DATA_WIDTH-1:0]      S_AXI_RDATA,
  input  wire                               S_AXI_RREADY,

  // [수정] 9개의 커널 값을 출력하는 포트 (각 32비트)
  output reg  [1:0]                         oReg0,

  output reg signed [31:0] oKernel_0,
  output reg signed [31:0] oKernel_1,
  output reg signed [31:0] oKernel_2,
  output reg signed [31:0] oKernel_3,
  output reg signed [31:0] oKernel_4,
  output reg signed [31:0] oKernel_5,
  output reg signed [31:0] oKernel_6,
  output reg signed [31:0] oKernel_7,
  output reg signed [31:0] oKernel_8
);

  // AXI 내부 신호들
  reg    [C_S_AXI_ADDR_WIDTH-1:0]           axi_awaddr;
  reg                                       axi_awready;
  reg                                       axi_wready;
  reg                                       axi_bvalid;
  reg    [1:0]                              axi_bresp;
  reg    [C_S_AXI_ADDR_WIDTH-1:0]           axi_araddr;
  reg                                       axi_arready;
  reg                                       axi_rvalid;
  reg    [C_S_AXI_DATA_WIDTH-1:0]           axi_rdata;
  reg    [1:0]                              axi_rresp;

  wire                                      reg_rden;
  wire                                      reg_wren;
  reg    [C_S_AXI_DATA_WIDTH-1:0]           reg_data_out;
  reg                                       aw_en;

  // I/O Connections assignments
  assign S_AXI_AWREADY  = axi_awready;
  assign S_AXI_WREADY   = axi_wready;
  assign S_AXI_BRESP    = axi_bresp;
  assign S_AXI_BVALID   = axi_bvalid;
  assign S_AXI_ARREADY  = axi_arready;
  assign S_AXI_RDATA    = axi_rdata;
  assign S_AXI_RRESP    = axi_rresp;
  assign S_AXI_RVALID   = axi_rvalid;

  // 1. Write Address Ready
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end else begin    
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        axi_awready <= 1'b1;
        aw_en <= 1'b0;
      end else if (S_AXI_BREADY && axi_bvalid) begin
        aw_en <= 1'b1;
        axi_awready <= 1'b0;
      end else begin
        axi_awready <= 1'b0;
      end
    end 
  end       

  // 2. Write Address Latch
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awaddr <= 0;
    end else begin    
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        axi_awaddr <= S_AXI_AWADDR;
      end
    end 
  end       

  // 3. Write Data Ready
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_wready <= 1'b0;
    end else begin    
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
        axi_wready <= 1'b1;
      end else begin
        axi_wready <= 1'b0;
      end
    end 
  end       

  // -----------------------------------------------------------------------
  // [핵심 수정 1] 9개 레지스터 쓰기 로직 (Write)
  // -----------------------------------------------------------------------
  assign reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      // 초기값 (예: Identity Matrix 혹은 0)
      oKernel_0 <= 0; oKernel_1 <= 0; oKernel_2 <= 0;
      oKernel_3 <= 0; oKernel_4 <= 1; oKernel_5 <= 0; // 중앙만 1이면 원본 유지
      oKernel_6 <= 0; oKernel_7 <= 0; oKernel_8 <= 0;
    end 
    else if (reg_wren) begin
      // 주소별 분기 (4바이트씩 증가)
      if (axi_awaddr[C_S_AXI_ADDR_WIDTH-1:0] == 32'hA002_0000) begin
        oReg0 <= S_AXI_WDATA[1:0];
      end else begin
        case (axi_awaddr)
            32'hA003_0000 : oKernel_0 <= S_AXI_WDATA;
            32'hA003_0004 : oKernel_1 <= S_AXI_WDATA;
            32'hA003_0008 : oKernel_2 <= S_AXI_WDATA;
            32'hA003_000C : oKernel_3 <= S_AXI_WDATA;
            32'hA003_0010 : oKernel_4 <= S_AXI_WDATA; // Center
            32'hA003_0014 : oKernel_5 <= S_AXI_WDATA;
            32'hA003_0018 : oKernel_6 <= S_AXI_WDATA;
            32'hA003_001C : oKernel_7 <= S_AXI_WDATA;
            32'hA003_0020 : oKernel_8 <= S_AXI_WDATA;
            default: ; // 해당 없는 주소는 무시
        endcase
      end
    end
  end

  // 5. Write Response
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end else begin    
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0; 
      end else if (S_AXI_BREADY && axi_bvalid) begin
        axi_bvalid <= 1'b0; 
      end  
    end
  end   

  // 6. Read Address Ready
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end else begin    
      if (~axi_arready && S_AXI_ARVALID) begin
        axi_arready <= 1'b1;
        axi_araddr  <= S_AXI_ARADDR;
      end else begin
        axi_arready <= 1'b0;
      end
    end 
  end       

  // 7. Read Data Valid
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end else begin    
      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b0; 
      end else if (axi_rvalid && S_AXI_RREADY) begin
        axi_rvalid <= 1'b0;
      end                
    end
  end    

  // -----------------------------------------------------------------------
  // [핵심 수정 2] 9개 레지스터 읽기 로직 (Read) - 검증용
  // -----------------------------------------------------------------------
  assign reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
  
  always @(*) begin
    // 읽을 때도 4바이트 단위 주소 매핑
    case (axi_araddr[C_S_AXI_ADDR_WIDTH-1:0])
      32'hA002_0000 : reg_data_out <= {30'h0, oReg0[1:0]};

      32'hA003_0000 : reg_data_out <= oKernel_0;
      32'hA003_0004 : reg_data_out <= oKernel_1;
      32'hA003_0008 : reg_data_out <= oKernel_2;
      32'hA003_000C : reg_data_out <= oKernel_3;
      32'hA003_0010 : reg_data_out <= oKernel_4;
      32'hA003_0014 : reg_data_out <= oKernel_5;
      32'hA003_0018 : reg_data_out <= oKernel_6;
      32'hA003_001C : reg_data_out <= oKernel_7;
      32'hA003_0020 : reg_data_out <= oKernel_8;
      default       : reg_data_out <= 32'h0;
    endcase
  end

  // Output Register data
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_rdata  <= 0;
    end else begin    
      if (reg_rden) begin
          axi_rdata <= reg_data_out;     
      end   
    end
  end    

endmodule