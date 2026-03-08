`timescale 1ns / 1ps

module sdram_read(
    input sys_clk,
    input sys_reset_n,
    input init_done,
    input rd_en,
    input [24:0] rd_addr_in, // 24:23 - bank, 22:11 - row, 10 - auto precharge, 9:8 - unused, 7:0 - column
    input [15:0] rd_data_in,
    input [8:0] rd_blen_in,
    input rd_dqm_in,

    output rd_ack,
    output rd_end,
    output reg [3:0] rd_cmd_out,
    output reg [1:0] rd_bank_out,
    output reg [11:0] rd_addr_out,
    output reg rd_dqm_out,
    output reg [15:0] rd_data_out
);

    parameter 
        CMD_NOP = 4'b0111,
        CMD_ACTIVE = 4'b0011,
        CMD_READ = 4'b0101,
        CMD_PRECHARGE = 4'b0010,
        CMD_BURST_TERM = 4'b0110;

    parameter 
        TRCD_COUNT = 2'd2,
        TRP_COUNT = 2'd2,
        TCAS_COUNT = 2'd3; // Depends on the CL loaded into the mode register

    // FSM states
    parameter
        RD_IDLE = 4'd0,
        RD_ACTIVE = 4'd1,
        RD_WAIT_TRCD = 4'd2,
        RD_READ = 4'd3,
        RD_WAIT_CAS = 4'd4,
        RD_READ_DATA = 4'd5,
        RD_PRECHARGE = 4'd6,
        RD_WAIT_TRP = 4'd7,
        RD_END = 4'd8;
    
    reg [3:0] rd_state;
    reg [7:0] count_clk;
    reg reset_count_clk;

    assign rd_end = (rd_state == RD_END);

    reg valid_read;
    wire trcd_end, trp_end, tcas_end, tread_end, rdburst_end;
    
    // to prevent toggling of valid_read
    reg read_done;

    // Write cycle start tracking for validity
    wire [7:0] rd_data_cycles;
    reg [7:0] rd_cycle_count;

    // Driven high when the last read cycle is encountered
    wire last_cycle;
    assign last_cycle = (rd_cycle_count == rd_blen_in - 1'b1);

    // Number of cycles for RD_READ_DATA state
    assign rd_data_cycles = (rd_blen_in > TCAS_COUNT) ? (rd_blen_in - TCAS_COUNT) : 1'b1;
    
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            rd_cycle_count <= 8'd0;
        else if (tcas_end) 
            rd_cycle_count <= 8'd0;
        else if (last_cycle)
            rd_cycle_count <= 8'd0;
        else if (rd_state == RD_IDLE)
            rd_cycle_count <= 8'd0;
        else
            rd_cycle_count <= rd_cycle_count + 1'b1;
    end

    assign trcd_end = ((rd_state == RD_WAIT_TRCD) & (count_clk == TRCD_COUNT - 1'b1));
    assign trp_end = ((rd_state == RD_WAIT_TRP) & (count_clk == TRP_COUNT - 1'b1));
    assign tcas_end = ((rd_state == RD_WAIT_CAS) & (count_clk == TCAS_COUNT - 1'b1));
    assign tread_end = ((rd_state == RD_READ_DATA) & (rd_cycle_count == rd_data_cycles - 1'b1));
    
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            count_clk <= 8'd0;
        else if (reset_count_clk)
            count_clk <= 8'd0;
        else
            count_clk <= count_clk + 1'b1;        
    end

    // counter reset logic
    always @(*) begin
        case (rd_state)
            RD_WAIT_TRCD: reset_count_clk = trcd_end;
            RD_WAIT_TRP: reset_count_clk = trp_end;
            RD_READ_DATA: reset_count_clk = tread_end;
            RD_WAIT_CAS: reset_count_clk = tcas_end;
            default: reset_count_clk = 1'b1;
        endcase
    end

    // FSM transitions
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            rd_state <= RD_IDLE;
        else begin
            case (rd_state)
                RD_IDLE: begin
                    if (rd_en & init_done)
                        rd_state <= RD_ACTIVE;
                    else
                        rd_state <= RD_IDLE;
                end

                RD_ACTIVE: begin
                    rd_state <= RD_WAIT_TRCD;
                end

                RD_WAIT_TRCD: begin
                    if (trcd_end)
                        rd_state <= RD_READ;
                    else
                        rd_state <= RD_WAIT_TRCD;
                end

                RD_READ:
                    rd_state <= RD_WAIT_CAS;

                RD_WAIT_CAS: begin
                    if (tcas_end)
                        rd_state <= RD_READ_DATA;
                    else
                        rd_state <= RD_WAIT_CAS;
                end

                RD_READ_DATA: begin
                    if (tread_end) begin
                        if (rd_addr_in[10] == 1'b1)
                            rd_state <= RD_WAIT_TRP;
                        else
                            rd_state <= RD_PRECHARGE;
                    end

                    else
                        rd_state <= RD_READ_DATA;
                end

                RD_PRECHARGE:
                    rd_state <= RD_WAIT_TRP;

                RD_WAIT_TRP: begin
                    if (trp_end)
                        rd_state <= RD_END;
                    else
                        rd_state <= RD_WAIT_TRP; 
                end

                RD_END:
                    rd_state <= RD_IDLE;

                default:
                    rd_state <= RD_IDLE;

            endcase
        end
    end

    // SDRAM outputs
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            rd_cmd_out <= CMD_NOP;
            rd_bank_out <= 2'b11;
            rd_addr_out <= 12'hfff;
        end
        else begin
            case (rd_state)
                RD_IDLE: begin
                    rd_cmd_out <= CMD_NOP;
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= 1'b0;
                    read_done <= 1'b0;
                end

                RD_ACTIVE: begin
                    rd_cmd_out <= CMD_ACTIVE;
                    rd_bank_out <= rd_addr_in[24:23];
                    rd_addr_out <= rd_addr_in[22:11]; // row addr
                    valid_read <= 1'b0;
                    read_done <= 1'b0;
                end

                RD_READ: begin
                    rd_cmd_out <= CMD_READ;
                    rd_bank_out <= rd_addr_in[24:23];
                    rd_addr_out <= {4'b0000, rd_addr_in[7:0]}; // col addr
                    valid_read <= 1'b0;
                    read_done <= 1'b0;
                end

                RD_WAIT_CAS: begin
                    rd_cmd_out <= CMD_NOP;
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= (tcas_end) ? 1'b1 : 1'b0;
                    read_done <= 1'b0;
                end

                RD_READ_DATA: begin
                    if (tread_end) begin
                        rd_cmd_out <= CMD_BURST_TERM;
                    end
                    else begin
                        rd_cmd_out <= CMD_NOP;
                    end
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= (last_cycle) ? 1'b0 : ~read_done;
                    read_done <= (read_done | last_cycle);
                end

                RD_PRECHARGE: begin
                    rd_cmd_out <= CMD_PRECHARGE;
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= (last_cycle) ? 1'b0 : ~read_done;
                    read_done <= (read_done | last_cycle);
                end

                RD_WAIT_TRP: begin
                    rd_cmd_out <= CMD_NOP;
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= (last_cycle) ? 1'b0 : ~read_done;
                    read_done <= (read_done | last_cycle);
                end

                RD_END: begin
                    rd_cmd_out <= CMD_NOP;
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= 1'b0;
                    read_done <= read_done;
                end

                default: begin
                    rd_cmd_out <= CMD_NOP;
                    rd_bank_out <= 2'b11;
                    rd_addr_out <= 12'hfff;
                    valid_read <= 1'b0;
                    read_done <= read_done;
                end
            endcase
        end
    end

    // DQM latency handling using a shift register
    reg [TCAS_COUNT-1:0] dqm_reg;
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            rd_dqm_out <= 1'b0;
            dqm_reg <= {TCAS_COUNT{1'b0}};
        end
        else begin
            rd_dqm_out <= dqm_reg[TCAS_COUNT-1];
            dqm_reg <= {dqm_reg[TCAS_COUNT-2:0], rd_dqm_in};
        end
    end

    // Data latch - rd_data_in comes from the sdram model
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) 
            rd_data_out <= 16'd0;
        else  if (~dqm_reg[TCAS_COUNT-1] && valid_read)
            rd_data_out <= rd_data_in;
        else
            rd_data_out <= 16'd1;
    end

endmodule