package param_pkg;
  parameter ADDR_SIZE = 16;
  parameter DATA_SIZE = 32;
  parameter DEPTH_SIZE = 1024;
  parameter MEM_ADDR_SIZE = 10;

  typedef enum logic [1:0] {
    OKAY   = 2'b00,
    EXOKAY = 2'b01,
    SLVERR = 2'b10,
    DECERR = 2'b11
  } axi_resp_e;
endpackage
