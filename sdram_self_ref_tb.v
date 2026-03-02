`timescale 1ns / 1ps

module sdram_self_ref_tb ();
 
    reg             sys_clk = 0;
    reg             sys_reset_n = 0;
    reg             sref_en = 0;
    
    wire            sdram_cke;
    wire [3:0]      sdram_cmd;
    wire [1:0]      sdram_ba;
    wire [11:0]     sdram_addr;
    wire            self_ref_done;
    
    wire [15:0]     sdram_dq;
    wire            init_done;
    
    assign init_done = 1;
    
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
        repeat(10) @(posedge sys_clk);
        sref_en <= 1'b1; // Enable Self-Refresh
        repeat(15) @(posedge sys_clk);
        sref_en <= 1'b0; // Disable Self-Refresh (Exit)
    end
 
    // Monitor Self-Refresh Completion
    initial begin
        @(posedge self_ref_done);
        $display("Self-Refresh Completed!");
        repeat (5) @(posedge sys_clk);
        $finish;
    end
 
    // Instantiate Self-Refresh Module
    sdram_self_ref_gen  sdram_self_refresh_inst (
        .sys_clk        (sys_clk),
        .sys_reset_n    (sys_reset_n),
        .sref_en        (sref_en),
        .init_done      (init_done),
        .sdram_cke      (sdram_cke),
        .sref_cmd_out   (sdram_cmd),
        .sref_bank_out  (sdram_ba),
        .sref_addr_out  (sdram_addr),
        .sref_end       (self_ref_done)
    );
 
    // Instantiate SDRAM Model
    sdram_model_plus  sdram_model_plus_inst (
        .Dq         (sdram_dq),        // Bi-directional Data Bus
        .Addr       (sdram_addr),
        .Ba         (sdram_ba),
        .Clk        (sys_clk),
        .Cke        (sdram_cke),
        .Cs_n       (sdram_cmd[3]),
        .Ras_n      (sdram_cmd[2]),
        .Cas_n      (sdram_cmd[1]),
        .We_n       (sdram_cmd[0]),
        .Dqm        (2'b00),
        .Debug      (1'b1)
    );
 
endmodule