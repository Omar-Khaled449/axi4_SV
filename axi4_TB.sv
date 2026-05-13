import param_pkg::*;
import axi4_class::*;

module my_TB (
    axi4_if.master master
);

  axi4_pkt object;

  // Associative array that mimics the memory of slave
  logic [DATA_SIZE-1:0] golden_arr[logic [ADDR_SIZE-1:0]];

  typedef enum logic {
    write,
    read
  } op_e;

  op_e  operation = write;
  logic flag = 0;

  // ---------------------------------------------------------
  // Utility Tasks
  // ---------------------------------------------------------
  task automatic generate_stim(input axi4_pkt obj);
    assert (obj.randomize())
    else $fatal("Randomization failed.");
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

  task automatic golden_model(input axi4_pkt obj);
    int address = obj.AWADDR;
    for (int i = 0; i < obj.W_beats; i++) begin
      golden_arr[address] = obj.WDATA[i];
      address += 4;  // Assuming fixed 32-bit (4-byte) word alignment
    end
  endtask

  // ---------------------------------------------------------
  // Main Protocol Tasks
  // ---------------------------------------------------------
  task automatic write_op(input axi4_pkt obj, ref op_e op, ref logic flag);
    if (!flag) generate_stim(obj);

    if (op == write) begin
      // 1. WRITE ADDRESS PHASE
      @(posedge master.ACLK);
      master.AWADDR  <= obj.AWADDR;
      master.AWLEN   <= obj.AWLEN;
      master.AWSIZE  <= obj.AWSIZE;
      master.AWVALID <= 1'b1;

      do begin
        @(posedge master.ACLK);
      end while (master.AWREADY !== 1'b1);

      update_object(obj);
      obj.cg_packet.sample();
      master.AWVALID <= 1'b0;

      // 2. WRITE DATA PHASE
      for (int i = 0; i < obj.W_beats; i++) begin
        master.WDATA  <= obj.WDATA[i];
        master.WLAST  <= (i == (obj.W_beats - 1));
        master.WVALID <= 1'b1;

        do begin
          @(posedge master.ACLK);
        end while (master.WREADY !== 1'b1);

        obj.cg_beat.sample();
      end

      master.WVALID <= 1'b0;
      master.WLAST  <= 1'b0;
      golden_model(obj);  // Update scoreboard after successful drive

      // 3. RESPONSE PHASE
      master.BREADY <= 1'b1;
      do begin
        @(posedge master.ACLK);
      end while (master.BVALID !== 1'b1);

      update_object(obj);
      obj.cg_packet.sample();
      master.BREADY <= 1'b0;

      flag = 1'b1;
      op   = read;
    end
  endtask

  task automatic read_op(input axi4_pkt obj, ref op_e op, ref logic flag);
    int current_addr;  // Declared at the top of the scope

    if (!flag) generate_stim(obj);

    // 1. READ ADDRESS PHASE
    @(posedge master.ACLK);
    master.ARADDR  <= obj.ARADDR;
    master.ARLEN   <= obj.ARLEN;
    master.ARSIZE  <= obj.ARSIZE;
    master.ARVALID <= 1'b1;

    do begin
      @(posedge master.ACLK);
    end while (master.ARREADY !== 1'b1);

    update_object(obj);
    obj.cg_packet.sample();
    master.ARVALID <= 1'b0;

    // 2. READ DATA PHASE (Combined Handshake and Check)
    master.RREADY  <= 1'b1;
    current_addr = (!flag) ? int'(master.ARADDR) : int'(master.AWADDR);

    for (int i = 0; i < obj.R_beats; i++) begin
      do begin
        @(posedge master.ACLK);
      end while (master.RVALID !== 1'b1);

      // Scoreboard comparison at the exact moment of handshake
      if (golden_arr.exists(current_addr)) begin
        if (golden_arr[current_addr] == master.RDATA) begin
          $display("[PASS] Beat %0d: Expected %0h, Got %0h", i, golden_arr[current_addr],
                   master.RDATA);
        end else begin
          $error("[FAIL] Beat %0d: Expected %0h, Got %0h", i, golden_arr[current_addr],
                 master.RDATA);
        end
        current_addr += 4;
      end else begin
        $display("[WARN] Address %0h is empty in golden model", current_addr);
      end

      update_object(obj);
      obj.cg_beat.sample();
    end

    obj.cg_packet.sample();
    master.RREADY <= 1'b0;

    // Prepare for next transaction
    op   = op_e'($urandom_range(0, 1));
    flag = 1'b0;
  endtask

  task automatic protocol(input axi4_pkt obj, int size, ref op_e op, ref logic flag);
    for (int i = 0; i < size; i++) begin
      write_op(obj, op, flag);
      read_op(obj, op, flag);
    end
  endtask

  // ---------------------------------------------------------
  // Main Execution Block
  // ---------------------------------------------------------
  initial begin
    // Initialize interface signals to strictly adhere to protocol
    master.AWVALID = 1'b0;
    master.WVALID = 1'b0;
    master.ARVALID = 1'b0;
    master.RREADY = 1'b0;
    master.BREADY = 1'b0;
    master.WLAST = 1'b0;
    master.WDATA = '0;
    master.AWADDR = '0;
    master.ARADDR = '0;

    object = new();

    // Level-sensitive wait to ensure DUT is out of reset
    wait (master.ARESETn == 1'b1);

    // Start stimulus
    protocol(object, 50, operation, flag);
    $display("Simulation completed successfully.");
    $stop;
  end
endmodule
