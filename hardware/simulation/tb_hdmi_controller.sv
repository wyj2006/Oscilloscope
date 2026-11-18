`timescale 1ns / 1ns

module tb_hdmi_controller ();

  logic       sys_clk;
  logic       reset;

  logic       tmds_clk_p;
  logic       tmds_clk_n;
  logic [2:0] tmds_data_p;
  logic [2:0] tmds_data_n;

  initial begin
    sys_clk = 1'b1;
    reset <= 1'b0;
    #201 reset <= 1'b1;
  end

  //产生50Mhz时钟
  always #10 sys_clk <= ~sys_clk;

  //例化HDMI彩条显示地顶层模块
  hdmi_controller hdmi_controller (
      .sys_clk(sys_clk),
      .reset  (reset),

      .tmds_clk_p (tmds_clk_p),   // TMDS 时钟通道
      .tmds_clk_n (tmds_clk_n),
      .tmds_data_p(tmds_data_p),  // TMDS 数据通道
      .tmds_data_n(tmds_data_n)
  );

endmodule
