`timescale 1ns / 1ps

module sdram_init_tb();
    
    reg s_clk = 1'b0;
    reg s_rstn = 1'b0;

    wire [3:0] init_cmd; // SDRAM command signals (CS#, RAS#, CAS#, WE#)
    wire [1:0] init_bank;
    wire [11:0] init_addr;
    wire init_done;
 
    // clock signal with 10ns time period
    always #5 s_clk = ~s_clk;

    // Reset generation: Assert for 3 clock cycles
    // Use NBA to avoid race condition during deassertion
    initial begin
        s_rstn <= 1'b0;
        repeat(3) @(posedge s_clk);
        s_rstn <= 1'b1;
    end

    initial begin
        @(posedge init_done);
        repeat (2) @(posedge s_clk);
        $finish;
    end

    initial begin
        $dumpfile("sdram_init.vcd");
        $dumpvars(0);
    end

    sdram_init sdram_init_inst (
        .sys_clk(s_clk),
        .sys_reset_n(s_rstn),
        .init_cmd_out(init_cmd),
        .init_bank_out(init_bank),
        .init_addr_out(init_addr),
        .init_done(init_done)
    );

    // Optional: Instantiate SDRAM Model for Command Monitoring
    sdram_model_plus sdram_model_plus_inst (
        .Dq     (/* unused for init */), // Data bus not used during init
        .Addr   (init_addr),
        .Ba     (init_bank),
        .Clk    (s_clk),
        .Cke    (1'b1), // Clock enable (always ON)
        .Cs_n   (init_cmd[3]),
        .Ras_n  (init_cmd[2]),
        .Cas_n  (init_cmd[1]),
        .We_n   (init_cmd[0]),
        .Dqm    (2'b00), // Data mask (disabled)
        .Debug  (1'b1) // Debug mode ON
    );

endmodule