
`timescale 1 ns / 1 ps

module display_controller #(
    // Parameters of Axi Master Bus Interface M_AXI
    parameter integer C_M_AXI_TARGET_SLAVE_BASE_ADDR = 32'h10000000,
    parameter integer C_M_AXI_BURST_LEN = 128,  //必须是H_DISP的因数
    parameter integer C_M_AXI_ID_WIDTH = 1,
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    parameter integer C_M_AXI_DATA_WIDTH = 32,
    parameter integer C_M_AXI_AWUSER_WIDTH = 0,
    parameter integer C_M_AXI_ARUSER_WIDTH = 0,
    parameter integer C_M_AXI_WUSER_WIDTH = 0,
    parameter integer C_M_AXI_RUSER_WIDTH = 0,
    parameter integer C_M_AXI_BUSER_WIDTH = 0
) (
    // Ports of Axi Master Bus Interface M_AXI
    input logic m_axi_aclk,
    input logic m_axi_aresetn,
    output logic [C_M_AXI_ID_WIDTH-1 : 0] m_axi_awid,
    output logic [C_M_AXI_ADDR_WIDTH-1 : 0] m_axi_awaddr,
    output logic [7 : 0] m_axi_awlen,
    output logic [2 : 0] m_axi_awsize,
    output logic [1 : 0] m_axi_awburst,
    output logic m_axi_awlock,
    output logic [3 : 0] m_axi_awcache,
    output logic [2 : 0] m_axi_awprot,
    output logic [3 : 0] m_axi_awqos,
    output logic [C_M_AXI_AWUSER_WIDTH-1 : 0] m_axi_awuser,
    output logic m_axi_awvalid,
    input logic m_axi_awready,
    output logic [C_M_AXI_DATA_WIDTH-1 : 0] m_axi_wdata,
    output logic [C_M_AXI_DATA_WIDTH/8-1 : 0] m_axi_wstrb,
    output logic m_axi_wlast,
    output logic [C_M_AXI_WUSER_WIDTH-1 : 0] m_axi_wuser,
    output logic m_axi_wvalid,
    input logic m_axi_wready,
    input logic [C_M_AXI_ID_WIDTH-1 : 0] m_axi_bid,
    input logic [1 : 0] m_axi_bresp,
    input logic [C_M_AXI_BUSER_WIDTH-1 : 0] m_axi_buser,
    input logic m_axi_bvalid,
    output logic m_axi_bready,
    output logic [C_M_AXI_ID_WIDTH-1 : 0] m_axi_arid,
    output logic [C_M_AXI_ADDR_WIDTH-1 : 0] m_axi_araddr,
    output logic [7 : 0] m_axi_arlen,
    output logic [2 : 0] m_axi_arsize,
    output logic [1 : 0] m_axi_arburst,
    output logic m_axi_arlock,
    output logic [3 : 0] m_axi_arcache,
    output logic [2 : 0] m_axi_arprot,
    output logic [3 : 0] m_axi_arqos,
    output logic [C_M_AXI_ARUSER_WIDTH-1 : 0] m_axi_aruser,
    output logic m_axi_arvalid,
    input logic m_axi_arready,
    input logic [C_M_AXI_ID_WIDTH-1 : 0] m_axi_rid,
    input logic [C_M_AXI_DATA_WIDTH-1 : 0] m_axi_rdata,
    input logic [1 : 0] m_axi_rresp,
    input logic m_axi_rlast,
    input logic [C_M_AXI_RUSER_WIDTH-1 : 0] m_axi_ruser,
    input logic m_axi_rvalid,
    output logic m_axi_rready,

    output logic       tmds_clk_p,
    output logic       tmds_clk_n,
    output logic [2:0] tmds_data_p,
    output logic [2:0] tmds_data_n
);

  //1920*1080分辨率时序参数
  parameter integer H_SYNC = 12'd44;  //行同步
  parameter integer H_BACK = 12'd148;  //行显示后沿
  parameter integer H_DISP = 12'd1920;  //行有效数据
  parameter integer H_FRONT = 12'd88;  //行显示前沿
  parameter integer H_TOTAL = 12'd2200;  //行扫描周期

  parameter integer V_SYNC = 12'd5;  //场同步
  parameter integer V_BACK = 12'd36;  //场显示后沿
  parameter integer V_DISP = 12'd1080;  //场有效数据
  parameter integer V_FRONT = 12'd4;  //场显示前沿
  parameter integer V_TOTAL = 12'd1125;  //场扫描周期

  logic        pixel_clk;
  logic        pixel_clk_5x;
  logic        clk_locked;

  logic [10:0] pixel_xpos;
  logic [10:0] pixel_ypos;
  logic [23:0] pixel_data;
  logic [11:0] cnt_v;
  logic [11:0] cnt_h;

  logic        hsync;
  logic        vsync;
  logic        de;
  logic [23:0] rgb;

  pixel_clk_gen pixel_clk_gen (
      .clk_in1 (m_axi_aclk),
      .clk_out1(pixel_clk),
      .clk_out2(pixel_clk_5x),

      .reset (~m_axi_aresetn),
      .locked(clk_locked)
  );

  video_driver #(
      .H_SYNC (H_SYNC),
      .H_BACK (H_BACK),
      .H_DISP (H_DISP),
      .H_FRONT(H_FRONT),
      .H_TOTAL(H_TOTAL),

      .V_SYNC (V_SYNC),
      .V_BACK (V_BACK),
      .V_DISP (V_DISP),
      .V_FRONT(V_FRONT),
      .V_TOTAL(V_TOTAL)
  ) video_driver (
      .pixel_clk(pixel_clk),
      .reset(m_axi_aresetn & clk_locked),

      .hsync(hsync),
      .vsync(vsync),
      .de(de),
      .rgb(rgb),

      .pixel_xpos(pixel_xpos),
      .pixel_ypos(pixel_ypos),
      .pixel_data(pixel_data),
      .cnt_v(cnt_v),
      .cnt_h(cnt_h)
  );

  dvi_transmitter dvi_transmitter (
      .pixel_clk   (pixel_clk),
      .pixel_clk_5x(pixel_clk_5x),
      .reset(m_axi_aresetn & clk_locked),

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

  video_generator #(
      .C_M_AXI_TARGET_SLAVE_BASE_ADDR(C_M_AXI_TARGET_SLAVE_BASE_ADDR),
      .C_M_AXI_BURST_LEN(C_M_AXI_BURST_LEN),
      .C_M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH),
      .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
      .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
      .C_M_AXI_AWUSER_WIDTH(C_M_AXI_AWUSER_WIDTH),
      .C_M_AXI_ARUSER_WIDTH(C_M_AXI_ARUSER_WIDTH),
      .C_M_AXI_WUSER_WIDTH(C_M_AXI_WUSER_WIDTH),
      .C_M_AXI_RUSER_WIDTH(C_M_AXI_RUSER_WIDTH),
      .C_M_AXI_BUSER_WIDTH(C_M_AXI_BUSER_WIDTH),

      .H_SYNC (H_SYNC),
      .H_BACK (H_BACK),
      .H_DISP (H_DISP),
      .H_FRONT(H_FRONT),
      .H_TOTAL(H_TOTAL),

      .V_SYNC (V_SYNC),
      .V_BACK (V_BACK),
      .V_DISP (V_DISP),
      .V_FRONT(V_FRONT),
      .V_TOTAL(V_TOTAL)
  ) video_generator (
      .m_axi_aclk(m_axi_aclk),
      .m_axi_aresetn(m_axi_aresetn & clk_locked),
      .m_axi_awid(m_axi_awid),
      .m_axi_awaddr(m_axi_awaddr),
      .m_axi_awlen(m_axi_awlen),
      .m_axi_awsize(m_axi_awsize),
      .m_axi_awburst(m_axi_awburst),
      .m_axi_awlock(m_axi_awlock),
      .m_axi_awcache(m_axi_awcache),
      .m_axi_awprot(m_axi_awprot),
      .m_axi_awqos(m_axi_awqos),
      .m_axi_awuser(m_axi_awuser),
      .m_axi_awvalid(m_axi_awvalid),
      .m_axi_awready(m_axi_awready),
      .m_axi_wdata(m_axi_wdata),
      .m_axi_wstrb(m_axi_wstrb),
      .m_axi_wlast(m_axi_wlast),
      .m_axi_wuser(m_axi_wuser),
      .m_axi_wvalid(m_axi_wvalid),
      .m_axi_wready(m_axi_wready),
      .m_axi_bid(m_axi_bid),
      .m_axi_bresp(m_axi_bresp),
      .m_axi_buser(m_axi_buser),
      .m_axi_bvalid(m_axi_bvalid),
      .m_axi_bready(m_axi_bready),
      .m_axi_arid(m_axi_arid),
      .m_axi_araddr(m_axi_araddr),
      .m_axi_arlen(m_axi_arlen),
      .m_axi_arsize(m_axi_arsize),
      .m_axi_arburst(m_axi_arburst),
      .m_axi_arlock(m_axi_arlock),
      .m_axi_arcache(m_axi_arcache),
      .m_axi_arprot(m_axi_arprot),
      .m_axi_arqos(m_axi_arqos),
      .m_axi_aruser(m_axi_aruser),
      .m_axi_arvalid(m_axi_arvalid),
      .m_axi_arready(m_axi_arready),
      .m_axi_rid(m_axi_rid),
      .m_axi_rdata(m_axi_rdata),
      .m_axi_rresp(m_axi_rresp),
      .m_axi_rlast(m_axi_rlast),
      .m_axi_ruser(m_axi_ruser),
      .m_axi_rvalid(m_axi_rvalid),
      .m_axi_rready(m_axi_rready),

      .pixel_clk(pixel_clk),
      .cnt_v(cnt_v),
      .cnt_h(cnt_h),
      .pixel_xpos(pixel_xpos),
      .pixel_ypos(pixel_ypos),
      .pixel_data(pixel_data)
  );

endmodule
