
module my_axi4_memory (
    axi4_if.mem_ram mem
);

  parameter DATA_WIDTH = mem.DATA_WIDTH;
  parameter ADDR_WIDTH = mem.MEM_ADDR_WIDTH;  // For 1024 locations
  parameter DEPTH = mem.DEPTH;
  // Memory array
  reg [mem.DATA_WIDTH-1:0] memory[0:DEPTH-1];


  integer j;

  // Memory write
  always @(posedge mem.ACLK) begin
    if (!mem.ARESETn) mem.mem_rdata <= 0;
    else if (mem.mem_en) begin  // the condition was made opposite so it never wrote any data
      if (mem.mem_we) memory[mem.mem_addr] <= mem.mem_wdata;
      else
        mem.mem_rdata <= memory[mem.mem_addr]; // (& 'hF0) this was a mistake that made all values = 0
    end
  end

  // Initialize memory
  initial begin
    for (j = 0; j < mem.DEPTH; j = j + 1) memory[j] = 0;
  end

endmodule
