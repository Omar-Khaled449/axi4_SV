import param_pkg::*;
import axi4_class::*;

module my_TB (
    axi4_if.master master
);

  axi4_pkt object;
  // Associative array that mimics the memory of slave
  logic [DATA_SIZE-1:0] golden_arr[logic [ADDR_SIZE-1:0]];



  //////////////////////////////    internal signsl to flag phase start and end   //////////////////////////////
  //////////////////////////////    internal signsl to flag phase start and end   //////////////////////////////
  //////////////////////////////    internal signsl to flag phase start and end   //////////////////////////////


  typedef enum logic {
    write,
    read
  } op_e;

  op_e  operation = write;
  logic flag = 0;



  ////////////////////////////////////    TASKS DEFINITIONS   ////////////////////////////////////
  ////////////////////////////////////    TASKS DEFINITIONS   ////////////////////////////////////
  ////////////////////////////////////    TASKS DEFINITIONS   ////////////////////////////////////

  task automatic generate_stim(input axi4_pkt obj);
    assert (obj.randomize())
    else $fatal("Randomization gone wrong");
  endtask

  task automatic update_object(input axi4_pkt obj);
    obj.AWVALID = master.AWVALID;
    obj.AWREADY = master.AWREADY;
    obj.WVALID = master.WVALID;
    obj.WREADY = master.WREADY;
    obj.ARVALID = master.ARVALID;
    obj.ARREADY = master.ARREADY;
    obj.RVALID = master.RVALID;
    obj.RREADY = master.RREADY;
    obj.BVALID = master.BVALID;
    obj.BRESP = axi_resp_e'(master.BRESP);
    obj.BREADY = master.BREADY;
    obj.WLAST = master.WLAST;
    obj.RLAST = master.RLAST;
    obj.RRESP = axi_resp_e'(master.RRESP);
    obj.sampled_rdata = master.RDATA;
    obj.sampled_wdata = master.WDATA;
  endtask

  task automatic drive_addr_write(input axi4_pkt obj);

    // master signals
    master.AWADDR = obj.AWADDR;
    master.AWLEN  = obj.AWLEN;
    master.AWSIZE = obj.AWSIZE;

  endtask

  task automatic drive_addr_read(input axi4_pkt obj);
    if (!flag) begin
      master.ARADDR = obj.ARADDR;
      master.ARLEN  = obj.ARLEN;
      master.ARSIZE = obj.ARSIZE;
    end else begin
      master.ARADDR = obj.AWADDR;
      master.ARLEN  = obj.AWLEN;
      master.ARSIZE = obj.AWSIZE;
      obj.R_beats   = obj.W_beats;
    end

  endtask

  task automatic drive_data(input axi4_pkt obj);
    master.WVALID = 1;
    @(negedge master.ACLK);
    for (int i = 0; i < obj.W_beats; i++) begin
      master.WDATA = obj.WDATA[i];
      if (i == (obj.WDATA.size() - 1)) master.WLAST = 1;
      wait (master.WREADY);
      update_object(obj);
      obj.cg.sample();
      @(negedge master.ACLK);
    end
    master.WVALID = 0;
    master.WLAST  = 0;
  endtask


  task automatic golden_model(input axi4_pkt obj);
    int unsigned address = (obj.AWADDR >> 2);  // MUST be unsigned

    for (int i = 0; i < obj.W_beats; i++) begin
      if (address < 1023) begin
        golden_arr[address] = obj.WDATA[i];
      end else begin
        $display("Golden Model: Write rejected by DUT at addr %h", address);
      end
      address++;
    end
  endtask


  //////////////////////////////////// CHECK DATA ///////////////////////////////////////////

  task automatic check_data(input axi4_pkt obj);
    int address;
    address = (!flag) ? int'(master.ARADDR >> 2) : int'(master.AWADDR >> 2);

    master.RREADY = 1;
    for (int i = 0; i < obj.R_beats; i++) begin
      @(posedge master.ACLK);
      while (!master.RVALID) @(posedge master.ACLK);

      if (master.RRESP == 2'b10) begin  // SLVERR
        if (master.RDATA === 32'h0000_0000) begin
          $display("ID: %0d, DUT safely blocked illegal read at address %h (SLVERR).", i, address);
        end else begin
          $error("ID: %0d, DUT threw SLVERR but leaked data %h at address %h", i, master.RDATA,
                 address);
        end
      end
      else begin
        if (golden_arr.exists(address)) begin
          if (golden_arr[address] == master.RDATA) begin
            $display("ID: %d , Correct READ: Expected data: %h, at address: %h Actual Data: %h", i,
                     golden_arr[address], address, master.RDATA);
          end else begin
            $error("ID: %d Expected data: %h at address: %h , Actual Data: %h", i,
                   golden_arr[address], address, master.RDATA);
          end
        end else begin
          $display("This memory location is empty");
        end
      end

      address++;
      update_object(obj);
      obj.cg.sample();
      if (i == obj.R_beats - 1) obj.cg.sample();
    end
    master.RREADY = 0;
  endtask




  task automatic write_op(input axi4_pkt obj, ref op_e op, ref logic flag);

    if (op == write) begin
      @(negedge master.ACLK);
      generate_stim(obj);

      // WRITE ADDRESS PHASE

      master.AWVALID = 1;
      drive_addr_write(obj);
      wait (master.AWREADY);
      update_object(obj);
      obj.cg.sample();
      @(negedge master.ACLK);
      master.AWVALID = 0;

      // DATA PHASE
      drive_data(obj);
      golden_model(obj);

      // RESPONSE PHASE
      master.BREADY = 1;
      wait (master.BVALID);
      update_object(obj);
      obj.cg.sample();
      @(negedge master.ACLK);
      master.BREADY = 0;
      flag = 1;
      op = read;
    end

  endtask

  task automatic read_op(input axi4_pkt obj, ref op_e op, ref logic flag);

    if (op == read) begin
      if (!flag) generate_stim(obj);

      // READ ADDRESS PHASE
      master.ARVALID = 1;
      drive_addr_read(obj);
      wait (master.ARREADY);
      update_object(obj);
      obj.cg.sample();
      @(negedge master.ACLK);
      master.ARVALID = 0;

      // READ DATA PHASE
      check_data(obj);
      master.RREADY = 0;

      //WRITE BACK READ
      op = write;
      flag = 0;
    end
  endtask

  task automatic protocol(input axi4_pkt obj, int size, ref op_e op, ref logic flag);

    for (int i = 0; i < size; i++) begin
      $display("Transaction no.: %0d, operation: %s", i, op.name());
      write_op(obj, op, flag);
      read_op(obj, op, flag);
    end
  endtask

  initial begin
    master.AWVALID = 0;
    master.WVALID = 0;
    master.ARVALID = 0;
    master.RREADY = 0;
    master.BREADY = 0;
    master.WLAST = 0;
    master.WDATA = 0;
    master.AWADDR = 0;
    master.ARADDR = 0;
    object = new();
    wait (master.ARESETn);
    @(negedge master.ACLK);
    protocol(object, 2000, operation, flag);
    $stop;
  end
endmodule
