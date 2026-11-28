module video_generator #(
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
    parameter integer C_M_AXI_BUSER_WIDTH = 0,

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

    input  bit          pixel_clk,
    input  logic [11:0] cnt_v,
    input  logic [11:0] cnt_h,
    input        [10:0] pixel_xpos,  //像素点横坐标
    input        [10:0] pixel_ypos,  //像素点纵坐标
    output logic [23:0] pixel_data   //像素点数据
);

  function automatic integer clogb2(input integer bit_depth);
    begin
      for (clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1) bit_depth = bit_depth >> 1;
    end
  endfunction

  typedef enum {
    IDLE,
    RADDR,
    RDATA
  } state_t;
  state_t state;

  parameter integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN - 1);

  logic [C_M_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
  logic [C_M_AXI_ADDR_WIDTH-1 : 0] frame_addr;
  logic [C_TRANSACTIONS_NUM+2 : 0] burst_size_bytes;
  logic [C_M_AXI_ADDR_WIDTH-1 : 0] read_index;

  logic cur_cache;
  logic cache_index;
  logic switch_cache1;
  logic switch_cache2;
  logic switch_cache3;

  logic [11:0] addra;
  logic [31:0] dina;
  logic ena;

  logic [11:0] addrb;
  logic [31:0] doutb;
  logic enb;

  //只读不写
  assign m_axi_awvalid = 1'b0;
  assign m_axi_wvalid = 1'b0;
  assign m_axi_bready = 1'b0;

  assign m_axi_arid = 1'b0;
  assign m_axi_araddr = C_M_AXI_TARGET_SLAVE_BASE_ADDR + frame_addr + axi_araddr;
  assign m_axi_arlen = C_M_AXI_BURST_LEN - 1;
  assign m_axi_arsize = clogb2((C_M_AXI_DATA_WIDTH / 8) - 1);
  assign m_axi_arburst = 2'b01;
  assign m_axi_arlock = 1'b0;
  assign m_axi_arcache = 4'b0010;
  assign m_axi_arprot = 3'h0;
  assign m_axi_arqos = 4'h0;
  assign m_axi_aruser = 1;
  assign burst_size_bytes = C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH / 8;

  blk_mem_gen blk_mem_gen (
      .addra(addra),
      .clka (m_axi_aclk),
      .dina (dina),
      .ena  (ena),
      .wea  (1),

      .addrb(addrb),
      .clkb (pixel_clk),
      .doutb(doutb),
      .enb  (enb)
  );

  always @(posedge m_axi_aclk) begin
    if (m_axi_aresetn == 0) begin
      m_axi_arvalid <= 0;
      m_axi_rready <= 0;
      axi_araddr <= 0;
      read_index <= 0;
      state <= IDLE;
      ena <= 0;
      cache_index <= 0;  //复位时switch_cache1为1, 所以最终cache_index和cur_cache会错开
      switch_cache2 <= 0;
      switch_cache3 <= 0;
      frame_addr <= 0;
    end else begin
      switch_cache2 <= switch_cache1;
      switch_cache3 <= switch_cache2;
      case (state)
        IDLE: begin
          ena <= 0;
          if (switch_cache3) begin
            m_axi_arvalid <= 1;
            cache_index <= cache_index + 1;
            state <= RADDR;
          end
        end
        RADDR: begin
          ena <= 0;
          if (m_axi_arvalid && m_axi_arready) begin
            m_axi_arvalid <= 0;
            m_axi_rready <= 1;
            axi_araddr <= axi_araddr + burst_size_bytes;
            state <= RDATA;
          end else state <= state;
        end
        RDATA: begin
          if (m_axi_rvalid) begin
            read_index <= read_index + 1;
            ena <= 1;
            addra <= read_index % H_DISP + cache_index * H_DISP;
            dina <= m_axi_rdata;
          end else begin
            ena <= 0;
          end
          if (m_axi_rvalid && m_axi_rlast && read_index % H_DISP == H_DISP - 1) begin
            m_axi_rready <= 0;
            state <= IDLE;
            if (read_index == H_DISP * V_DISP - 1) begin
              read_index <= 0;
              axi_araddr <= 0;
              case (m_axi_rdata[31:30])
                'b11: frame_addr <= frame_addr == 0 ? H_DISP * V_DISP * 4 : 0;
                default: frame_addr <= frame_addr;
              endcase
            end
          end else if (m_axi_rvalid && m_axi_rlast) begin
            m_axi_arvalid <= 1;
            m_axi_rready <= 0;
            state <= RADDR;
          end
        end
        default: state <= state;
      endcase
    end
  end

  always @(posedge pixel_clk) begin
    if (m_axi_aresetn == 0) begin
      enb <= 0;
      cur_cache <= 0;
      switch_cache1 <= 1;
    end else begin
      if (cnt_h >= H_SYNC + H_BACK - 12'd2 && cnt_h < H_SYNC + H_BACK + H_DISP - 12'd2
          && cnt_v >= V_SYNC + V_BACK && cnt_v < V_SYNC + V_BACK + V_DISP) begin
        enb <= 1;
        addrb <= cur_cache * H_DISP + pixel_xpos;
        pixel_data <= doutb[23:0];
      end else enb <= 0;
      if (cnt_v >= V_SYNC + V_BACK && cnt_v < V_SYNC + V_BACK + V_DISP && cnt_h == 0) begin
        switch_cache1 <= 1;
        cur_cache <= cur_cache + 1;
      end else switch_cache1 <= 0;
    end
  end

endmodule
