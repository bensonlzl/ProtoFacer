module counter(     input wire clk_in,
                    input wire rst_in,
                    input wire [31:0] period_in,
                    output logic [31:0] count_out
              );

    //your code here
  always_ff @(posedge clk_in) begin 
    if ((rst_in == 1'b1) || (count_out + 1) == period_in) begin
      count_out = 0;
    end else begin 
      count_out <= count_out + 1;
    end
  end
endmodule

module pwm #(
    parameter POWER_MOD = 16
)
(
    input wire clk_in,
    input wire rst_in,
    input wire [LOG_POWER_MOD-1:0] dc_in,
    output logic sig_out
    );
    localparam LOG_POWER_MOD=$clog2(POWER_MOD);


    logic [31:0] count;
    counter mc(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .period_in(POWER_MOD-1),
        .count_out(count)   
    );

    always_comb begin 
        sig_out = (count < dc_in);
    end

endmodule

module hub75_pwm #(
    parameter NUM_BLOCK_ROWS=16,
    parameter NUM_PIXELS=128,
    parameter POWER_MOD = 16
) (
    input logic clk_in,
    input logic rst_in,
    input logic [LOG_POWER_MOD-1:0] power_counter,
    input logic [LOG_ROWS-1:0] row_counter,
    input logic [LOG_NUM_PIXELS-1:0] pixel_counter,
    output logic [ADDRESS_SIZE-1:0] row_0_pixel_address,
    output logic [ADDRESS_SIZE-1:0] row_1_pixel_address,
    input logic [PIXEL_SIZE-1:0] row_0_pixel_data,
    input logic [PIXEL_SIZE-1:0] row_1_pixel_data,
    output logic [2:0] pixel_0_rgb,
    output logic [2:0] pixel_1_rgb
);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam TOTAL_ADDRESSES = NUM_BLOCK_ROWS * NUM_PIXELS;
    localparam ADDRESS_SIZE = $clog2(TOTAL_ADDRESSES);
    localparam LOG_POWER_MOD=$clog2(POWER_MOD);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;


    assign row_0_pixel_address = {row_counter,pixel_counter};
    assign row_1_pixel_address = {row_counter,pixel_counter};

    logic [1:0][LOG_POWER_MOD-1:0] pipelined_power_counter;
    always_ff @(posedge clk_in) begin
        pipelined_power_counter[1] <= pipelined_power_counter[0];
        pipelined_power_counter[0] <= power_counter;
    end

    assign pixel_0_rgb = {
        (pipelined_power_counter[1] < row_0_pixel_data[3*LOG_POWER_MOD-1:2*LOG_POWER_MOD]),
        (pipelined_power_counter[1] < row_0_pixel_data[2*LOG_POWER_MOD-1:1*LOG_POWER_MOD]),
        (pipelined_power_counter[1] < row_0_pixel_data[LOG_POWER_MOD-1:0])
    };
    assign pixel_1_rgb = {
        (pipelined_power_counter[1] < row_1_pixel_data[3*LOG_POWER_MOD-1:2*LOG_POWER_MOD]),
        (pipelined_power_counter[1] < row_1_pixel_data[2*LOG_POWER_MOD-1:1*LOG_POWER_MOD]),
        (pipelined_power_counter[1] < row_1_pixel_data[LOG_POWER_MOD-1:0])
    };

endmodule