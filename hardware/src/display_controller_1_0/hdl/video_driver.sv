module video_driver #(
    //1920*1080分辨率时序参数
    parameter integer H_SYNC  = 12'd44,    //行同步
    parameter integer H_BACK  = 12'd148,   //行显示后沿
    parameter integer H_DISP  = 12'd1920,  //行有效数据
    parameter integer H_FRONT = 12'd88,    //行显示前沿
    parameter integer H_TOTAL = 12'd2200,  //行扫描周期

    parameter integer V_SYNC = 12'd5,  //场同步
    parameter integer V_BACK = 12'd36,  //场显示后沿
    parameter integer V_DISP = 12'd1080,  //场有效数据
    parameter integer V_FRONT = 12'd4,  //场显示前沿
    parameter integer V_TOTAL = 12'd1125  //场扫描周期
) (
    input reset,
    input pixel_clk,

    output logic [23:0] rgb,
    output logic hsync,
    output logic vsync,
    output logic de,

    input [23:0] pixel_data,
    output logic [10:0] pixel_xpos,
    output logic [10:0] pixel_ypos,
    output logic [11:0] cnt_v,
    output logic [11:0] cnt_h
);
  logic data_req;

  assign rgb = de ? pixel_data : 24'd0;
  assign hsync = (cnt_h < H_SYNC) ? 1'b0 : 1'b1;
  assign vsync = (cnt_v < V_SYNC) ? 1'b0 : 1'b1;

  assign pixel_xpos = data_req ? cnt_h + 11'd2 - H_SYNC - H_BACK : 0;

  always @(posedge pixel_clk or negedge reset) begin
    if (reset == 0) de <= 1'd0;
    else de <= data_req;
  end

  always @(posedge pixel_clk or negedge reset) begin
    if (reset == 0) data_req <= 1'b0;
    else if(((cnt_h >= H_SYNC + H_BACK - 12'd2) && (cnt_h < H_SYNC + H_BACK + H_DISP - 12'd2))
                  && ((cnt_v >= V_SYNC + V_BACK) && (cnt_v < V_SYNC + V_BACK+V_DISP)))
      data_req <= 1'd1;
    else data_req <= 1'd0;
  end

  always @(posedge pixel_clk or negedge reset) begin
    if (reset == 0) pixel_ypos <= 11'd0;
    else if ((cnt_v >= (V_SYNC + V_BACK)) && (cnt_v < (V_SYNC + V_BACK + V_DISP)))
      pixel_ypos <= cnt_v + 11'd1 - (V_SYNC + V_BACK);
    else pixel_ypos <= 11'd0;
  end

  always @(posedge pixel_clk or negedge reset) begin
    if (reset == 0) cnt_h <= 12'd0;
    else begin
      if (cnt_h < H_TOTAL - 12'd1) cnt_h <= cnt_h + 12'd1;
      else cnt_h <= 12'd0;
    end
  end

  always @(posedge pixel_clk or negedge reset) begin
    if (reset == 0) cnt_v <= 12'd0;
    else if (cnt_h == H_TOTAL - 12'd1) begin
      if (cnt_v < V_TOTAL - 12'd1) cnt_v <= cnt_v + 12'd1;
      else cnt_v <= 12'd0;
    end
  end

endmodule
