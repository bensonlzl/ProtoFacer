module counter_with_out_and_tick #(parameter MAX_COUNT=2**32)(     
    input wire clk_in,
    input wire rst_in,
    input wire [$clog2(MAX_COUNT)-1:0] period_in,
    output logic [$clog2(MAX_COUNT)-1:0] count_out,
    output logic tick
);
    
    //your code here

  always_ff @(posedge clk_in) begin 
    if ((rst_in == 1'b1) || (count_out + 1) == period_in) begin
      count_out <= 0;
    end else begin 
      count_out <= count_out + 1;
    end
  end

  always_comb begin
    if (((count_out + 1) == period_in) && rst_in == 1'b0) begin
        tick = 1;
    end else begin
        tick = 0;
    end
  end
endmodule