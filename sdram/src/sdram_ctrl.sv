`timescale 1ns / 1ps

// dram timing is designed to satisfy both 100MHz and 133MHz, but the FPGA may not able to do so.

module SDRAM_CTRL(
    input clk,
    input aux_clk,
    input rst_n,

    input cmd_en,
    input cmd_wr_rd, // 0: write, 1: read
    output cmd_av,
    
    input [9:0] cmd_len, // write length in 2Bytes
    input [24:0] cmd_adr, // address in 2Bytes
    //CS 1bit, row 13bits, bank 2bits, col 9bits

    output [9:0] wr_remain_space, 
    // user should not write data when this is 0
    // unless you know what you are doing
    
    input wr_en,
    input [15:0] wr_data,
    input [1:0] wr_mask,
    // write procedure might start immediately
    // so it's recommended to write all data into the buffer first
    // or write the buffer faster than the SDRAM and at least one data should be in the buffer
    
    output [9:0] rd_remain_space, 
    // user should not read data longer than this
    // unless you know what you are doing
    // it would be possible to read more data than this
    // when the readout speed is fast enough


    output [15:0] rd_data,
    output rd_av,
    input rd_en,
    //CS 1bit, row 13bits, bank 2bits, col 9bits
  


    output cs,
    output ras,
    output cas,
    output we,

    output [12:0] adr,
    output [1:0] ba,

    output [1:0] dqm,
    inout [15:0] dq,

    output init_fin
);


reg cs_r;
reg ras_r;
reg cas_r;
reg we_r;

reg [12:0] adr_r;
reg [1:0] ba_r;

reg [1:0] dqm_r;

reg [15:0] dq_wr;
wire [15:0] dq_rd;
reg dq_wr_en;

assign dq_rd = dq;
assign dq = dq_wr_en ? dq_wr : 16'hZZ;


reg [15:0] dq_rd_buf;
always@(posedge aux_clk)begin
    dq_rd_buf <= dq_rd;
end


reg cke_r;



// init zone
reg init_cs_r;
reg init_ras_r;
reg init_cas_r;
reg init_we_r;

reg [12:0] init_adr_r;
// init zone end

// work zone
reg cs_w;
reg ras_w;
reg cas_w;
reg we_w;

reg [12:0] adr_w;
reg [1:0] ba_w;

reg [1:0] dqm_w;
// work zone end


// refresh 8192 times in 64ms
// assume 100MHz clk
// 64ms / 8192 = 7.8125us
// 7.81us / 10ns = 781
reg ref_sel;
reg [9:0] ref_cnt;


`include "sdram_tasks.svh"

//cs 2, bank 4
reg [0:7] opened_rows;
reg [12:0] opened_row_adr [0:7];


// init

reg init_fin_r;
reg [3:0] init_state;
reg [12:0] init_cnt_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cke_r <= 1'b0;

        init_fin_r <= 1'b0;
        init_state <= 4'b0000;
        init_cnt_r <= 13'b0;

        init_cs_r <= 1'b0;
        init_nop();
    end else begin
        init_nop();
        init_cnt_r <= init_cnt_r + 1'b1;

        case(init_state)
            0: begin // half wait
                if(init_cnt_r == 13'd6400) begin // about 64us
                    init_state <= 4'd1;
                    init_cnt_r <= 13'b0;
                end
            end
            1: begin // half wait, give cke
                cke_r <= 1'b1;
                if(init_cnt_r == 13'd6400) begin // about 64us
                    init_state <= 4'd2;
                    init_cnt_r <= 13'b0;

                    init_precharge_all_bank();
                end
            end
            2: begin // wait precharge
                if(init_cnt_r == 13'd3) begin // about 64us
                    init_state <= 4'd3;
                    init_cnt_r <= 13'b0;

                    init_auto_refresh();
                end
            end
            3: begin // wait auto refresh
                if(init_cnt_r == 13'd9) begin // about 64us
                    init_state <= 4'd4;
                    init_cnt_r <= 13'b0;

                    init_auto_refresh();
                end
            end
            4: begin // wait auto refresh
                if(init_cnt_r == 13'd9) begin // about 64us
                    init_state <= 4'd5;
                    init_cnt_r <= 13'b0;

                    init_load_mode_reg(13'h130); //WR Single, CL3, BL1
                end
            end
            5: begin
                if(init_cs_r == 1'b0) begin // init the second SDRAM
                    init_state <= 4'd2;
                    init_cnt_r <= 13'b0;

                    init_cs_r <= 1'b1;

                    init_precharge_all_bank();
                end else begin
                    if(init_cnt_r == 13'd3) begin
                        init_state <= 4'd6;

                        init_fin_r <= 1'b1;
                    end
                end
            end
            6: begin
                init_cnt_r <= 13'b0; // stop it to reduce power
            end
        endcase
    end
end

reg [17:0] wr_buf [0:4095];
reg [11:0] wr_ptr_in;
reg [11:0] wr_ptr_out;

reg [9:0] wr_remain_space_r;


reg [15:0] rd_buf [0:4095];
reg [11:0] rd_ptr_in;
reg [11:0] rd_ptr_out;

reg [9:0] rd_remain_space_r;


reg [24:0] adr_counter;

reg [9:0] cur_cnt;


reg [35:0] cmd_buf [0:7]; // 7 commands in queue at most
reg [2:0] cmd_ptr_in;
reg [2:0] cmd_ptr_out;

reg cmd_av_r;

reg cmd_wr_rd_wk;
wire cmd_cs; assign cmd_cs = adr_counter[24];
wire [12:0] cmd_row; assign cmd_row = adr_counter[23:11];
wire [1:0] cmd_bank; assign cmd_bank = adr_counter[10:9];
wire [8:0] cmd_col; assign cmd_col = adr_counter[8:0];



reg [1:0] rd_pre_fill;
reg [15:0] rd_out_buf;
reg rd_av_r;
reg [15:0] rd_data_r;

reg [2:0] major_state;

reg [3:0] major_tick;

reg [15:0] write_fifo_out_buf;
reg [1:0] write_fifo_out_buf_mask;

reg [4:0] rd_tick;

// major

always@(posedge clk)begin
    if(!init_fin_r)begin
        ref_sel <= 1'b0;
        ref_cnt <= 10'b0;

        cmd_av_r <= 1'b0;
        cmd_ptr_in <= 3'b0;
        cmd_ptr_out <= 3'b0;
        
        wr_ptr_in <= 12'b0;
        wr_ptr_out <= 12'b0;

        rd_ptr_in <= 12'b0;
        rd_ptr_out <= 12'b0;

        major_state <= 3'b0;
        major_tick <= 4'd15;

        rd_tick <= 5'd0;
        rd_pre_fill <= 2'b0;
        rd_av_r <= 1'b0;

        wr_remain_space_r <= 10'd0;
        rd_remain_space_r <= 10'd0;

        nop();
    end else begin
        nop();
        ref_cnt <= ref_cnt + 1'b1;
        dq_wr_en <= 1'b0;

        rd_tick <= {rd_tick[3:0], 1'b0};
        
        // cmd fifo
        if(cmd_en && cmd_av)begin
            cmd_buf[cmd_ptr_in] <= {cmd_wr_rd, cmd_len, cmd_adr};
            cmd_ptr_in <= cmd_ptr_in + 1'b1;
        end
        cmd_av_r <= 1'b1;
        if(cmd_ptr_in + 3'b1 == cmd_ptr_out)begin
            cmd_av_r <= 1'b0;
        end
        if(cmd_ptr_in + 3'b10 == cmd_ptr_out && cmd_en)begin
            cmd_av_r <= 1'b0;
        end
        // cmd end

        // write fifo
        if(wr_en)begin
            wr_buf[wr_ptr_in] <= {wr_mask, wr_data};
            wr_ptr_in <= wr_ptr_in + 1'b1;
        end
        if(wr_ptr_out - wr_ptr_in - 16 > 12'd1023)begin
            wr_remain_space_r <= 10'd1023;
        end else begin
            wr_remain_space_r <= wr_ptr_out - wr_ptr_in - 16;
            if(wr_ptr_out - wr_ptr_in < 16)begin
                wr_remain_space_r <= 10'd0;
            end
        end
        // write end

        // read fifo
        rd_data_r <= rd_data_r;
        if(rd_ptr_out != rd_ptr_in)begin
            if(rd_av_r == 1'b0)begin
                rd_data_r <= rd_buf[rd_ptr_out];
                rd_ptr_out <= rd_ptr_out + 1'b1;
                rd_av_r <= 1'b1;
            end
        end

        if(rd_en && rd_av_r)begin
            if(rd_ptr_out == rd_ptr_in)begin
                rd_av_r <= 1'b0;
            end else begin
                rd_ptr_out <= rd_ptr_out + 1'b1;
                rd_data_r <= rd_buf[rd_ptr_out];
            end
        end


        if(rd_ptr_in - rd_ptr_out - 16 > 12'd1023)begin
            rd_remain_space_r <= 10'd1023;
        end else begin
            rd_remain_space_r <= rd_ptr_in - rd_ptr_out - 16;
            if(rd_ptr_in - rd_ptr_out < 16)begin
                rd_remain_space_r <= 10'd0;
            end
        end
        // read end

        // major
        if(major_tick != 4'd0)begin
            major_tick <= major_tick - 1'b1;
        end
        case(major_state)
            0:begin
                if(cmd_ptr_in != cmd_ptr_out && major_tick == 0)begin
                    cmd_wr_rd_wk <= cmd_buf[cmd_ptr_out][35];
                    cur_cnt <= cmd_buf[cmd_ptr_out][34:25];
                    adr_counter <= cmd_buf[cmd_ptr_out][24:0];

                    major_state <= 1;
                    cmd_ptr_out <= cmd_ptr_out + 1'b1;

                    if(cmd_buf[cmd_ptr_out][35] == 1'b0)begin // write
                        write_fifo_out_buf <= wr_buf[wr_ptr_out][15:0];
                        write_fifo_out_buf_mask <= wr_buf[wr_ptr_out][17:16];

                        wr_ptr_out <= wr_ptr_out + 1'b1;
                    end

                    if(cmd_buf[cmd_ptr_out][34:25] == 0)begin
                        major_state <= 0;
                        wr_ptr_out <= wr_ptr_out;
                    end
                end
            end
            1:begin
                if(cur_cnt == 10'd0)begin
                    major_state <= 0;
                end else begin
                    //check if current row is opened
                    if(opened_rows[{cmd_cs,cmd_bank}] && opened_row_adr[{cmd_cs,cmd_bank}][12:0] == cmd_row)begin
                        // opened, directly read
                        if(cmd_wr_rd_wk == 1'b0)begin // write
                            write(cmd_cs,cmd_bank,cmd_col,write_fifo_out_buf,write_fifo_out_buf_mask);

                            write_fifo_out_buf <= wr_buf[wr_ptr_out][15:0];
                            write_fifo_out_buf_mask <= wr_buf[wr_ptr_out][17:16];

                            if(cur_cnt>1)wr_ptr_out <= wr_ptr_out + 1'b1;

                        end else begin // read
                            read(cmd_cs,cmd_bank,cmd_col);
                            rd_tick[0] <= 1'b1;
                        end
                        
                        cur_cnt <= cur_cnt - 1'b1;
                        adr_counter <= adr_counter + 1'b1;
                    end else begin
                        if(opened_rows[{cmd_cs,cmd_bank}])begin
                            // opened, but not current row, close it
                            precharge(cmd_cs,cmd_bank);
                            opened_rows[{cmd_cs,cmd_bank}] <= 1'b0;

                            major_state <= 2;
                            major_tick <= 4'd2;
                        end else begin
                            // not opened, open it
                            active(cmd_cs,cmd_bank,cmd_row);
                            opened_rows[{cmd_cs,cmd_bank}] <= 1'b1;
                            opened_row_adr[{cmd_cs,cmd_bank}] <= cmd_row;

                            major_state <= 2;
                            major_tick <= 4'd2;
                        end
                    end

                    if(major_tick != 4'd0)begin
                        major_state <= 2;
                    end
                end
            end
            2:begin
                if(major_tick == 0)begin
                    major_state <= 1;
                end
            end
        endcase

        if(rd_tick[4])begin
            rd_ptr_in <= rd_ptr_in + 1'b1;
            rd_buf[rd_ptr_in] <= dq_rd_buf;
        end


        if(ref_cnt == 10'd775) begin // about 7.81us
            major_tick <= 4'd15;
        end
        if(ref_cnt == 10'd781) begin // about 7.81us
            ref_cnt <= 10'b0;
        end
        if(ref_cnt == 10'd0)begin // refresh the first SDRAM
            opened_rows <= 8'h00;

            precharge_all_bank(0);
        end
        if(ref_cnt == 10'd1)begin
            precharge_all_bank(1);
        end
        if(ref_cnt == 10'd4)begin
            auto_refresh(0);
        end
        if(ref_cnt == 10'd5)begin
            auto_refresh(1);
            major_tick <= 4'd10;
        end
    end
end



always_comb begin
    if(init_fin_r == 1'b0)begin
        cs_r <= init_cs_r;
        ras_r <= init_ras_r;
        cas_r <= init_cas_r;
        we_r <= init_we_r;

        adr_r <= init_adr_r;
        ba_r <= 2'b00;
        dqm_r <= 2'b11;

    end else begin
        cs_r <= cs_w;
        ras_r <= ras_w;
        cas_r <= cas_w;
        we_r <= we_w;

        adr_r <= adr_w;
        ba_r <= ba_w;
        dqm_r <= dqm_w;
    end
end

assign cs = cs_r;
assign ras = ras_r;
assign cas = cas_r;
assign we = we_r;

assign adr = adr_r;
assign ba = ba_r;

assign dqm = dqm_r;

assign init_fin = init_fin_r;

assign cmd_av = cmd_av_r;
assign wr_remain_space = wr_remain_space_r;
assign rd_remain_space = rd_remain_space_r;

assign rd_data = rd_data_r;
assign rd_av = rd_av_r;

endmodule
