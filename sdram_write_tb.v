`timescale 1ns / 1ps

module tb_sdram_write;

  reg sys_clk   = 0;
  reg sys_reset_n = 0;
  reg wr_wait   = 0;

  // Clock: 100 MHz (Period = 10ns)
  always #5 sys_clk = ~sys_clk;

  // Reset pulse
  initial begin
    sys_reset_n = 0;
    repeat(3) @(posedge sys_clk);
    sys_reset_n <= 1;
  end

  initial begin
        $dumpfile("sdram_write.vcd");
        $dumpvars(0);
    end

  wire [3:0]  init_cmd_out;
  wire [1:0]  init_bank_out;
  wire [11:0] init_addr_out;
  wire        init_done;

  sdram_init sdram_init_inst (
    .sys_clk       (sys_clk),
    .sys_reset_n   (sys_reset_n),
    .init_cmd_out  (init_cmd_out),
    .init_bank_out (init_bank_out),
    .init_addr_out (init_addr_out),
    .init_done     (init_done)
  );

  reg         wr_en;
  reg [24:0]  wr_addr_in;
  reg [15:0]  wr_data_in;
  reg [8:0]   burst_len_in;
  reg         dqm_in;

  wire        ack_out;
  wire        apply_data;
  wire        wr_end;
  wire [3:0]  wr_cmd_out;
  wire [1:0]  wr_bank_out;
  wire [11:0] wr_addr_out;
  wire        dqm_out;
  wire [15:0] wr_data_out;
  wire        wr_err;

  sdram_write dut (
    .sys_clk        (sys_clk),
    .sys_reset_n    (sys_reset_n),
    .init_done      (init_done),
    .wr_en          (wr_en),
    .wr_addr_in     (wr_addr_in),
    .wr_data_in     (wr_data_in),
    .burst_len_in   (burst_len_in),
    .dqm_in         (dqm_in),
    .wr_wait        (wr_wait),
    .ack_out        (ack_out),
    .apply_data     (apply_data),
    .wr_end (wr_end),
    .wr_cmd_out     (wr_cmd_out),
    .wr_bank_out    (wr_bank_out),
    .wr_addr_out    (wr_addr_out),
    .dqm_out        (dqm_out),
    .wr_data_out    (wr_data_out),
    .wr_err      (wr_err)
  );

  wire [3:0]  cmd  = (init_done) ? wr_cmd_out  : init_cmd_out;
  wire [1:0]  ba   = (init_done) ? wr_bank_out : init_bank_out;
  wire [11:0] addr = (init_done) ? wr_addr_out : init_addr_out;

  sdram_model_plus sdram_model_plus_inst (
    .Dq     (wr_data_out),
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


  // write operation stimulus
  initial begin
    wr_en        = 0;
    wr_addr_in   = 0;
    wr_data_in   = 0;
    burst_len_in = 0;
    dqm_in       = 0;
    wr_wait      = 0;

    @(posedge init_done);
    repeat(5) @(posedge sys_clk);
 
    // Write WITHOUT wait
    $display("Starting Write without wait...");
    wr_en        = 1;
    wr_addr_in   = 25'b11_000000000001_0_00_00000001; 
    burst_len_in = 9'd8;

    @(posedge sys_clk);
    wr_en = 0;

    wait(wr_cmd_out == 4'd4);
    wr_data_in = 16'hA001;
    
    @(posedge wr_end or posedge wr_err);
    repeat(10) @(posedge sys_clk);

    // Write WITH wait
    $display("Starting Write with wait...");
    wr_en        = 1;
    wr_addr_in   = 25'b11_000000000010_0_00_00000001; // Different Row
    burst_len_in = 9'd8;
    wr_data_in = 16'h0;

    @(posedge sys_clk);
    wr_en = 0;

    wait(wr_cmd_out == 4'd4);
    wr_data_in = 16'hB001;

    // Trigger wait
    wait(wr_cmd_out == 4'd4)
    repeat (2) @(posedge sys_clk);
    wr_wait <= 1;
    
    repeat(1) @(posedge sys_clk);    
    wr_wait <= 0;

    @(posedge wr_end or posedge wr_err);
    repeat(10) @(posedge sys_clk);

    // Write WITH wait
    $display("Starting Write with wait (edge case)...");
    wr_en        = 1;
    wr_addr_in   = 25'b11_000000000010_0_00_00000001; // Different Row
    burst_len_in = 9'd8;
    wr_data_in = 16'h0;

    @(posedge sys_clk);
    wr_en = 0;

    wait(wr_cmd_out == 4'd4);
    wr_data_in = 16'hC001;

    // Trigger wait
    wait(wr_cmd_out == 4'd4)
    repeat (7) @(posedge sys_clk);
    wr_wait <= 1;
    
    repeat(1) @(posedge sys_clk);    
    wr_wait <= 0;

    @(posedge wr_end or posedge wr_err);
    repeat(10) @(posedge sys_clk);

    // Write WITHOUT wait
    $display("Starting Write without wait (again)...");
    wr_en        = 1;
    wr_addr_in   = 25'b11_000000000011_0_00_00000001; 
    burst_len_in = 9'd8;
    wr_data_in = 16'h0;

    @(posedge sys_clk);
    wr_en = 0;

    wait(wr_cmd_out == 4'd4);
    wr_data_in = 16'hD001;
    
    @(posedge wr_end);
    repeat(10) @(posedge sys_clk);
    
    repeat(15) @(posedge sys_clk);
    $display("Simulation Finished");
    $finish;
  end

  always @(posedge apply_data) begin
    wait(apply_data);
    repeat (burst_len_in - 1'b1) begin
      @(posedge sys_clk);
      wr_data_in <= wr_data_in + 1'b1;
    end
  end

endmodule