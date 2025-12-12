/*********************************************************************
  - Project          : PL_CNN Project
  - File name        : S_AXI_LITE_REG_CNN.v
  - Description      : AXI interface, receieve axi packet and extract the data
  - Owner            : Inchul.song
  - Revision history : 1) 2025.11.09 : Initial release
                       2) 2025.11.16 : + Vio_0/1
                       3) 2025.11.23 : + Mode from SW
*********************************************************************/

`timescale 1 ns / 10 ps

module S_AXI_LITE_REG_CNN #(
  parameter C_S_AXI_DATA_WIDTH = 32,
  parameter C_S_AXI_ADDR_WIDTH = 32)
(

  // Clock & Reset(Sync. & active low)
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


  // Write register out
  output reg  [1:0]                         oReg0
  // Other registers in here !!!

  );


  // wire & reg declaration
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



  // Example-specific design signals
  // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
  // ADDR_LSB is used for addressing 32/64 bit registers/memories
  // ADDR_LSB = 2 for 32 bits (n downto 2) <--
  // ADDR_LSB = 3 for 64 bits (n downto 3)
  wire                                      reg_rden;
  wire                                      reg_wren;
  // Word access only !!!
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



  // Implement axi_awready latching
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end 
    else begin    

      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        // slave is ready to accept write address when 
        // there is a valid write address and write data
        // on the write address and data bus. This design 
        // expects no outstanding transactions. 
        axi_awready <= 1'b1;
        aw_en <= 1'b0;
      end
      else if (S_AXI_BREADY && axi_bvalid) begin
        aw_en       <= 1'b1;
        axi_awready <= 1'b0;
      end
      else begin
        axi_awready <= 1'b0;
      end

    end 

  end       
  
  // Implement axi_awaddr latching
  // This process is used to latch the address when both 
  // S_AXI_AWVALID and S_AXI_WVALID are valid. 
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      axi_awaddr <= 0;
    end 
    else begin    

      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        // Write Address latching 
        axi_awaddr <= S_AXI_AWADDR;
      end

    end 

  end       
  


  // Implement axi_wready generation
  // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
  // de-asserted when reset is low. 
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      axi_wready <= 1'b0;
    end 
    else begin    

      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
        // slave is ready to accept write data when 
        // there is a valid write address and write data
        // on the write address and data bus. This design 
        // expects no outstanding transactions. 
        axi_wready <= 1'b1;
      end
      else begin
        axi_wready <= 1'b0;
      end

    end 

  end       
  


  // Implement memory mapped register select and write logic generation
  // The write data is accepted and written to memory mapped registers when
  // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
  // select byte enables of slave registers while writing.
  // These registers are cleared when reset (active low) is applied.
  // Slave register write enable is asserted when valid address and data are available
  // and the slave is ready to accept the write address and write data.
  // Word access only !!!
  assign reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      oReg0 <= 2'h3;
    end 
    else if (reg_wren) begin

      if (axi_awaddr[C_S_AXI_ADDR_WIDTH-1:0] == 32'hA002_0000)
	// Word access only !!!
        oReg0 <= S_AXI_WDATA[1:0];
        // Decribe other registers in here !!!
        // else if (axi_awaddr[C_S_AXI_ADDR_WIDTH-1:0] == ...

    end
  
  end
  
  
  
  // Implement write response logic generation
  // The write response and response valid signals are asserted by the slave 
  // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
  // This marks the acceptance of address and indicates the status of 
  // write transaction.
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end 
    else begin    

      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
        // indicates a valid write response is available
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0; // 'OKAY' response 
                            // work error responses in future
      end
      else begin

        if (S_AXI_BREADY && axi_bvalid) begin
          //check if bready is asserted while bvalid is high) 
          //(there is a possibility that bready is always asserted high)   
          axi_bvalid <= 1'b0; 
        end  

      end

    end

  end   
  


  // Implement axi_arready generation
  // axi_arready is asserted for one S_AXI_ACLK clock cycle when
  // S_AXI_ARVALID is asserted. axi_awready is 
  // de-asserted when reset (active low) is asserted. 
  // The read address is also latched when S_AXI_ARVALID is 
  // asserted. axi_araddr is reset to zero on reset assertion.
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
     axi_arready <= 1'b0;
     axi_araddr  <= 32'b0;
    end 
    else begin    

      if (~axi_arready && S_AXI_ARVALID) begin
        // indicates that the slave has acceped the valid read address
        axi_arready <= 1'b1;
        // Read address latching
        axi_araddr  <= S_AXI_ARADDR;
      end
      else begin
        axi_arready <= 1'b0;
      end

    end 

  end       
  


  // Implement axi_arvalid generation
  // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
  // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
  // data are available on the axi_rdata bus at this instance. The 
  // assertion of axi_rvalid marks the validity of read data on the 
  // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
  // is deasserted on reset (active low). axi_rresp and axi_rdata are 
  // cleared to zero on reset (active low).  
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end 
    else begin    

      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
        // Valid read data is available at the read data bus
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b0; // 'OKAY' response
      end   
      else if (axi_rvalid && S_AXI_RREADY) begin
        // Read data is accepted by the master
        axi_rvalid <= 1'b0;
      end                

    end

  end    
  


  // Implement memory mapped register select and read logic generation
  // Slave register read enable is asserted when valid address is available
  // and the slave is ready to accept the read address.
  assign reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
  
  // Output register or memory read data
  // Word access only !!!
  always @(posedge S_AXI_ACLK) begin

    if (!S_AXI_ARESETN) begin
      axi_rdata  <= 0;
    end 
    else begin    

      // When there is a valid read address (S_AXI_ARVALID) with 
      // acceptance of read address by the slave (axi_arready), 
      // output the read dada 
      if (reg_rden) begin
          axi_rdata <= reg_data_out;     // register read data
      end   

    end

  end    
  
  // Read data Mux.
  always @(*) begin

    // Address decoding for reading registers
    case (axi_araddr[C_S_AXI_ADDR_WIDTH-1:0] )
      32'hA002_0000 : reg_data_out <= {30'h0, oReg0[1:0]};
      default       : reg_data_out <=  32'h0;
    endcase

  end
  
  

endmodule
