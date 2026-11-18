module dvi_encoder (
    input reset,
    input clk,

    input [7:0] din,
    input c0,
    input c1,
    input de,

    output logic [9:0] dout
);

  logic [3:0] n1_d;
  logic [7:0] d;

  logic condition1;
  logic condition2;
  logic condition3;

  logic [8:0] q_m;
  logic [3:0] n1_q_m;
  logic [3:0] n0_q_m;

  logic [4:0] cnt;

  assign n1_d = din[0] + din[1] + din[2] + din[3] + din[4] + din[5] + din[6] + din[7];
  assign d = din;

  assign condition1 = n1_d > 4 || n1_d == 4 && d[0] == 0;

  assign q_m[0] = d[0];
  assign q_m[1] = (condition1) ? (q_m[0] ^~ d[1]) : (q_m[0] ^ d[1]);
  assign q_m[2] = (condition1) ? (q_m[1] ^~ d[2]) : (q_m[1] ^ d[2]);
  assign q_m[3] = (condition1) ? (q_m[2] ^~ d[3]) : (q_m[2] ^ d[3]);
  assign q_m[4] = (condition1) ? (q_m[3] ^~ d[4]) : (q_m[3] ^ d[4]);
  assign q_m[5] = (condition1) ? (q_m[4] ^~ d[5]) : (q_m[4] ^ d[5]);
  assign q_m[6] = (condition1) ? (q_m[5] ^~ d[6]) : (q_m[5] ^ d[6]);
  assign q_m[7] = (condition1) ? (q_m[6] ^~ d[7]) : (q_m[6] ^ d[7]);
  assign q_m[8] = (condition1) ? 1'b0 : 1'b1;

  assign n1_q_m = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
  assign n0_q_m = 4'd8 - n1_q_m;

  assign condition2 = cnt == 5'd0 || n1_q_m == n0_q_m;
  assign condition3 = ~cnt[4] && n1_q_m > n0_q_m || cnt[4] && n0_q_m > n1_q_m;

  always @(posedge clk or posedge reset) begin
    if (reset == 1) begin
      dout <= 10'd0;
      cnt  <= 4'd0;
    end else begin
      if (de == 0) begin
        cnt <= 0;
        unique case ({
          c1, c0
        })
          2'b00: dout <= 10'b1101010100;
          2'b01: dout <= 10'b0010101011;
          2'b10: dout <= 10'b0101010100;
          2'b11: dout <= 10'b1010101011;
        endcase
      end else begin
        if (condition2) begin
          dout[9] <= ~q_m[8];
          dout[8] <= q_m[8];
          dout[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
          cnt <= (q_m[8] == 0) ? (cnt + n0_q_m - n1_q_m) : (cnt + n1_q_m - n0_q_m);
        end else begin
          if (condition3) begin
            dout[9] <= 1;
            dout[8] <= q_m[8];
            dout[7:0] <= ~q_m[7:0];
            cnt <= cnt + {q_m[8], 1'b0} + n0_q_m - n1_q_m;
          end else begin
            dout[9] <= 0;
            dout[8] <= q_m[8];
            dout[7:0] <= q_m[7:0];
            cnt <= cnt - {~q_m[8], 1'b0} + n1_q_m - n0_q_m;
          end
        end
      end
    end
  end

endmodule
