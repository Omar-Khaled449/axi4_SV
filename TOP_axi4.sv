module TOP_axi4;
  bit clk = 0;
  bit rst_n;

  initial begin
    forever begin
      #5ns clk = ~clk;
    end
  end

  initial begin
    rst_n = 0;
    #20ns rst_n = 1;
  end

  axi4_if axi_inf (
      .ACLK(clk),
      .ARESETn(rst_n)
  );
  my_TB TB (axi_inf.master);
  my_axi4_memory memory (axi_inf.mem_ram);
  my_axi4 dut (axi_inf.slave, axi_inf.mem_ctrl);

endmodule
