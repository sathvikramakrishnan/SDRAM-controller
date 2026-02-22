`timescale 1ns / 1ps

module sdram_init(
    input sys_clk,
    input sys_reset_n,
    output reg [3:0] init_cmd_out,
    output reg [1:0] init_bank_out,
    output reg [11:0] init_addr_out,
    output init_done
);

    // 150us assertion parameter for 10ns clock time period
    // counts number of clock cycles required
    parameter count_power_on = 14'd15_000;
    
    wire power_on_wait_done;
    reg [13:0] count_150us;

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            count_150us <= 1'b0;
        else if (count_150us == count_power_on)
            count_150us <= 1'b0;
        else
            count_150us <= count_150us + 1'b1;
    end

    // completion of 150us  power-up  wait required for SDRAM init
    assign power_on_wait_done = (count_150us == count_power_on);

    // FSM parameters for the different states involved in initialization
    parameter 
        INIT_POWER_ON_WAIT = 3'd0,
        INIT_PRECHARGE = 3'd1,
        INIT_WAIT_TRP = 3'd2,
        INIT_AUTO_REF = 3'd3,
        INIT_WAIT_TRFC = 3'd4,
        INIT_MODE_REG = 3'd5,
        INIT_WAIT_TMRD = 3'd6,
        INIT_END = 3'd7;
    
    reg [2:0] init_state;
    reg [2:0] count_clock;
    reg rst_clock_count; // keep track of clock cycles for wait

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            count_clock <= 3'd0;
        else if (rst_clock_count)
            count_clock <= 3'd0; // reset when requested
        else
            count_clock <= count_clock + 1'b1;
    end

    wire trp_end, trfc_end, tmrd_end;

    // SDRAM timing constraints (units: number of clock cycles) from data sheet
    parameter 
        TRP_COUNT = 3'd2,
        TRFC_COUNT = 3'd7,
        TMRD_COUNT = 3'd2;
    
    assign trp_end = ((init_state == INIT_WAIT_TRP) & (count_clock == TRP_COUNT - 1'b1));
    assign trfc_end = ((init_state == INIT_WAIT_TRFC) & (count_clock == TRFC_COUNT - 1'b1));
    assign tmrd_end = ((init_state == INIT_WAIT_TMRD) &  (count_clock == TMRD_COUNT - 1'b1));

    always @(*) begin
        case (init_state)
            INIT_WAIT_TRP: rst_clock_count = trp_end;
            INIT_WAIT_TRFC: rst_clock_count = trfc_end;
            INIT_WAIT_TMRD: rst_clock_count = tmrd_end;
            default: rst_clock_count = 1'b1;
        endcase        
    end

    reg [2:0] cnt_auto_ref; // tracks number of auto refresh cycles


    // FSM transitions
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            init_state     <= INIT_POWER_ON_WAIT;
            cnt_auto_ref   <= 3'd0;
        end 
        else begin
            case (init_state)
                INIT_POWER_ON_WAIT: begin
                    cnt_auto_ref <= 3'd0;
                    if (power_on_wait_done)
                        init_state <= INIT_PRECHARGE;
                end

                INIT_PRECHARGE:
                    init_state <= INIT_WAIT_TRP;

                INIT_WAIT_TRP:
                    if (trp_end)
                        init_state <= INIT_AUTO_REF;

                INIT_AUTO_REF:
                    init_state <= INIT_WAIT_TRFC;

                INIT_WAIT_TRFC: begin
                    if (trfc_end) begin
                        if (cnt_auto_ref == 3'd4) // after 5 refershes (0 to 4)
                            init_state <= INIT_MODE_REG;
                        else begin
                            init_state   <= INIT_AUTO_REF;
                            cnt_auto_ref <= cnt_auto_ref + 1;
                        end
                    end
                end

                INIT_MODE_REG:
                    init_state <= INIT_WAIT_TMRD;

                INIT_WAIT_TMRD:
                    if (tmrd_end)
                        init_state <= INIT_END;

                INIT_END:
                    init_state <= INIT_END;

                default:
                    init_state <= INIT_POWER_ON_WAIT;
            endcase
        end
    end

    assign init_done = (init_state == INIT_END);

    // SDRAM command definitions (4 bit command codes: CS#, RAS#, CAS#, WE#)
    localparam CMD_NOP = 4'b0111;
    localparam CMD_PRECHARGE = 4'b0010;
    localparam CMD_AUTO_REF = 4'b0001;
    localparam CMD_MODE_REG = 4'b0000;

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n) begin
            init_cmd_out <= CMD_NOP;
            init_bank_out <= 2'b11;
            init_addr_out <= 12'hfff;
        end
        else begin
            case (init_state)
                INIT_PRECHARGE: begin
                    init_cmd_out <= CMD_PRECHARGE;
                    init_bank_out <= 2'bxx; // Don't care; can also be set to default value 2'b11
                    init_addr_out <= 12'hfff; // A10 = 1
                end

                INIT_AUTO_REF: begin
                    init_cmd_out <= CMD_AUTO_REF;
                    init_bank_out <= 2'b11;
                    init_addr_out <= 12'hfff;
                end

                INIT_MODE_REG: begin
                    init_cmd_out <= CMD_MODE_REG;
                    init_bank_out <= 2'b00; //  Bank address 00 for mode register
                    init_addr_out <= 12'b00_0_00_011_0_111;
                end

                default: begin
                    init_cmd_out <= CMD_NOP;
                    init_bank_out <= 2'b11;
                    init_addr_out <= 12'hfff;
                end
            endcase
        end
    end

endmodule


module sdram_auto_ref_gen(
    input sys_clk,
    input sys_reset_n,
    input init_done,
    input aref_en,

    output reg aref_req,
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
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (~sys_reset_n)
            aref_req <= 1'b0;
        else if (clk_count == (SINGLE_ROW_COUNT - 1'b1))
            aref_req <= 1'b1;
        else
            aref_req <= 1'b0;
    end

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