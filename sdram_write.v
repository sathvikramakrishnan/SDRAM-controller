module sdram_write(
    input sys_clk,
    input sys_reset_n,
    input init_done,
    input wr_en,
    input [24:0] wr_addr_in, // 24:23 - bank, 22:11 - row, 10 - auto precharge, 9:8 - unused, 7:0 - column
    input [15:0] wr_data_in,
    input [7:0] burst_len_in,
    input dqm_in,

    output ack_out,
    output burst_done_out,
    output reg [3:0] wr_cmd_out,
    output reg [1:0] wr_bank_out,
    output reg [11:0] wr_addr_out,
    output reg dqm_out,
    output [15:0] wr_data_out
);

    parameter 
        TRCD_COUNT = 2'd2,
        TRP_COUNT = 2'd2,
        TWR_COUNT = 2'd2,
        WR_AUTO_PRE_COUNT = 3'd4; // In case of write with auto precharge enabled

    // State definitions
    parameter
        WR_IDLE = 4'd0,
        WR_ACTIVE = 4'd1,
        WR_WAIT_TRCD = 4'd2,
        WR_WRITE_START = 4'd3,
        WR_WRITING = 4'd4,
        WR_PRECHARGE = 4'd5,
        WR_WAIT_TRP = 4'd6,
        WR_END = 4'd7,
        WR_WAIT_TWR = 4'd8,
        WR_AUTO_PRE = 4'd9;

    // SDRAM commands
    parameter 
        CMD_NOP = 4'b0111,
        CMD_ACTIVE = 4'b0011,
        CMD_WRITE = 4'b0100,
        CMD_PRECHARGE = 4'b0010,
        CMD_BURST_TERM = 4'b0110;

    wire trcd_end, trp_end, twr_end, wr_cycle_done, auto_pre_end;
    reg [3:0] wr_state;
    reg [7:0] clk_count; // 2^8 = 256 columns
    reg reset_clk_count;

    assign burst_done_out = (wr_state == WR_END);

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            clk_count <= 8'd0;
        else if (reset_clk_count)
            clk_count <= 8'd0;
        else
            clk_count <= clk_count + 1'b1;        
    end

    // counter reset logic
    always @(*) begin
        case (wr_state)
            WR_WAIT_TRCD: reset_clk_count = trcd_end;
            WR_WAIT_TRP: reset_clk_count = trp_end;
            WR_WAIT_TWR: reset_clk_count = twr_end;
            WR_WRITING: reset_clk_count = wr_cycle_done;
            WR_AUTO_PRE: reset_clk_count = auto_pre_end;
            default: reset_clk_count = 1'b1;
        endcase
    end

    assign trcd_end = ((wr_state == WR_WAIT_TRCD) & (clk_count == TRCD_COUNT - 1'b1));
    assign trp_end = ((wr_state == WR_WAIT_TRP) & (clk_count == TRP_COUNT - 1'b1));
    assign twr_end = ((wr_state == WR_WAIT_TWR) & (clk_count == TWR_COUNT - 1'b1));
    assign wr_cycle_done = ((wr_state == WR_WRITING) & (clk_count == burst_len_in - 1'b1));
    assign auto_pre_end = ((wr_state == WR_AUTO_PRE) & (clk_count == WR_AUTO_PRE_COUNT - 1'b1));

    // FSM transitions
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            wr_state <= WR_IDLE;
        else begin
            case (wr_state)
                WR_IDLE: begin
                    if (init_done & wr_en)
                        wr_state <= WR_ACTIVE;
                    else 
                        wr_state <= WR_IDLE;
                end

                WR_ACTIVE: begin
                    wr_state <= WR_WAIT_TRCD;
                end

                WR_WAIT_TRCD: begin
                    if (trcd_end)
                        wr_state <= WR_WRITE_START;
                    else
                        wr_state <= WR_WAIT_TRCD;

                end

                WR_WRITE_START: begin
                    wr_state <= WR_WRITING;
                end

                WR_WRITING: begin
                    if (wr_cycle_done) begin
                        if (wr_addr_in[10] == 1'b1)
                            wr_state <= WR_AUTO_PRE;
                        else
                            wr_state <= WR_WAIT_TWR;
                    end
                    
                    else
                        wr_state <= WR_WRITING;
                end

                WR_AUTO_PRE: begin
                    if (auto_pre_end)
                        wr_state <= WR_END;
                    else
                        wr_state <= WR_AUTO_PRE;
                end

                WR_WAIT_TWR: begin
                    if (twr_end)
                        wr_state <= WR_PRECHARGE;
                    else
                        wr_state <= WR_WAIT_TWR;
                end

                WR_PRECHARGE: begin
                    wr_state <= WR_WAIT_TRP;
                end

                WR_WAIT_TRP: begin
                    if (trp_end)
                        wr_state <= WR_END;
                    else 
                        wr_state <= WR_WAIT_TRP;
                end

                WR_END: begin
                    wr_state <= WR_IDLE;
                end

                default: begin
                    wr_state <= WR_IDLE;
                end
            endcase
        end        
    end

    // SDRAM command control
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            wr_cmd_out <= CMD_NOP;
            wr_bank_out <= 2'b11;
            wr_addr_out <= 12'hfff;
        end
        else begin
            case (wr_state)
                WR_ACTIVE: begin
                    wr_cmd_out <= CMD_ACTIVE;
                    wr_bank_out <= wr_addr_in[24:23];
                    wr_addr_out <= wr_addr_in[22:11]; // row addr
                end

                WR_WRITE_START: begin
                    wr_cmd_out <= CMD_WRITE;
                    wr_bank_out <= wr_addr_in[24:23];
                    wr_addr_out <= {4'b0000, wr_addr_in[7:0]};
                end

                WR_WRITING: begin
                    if (wr_cycle_done) begin
                        wr_cmd_out <= CMD_BURST_TERM;
                    end
                    else begin
                        wr_cmd_out <= CMD_NOP;
                    end
                    wr_bank_out <= 2'b11;
                    wr_addr_out <= 12'hfff;
                end

                WR_AUTO_PRE: begin
                    wr_cmd_out <= CMD_NOP;
                    wr_bank_out <= 2'b11;
                    wr_addr_out <= 12'hfff;
                end

                WR_PRECHARGE: begin
                    wr_cmd_out <= CMD_PRECHARGE;
                    wr_bank_out <= 2'b11;
                    wr_addr_out <= 12'hfff;
                end

                WR_END: begin
                    wr_cmd_out <= CMD_NOP;
                    wr_bank_out <= 2'b11;
                    wr_addr_out <= 12'hfff;
                end

                default: begin
                    wr_cmd_out <= CMD_NOP;
                    wr_bank_out <= 2'b11;
                    wr_addr_out <= 12'hfff;
                end
            endcase
        end
    end

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            dqm_out <= 1'b0;
        else
            dqm_out <= dqm_in;            
    end

    assign wr_data_out = (~dqm_in) ? wr_data_in : 16'hz;

endmodule