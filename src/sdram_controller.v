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

    input sref_req,
    input sref_cke,
    input [3:0] sref_cmd_out,
    input [1:0] sref_bank_out,
    input [11:0] sref_addr_out,
    input sref_end,

    input wr_req,
    input wr_end,
    input wr_err,
    input [3:0] wr_cmd_out,
    input [1:0] wr_bank_out,
    input [11:0] wr_addr_out,

    input rd_req,
    input rd_end,
    input rd_err,
    input [3:0] rd_cmd_out,
    input [1:0] rd_bank_out,
    input [11:0] rd_addr_out,

    output reg aref_en,
    output reg sref_en,
    output reg wr_en,
    output reg wr_wait,
    output reg rd_en,
    output reg rd_wait,

    output reg [3:0] cmd_out,
    output reg [1:0] bank_out,
    output reg [11:0] addr_out,
    output reg cke,
    output busy
);

    assign busy = (~init_done) || (aref_en) || (sref_en) || (wr_en) || (rd_en) ;

    parameter CMD_NOP = 4'b0111;

    parameter
        IDLE = 4'd0,
        ACCEPT_OP = 4'd1,
        SERVE_AR = 4'd2,
        ACCEPT_WR = 4'd3,
        WR_ABRUPT_END = 4'd4,
        WR_DONE = 4'd5,
        ACCEPT_RD = 4'd6,
        RD_ABRUPT_END = 4'd7,
        RD_DONE = 4'd8,
        SERVE_SR = 4'd9;

    reg [3:0] contr_state;

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
                    else if (sref_req)
                        contr_state <= SERVE_SR;
                    else if (wr_req)
                        contr_state <= ACCEPT_WR;
                    else if (rd_req)
                        contr_state <= ACCEPT_RD;
                    else
                        contr_state <= ACCEPT_OP;
                end

                SERVE_AR: begin
                    if (aref_end)
                        contr_state <= ACCEPT_OP;
                    else
                        contr_state <= SERVE_AR;
                end

                SERVE_SR: begin
                    if (sref_end)
                        contr_state <= ACCEPT_OP;
                    else
                        contr_state <= SERVE_SR;
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
                    if (wr_err || wr_end)
                        contr_state <= SERVE_AR;
                    else
                        contr_state <= WR_ABRUPT_END;
                end

                WR_DONE: begin
                    contr_state <= ACCEPT_OP;
                end

                ACCEPT_RD: begin
                    if (aref_req)
                        contr_state <= RD_ABRUPT_END;
                    else if (rd_end)
                        contr_state <= RD_DONE;
                    else
                        contr_state <= ACCEPT_RD;
                end

                RD_ABRUPT_END: begin
                    if (rd_err || rd_end)
                        contr_state <= SERVE_AR;
                    else
                        contr_state <= RD_ABRUPT_END;
                end

                RD_DONE: begin
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
            sref_en <= 1'b0;
            wr_en <= 1'b0;
            wr_wait <= 1'b0;
            rd_en <= 1'b0;
            rd_wait <= 1'b0;
            cmd_out <= CMD_NOP;
            bank_out <= 2'b11;
            addr_out <= 12'hfff;
            cke <= 1'b1;
        end

        else begin
            case (contr_state)
                IDLE: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= init_cmd_out;
                    bank_out <= init_bank_out;
                    addr_out <= init_addr_out;
                    cke <= 1'b1;
                end

                ACCEPT_OP: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                    cke <= 1'b1;
                end

                SERVE_AR: begin
                    aref_en <= (~aref_end);
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= aref_cmd_out;
                    bank_out <= aref_bank_out;
                    addr_out <= aref_addr_out;
                    cke <= 1'b1;
                end

                SERVE_SR: begin
                    aref_en <= 1'b0;
                    sref_en <= (sref_req);
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= sref_cmd_out;
                    bank_out <= sref_bank_out;
                    addr_out <= sref_addr_out;
                    cke <= sref_cke;
                end

                ACCEPT_WR: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= (~wr_end);
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= wr_cmd_out;
                    bank_out <= wr_bank_out;
                    addr_out <= wr_addr_out;
                    cke <= 1'b1;
                end

                WR_ABRUPT_END: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= ~(wr_err || wr_end);
                    wr_wait <= 1'b1;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= wr_cmd_out;
                    bank_out <= wr_bank_out;
                    addr_out <= wr_addr_out;
                    cke <= 1'b1;
                end

                WR_DONE: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                    cke <= 1'b1;
                end

                ACCEPT_RD: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= (~rd_end);
                    rd_wait <= 1'b0;
                    cmd_out <= rd_cmd_out;
                    bank_out <= rd_bank_out;
                    addr_out <= rd_addr_out;
                    cke <= 1'b1;
                end

                RD_ABRUPT_END: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= ~(rd_err || rd_end);
                    rd_wait <= 1'b1;
                    cmd_out <= rd_cmd_out;
                    bank_out <= rd_bank_out;
                    addr_out <= rd_addr_out;
                    cke <= 1'b1;
                end

                RD_DONE: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                    cke <= 1'b1;
                end

                default: begin
                    aref_en <= 1'b0;
                    sref_en <= 1'b0;
                    wr_en <= 1'b0;
                    wr_wait <= 1'b0;
                    rd_en <= 1'b0;
                    rd_wait <= 1'b0;
                    cmd_out <= CMD_NOP;
                    bank_out <= 2'b11;
                    addr_out <= 12'hfff;
                    cke <= 1'b1;
                end
            endcase
        end
    end

endmodule