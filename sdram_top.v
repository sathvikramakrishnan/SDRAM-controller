`timescale 1ns / 1ps

module sdram_top (
    input sys_clk,
    input sys_reset_n,
    input wr_req,
    input [24:0] wr_addr_in,
    input [15:0] wr_data_in,
    input [8:0] wr_blen_in,
    input wr_dqm_in,

    output wr_end,
    output wr_err,
    output apply_data,
    output [15:0] wr_data_out,

    output [3:0] cmd_out,
    output [1:0] bank_out,
    output [11:0] addr_out,
    output busy
);

    wire init_done;
    wire [3:0] init_cmd_out;
    wire [1:0] init_bank_out;
    wire [11:0] init_addr_out;

    wire aref_req;
    wire aref_end;
    wire aref_en;
    wire [3:0] aref_cmd_out;
    wire [1:0] aref_bank_out;
    wire [11:0] aref_addr_out;

    wire wr_en;
    wire wr_wait;
    wire [3:0] wr_cmd_out_int;
    wire [1:0] wr_bank_out_int;
    wire [11:0] wr_addr_out_int;
    wire wr_dqm_out;

    sdram_init sdram_init_inst (
        .sys_clk (sys_clk),
        .sys_reset_n (sys_reset_n),
        .init_cmd_out (init_cmd_out),
        .init_bank_out (init_bank_out),
        .init_addr_out (init_addr_out),
        .init_done (init_done)
    );

    sdram_controller sdram_controller_inst (
        .sys_clk (sys_clk),
        .sys_reset_n (sys_reset_n),
        .init_cmd_out (init_cmd_out),
        .init_bank_out (init_bank_out),
        .init_addr_out (init_addr_out),
        .init_done (init_done),
        .aref_req (aref_req),
        .aref_cmd_out (aref_cmd_out),
        .aref_bank_out (aref_bank_out),
        .aref_addr_out (aref_addr_out),
        .aref_end (aref_end),
        .wr_req (wr_req),
        .wr_end (wr_end),
        .wr_err (wr_err),
        .wr_cmd_out (wr_cmd_out_int),
        .wr_bank_out (wr_bank_out_int),
        .wr_addr_out (wr_addr_out_int),
        .aref_en (aref_en),
        .wr_en (wr_en),
        .wr_wait (wr_wait),
        .cmd_out (cmd_out),
        .bank_out (bank_out),
        .addr_out (addr_out),
        .busy (busy)
    );

    sdram_auto_ref_gen sdram_auto_ref_gen_inst (
        .sys_clk (sys_clk),
        .sys_reset_n (sys_reset_n),
        .init_done (init_done),
        .aref_en (aref_en),
        .aref_req (aref_req),
        .aref_cmd_out (aref_cmd_out),
        .aref_bank_out (aref_bank_out),
        .aref_addr_out (aref_addr_out),
        .aref_end (aref_end)
    );

    sdram_write sdram_write_inst (
        .sys_clk (sys_clk),
        .sys_reset_n (sys_reset_n),
        .init_done (init_done),
        .wr_en (wr_en),
        .wr_addr_in (wr_addr_in),
        .wr_data_in (wr_data_in),
        .wr_blen_in (wr_blen_in),
        .wr_dqm_in (wr_dqm_in),
        .wr_wait (wr_wait),
        .apply_data (apply_data),
        .wr_end (wr_end),
        .wr_cmd_out (wr_cmd_out_int),
        .wr_bank_out (wr_bank_out_int),
        .wr_addr_out (wr_addr_out_int),
        .wr_dqm_out (wr_dqm_out),
        .wr_data_out (wr_data_out),
        .wr_err (wr_err)
    );

endmodule