module dvi_transmitter (
    input reset,
    input pixel_clk,
    input pixel_clk_5x,

    input [23:0] rgb,
    input hsync,
    input vsync,
    input de,

    output logic tmds_clk_p,
    output logic tmds_clk_n,
    output logic [2:0] tmds_data_p,
    output logic [2:0] tmds_data_n,
    output logic tmds_oen
);

  logic sync_reset;  //高有效

  logic [2:0] tmds_data_serial;
  logic tmds_clk_serial;

  logic [9:0] red_10bit;
  logic [9:0] green_10bit;
  logic [9:0] blue_10bit;
  logic [9:0] clk_10bit;

  assign tmds_oen  = 1;
  assign clk_10bit = 10'b1111100000;

  async_reset_sync async_rst_sync (
      .reset(reset),
      .clk  (pixel_clk),

      .sync_reset(sync_reset)
  );

  dvi_encoder encoder_b (
      .clk  (pixel_clk),
      .reset(sync_reset),

      .din (rgb[7:0]),
      .c0  (hsync),
      .c1  (vsync),
      .de  (de),
      .dout(blue_10bit)
  );

  dvi_encoder encoder_g (
      .clk  (pixel_clk),
      .reset(sync_reset),

      .din (rgb[15:8]),
      .c0  (1'b0),
      .c1  (1'b0),
      .de  (de),
      .dout(green_10bit)
  );

  dvi_encoder encoder_r (
      .clk  (pixel_clk),
      .reset(sync_reset),

      .din (rgb[23:16]),
      .c0  (1'b0),
      .c1  (1'b0),
      .de  (de),
      .dout(red_10bit)
  );

  serializer_10to1 serializer_b (
      .reset        (sync_reset),
      .paralell_clk (pixel_clk),
      .serial_clk   (pixel_clk_5x),
      .paralell_data(blue_10bit),

      .serial_data(tmds_data_serial[0])
  );

  serializer_10to1 serializer_g (
      .reset        (sync_reset),
      .paralell_clk (pixel_clk),
      .serial_clk   (pixel_clk_5x),
      .paralell_data(green_10bit),

      .serial_data(tmds_data_serial[1])
  );

  serializer_10to1 serializer_r (
      .reset        (sync_reset),
      .paralell_clk (pixel_clk),
      .serial_clk   (pixel_clk_5x),
      .paralell_data(red_10bit),

      .serial_data(tmds_data_serial[2])
  );

  serializer_10to1 serializer_clk (
      .reset        (sync_reset),
      .paralell_clk (pixel_clk),
      .serial_clk   (pixel_clk_5x),
      .paralell_data(clk_10bit),

      .serial_data(tmds_clk_serial)
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33")
  ) TMDS0 (
      .I (tmds_data_serial[0]),
      .O (tmds_data_p[0]),
      .OB(tmds_data_n[0])
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33")
  ) TMDS1 (
      .I (tmds_data_serial[1]),
      .O (tmds_data_p[1]),
      .OB(tmds_data_n[1])
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33")
  ) TMDS2 (
      .I (tmds_data_serial[2]),
      .O (tmds_data_p[2]),
      .OB(tmds_data_n[2])
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33")
  ) TMDS3 (
      .I (tmds_clk_serial),
      .O (tmds_clk_p),
      .OB(tmds_clk_n)
  );

endmodule
