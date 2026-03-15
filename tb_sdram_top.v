`timescale 1ns / 1ps

module tb_sdram_top;

    reg sys_clk;
    reg sys_reset_n;
    reg wr_req;
    reg [24:0] wr_addr_in;
    reg [15:0] wr_data_in;
    reg [8:0] wr_blen_in;
    reg wr_dqm_in;

    wire wr_end;
    wire wr_err;
    wire apply_data;
    wire [15:0] wr_data_out;
    wire [3:0] cmd_out;
    wire [1:0] bank_out;
    wire [11:0] addr_out;
    wire busy;

    sdram_top dut (
        .sys_clk (sys_clk),
        .sys_reset_n (sys_reset_n),
        .wr_req (wr_req),
        .wr_addr_in (wr_addr_in),
        .wr_data_in (wr_data_in),
        .wr_blen_in (wr_blen_in),
        .wr_dqm_in (wr_dqm_in),
        .wr_end (wr_end),
        .wr_err (wr_err),
        .apply_data (apply_data),
        .wr_data_out (wr_data_out),
        .cmd_out (cmd_out),
        .bank_out (bank_out),
        .addr_out (addr_out),
        .busy (busy)
    );

    sdram_model_plus sdram_model_plus_inst (
        .Dq (wr_data_out),
        .Addr (addr_out),
        .Ba (bank_out),
        .Clk (sys_clk),
        .Cke (1'b1),
        .Cs_n (cmd_out[3]),
        .Ras_n (cmd_out[2]),
        .Cas_n (cmd_out[1]),
        .We_n (cmd_out[0]),
        .Dqm (wr_dqm_in),
        .Debug (1'b1)
    );

    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;
    end

    initial begin
        $dumpfile("sdram_top.vcd");
        $dumpvars(0);
    end

    initial begin
        sys_reset_n = 0;
        wr_req = 0;
        wr_addr_in = 25'd0;
        wr_data_in = 16'h0000;
        wr_blen_in = 9'd0;
        wr_dqm_in = 0;

        #20;
        sys_reset_n = 1;

        #20;
        @(negedge busy);
        @(posedge sys_clk);

        $display("Starting Write without wait...");
        wr_addr_in = 25'b11_000000000001_0_00_00000001;
        wr_data_in = 16'h00A1;
        wr_blen_in = 9'd8;
        wr_dqm_in = 1'b0;
        wr_req = 1;

        @(posedge apply_data);
        repeat(wr_blen_in - 1'b1) begin
            @(posedge sys_clk);
            wr_data_in = wr_data_in + 1;
        end

        @(posedge wr_end or posedge wr_err);
        wr_req = 0;

        // @(negedge dut.aref_req);

        // repeat(1535) @(posedge sys_clk);   
        // $display("Starting Write with wait...");
        // wr_addr_in = 25'b11_000000000001_0_00_00000001;
        // wr_data_in = 16'h00B1;
        // wr_blen_in = 9'd8;
        // wr_dqm_in = 1'b0;
        // wr_req = 1;

        // @(posedge apply_data);
        // repeat(wr_blen_in - 1'b1) begin
        //     @(posedge sys_clk);
        //     wr_data_in = wr_data_in + 1;
        // end

        // @(posedge wr_end or posedge wr_err);
        // wr_req = 0;
        

        @(posedge dut.aref_req);
        @(posedge dut.aref_end);
        @(posedge sys_clk);
        $finish;
    end

    initial begin
        $monitor("error %d", wr_err);
    end
    

endmodule