import param_pkg::*;

interface axi4_if #(
    parameter ADDR_WIDTH     = ADDR_SIZE,
    parameter DATA_WIDTH     = DATA_SIZE,
    parameter DEPTH          = DEPTH_SIZE,
    parameter MEM_ADDR_WIDTH = MEM_ADDR_SIZE
) (
    input ACLK,
    input bit ARESETn
);


  //////// WRITE signals ////////////

  logic [ADDR_WIDTH-1:0] AWADDR;
  logic [7:0] AWLEN;
  logic [2:0] AWSIZE;
  logic AWVALID;
  logic AWREADY;
  logic [DATA_WIDTH-1:0] WDATA;
  logic WVALID;
  logic WLAST;
  logic WREADY;
  logic [1:0] BRESP;
  logic BVALID;
  logic BREADY;

  //////// READ signals ////////////

  logic [ADDR_WIDTH-1:0] ARADDR;
  logic [7:0] ARLEN;
  logic [2:0] ARSIZE;
  logic ARVALID;
  logic ARREADY;
  logic [DATA_WIDTH-1:0] RDATA;
  logic [1:0] RRESP;
  logic RVALID;
  logic RLAST;
  logic RREADY;

  //////// MEMORY signals ////////////

  logic mem_en;
  logic mem_we;
  logic [MEM_ADDR_WIDTH-1:0] mem_addr;
  logic [DATA_WIDTH-1:0] mem_wdata;
  logic [DATA_WIDTH-1:0] mem_rdata;

  modport slave(
      input ACLK, ARESETn, AWADDR, AWLEN, AWSIZE, AWVALID, WDATA, WVALID, WLAST,
            BREADY, ARADDR, ARLEN, ARSIZE, ARVALID, RREADY,
      output AWREADY, WREADY, BRESP, BVALID, ARREADY, RDATA, RRESP, RVALID, RLAST
  );
  modport master(
      output AWADDR, AWLEN, AWSIZE, AWVALID, WDATA, WVALID, WLAST, BREADY, ARADDR, ARLEN, ARSIZE, ARVALID, RREADY,
      input ACLK, ARESETn, AWREADY, WREADY, BRESP, BVALID, ARREADY, RDATA, RRESP, RVALID, RLAST
  );

  modport mem_ram(input ACLK, ARESETn, mem_en, mem_we, mem_addr, mem_wdata, output mem_rdata);

  modport mem_ctrl(output mem_en, mem_we, mem_addr, mem_wdata, input mem_rdata, ACLK, ARESETn);


  property P_AWADDR;
    @(posedge ACLK) disable iff (!ARESETn) $rose(AWVALID) |-> ##[0:$] AWVALID && AWREADY;
  endproperty

  property P_WDATA;
    @(posedge ACLK) disable iff (!ARESETn) $rose(WVALID) |-> ##[0:$] WVALID && WREADY;
  endproperty

  property P_WRESP;
    @(posedge ACLK) disable iff (!ARESETn) $rose(BVALID) |-> ##[0:$] BVALID && BREADY;
  endproperty

  property P_ARADDR;
    @(posedge ACLK) disable iff (!ARESETn) $rose(ARVALID) |-> ##[0:$] ARVALID && ARREADY;
  endproperty

  property P_RDATA;
    @(posedge ACLK) disable iff (!ARESETn) $rose(RVALID) |-> ##[0:$] RVALID && RREADY;
  endproperty



  AWADDR_handshake :
  assert property (P_AWADDR);  // Address write handshake
  WDATA_handshake :
  assert property (P_WDATA);  // Write data handshake
  WRESP_handshake :
  assert property (P_WRESP);  // Write response handshake
  ARADDR_handshake :
  assert property (P_ARADDR); // Address Read handshake
  RDATA_handshake :
  assert property (P_RDATA);  // Read data handshake

endinterface


