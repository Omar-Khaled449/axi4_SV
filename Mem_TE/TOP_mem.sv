module TOP_mem;
  bit   clk = 0;
  logic rst_n = 1;

  initial begin
    forever begin
      #5ns clk = ~clk;
    end
  end

  initial begin
    rst_n = 0;
    #20ns rst_n = 1;
  end

  axi4_if intf (
      clk,
      rst_n

  );
  mem_TB test (intf.mem_ctrl);
  my_axi4_memory dut (intf.mem_ram);
endmodule
