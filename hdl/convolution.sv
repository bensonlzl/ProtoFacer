`timescale 1ns / 1ps
`default_nettype none


module convolution (
    input wire clk_in,
    input wire rst_in,
    input wire [KERNEL_SIZE-1:0][8-1:0] data_in,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    input wire data_valid_in,
    output logic data_valid_out,
    output logic [10:0] hcount_out,
    output logic [9:0] vcount_out,
    output logic [8-1:0] line_out
    );

    parameter K_SELECT = 0;
    localparam KERNEL_SIZE = 3;

    logic signed [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][13:0] pixel_cache ;

    logic signed [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][13:0] pixel_intermediates_mult; // extend by 4 bits

    logic signed [2:0][13:0] pixel_intermediate_sum_row; // extend by 5 bits
    logic signed [13:0] pixel_intermediate_sum; // extend by 5 bits
    logic signed [13:0] pixel_intermediate_shift; // extend by 5 bits

    logic [8-1:0] pixel_final_val;

    logic [5:0]data_valid_out_buffer;
    logic [5:0][10:0] hcount_out_buffer;
    logic [5:0][9:0] vcount_out_buffer;   

    always_ff @(posedge clk_in) begin
        data_valid_out_buffer <= {data_valid_out_buffer[4:0],data_valid_in};
        hcount_out_buffer <= {hcount_out_buffer[4:0],hcount_in};
        vcount_out_buffer <= {vcount_out_buffer[4:0],vcount_in};
    end
      

    // Your code here!

    /* Note that the coeffs output of the kernels module
     * is packed in all dimensions, so coeffs should be
     * defined as `logic signed [2:0][2:0][7:0] coeffs`
     *
     * This is because iVerilog seems to be weird about passing
     * signals between modules that are unpacked in more
     * than one dimension - even though this is perfectly
     * fine Verilog.
     */

    logic signed [2:0][2:0][7:0] coeffs;
    logic signed [7:0] shift;

    kernels #(.K_SELECT(K_SELECT)) kernel(
        .rst_in(rst_in),
        .coeffs(coeffs),
        .shift(shift)
    );

    always_ff @(posedge clk_in) begin  
        if (rst_in) begin   
            pixel_cache <= '0;
            pixel_intermediates_mult <= '0;

            pixel_intermediate_sum <= '0;

            pixel_final_val <= '0;


        end else begin

            if (data_valid_in) begin 
            
                pixel_cache[0][0] <= $signed(pixel_cache[0][1]);
                pixel_cache[0][1] <= $signed(pixel_cache[0][2]);
                pixel_cache[0][2] <= $signed({1'b0,data_in[0]});
                pixel_cache[1][0] <= $signed(pixel_cache[1][1]);
                pixel_cache[1][1] <= $signed(pixel_cache[1][2]);
                pixel_cache[1][2] <= $signed({1'b0,data_in[1]});
                pixel_cache[2][0] <= $signed(pixel_cache[2][1]);
                pixel_cache[2][1] <= $signed(pixel_cache[2][2]);
                pixel_cache[2][2] <= $signed({1'b0,data_in[2]});
            end 


            pixel_intermediates_mult[0][0] <= $signed(pixel_cache[0][0]) * $signed(coeffs[0][0]);
            pixel_intermediates_mult[0][1] <= $signed(pixel_cache[0][1]) * $signed(coeffs[0][1]);
            pixel_intermediates_mult[0][2] <= $signed(pixel_cache[0][2]) * $signed(coeffs[0][2]);
            pixel_intermediates_mult[1][0] <= $signed(pixel_cache[1][0]) * $signed(coeffs[1][0]);
            pixel_intermediates_mult[1][1] <= $signed(pixel_cache[1][1]) * $signed(coeffs[1][1]);
            pixel_intermediates_mult[1][2] <= $signed(pixel_cache[1][2]) * $signed(coeffs[1][2]);
            pixel_intermediates_mult[2][0] <= $signed(pixel_cache[2][0]) * $signed(coeffs[2][0]);
            pixel_intermediates_mult[2][1] <= $signed(pixel_cache[2][1]) * $signed(coeffs[2][1]);
            pixel_intermediates_mult[2][2] <= $signed(pixel_cache[2][2]) * $signed(coeffs[2][2]);


            pixel_intermediate_sum_row[0] <= $signed(pixel_intermediates_mult[0][0]) + $signed(pixel_intermediates_mult[0][1]) + $signed(pixel_intermediates_mult[0][2]);
            pixel_intermediate_sum_row[1] <= $signed(pixel_intermediates_mult[1][0]) + $signed(pixel_intermediates_mult[1][1]) + $signed(pixel_intermediates_mult[1][2]);
            pixel_intermediate_sum_row[2] <= $signed(pixel_intermediates_mult[2][0]) + $signed(pixel_intermediates_mult[2][1]) + $signed(pixel_intermediates_mult[2][2]);


            pixel_intermediate_sum <= (
                $signed(pixel_intermediate_sum_row[0])
                + $signed(pixel_intermediate_sum_row[1]) 
                + $signed(pixel_intermediate_sum_row[2])
            );

            pixel_intermediate_shift <= ($signed(pixel_intermediate_sum) >>> (shift));

            // Red Values
            if ($signed(pixel_intermediate_shift) <= -256) begin 
                pixel_final_val <= 8'b11111111;
            end else if ($signed(pixel_intermediate_shift) < 0) begin 
                pixel_final_val <= (-$signed(pixel_intermediate_shift));
            end else if ($signed(pixel_intermediate_shift) >= 256) begin 
                pixel_final_val <= 8'b11111111;
            end else begin 
                pixel_final_val <= $signed(pixel_intermediate_shift);
            end

        end
    end



    assign data_valid_out = data_valid_out_buffer[5];
    assign hcount_out = hcount_out_buffer[5];
    assign vcount_out = vcount_out_buffer[5];
    assign line_out = pixel_final_val;
endmodule

`default_nettype wire

