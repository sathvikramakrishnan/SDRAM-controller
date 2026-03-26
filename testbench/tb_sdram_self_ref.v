`timescale 1ns / 1ps

module sdram_self_ref_tb ();
 
    reg             sys_clk = 0;
    reg             sys_reset_n = 0;
    reg             sref_en = 0;
    
    wire            sref_cke;
    wire [3:0]      sref_cmd_out;
    wire [1:0]      sref_bank_out;
    wire [11:0]     sref_addr_out;
    wire            sref_end;
    
    wire [15:0]     sdram_dq;

    // SDRAM Initialization Module Signals
    wire [3:0]  init_cmd_out;
    wire [1:0]  init_bank_out;
    wire [11:0] init_addr_out;
    wire        init_done;

    wire [3:0]  sdram_cmd  = (init_done) ? sref_cmd_out  : init_cmd_out;
    wire [1:0]  sdram_ba   = (init_done) ? sref_bank_out : init_bank_out;
    wire [11:0] sdram_addr = (init_done) ? sref_addr_out : init_addr_out;

    
    // Generate 100MHz clock (10ns period)
    always #5 sys_clk = ~sys_clk;

    initial begin
        $dumpfile("sdram_self_ref.vcd");
        $dumpvars(0);
    end
 
    // Reset Sequence
    initial begin
        sys_reset_n <= 1'b0;
        repeat(5) @(posedge sys_clk);
        sys_reset_n <= 1'b1;
    end
 
    // Trigger Self-Refresh
    initial begin
        wait(init_done == 1'b1);
        $display("Initialization Complete at %t", $time);

        repeat(10) @(posedge sys_clk);
        sref_en <= 1'b1; // Enable Self-Refresh
        $display("Self-Refresh Request Detected at %t", $time);

        repeat(30) @(posedge sys_clk);
        sref_en <= 1'b0; // Disable Self-Refresh (Exit)

        @(posedge sref_end);
        $display("Self-Refresh Sequence Exited at %t", $time);

        repeat(10) @(posedge sys_clk);
        $finish;
    end
 
    // Instantiate Self-Refresh Module
    sdram_self_ref_gen  sdram_self_refresh_inst (
        .sys_clk        (sys_clk),
        .sys_reset_n    (sys_reset_n),
        .sref_en        (sref_en),
        .init_done      (init_done),
        .sref_cke      (sref_cke),
        .sref_cmd_out   (sref_cmd_out),
        .sref_bank_out  (sref_bank_out),
        .sref_addr_out  (sref_addr_out),
        .sref_end       (sref_end)
    );

    sdram_init sdram_init_inst (
        .sys_clk      (sys_clk),
        .sys_reset_n  (sys_reset_n),
        .init_cmd_out (init_cmd_out),
        .init_bank_out(init_bank_out),
        .init_addr_out(init_addr_out),
        .init_done    (init_done)
    );
 
    // Instantiate SDRAM Model
    sdram_model_plus  sdram_model_plus_inst (
        .Dq         (sdram_dq),        // Bi-directional Data Bus
        .Addr       (sdram_addr),
        .Ba         (sdram_ba),
        .Clk        (sys_clk),
        .Cke        (sref_cke),
        .Cs_n       (sdram_cmd[3]),
        .Ras_n      (sdram_cmd[2]),
        .Cas_n      (sdram_cmd[1]),
        .We_n       (sdram_cmd[0]),
        .Dqm        (2'b00),
        .Debug      (1'b1)
    );
 
endmodule