`timescale 1ns / 1ps

module sdram_auto_ref_tb();

    reg s_clk = 1'b0;
    reg s_rstn = 1'b0;

    always #5 s_clk = ~s_clk;

    initial begin
        s_rstn <= 1'b0;
        repeat(3) @(posedge s_clk);
        s_rstn <= 1'b1;
    end

    initial begin
        $dumpfile("sdram_auto_ref.vcd");
        $dumpvars(0);
    end

    // SDRAM Initialization Module Signals
    wire [3:0]  init_cmd_out;
    wire [1:0]  init_bank_out;
    wire [11:0] init_addr_out;
    wire        init_done;

    sdram_init sdram_init_inst (
        .sys_clk      (s_clk),
        .sys_reset_n  (s_rstn),
        .init_cmd_out (init_cmd_out),
        .init_bank_out(init_bank_out),
        .init_addr_out(init_addr_out),
        .init_done    (init_done)
    );

    // SDRAM Auto-Refresh Module Signals
    reg          aref_en;
    wire         aref_req;
    wire [3:0]   aref_cmd_out;
    wire [1:0]   aref_bank_out;
    wire [11:0]  aref_addr_out;
    wire         aref_end;

    sdram_auto_ref_gen dut (
        .sys_clk       (s_clk),
        .sys_reset_n   (s_rstn),
        .init_done     (init_done),
        .aref_en       (aref_en),
        .aref_req      (aref_req),
        .aref_cmd_out  (aref_cmd_out),
        .aref_bank_out (aref_bank_out),
        .aref_addr_out (aref_addr_out),
        .aref_end      (aref_end)
    );

    // Switches control from Init module to Auto-Ref module once init_done is high
    wire [3:0]  sdram_cmd  = (init_done) ? aref_cmd_out  : init_cmd_out;
    wire [1:0]  sdram_ba   = (init_done) ? aref_bank_out : init_bank_out;
    wire [11:0] sdram_addr = (init_done) ? aref_addr_out : init_addr_out;

    // --- SDRAM Model Instantiation ---
    sdram_model_plus sdram_model_plus_inst (
        .Dq    (), 
        .Addr  (sdram_addr),
        .Ba    (sdram_ba),
        .Clk   (s_clk),
        .Cke   (1'b1),
        .Cs_n  (sdram_cmd[3]),
        .Ras_n (sdram_cmd[2]),
        .Cas_n (sdram_cmd[1]),
        .We_n  (sdram_cmd[0]),
        .Dqm   (2'b00),
        .Debug (1'b1) 
    );

    // Main Test Sequence
    // Use NBA to avoid race conditions
    initial begin
        aref_en <= 1'b0;

        // 1. Wait for Initialization to complete
        wait(init_done == 1'b1);
        $display("Initialization Complete at %t", $time);
        
        // 2. Wait for the Auto-Ref module to trigger a request (aref_req)
        // This happens after SINGLE_ROW_COUNT (1550) clock cycles
        wait(aref_req == 1'b1);
        $display("Auto-Refresh Request Detected at %t", $time);

        // 3. Acknowledge/Enable the refresh operation
        @(posedge s_clk);
        aref_en <= 1'b1;

        // 4. Wait for the Refresh FSM to finish its sequence (PRE -> TRP -> REF -> TRFC)
        wait(aref_end == 1'b1);
        $display("Auto-Refresh Sequence Finished at %t", $time);
        
        @(posedge s_clk);
        aref_en <= 1'b0;

        repeat(10) @(posedge s_clk);
        $finish;
    end

endmodule