`timescale 1ns / 1ps

module sdram_auto_ref_gen(
    input sys_clk,
    input sys_reset_n,
    input init_done,
    input aref_en,

    output aref_req,
    output reg [3:0] aref_cmd_out,
    output reg [1:0] aref_bank_out,
    output reg [11:0] aref_addr_out,
    output aref_end
);

    parameter
        AREF_IDLE = 3'd0,
        AREF_PRECHARGE = 3'd1,
        AREF_WAIT_TRP = 3'd2,
        AREF_AUTO_REF = 3'd3,
        AREF_WAIT_TRFC = 3'd4,
        AREF_END = 3'd5;
    
    reg [2:0] aref_state;

    // Auto-refresh request signal
    parameter SINGLE_ROW_COUNT = 11'd1550;
    reg [10:0] clk_count;

    // clock cycle counter
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            clk_count <=11'd0;
        else if (clk_count == SINGLE_ROW_COUNT - 1'b1)
            clk_count <= 11'd0;
        else if (init_done)
            clk_count <= clk_count + 1'b1;
    end

    // auto refresh request
    assign aref_req = (clk_count == SINGLE_ROW_COUNT - 1'b1);

    // Keeping track of waiting times: TRP and TRFC
    parameter 
        TRP_COUNT = 2'd2,
        TRFC_COUNT = 3'd7;
    
    wire trp_end, trfc_end;
    reg [2:0] wait_count;
    reg wait_count_rst;

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            wait_count <= 3'd0;
        else if (wait_count_rst)
            wait_count <= 3'd0;
        else
            wait_count <= wait_count + 1'b1;
    end

    assign trp_end = ((aref_state == AREF_WAIT_TRP) & (wait_count == TRP_COUNT - 1'b1));
    assign trfc_end = ((aref_state == AREF_WAIT_TRFC) & (wait_count == TRFC_COUNT - 1'b1));

    always @(*) begin
        case (aref_state)
            AREF_WAIT_TRP: wait_count_rst = (trp_end);
            AREF_WAIT_TRFC: wait_count_rst = (trfc_end);
            AREF_END: wait_count_rst = 1'b1;
            default: wait_count_rst = 1'b1;
        endcase
    end

    // FSM transitions
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            aref_state <= AREF_IDLE;

        else begin
            case (aref_state)
                AREF_IDLE: begin
                    if ((aref_en) & (init_done))
                        aref_state <= AREF_PRECHARGE;
                    else
                        aref_state <= AREF_IDLE;
                end

                AREF_PRECHARGE:
                    aref_state <= AREF_WAIT_TRP;

                AREF_WAIT_TRP: begin
                    if (trp_end)
                        aref_state <= AREF_AUTO_REF;
                    else
                        aref_state <= AREF_WAIT_TRP; 
                end

                AREF_AUTO_REF:
                    aref_state <= AREF_WAIT_TRFC;

                AREF_WAIT_TRFC: begin
                    if (trfc_end)
                        aref_state <= AREF_END;
                    else
                        aref_state <= AREF_WAIT_TRFC; 
                end

                AREF_END:
                    aref_state <= AREF_IDLE;

                default: 
                    aref_state <= AREF_IDLE;
            endcase
        end
    end

    assign aref_end = (aref_state == AREF_END);

    // command values
    localparam  CMD_PRECHARGE = 4'b0010;
    localparam CMD_AUTO_REF = 4'b0001;
    localparam CMD_NOP = 4'b0111;

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            aref_cmd_out <=  CMD_NOP;
            aref_bank_out <= 2'b11;
            aref_addr_out <= 12'hfff;
        end

        else begin
            case (aref_state)
                AREF_PRECHARGE: begin
                    aref_cmd_out <= CMD_PRECHARGE;
                    aref_bank_out <= 2'b11;
                    aref_addr_out <= 12'hfff;
                end

                AREF_AUTO_REF: begin
                    aref_cmd_out <= CMD_AUTO_REF;
                    aref_bank_out <= 2'b11;
                    aref_addr_out <= 12'hfff;
                end

                default: begin
                    aref_cmd_out <=  CMD_NOP;
                    aref_bank_out <= 2'b11;
                    aref_addr_out <= 12'hfff;
                end
            endcase
        end
    end

endmodule