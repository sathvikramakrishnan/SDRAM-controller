`timescale 1ns / 1ps

module sdram_self_ref_gen (
    input sys_clk,
    input sys_reset_n,
    input init_done,
    input sref_en,

    output reg sdram_cke,
    output reg [3:0] sref_cmd_out,
    output reg [1:0] sref_bank_out,
    output reg [11:0] sref_addr_out,
    output sref_end
);

    // Command definitions
    localparam CMD_NOP = 4'b0111;
    localparam CMD_PRECHARGE = 4'b0010;
    localparam CMD_AUTO_REF = 4'b0001;

    // FSM parameters and signals
    parameter 
        SREF_IDLE = 4'd0,
        SREF_PRECHARGE = 4'd1,
        SREF_WAIT_TRP = 4'd2,
        SREF_AUTO_REF = 4'd3,
        SREF_WAIT_TRFC = 4'd4,
        SREF_ENTER = 4'd5,
        SREF_EXIT = 4'd6,
        SREF_WAIT_TXSR = 4'd7,
        SREF_END = 4'd8;

    reg [3:0] sref_state;

    // Waiting time parameters and signals
    parameter 
        TRP_COUNT = 2'd2,
        TRFC_COUNT = 3'd7,
        TXSR_COUNT = 4'd8;
    
    wire trp_end, trfc_end, txsr_end;
    reg [2:0] wait_count;
    reg wait_count_rst;

    assign trp_end = ((sref_state == SREF_WAIT_TRP) & (wait_count == TRP_COUNT - 1'b1));
    assign trfc_end = ((sref_state == SREF_WAIT_TRFC) & (wait_count == TRFC_COUNT - 1'b1));
    assign txsr_end = ((sref_state == SREF_WAIT_TXSR) & (wait_count == TXSR_COUNT - 1'b1));

    // Wait time counter
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            wait_count <= 3'd0;
        else if (wait_count_rst)
            wait_count <= 3'd0;
        else
            wait_count <= wait_count + 1'b1;
    end

    always @(*) begin
        case (sref_state)
            SREF_WAIT_TRP: wait_count_rst = trp_end;
            SREF_WAIT_TRFC: wait_count_rst = trfc_end;
            SREF_WAIT_TXSR: wait_count_rst = txsr_end;
            SREF_EXIT: wait_count_rst = 1'b1;
            default: wait_count_rst = 1'b1;
        endcase
    end

    // FSM state transitions
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            sref_state <= SREF_IDLE;

            sdram_cke <= 1'b1;
            sref_cmd_out <=  CMD_NOP;
            sref_bank_out <= 2'b11;
            sref_addr_out <= 12'hfff;
        end

        else begin            
            case (sref_state)
                SREF_IDLE: begin
                    if (init_done & sref_en)
                        sref_state <= SREF_PRECHARGE;
                    else
                        sref_state <= SREF_IDLE;

                    sdram_cke <= 1'b1;
                    sref_cmd_out <=  CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_PRECHARGE: begin
                    sref_state <= SREF_WAIT_TRP;

                    sdram_cke <= 1'b1;
                    sref_cmd_out <= CMD_PRECHARGE;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff; // A10 must be set during precharge command
                end

                SREF_WAIT_TRP: begin
                    if (trp_end)
                        sref_state <= SREF_AUTO_REF;

                    else
                        sref_state <= SREF_WAIT_TRP;
                    
                    sdram_cke <= 1'b1;
                    sref_cmd_out <=  CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_AUTO_REF: begin
                    sref_state <= SREF_WAIT_TRFC;

                    sdram_cke <= 1'b0;
                    sref_cmd_out <= CMD_AUTO_REF;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_WAIT_TRFC: begin
                    if (trfc_end)
                        sref_state <= SREF_ENTER;
                    
                    else
                        sref_state <= SREF_WAIT_TRFC;
                    
                    sdram_cke <= 1'b0;
                    sref_cmd_out <= CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_ENTER: begin
                    if (~sref_en)
                        sref_state <= SREF_EXIT;
                    
                    else
                        sref_state <= SREF_ENTER;

                    sdram_cke <= 1'b0;
                    sref_cmd_out <= CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_EXIT: begin
                    sref_state <= SREF_WAIT_TXSR;
                    
                    sdram_cke <= 1'b1;
                    sref_cmd_out <= CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_WAIT_TXSR: begin
                    if (txsr_end)
                        sref_state <= SREF_END;
                    
                    else
                        sref_state <= SREF_WAIT_TXSR;
                    
                    sdram_cke <= 1'b1;
                    sref_cmd_out <= CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                SREF_END: begin
                    sref_state <= SREF_IDLE;

                    sdram_cke <= 1'b1;
                    sref_cmd_out <= CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end

                default: begin
                    sref_state <= SREF_IDLE;

                    sdram_cke <= 1'b1;
                    sref_cmd_out <=  CMD_NOP;
                    sref_bank_out <= 2'b11;
                    sref_addr_out <= 12'hfff;
                end
            endcase
        end
    end

    assign sref_end = (sref_state == SREF_END);
    
endmodule