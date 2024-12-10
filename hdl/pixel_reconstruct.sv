`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct
	#(
	 parameter HCOUNT_WIDTH = 11,
	 parameter VCOUNT_WIDTH = 10
	 )
	(
	 input wire 										 clk_in,
	 input wire 										 rst_in,
	 input wire 										 camera_pclk_in,
	 input wire 										 camera_hs_in,
	 input wire 										 camera_vs_in,
	 input wire [7:0] 							 camera_data_in,
	 output logic 									 pixel_valid_out,
	 output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
	 output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
	 output logic [7:0] 						 pixel_data_out
	 );

	 // your code here! and here's a handful of logics that you may find helpful to utilize.
	 
	 // previous value of PCLK
	 logic 													 pclk_prev;
     logic rising_pclk;
     assign rising_pclk = ((pclk_prev == 1'b0) && (camera_pclk_in == 1'b1));

	 // can be assigned combinationally:
	 //  true when pclk transitions from 0 to 1
	 logic 													 camera_sample_valid;
	 assign camera_sample_valid = ((pclk_prev == 1'b0) && (camera_pclk_in == 1'b1)); // Rising edge of camera clock, read data
	 
	 // previous value of camera data, from last valid sample!
	 // should NOT update on every cycle of clk_in, only
	 // when samples are valid.
	 logic 													 last_sampled_hs;
	 logic [7:0] 										 last_sampled_data;

	 // flag indicating whether the last byte has been transmitted or not.
	 logic 													 half_pixel_ready;
    
    // assign half_pixel_ready = 1;
     always_ff@(posedge clk_in) begin
        if (rst_in) begin
            pixel_vcount_out <= 0;
            pixel_hcount_out <= -1;
            half_pixel_ready <= 1'b0;
            pixel_valid_out <= 1'b0;
            pixel_data_out <= 0;
            last_sampled_hs <= 0;
            last_sampled_data <= 0;
            pclk_prev <= 0;
        end else begin
            if (rising_pclk) begin 
                if (camera_vs_in == 1'b0) begin  // entering vsync region, frame has completed
                    pixel_vcount_out <= 0;
                    pixel_hcount_out <= -1;
                    half_pixel_ready <= 1'b0;
                    pixel_valid_out <= 1'b0;
                    pixel_data_out <= 1'b0;
                    last_sampled_data <= 0;
                    last_sampled_hs <= 0;
                end else begin 
                    if (camera_hs_in == 1'b0) begin  // entering hsync region, row has completed
                        if (last_sampled_hs == 1'b1) begin  // new row! increment the v counter and reset the h counter 
                            pixel_vcount_out <= pixel_vcount_out + 1;
                            pixel_hcount_out <= -1;
                        end
                        half_pixel_ready <= 1'b0;
                        pixel_valid_out <= 1'b0;
                        pixel_data_out <= 1'b0;
                    end else begin  // currently drawing
                        if(camera_sample_valid) begin // received camera data
                            pixel_hcount_out <= pixel_hcount_out + 1;                                
                            pixel_data_out <= camera_data_in;
                            pixel_valid_out <= 1'b1;
                        end else begin  // pixel not ready to be sent
                            pixel_valid_out <= 1'b0;
                        end
                    end 
                    last_sampled_hs <= camera_hs_in; // only sample if vs = 1
                end
            end else begin 
                pixel_valid_out <= 1'b0;

            end
            pclk_prev <= camera_pclk_in;
        end
	 end

endmodule

`default_nettype wire
