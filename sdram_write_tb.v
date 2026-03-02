`timescale 1ns / 1ps

module tb_sdram_write;
  reg sys_clk     = 0;
  reg sys_reset_n = 0;

  // Clock: 100 MHz (Period = 10ns)
  always #5 sys_clk = ~sys_clk;

  // Reset pulse for 3 clock cycles
  initial begin
    sys_reset_n <= 0;
    repeat(3) @(posedge sys_clk);
    sys_reset_n <= 1;
  end

  initial begin
        $dumpfile("sdram_write.vcd");
        $dumpvars(0);
    end

  // SDRAM Initialization Module Signals
  wire [3:0]  init_cmd;
  wire [1:0]  init_ba;
  wire [11:0] init_addr;
  wire        init_done;

  sdram_init sdram_init_inst (
    .sys_clk     (sys_clk),        
    .sys_reset_n   (sys_reset_n),    
    .init_cmd_out    (init_cmd),     
    .init_bank_out     (init_ba),      
    .init_addr_out   (init_addr),    
    .init_done   (init_done)     
  );

  // DUT Inputs
  reg         wr_en;
  reg [24:0]  wr_addr_in;
  reg [15:0]  wr_data_in;
  reg [9:0]   burst_len_in;
  reg         dqm_in;

  // DUT Outputs
  wire        ack_out;         // Replaces apply_data
  wire        burst_done_out;  // Replaces wr_end
  wire [3:0]  wr_cmd_out;
  wire [1:0]  wr_bank_out;
  wire [11:0] wr_addr_out;
  wire        dqm_out;
  wire [15:0] wr_data_out;

  // DUT Instance
  sdram_write dut (
    .sys_clk       (sys_clk),
    .sys_reset_n   (sys_reset_n),
    .init_done     (init_done),
    .wr_en         (wr_en),
    .wr_addr_in    (wr_addr_in),
    .wr_data_in    (wr_data_in),
    .burst_len_in  (burst_len_in),
    .dqm_in        (dqm_in),
    .ack_out       (ack_out),
    .burst_done_out(burst_done_out),
    .wr_cmd_out    (wr_cmd_out),
    .wr_bank_out   (wr_bank_out),
    .wr_addr_out   (wr_addr_out),
    .dqm_out       (dqm_out),
    .wr_data_out   (wr_data_out)
  );

  // addr/cmd multiplexer
  wire [3:0]  cmd;
  wire [1:0]  ba;
  wire [11:0] addr;

  assign cmd  = (init_done) ? wr_cmd_out  : init_cmd;
  assign ba   = (init_done) ? wr_bank_out : init_ba;
  assign addr = (init_done) ? wr_addr_out : init_addr;

  sdram_model_plus sdram_model_plus_inst (
    .Dq     (wr_data_out), // Using the output data bus from DUT
    .Addr   (addr),
    .Ba     (ba),
    .Clk    (sys_clk),
    .Cke    (1'b1),
    .Cs_n   (cmd[3]),
    .Ras_n  (cmd[2]),
    .Cas_n  (cmd[1]),
    .We_n   (cmd[0]),
    .Dqm    (dqm_out),
    .Debug  (1'b1)
  );


  // Write Operation Stimulus
  initial begin
    wr_en        = 0;
    wr_addr_in   = 0;
    wr_data_in   = 0;
    burst_len_in = 0;
    dqm_in       = 0;

    @(posedge init_done);
    @(posedge sys_clk);

    // Begin Write Operation
    wr_en        <= 1;
    // Bank=3, Row=1, Col=1, Auto-precharge=1
    wr_addr_in   <= 25'b11_000000000001_1_00_00000001;
    wr_data_in <= 16'h01;
    burst_len_in <= 10'd8;
    dqm_in       <= 0;

    repeat(15) begin
      @(posedge sys_clk);
      wr_data_in <= wr_data_in + 1;
    end

    @(posedge sys_clk);
    wr_en <= 0;

    wait(burst_done_out);
    repeat (5) @(posedge sys_clk);

    $display("Simulation Finished Successfully");
    $finish;
  end

endmodule