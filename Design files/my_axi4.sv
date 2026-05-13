module my_axi4 (
    axi4_if.slave slave,
    axi4_if.mem_ctrl memory
);

  parameter DATA_WIDTH = slave.DATA_WIDTH;
  parameter ADDR_WIDTH = slave.ADDR_WIDTH;
  parameter MEMORY_DEPTH = slave.DEPTH;


  // Address and burst management
  reg [ADDR_WIDTH-1:0] write_addr, read_addr;
  reg [7:0] write_burst_len, read_burst_len;
  reg [7:0] write_burst_cnt, read_burst_cnt;
  reg [2:0] write_size, read_size;

  wire [ADDR_WIDTH-1:0] write_addr_incr, read_addr_incr;

  // Address increment calculation
  assign write_addr_incr = (1 << write_size);
  assign read_addr_incr = (1 << read_size);

  // Address boundary check (4KB boundary = 12 bits)
  assign write_boundary_cross = ((write_addr & 12'hFFF) + (write_burst_cnt << write_size)) > 12'hFFF;
  assign read_boundary_cross = ((read_addr & 12'hFFF) + (read_burst_cnt << read_size)) > 12'hFFF;

  // Address range check
  assign write_addr_valid = (write_addr >> 2) < MEMORY_DEPTH;
  assign read_addr_valid = (read_addr >> 2) < MEMORY_DEPTH;

  // FSM states
  reg [2:0] write_state;
  localparam W_IDLE = 3'd0, W_ADDR = 3'd1, W_DATA = 3'd2, W_RESP = 3'd3;

  reg [2:0] read_state;
  localparam R_IDLE = 3'd0, R_ADDR = 3'd1, R_WAIT = 3'd2, R_DATA = 3'd3;

  // Registered memory read data for timing
  reg [DATA_WIDTH-1:0] mem_rdata_reg;

  always @(posedge slave.ACLK or negedge slave.ARESETn) begin
    if (!slave.ARESETn) begin
      // Reset all outputs
      slave.AWREADY    <= 1'b1;
      slave.WREADY     <= 1'b0;
      slave.BVALID     <= 1'b0;
      slave.BRESP      <= 2'b00;

      slave.ARREADY    <= 1'b1;
      slave.RVALID     <= 1'b0;
      slave.RRESP      <= 2'b00;
      slave.RDATA      <= {DATA_WIDTH{1'b0}};
      slave.RLAST      <= 1'b0;

      // Reset internal state
      write_state      <= W_IDLE;
      read_state       <= R_IDLE;
      memory.mem_en    <= 1'b0;
      memory.mem_we    <= 1'b0;
      memory.mem_addr  <= {$clog2(MEMORY_DEPTH) {1'b0}};
      memory.mem_wdata <= {DATA_WIDTH{1'b0}};

      // Reset address tracking
      write_addr       <= {ADDR_WIDTH{1'b0}};
      read_addr        <= {ADDR_WIDTH{1'b0}};
      write_burst_len  <= 8'b0;
      read_burst_len   <= 8'b0;
      write_burst_cnt  <= 8'b0;
      read_burst_cnt   <= 8'b0;
      write_size       <= 3'b0;
      read_size        <= 3'b0;

      mem_rdata_reg    <= {DATA_WIDTH{1'b0}};

    end else begin
      // Default memory disable
      memory.mem_en <= 1'b0;
      memory.mem_we <= 1'b0;

      // --------------------------
      // Write Channel FSM
      // --------------------------
      case (write_state)
        W_IDLE: begin
          slave.AWREADY <= 1'b1;
          slave.WREADY  <= 1'b0;
          slave.BVALID  <= 1'b0;

          if (slave.AWVALID && slave.AWREADY) begin
            write_addr      <= slave.AWADDR;
            write_burst_len <= slave.AWLEN;
            write_burst_cnt <= slave.AWLEN;
            write_size      <= slave.AWSIZE;

            slave.AWREADY   <= 1'b0;
            write_state     <= W_ADDR;
          end
        end

        W_ADDR: begin
          slave.WREADY <= 1'b1;
          write_state  <= W_DATA;
        end

        W_DATA: begin
          if (slave.WVALID && slave.WREADY) begin
            if (write_addr_valid && !write_boundary_cross) begin
              memory.mem_en    <= 1'b1;
              memory.mem_we    <= 1'b1;
              memory.mem_addr  <= write_addr >> 2;
              memory.mem_wdata <= slave.WDATA;
            end

            if (slave.WLAST || write_burst_cnt == 0) begin
              slave.WREADY <= 1'b0;
              write_state  <= W_RESP;

              if (!write_addr_valid || write_boundary_cross) begin
                slave.BRESP <= 2'b10;  // SLVERR
              end else begin
                slave.BRESP <= 2'b00;  // OKAY
              end
              slave.BVALID <= 1'b1;
            end else begin
              write_addr      <= write_addr + write_addr_incr;
              write_burst_cnt <= write_burst_cnt - 1'b1;
            end
          end
        end

        W_RESP: begin
          if (slave.BREADY && slave.BVALID) begin
            slave.BVALID <= 1'b0;
            slave.BRESP  <= 2'b00;
            write_state  <= W_IDLE;
          end
        end

        default: write_state <= W_IDLE;
      endcase

      // --------------------------
      // Read Channel FSM
      // --------------------------
      case (read_state)
        R_IDLE: begin
          slave.ARREADY <= 1'b1;
          slave.RVALID  <= 1'b0;
          slave.RLAST   <= 1'b0;

          if (slave.ARVALID && slave.ARREADY) begin
            read_addr      <= slave.ARADDR;
            read_burst_len <= slave.ARLEN;
            read_burst_cnt <= slave.ARLEN;
            read_size      <= slave.ARSIZE;

            slave.ARREADY  <= 1'b0;
            read_state     <= R_ADDR;
          end
        end

        R_ADDR: begin
          if (read_addr_valid && !read_boundary_cross) begin
            memory.mem_en   <= 1'b1;
            memory.mem_addr <= read_addr >> 2;
          end
          read_state <= R_WAIT;  //  added this to Wait for memory fetch
        end

        R_WAIT: begin  // new added state
          read_state <= R_DATA;  // Data is now valid on memory.mem_rdata
        end

        R_DATA: begin
          if (read_addr_valid && !read_boundary_cross) begin
            slave.RDATA <= memory.mem_rdata;
            slave.RRESP <= 2'b00;  // OKAY
          end else begin
            slave.RDATA <= {DATA_WIDTH{1'b0}};
            slave.RRESP <= 2'b10;  // SLVERR
          end

          slave.RVALID <= 1'b1;
          slave.RLAST  <= (read_burst_cnt == 0);

          if (slave.RREADY && slave.RVALID) begin
            slave.RVALID <= 1'b0;

            if (read_burst_cnt > 0) begin
              read_addr      <= read_addr + read_addr_incr;
              read_burst_cnt <= read_burst_cnt - 1'b1;

              if (read_addr_valid && !read_boundary_cross) begin
                memory.mem_en   <= 1'b1;
                memory.mem_addr <= (read_addr + read_addr_incr) >> 2;
              end

              read_state <= R_WAIT;

              // Stay in R_DATA for next transfer
            end else begin
              slave.RLAST <= 1'b0;
              read_state  <= R_IDLE;
            end
          end
        end

        default: read_state <= R_IDLE;
      endcase
    end
  end

endmodule
