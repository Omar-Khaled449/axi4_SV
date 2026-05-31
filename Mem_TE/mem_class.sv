import param_pkg::*;

class mem_class;
  rand logic mem_en;
  rand logic mem_we;
  rand logic [MEM_ADDR_SIZE-1:0] mem_addr;
  rand logic [DATA_SIZE-1:0] mem_wdata;
  logic [DATA_SIZE-1:0] mem_rdata;
  logic [MEM_ADDR_SIZE-1:0] last_addr;
  logic integrity_mode = 0;
  logic last_we = 0;
  logic last_en = 0;


  constraint mem_en_c {
    mem_en dist {
      {1'b1} :/ 90,
      {1'b0} :/ 10
    };
  }
  constraint mem_addr_c {
    this.mem_addr dist {
      {10'd0} :/ 5,
      {10'd1023} :/ 5,
      [10'd1 : 10'd1022] :/ 90
    };
  }

  function void post_randomize();
    if (this.last_we && this.last_en) begin
      this.mem_addr = this.last_addr;
      this.mem_we   = 0;
      this.mem_en   = 1;
    end

  endfunction

  /*
  constraint mem_we_c {
        mem_we == {1'b0};
    }
    */

  covergroup cg;
    option.auto_bin_max = 0;
    mem_en: coverpoint mem_en {
      bins zero = {1'b0}; bins one = {1'b1}; bins one_to_one = (1'b1 => 1'b1);
    }

    mem_we: coverpoint mem_we {
      bins zero = {1'b0};
      bins one = {1'b1};
      bins one_to_zero = (1'b1 => 1'b0);
      bins zero_to_one = (1'b0 => 1'b1);
    }


    addr: coverpoint mem_addr {
      bins max = {10'd1023}; bins min = {10'd0}; bins mid = {[10'd1 : 10'd1022]};
    }

    Read_Write: cross mem_en, mem_we{

      ignore_bins ignore = binsof (mem_en.zero);
      bins read = binsof (mem_en.one) && binsof (mem_we.zero);
      bins write = binsof (mem_en.one) && binsof (mem_we.one);
      bins read_to_write = binsof (mem_en.one_to_one) && binsof (mem_we.zero_to_one);
      bins write_to_read = binsof (mem_en.one_to_one) && binsof (mem_we.one_to_zero);
    }
  endgroup

  function new();
    cg = new();
  endfunction
endclass
