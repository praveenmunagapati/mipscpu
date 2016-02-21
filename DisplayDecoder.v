module SevenSegmentDisplayDecoder(i_Clk, ssOut, nIn);
  output reg [6:0] ssOut;
  input [3:0] nIn;
  input i_Clk;

  // ssOut format {g, f, e, d, c, b, a}

  always @(posedge i_Clk)
    case (nIn)
      4'h0: ssOut = 7'b1000000;
      4'h1: ssOut = 7'b1111001;
      4'h2: ssOut = 7'b0100100;
      4'h3: ssOut = 7'b0110000;
      4'h4: ssOut = 7'b0011001;
      4'h5: ssOut = 7'b0010010;
      4'h6: ssOut = 7'b0000010;
      4'h7: ssOut = 7'b1111000;
      4'h8: ssOut = 7'b0000000;
      4'h9: ssOut = 7'b0011000;
      4'hA: ssOut = 7'b0001000;
      4'hB: ssOut = 7'b0000011;
      4'hC: ssOut = 7'b1000110;
      4'hD: ssOut = 7'b0100001;
      4'hE: ssOut = 7'b0000110;
      4'hF: ssOut = 7'b0001110;
    endcase
endmodule

module SevenSegmentPFD(i_Clk, ssOut, nIn);  //1=P,2=F,3=D
  output reg [6:0] ssOut;
  input [1:0] nIn;
  input i_Clk;

  // ssOut format {g, f, e, d, c, b, a

  always @(posedge i_Clk)
    case (nIn)
      2'h0: ssOut = 7'b1111111;
      2'h1: ssOut = 7'b0001100;
      2'h2: ssOut = 7'b0001110;
      2'h3: ssOut = 7'b0100001;
    endcase
endmodule
