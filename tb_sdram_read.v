`timescale 1ns / 1ps

module tb_sdram_read;

    // Clock and Reset Declarations
    reg sys_clk     = 0;
    reg sys_reset_n = 0;

    always #5 sys_clk = ~sys_clk;

    // Reset Pulse Generation
    initial begin
        sys_reset_n = 0;
        repeat(3) @(posedge sys_clk);
        sys_reset_n = 1;
    end

    initial begin
        $dumpfile("sdram_read.vcd");
        $dumpvars(0);
    end

    // SDRAM Initialization Interface Wires
    wire [3:0]  init_cmd;
    wire [1:0]  init_bank;
    wire [11:0] init_addr;
    wire        init_done;

    // SDRAM Initialization Instance
    sdram_init sdram_init_inst (
        .sys_clk     (sys_clk),        
        .sys_reset_n   (sys_reset_n),    
        .init_cmd_out    (init_cmd),     
        .init_bank_out     (init_bank),      
        .init_addr_out   (init_addr),    
        .init_done   (init_done)     
    );

    // Inputs to SDRAM Read Controller
    reg         rd_en;
    reg [24:0]  rd_addr_in;
    wire [15:0] rd_data_in;
    reg [8:0]   rd_blen_in;
    reg         rd_dqm_in;

    // Outputs from SDRAM Read Controller
    wire        rd_end;
    wire [3:0]  rd_cmd_out;
    wire [1:0]  rd_bank_out; 
    wire [11:0] rd_addr_out; 
    wire [15:0] rd_data_out;
    wire rd_dqm_out;

    sdram_read dut (
        .sys_clk      (sys_clk),
        .sys_reset_n  (sys_reset_n),
        .init_done    (init_done),
        .rd_en        (rd_en),
        .rd_addr_in   (rd_addr_in),
        .rd_data_in   (rd_data_in),
        .rd_blen_in   (rd_blen_in),
        .rd_dqm_in    (rd_dqm_in),
        .rd_end       (rd_end),
        .rd_cmd_out   (rd_cmd_out),
        .rd_bank_out  (rd_bank_out),
        .rd_addr_out  (rd_addr_out),
        .rd_dqm_out   (rd_dqm_out),
        .rd_data_out  (rd_data_out)
    );

    // MUX for SDRAM command interface (init or read mode)
    wire [3:0]  cmd;
    wire [1:0]  ba;
    wire [11:0] addr;

    assign cmd  = (init_done) ? rd_cmd_out  : init_cmd;
    assign ba   = (init_done) ? rd_bank_out : init_bank;
    assign addr = (init_done) ? rd_addr_out : init_addr;

    // SDRAM Model Instance
    sdram_model_plus sdram_model_plus_inst (
        .Dq     (rd_data_in),     // Data coming from model to controller
        .Addr   (addr),           
        .Ba     (ba),             
        .Clk    (sys_clk),        
        .Cke    (1'b1),           
        .Cs_n   (cmd[3]),
        .Ras_n  (cmd[2]),
        .Cas_n  (cmd[1]),
        .We_n   (cmd[0]),
        .Dqm    (1'b0),           
        .Debug  (1'b1)
    );

    // Stimulus
    initial begin
        // Initial Inputs
        rd_en      = 0;
        rd_addr_in = 0;
        rd_blen_in = 0;
        rd_dqm_in  = 0;

        // Wait for SDRAM Initialization to Complete
        @(posedge init_done);
        @(posedge sys_clk);

        // Start Read Operation
        rd_en <= 1;
        rd_addr_in <= 25'b00_000000000001_0_00_00000001; // Bank 0, Row 1, Col 1
        rd_blen_in <= 9'd8;
        rd_dqm_in <= 0;

        wait (rd_cmd_out == 4'd5);
        repeat (rd_blen_in - 1) begin
            @(posedge sys_clk);
        end

        @(posedge sys_clk);
        rd_en <= 0;

        repeat(10) @(posedge sys_clk);
        $display("Simulation Finished Successfully");
        $finish;
    end

    // Mask second value read
    initial begin
        wait (rd_cmd_out == 4'd5) begin
            repeat (1) @(posedge sys_clk);
            rd_dqm_in <= 1'b1;
            @(posedge sys_clk);
            rd_dqm_in <= 1'b0;
        end
    end

endmodule