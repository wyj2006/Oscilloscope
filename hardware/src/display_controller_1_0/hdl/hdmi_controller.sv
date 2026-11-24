module hdmi_controller (
    input sys_clk,
    input reset,

    output logic       tmds_clk_p,
    output logic       tmds_clk_n,
    output logic [2:0] tmds_data_p,
    output logic [2:0] tmds_data_n
);

  logic        pixel_clk;
  logic        pixel_clk_5x;
  logic        clk_locked;

  logic [10:0] pixel_xpos;
  logic [10:0] pixel_ypos;
  logic [23:0] pixel_data;

  logic        hsync;
  logic        vsync;
  logic        de;
  logic [23:0] rgb;

  pixel_clk_gen pixel_clk_gen (
      .clk_in1 (sys_clk),
      .clk_out1(pixel_clk),
      .clk_out2(pixel_clk_5x),

      .reset (~reset),
      .locked(clk_locked)
  );

  video_driver video_driver (
      .pixel_clk(pixel_clk),
      .reset(reset),

      .hsync(hsync),
      .vsync(vsync),
      .de(de),
      .rgb(rgb),

      .pixel_xpos(pixel_xpos),
      .pixel_ypos(pixel_ypos),
      .pixel_data(pixel_data)
  );

  video_generator video_generator (
      .pixel_clk(pixel_clk),
      .reset(reset),

      .pixel_xpos(pixel_xpos),
      .pixel_ypos(pixel_ypos),
      .pixel_data(pixel_data)
  );

  dvi_transmitter dvi_transmitter (
      .pixel_clk   (pixel_clk),
      .pixel_clk_5x(pixel_clk_5x),
      .reset(reset & clk_locked),

      .rgb  (rgb),
      .hsync(hsync),
      .vsync(vsync),
      .de   (de),

      .tmds_clk_p (tmds_clk_p),
      .tmds_clk_n (tmds_clk_n),
      .tmds_data_p(tmds_data_p),
      .tmds_data_n(tmds_data_n),
      .tmds_oen   ()
  );

endmodule
