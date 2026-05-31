import param_pkg::*;
`include "mem_class.sv"
module mem_TB (
    axi4_if.mem_ctrl mem
);

  mem_class object;
  logic [DATA_SIZE-1:0] golden_memory[logic [MEM_ADDR_SIZE-1:0]];


  task automatic generate_stimulus(mem_class obj);

    assert (obj.randomize())
    else $fatal("Error randomizing");

  endtask

  task automatic drive_stim(mem_class obj);
    mem.mem_en    = obj.mem_en;
    mem.mem_we    = obj.mem_we;
    mem.mem_addr  = obj.mem_addr;
    mem.mem_wdata = obj.mem_wdata;
  endtask

  task automatic collect_out(mem_class obj);
    obj.mem_rdata = mem.mem_rdata;
  endtask

  task automatic golden_model(mem_class obj);
    if (obj.mem_we && obj.mem_en) golden_memory[obj.mem_addr] = obj.mem_wdata;
  endtask

  task automatic check_write(mem_class obj);
    if (golden_memory.exists(obj.mem_addr)) begin
      if (golden_memory[obj.mem_addr] == obj.mem_wdata)
        $display(
            "Correct Write: Address is: %h ,Write data : %h, golden_arr write data: %h",
            obj.mem_addr,
            obj.mem_wdata,
            golden_memory[obj.mem_addr]
        );
    end else begin
      $error("Write data : %h and Read data is: %h", obj.mem_wdata, golden_memory[obj.mem_addr]);
    end
  endtask

  task automatic check_read(mem_class obj);
    if (golden_memory.exists(obj.mem_addr)) begin
      if (golden_memory[obj.mem_addr] == obj.mem_rdata) begin

        $display("Correct Read: Address is: %h ,Read data : %h, golden_arr Read data: %h",
                 obj.mem_addr, obj.mem_rdata, golden_memory[obj.mem_addr]);
      end else begin

        $error("Adrress: %h, Read data : %h and golden_arr read is: %h", obj.mem_addr,
               obj.mem_rdata, golden_memory[obj.mem_addr]);
      end
    end else begin
      $display("This address is empty");
    end

  endtask


  task automatic send_and_check(int size, mem_class obj);
    wait (mem.ARESETn == 1);
    @(negedge mem.ACLK);
    for (int i = 0; i < size; i++) begin

      @(negedge mem.ACLK);
      generate_stimulus(obj);
      drive_stim(obj);
      golden_model(obj);
      @(negedge mem.ACLK);
      collect_out(obj);

      if (obj.mem_we && obj.mem_en) check_write(obj);
      else check_read(obj);

      obj.cg.sample();
      obj.last_addr = obj.mem_addr;
      obj.last_we   = obj.mem_we;
      obj.last_en   = obj.mem_en;
    end
  endtask




  initial begin


    object = new();
    object.integrity_mode = 1;
    send_and_check(50, object);
    $stop;
  end

endmodule
