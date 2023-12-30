module top(
    input clk_50M,
    input rst_n, //press S1 to start

    output sdram_clk,
    output sdram_cs,
    output sdram_ras,
    output sdram_cas,
    output sdram_we,

    output [12:0] sdram_adr,
    output [1:0] sdram_ba,
    output [1:0] sdram_dqm,
    inout [15:0] sdram_dq
);

wire clk_100M;
wire sdram_init_fin;

reg cmd_en;
reg cmd_wr_rd;
wire cmd_av;

reg [9:0] cmd_len;
reg [24:0] cmd_adr;

wire [9:0] wr_remain_space;
reg wr_en;
reg [15:0] wr_data;
reg [1:0] wr_mask;

wire [9:0] rd_remain_space;
wire rd_av;
reg rd_en;
wire [15:0] rd_data;


reg [3:0] test_status;

always@(posedge clk_100M or negedge sdram_init_fin)begin
    if(!sdram_init_fin)begin
        cmd_en <= 1'b0;
        cmd_wr_rd <= 1'b0;
        cmd_len <= 10'd0;
        cmd_adr <= 25'd0;

        wr_en <= 1'b0;
        wr_data <= 16'd0;
        wr_mask <= 2'd0;

        rd_en <= 1'b0;

        test_status <= 4'd0;
    end else begin
        rd_en<=1'b0;
        cmd_en<=1'b0;
        wr_en<=1'b0;
        case(test_status)
            4'd0:begin
                wr_en <= 1'b1;
                wr_data <= 16'd1234;
                wr_mask <= 2'b00;
                test_status <= 4'd1;
            end
            1:begin
                wr_en <= 1'b1;
                wr_data <= 16'd5678;
                test_status <= 4'd2;
            end
            2:begin
                wr_en <= 1'b1;
                wr_data <= 16'd9012;
                test_status <= 4'd3;
            end
            3:begin
                wr_en <= 1'b1;
                wr_data <= 16'd3456;
                test_status <= 4'd4;
            end
            4:begin
                wr_en <= 1'b1;
                wr_data <= 16'd7890;
                test_status <= 4'd5;
            end
            5:begin
                wr_en <= 1'b1;
                wr_data <= 16'd1234;
                test_status <= 4'd6;
            end
            6:begin
                cmd_en <= 1'b1;
                cmd_wr_rd <= 1'b0;
                cmd_len <= 10'd3;
                cmd_adr <= 25'h0;
                test_status <= 4'd7;
            end
            7:begin
                cmd_en <= 1'b1;
                cmd_wr_rd <= 1'b0;
                cmd_len <= 10'd3;
                cmd_adr <= 25'h1000000;
                test_status <= 4'd8;
            end
            8:begin
                cmd_en <= 1'b1;
                cmd_wr_rd <= 1'b1;
                cmd_len <= 10'd3;
                cmd_adr <= 25'h0;
                test_status <= 4'd9;
            end
            9:begin
                cmd_en <= 1'b1;
                cmd_wr_rd <= 1'b1;
                cmd_len <= 10'd3;
                cmd_adr <= 25'h1000000;
                test_status <= 4'd10;
            end
            10:begin
                if(rd_av)begin
                    rd_en <= 1'b1;
                end
            end
        endcase
    end
end



PLL100 SDRAM_PLL(
    .clkout0(clk_100M), //output clkout0
    .clkout1(sdram_clk),
    .clkin(clk_50M) //input clkin
);

SDRAM_CTRL SDRAM(
    .clk(clk_100M),
    .rst_n(rst_n),

    .cmd_en(cmd_en),
    .cmd_wr_rd(cmd_wr_rd),
    .cmd_av(cmd_av),
    .cmd_len(cmd_len),
    .cmd_adr(cmd_adr),

    .wr_remain_space(wr_remain_space),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .wr_mask(wr_mask),

    .rd_remain_space(rd_remain_space),
    .rd_av(rd_av),
    .rd_en(rd_en),
    .rd_data(rd_data),

    .cs(sdram_cs),
    .ras(sdram_ras),
    .cas(sdram_cas),
    .we(sdram_we),
    .adr(sdram_adr),
    .ba(sdram_ba),
    .dqm(sdram_dqm),
    .dq(sdram_dq),

    .init_fin(sdram_init_fin)
);


endmodule
