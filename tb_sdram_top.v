`timescale 1ns / 1ps

`include "sdram_config.vh"

module tb_sdram_top;

    reg sys_clk;
    reg sys_reset_n;

    reg sref_req;

    reg wr_req;
    reg [24:0] wr_addr_in;
    reg [15:0] wr_data_in;
    reg wr_dqm_in;

    reg rd_req;
    reg [24:0] rd_addr_in;
    reg [15:0] rd_data_in;
    reg rd_dqm_in;

    wire wr_end;
    wire wr_err;
    wire apply_data;
    wire [15:0] wr_data_out;

    wire rd_end;
    wire rd_err;
    wire valid_read;
    wire [15:0] rd_data_out;

    wire [3:0] cmd_out;
    wire [1:0] bank_out;
    wire [11:0] addr_out;
    wire cke;
    wire busy;

    // to select appropriate signals
    wire [15:0] dq_in;
    wire [15:0] dq_out;
    wire dq_en;
    wire [15:0] dq_bus;

    assign dq_bus = (dq_en) ? dq_out : 16'hz;
    assign dq_in = dq_bus;

    wire dqm;

    localparam TB_MODE_REG = `MODE_REG;

    localparam TB_CAS_LATENCY = TB_MODE_REG[6:4];

    localparam TB_WR_BURST_LEN = (TB_MODE_REG[2:0] == 3'b111 && TB_MODE_REG[3] == 1'b0) ? 256 : 
                    (TB_MODE_REG[2:0] == 3'b011) ? 8 : 
                    (TB_MODE_REG[2:0] == 3'b010) ? 4 : 1;
    localparam TB_RD_BURST_LEN = (TB_MODE_REG[2:0] == 3'b011) ? 8 : 
                    (TB_MODE_REG[2:0] == 3'b010) ? 4 : 1;

    sdram_top dut (
        .sys_clk      (sys_clk),
        .sys_reset_n  (sys_reset_n),

        .dq_in        (dq_in),
        .dqm          (dqm),

        .sref_req     (sref_req),

        .dq_out       (dq_out),
        .dq_en        (dq_en),

        .wr_req       (wr_req),
        .wr_addr_in   (wr_addr_in),
        .wr_data_in   (wr_data_in),
        .wr_dqm_in    (wr_dqm_in),
        .wr_end       (wr_end),
        .wr_err       (wr_err),
        .apply_data   (apply_data),
        .wr_data_out  (wr_data_out),

        .rd_req       (rd_req),
        .rd_addr_in   (rd_addr_in),
        .rd_dqm_in    (rd_dqm_in),
        .rd_end       (rd_end),
        .rd_err       (rd_err),
        .valid_read   (valid_read),
        .rd_data_out  (rd_data_out),

        .cmd_out      (cmd_out),
        .bank_out     (bank_out),
        .addr_out     (addr_out),
        .cke          (cke),
        .busy         (busy)
    );

    sdram_model_plus sdram_model_plus_inst (
        .Dq (dq_bus),
        .Addr (addr_out),
        .Ba (bank_out),
        .Clk (sys_clk),
        .Cke (1'b1),
        .Cs_n (cmd_out[3]),
        .Ras_n (cmd_out[2]),
        .Cas_n (cmd_out[1]),
        .We_n (cmd_out[0]),
        .Dqm (dqm),
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
        sref_req <= 1'b0;
        wr_req = 0;
        wr_addr_in = 25'd0;
        wr_data_in = 16'h0000;
        wr_dqm_in = 0;

        rd_req = 0;
        rd_addr_in = 25'd0;
        rd_data_in = 16'h0000;
        rd_dqm_in = 0;

        #20;
        sys_reset_n = 1;

        #20;
        @(negedge busy);
        @(posedge sys_clk);

        $display("Starting Write without wait...");
        wr_addr_in = 25'b11_000000000001_0_00_00000000;
        wr_data_in = 16'h00A1;
        wr_dqm_in = 1'b0;

        wr_req <= 1;

        @(negedge dut.aref_req);

        // delay WR operation so that it is interrupted by a refresh request
        repeat(1540) @(posedge sys_clk);
        $display("Starting Write with wait");
        wr_addr_in = 25'b11_000000000010_0_00_00000000;
        wr_data_in = 16'h00B1;
        wr_dqm_in = 1'b0;

        wr_req <= 1;

        @(negedge dut.aref_req);

        // delay RD operation so that it is interrupted by a refresh request
        repeat(1539) @(posedge sys_clk);
        $display("Starting read operation with wait");
        rd_addr_in = 25'b11_000000000001_0_00_00000000;
        rd_dqm_in = 1'b0;

        rd_req <= 1;

        repeat (200) @(posedge sys_clk);
        $display("Starting Write without wait but with masking");
        wr_addr_in = 25'b11_000000000001_0_00_00000000;
        wr_data_in = 16'h00C1;
        wr_dqm_in = 1'b0;

        wr_req <= 1;

        @(posedge wr_end);
        repeat (10) @(posedge sys_clk);

        $display("Starting read operation to check previous write operation's output");
        rd_addr_in = 25'b11_000000000001_0_00_00000000;
        rd_dqm_in = 1'b0;

        rd_req <= 1;

        @(posedge rd_end);
        repeat (10) @(posedge sys_clk);

        $display("Starting Write without wait again");
        wr_addr_in = 25'b11_000000000011_0_00_00000000;
        wr_data_in = 16'h00D1;
        wr_dqm_in = 1'b0;

        wr_req <= 1;

        @(posedge wr_end);
        repeat (10) @(posedge sys_clk);

        $display("Starting read operation without wait");
        rd_addr_in = 25'b11_000000000011_0_00_00000000;
        rd_dqm_in = 1'b0;

        rd_req <= 1;

        @(posedge rd_end);
        repeat (10) @(posedge sys_clk);

        $display ("Entering power down mode");
        sref_req <= 1'b1;

        repeat(2000) @(posedge sys_clk);
        sref_req <= 1'b0;

        repeat (10) @(posedge sys_clk);

        $display("Starting read operation after power down mode");
        rd_addr_in = 25'b11_000000000010_0_00_00000000;
        rd_dqm_in = 1'b0;

        rd_req <= 1;

        @(posedge rd_end);
        repeat (10) @(posedge sys_clk);
        
        @(posedge dut.aref_req);
        @(posedge dut.aref_end);
        repeat (10) @(posedge sys_clk);
        $display("Simulation finished");
        $finish;
    end

    always @(posedge wr_end or posedge wr_err) begin
        @(posedge sys_clk);
        wr_req <= 0;
    end

    always @(posedge rd_end or posedge rd_err) begin
        @(posedge sys_clk);
        rd_req <= 0;
    end

    always @(posedge apply_data) begin
        @(posedge sys_clk);
        repeat (TB_WR_BURST_LEN - 1'b1) begin
        @(posedge sys_clk);
        wr_data_in <= wr_data_in + 1'b1;
        end
    end

    // to not mask write operation the first time
    reg first = 0;

    // SDRAM dqm always offers 2 cycle delay irrespective of CAS latency
    // External device has to drive the dqm input accordingly
    always @(cmd_out) begin
        // Mask second last value read during read operation
        if (cmd_out == 4'd5) begin
            if (TB_CAS_LATENCY == 3) begin
                repeat (TB_RD_BURST_LEN - 1) @(posedge sys_clk);
                rd_dqm_in = 1'b1;
            end
        else if (TB_CAS_LATENCY == 2) begin
            repeat (TB_RD_BURST_LEN - 2) @(posedge sys_clk);
            rd_dqm_in = 1'b1;
        end

            @(posedge sys_clk);
            rd_dqm_in = 1'b0;
        end

        // Mask second value written during write operation
        else if (cmd_out == 4'd4) begin
            if (first) begin
                repeat (1) @(posedge sys_clk);
                wr_dqm_in = 1'b1;
                @(posedge sys_clk);
                wr_dqm_in = 1'b0;
            end
            else begin
                first = 1;
            end
        end
    end

endmodule