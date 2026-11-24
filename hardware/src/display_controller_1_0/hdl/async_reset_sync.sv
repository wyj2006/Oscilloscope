module async_reset_sync (
    input clk,   //目的时钟域
    input reset, //异步复位，低有效

    output logic sync_reset  //高有效
);

  logic reset_1;
  logic reset_2;

  assign sync_reset = reset_2;

  //对异步复位信号进行同步释放，并转换成高有效
  always @(posedge clk or negedge reset) begin
    if (reset == 0) begin
      reset_1 <= 1'b1;
      reset_2 <= 1'b1;
    end else begin
      reset_1 <= 1'b0;
      reset_2 <= reset_1;
    end
  end

endmodule
