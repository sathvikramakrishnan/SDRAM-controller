`timescale 1ns / 1ps

module sdram_controller (
    input sys_clk,
    input sys_reset_n,
    
    input [3:0] init_cmd_out,
    input [1:0] init_bank_out,
    input [11:0] init_addr_out,
    input init_done,

    input aref_req,
    input [3:0] aref_cmd_out,
    input [1:0] aref_bank_out,
    input [11:0] aref_addr_out,
    input aref_end,

    input wr_req,
    input wr_end,
    input wr_err,
    input [3:0] wr_cmd_out,
    input [1:0] wr_bank_out,
    input [11:0] wr_addr_out,

    output reg aref_en,
    output reg wr_en,
    output reg wr_wait,

    output reg [3:0] cmd_out,
    output reg [1:0] bank_out,
    output reg [11:0] addr_out,
    output busy
);

    assign busy = (~init_done) || (aref_en) || (wr_en);

    parameter CMD_NOP = 4'b0111;

    parameter
        IDLE = 3'd0,
        ACCEPT_OP = 3'd1,
        ACCEPT_WR = 3'd2,
        SERVE_AR = 3'd3,
        WR_ABRUPT_END = 3'd4,
        WR_DONE = 3'd5;

    reg [2:0] contr_state;

    // FSM transitions
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            contr_state <= IDLE;
        end
        else begin
            case (contr_state)
                IDLE: begin
                    if (init_done)
                        contr_state <= ACCEPT_OP;
                    else
                        contr_state <= IDLE;
                end

                ACCEPT_OP: begin
                    if (aref_req)
                        contr_state <= SERVE_AR;
                    else if (wr_req)
                        contr_state <= ACCEPT_WR;
                    else
                        contr_state <= ACCEPT_OP;
                end

                SERVE_AR: begin
                    if (aref_end)
                        contr_state <= ACCEPT_OP;
                    else
                        contr_state <= SERVE_AR;
                end

                ACCEPT_WR: begin
                    if (aref_req)
                        contr_state <= WR_ABRUPT_END;
                    else if (wr_end)
                        contr_state <= WR_DONE;
                    else
                        contr_state <= ACCEPT_WR;
                end

                WR_ABRUPT_END: begin
                    if (wr_err)
                        contr_state <= SERVE_AR;
                    else
                        contr_state <= WR_ABRUPT_END;
                end

                WR_DONE: begin
                    contr_state <= ACCEPT_OP;
                end

                default:
                    contr_state <= IDLE;

            endcase
        end
    end

    // FSM outputs
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            aref_en <= 1'b0;
            wr_en <= 1'b0;
            wr_wait <= 1'b0;
            cmd_out <= CMD_NOP;
            bank_out <= 2'b11;
            addr_out <= 12'hfff;
        end

        else begin
            case (contr_state)
                IDLE: begin
                    aref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    cmd_out <= init_cmd_out;
                    bank_out <= init_bank_out;
                    addr_out <= init_addr_out;
                end

                ACCEPT_OP: begin
                    aref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                end

                ACCEPT_WR: begin
                    aref_en <= 1'b0;
                    wr_en <= ~wr_end;
                    wr_wait <= 1'b0;
                    cmd_out <= wr_cmd_out;
                    bank_out <= wr_bank_out;
                    addr_out <= wr_addr_out;
                end

                SERVE_AR: begin
                    aref_en <= (~aref_end);
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    cmd_out <= aref_cmd_out;
                    bank_out <= aref_bank_out;
                    addr_out <= aref_addr_out;
                end

                WR_ABRUPT_END: begin
                    aref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b1;
                    cmd_out <= wr_cmd_out;
                    bank_out <= wr_bank_out;
                    addr_out <= wr_addr_out;
                end

                WR_DONE: begin
                    aref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                end

                default: begin
                    aref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                end
            endcase
        end
    end

endmodule