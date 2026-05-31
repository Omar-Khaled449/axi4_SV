package axi4_class;

  import param_pkg::*;

  class axi4_pkt;

    /////////////////////////////////////////////////////////
    // 1. WRITE SIGNALS
    /////////////////////////////////////////////////////////
    rand logic [ADDR_SIZE-1:0] AWADDR;
    rand logic [          7:0] AWLEN;
    rand logic [          2:0] AWSIZE;
    logic                      AWVALID;
    logic                      AWREADY;

    rand logic [DATA_SIZE-1:0] WDATA         [];
    logic                      WVALID;
    logic                      WLAST;
    logic                      WREADY;

    axi_resp_e                 BRESP;
    logic                      BVALID;
    logic                      BREADY;

    /////////////////////////////////////////////////////////
    // 2. READ SIGNALS
    /////////////////////////////////////////////////////////
    rand logic [ADDR_SIZE-1:0] ARADDR;
    rand logic [          7:0] ARLEN;
    rand logic [          2:0] ARSIZE;
    logic                      ARVALID;
    logic                      ARREADY;

    logic      [DATA_SIZE-1:0] RDATA         [];
    axi_resp_e                 RRESP;
    logic                      RVALID;
    logic                      RLAST;
    logic                      RREADY;

    /////////////////////////////////////////////////////////
    // 3. INTERNAL VARIABLES & HELPERS
    /////////////////////////////////////////////////////////
    int                        W_beats;
    int                        R_beats;

    logic      [DATA_SIZE-1:0] sampled_wdata;
    logic      [DATA_SIZE-1:0] sampled_rdata;
    int                        last_addr;

    function void post_randomize();
      this.W_beats = AWLEN + 1;
      this.R_beats = ARLEN + 1;
      this.RDATA   = new[ARLEN + 1];
    endfunction


    /////////////////////////////////////////////////////////
    // 4. WRITE CONSTRAINTS
    /////////////////////////////////////////////////////////
    constraint wsize_c {AWSIZE == 3'd2;}

    constraint awaddr_c {
      AWADDR dist {
        16'd0              := 5,  // 5% chance of hitting min address
        16'd4092           := 5,  // 5% chance of hitting max valid word address
        [16'd1 : 16'd4091] :/ 90  // 90% normal randomization
      };
    }

    constraint wlen_c {
      AWLEN dist {
        8'd0            := 5,  // 5% chance of 1 beat
        8'd255          := 5,  // 5% chance of 256 beats
        [8'd1 : 8'd254] :/ 90
      };
    }

    constraint wdata_c {
      WDATA.size() == AWLEN + 1;
      foreach (WDATA[i]) {WDATA[i] inside {[32'h0000_0000 : 32'hFFFF_FFFF]};}
    }


    /////////////////////////////////////////////////////////
    // 5. READ CONSTRAINTS
    /////////////////////////////////////////////////////////
    constraint arsize_c {ARSIZE == 3'd2;}

    constraint araddr_c {
      ARADDR dist {
        16'd0              := 5,
        16'd4092           := 5,
        [16'd1 : 16'd4091] :/ 90
      };
    }

    constraint arlen_c {
      ARLEN dist {
        8'd0            := 5,
        8'd255          := 5,
        [8'd1 : 8'd254] :/ 90
      };
    }


    /////////////////////////////////////////////////////////
    // 6. COVERGROUP
    /////////////////////////////////////////////////////////
    covergroup cg;
      option.auto_bin_max = 0;  // Remove automatic bins globally
      option.per_instance = 1;  // Highly recommended for class-based covergroups

      // ====================================================
      // WRITE PHASE COVERAGE
      // ====================================================

      // -- Write Address Handshake --
      master_AWvalid: coverpoint AWVALID {
        bins one = {1'b1}; bins zero = {1'b0};
      }
      slave_AWready: coverpoint AWREADY {bins one = {1'b1}; bins zero = {1'b0};}

      W_addr_handshake: cross master_AWvalid, slave_AWready{
        option.cross_auto_bin_max = 0;
        bins addr = binsof (master_AWvalid.one) && binsof (slave_AWready.one);
        ignore_bins ignore_zeros = binsof (master_AWvalid.zero) || binsof (slave_AWready.zero);
      }

      // -- Write Data Handshake --
      master_Wvalid: coverpoint WVALID {
        bins one = {1'b1}; bins zero = {1'b0};
      }
      slave_Wready: coverpoint WREADY {bins one = {1'b1}; bins zero = {1'b0};}
      W_last: coverpoint WLAST {bins one = {1'b1}; bins zero = {1'b0};}

      write_handshake: cross master_Wvalid, slave_Wready, W_last{
        option.cross_auto_bin_max = 0;
        bins write_start = binsof(slave_Wready.one) && binsof(master_Wvalid.one) && binsof(W_last.zero);
        bins write_end   = binsof(slave_Wready.one) && binsof(master_Wvalid.one) && binsof(W_last.one);
        ignore_bins ignore_zeros = binsof (master_Wvalid.zero) || binsof (slave_Wready.zero);
      }

      // -- Write Response Handshake --
      Bvalid_cv: coverpoint BVALID {
        bins one = {1'b1}; bins zero = {1'b0};
      }
      Bready_cv: coverpoint BREADY {bins one = {1'b1}; bins zero = {1'b0};}

      Bresp_check: cross Bready_cv, Bvalid_cv{
        option.cross_auto_bin_max = 0;
        bins resp_done = binsof (Bready_cv.one) && binsof (Bvalid_cv.one);
        ignore_bins ignore_zeros = binsof (Bready_cv.zero) || binsof (Bvalid_cv.zero);
      }

      // -- Write Protocol Vectors --
      W_address_regions: coverpoint AWADDR {
        bins w_addr_min = {16'd0};
        bins w_addr_low = {[16'd1 : 16'd1000]};
        bins w_addr_mid = {[16'd1001 : 16'd3000]};
        bins w_addr_high = {[16'd3001 : 16'd4091]};
        bins w_addr_max = {16'd4092};
      }

      W_burst_length: coverpoint AWSIZE {
        bins w_size = {3'd2}; illegal_bins illegal_w = {[3'd0 : 3'd1], [3'd3 : 3'd7]};
      }

      w_len: coverpoint AWLEN {
        bins w_len_min = {8'd0};
        bins w_len_low = {[8'd1 : 8'd80]};
        bins w_len_mid = {[8'd81 : 8'd160]};
        bins w_len_high = {[8'd161 : 8'd254]};
        bins w_len_max = {8'd255};
      }

      w_resp: coverpoint BRESP {bins okay = {OKAY}; bins slverr = {SLVERR};}

      write_boundary: cross w_len, W_address_regions, w_resp{
        option.cross_auto_bin_max = 0;
        bins max  = binsof(w_len.w_len_max) && binsof(W_address_regions.w_addr_max) && binsof(w_resp.slverr);
        bins max_ = binsof(w_len.w_len_max) && binsof(W_address_regions.w_addr_min) && binsof(w_resp.okay);
        bins mid_ = binsof(w_len.w_len_mid) && binsof(W_address_regions.w_addr_min) && binsof(w_resp.okay);
        bins min_ = binsof(w_len.w_len_min) && binsof(W_address_regions.w_addr_min) && binsof(w_resp.okay);
      }


      // ====================================================
      // READ PHASE COVERAGE
      // ====================================================

      // -- Read Address Handshake --
      master_ARvalid: coverpoint ARVALID {
        bins one = {1'b1}; bins zero = {1'b0};
      }
      slave_ARready: coverpoint ARREADY {bins one = {1'b1}; bins zero = {1'b0};}

      R_addr_handshake: cross master_ARvalid, slave_ARready{
        option.cross_auto_bin_max = 0;
        bins addr_done = binsof (master_ARvalid.one) && binsof (slave_ARready.one);
        ignore_bins ignore_zeros = binsof (master_ARvalid.zero) || binsof (slave_ARready.zero);
      }

      // -- Read Data Handshake --
      master_Rready: coverpoint RREADY {
        bins one = {1'b1}; bins zero = {1'b0};
      }
      slave_Rvalid: coverpoint RVALID {bins one = {1'b1}; bins zero = {1'b0};}
      R_last: coverpoint RLAST {bins one = {1'b1}; bins zero = {1'b0};}

      read_handshake: cross slave_Rvalid, master_Rready, R_last{
        option.cross_auto_bin_max = 0;
        bins read_start = binsof(master_Rready.one) && binsof(slave_Rvalid.one) && binsof(R_last.zero);
        bins read_end   = binsof(master_Rready.one) && binsof(slave_Rvalid.one) && binsof(R_last.one);
        ignore_bins ignore_zeros = binsof (master_Rready.zero) || binsof (slave_Rvalid.zero);
      }

      // -- Read Protocol Vectors --
      R_address_regions: coverpoint ARADDR {
        bins r_addr_min = {16'd0};
        bins r_addr_low = {[16'd1 : 16'd1000]};
        bins r_addr_mid = {[16'd1001 : 16'd3000]};
        bins r_addr_high = {[16'd3001 : 16'd4091]};
        bins r_addr_max = {16'd4092};
      }

      R_burst_length: coverpoint ARSIZE {
        bins r_size = {3'd2}; illegal_bins illegal_r = {[3'd0 : 3'd1], [3'd3 : 3'd7]};
      }

      r_len: coverpoint ARLEN {
        bins r_len_min = {8'd0};
        bins r_len_low = {[8'd1 : 8'd80]};
        bins r_len_mid = {[8'd81 : 8'd160]};
        bins r_len_high = {[8'd161 : 8'd254]};
        bins r_len_max = {8'd255};
      }

      r_resp: coverpoint RRESP {bins okay = {OKAY}; bins slverr = {SLVERR};}

      read_boundary: cross r_len, R_address_regions, r_resp{
        option.cross_auto_bin_max = 0;
        bins max  = binsof(r_len.r_len_max) && binsof(R_address_regions.r_addr_max) && binsof(r_resp.slverr);
        bins max_ = binsof(r_len.r_len_max) && binsof(R_address_regions.r_addr_min) && binsof(r_resp.okay);
        bins mid_ = binsof(r_len.r_len_mid) && binsof(R_address_regions.r_addr_min) && binsof(r_resp.okay);
        bins min_ = binsof(r_len.r_len_min) && binsof(R_address_regions.r_addr_min) && binsof(r_resp.okay);
      }

    endgroup

    function new();
      cg = new();
    endfunction

  endclass
endpackage
