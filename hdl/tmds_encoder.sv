module count_number_of_ones(
    input wire [7:0] data_in,
    output logic [3:0] c_one
);
    logic bitvals0;
    logic bitvals1;
    logic bitvals2;
    logic bitvals3;
    logic bitvals4;
    logic bitvals5;
    logic bitvals6;
    logic bitvals7;
    always_comb begin 
        bitvals0 = ((data_in & 8'b0000_0001) == 8'b0000_0001);
        bitvals1 = ((data_in & 8'b0000_0010) == 8'b0000_0010);
        bitvals2 = ((data_in & 8'b0000_0100) == 8'b0000_0100);
        bitvals3 = ((data_in & 8'b0000_1000) == 8'b0000_1000);
        bitvals4 = ((data_in & 8'b0001_0000) == 8'b0001_0000);
        bitvals5 = ((data_in & 8'b0010_0000) == 8'b0010_0000);
        bitvals6 = ((data_in & 8'b0100_0000) == 8'b0100_0000);
        bitvals7 = ((data_in & 8'b1000_0000) == 8'b1000_0000);
        c_one = (
            {3'b000, bitvals0} +
            {3'b000, bitvals1} +
            {3'b000, bitvals2} +
            {3'b000, bitvals3} +
            {3'b000, bitvals4} +
            {3'b000, bitvals5} +
            {3'b000, bitvals6} +
            {3'b000, bitvals7} 
        );
    end
endmodule

`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

    logic [4:0] running_cnt;
    logic [3:0] c_one;
    logic [8:0] q_m;
    logic sign_running_cnt; //= running_cnt[4]; //((running_cnt && 5'b10000) == 5'b10000);
    logic xbit; // = q_m[8]; // ((q_m & 9'b1_0000_0000) == 9'b1_0000_0000);
    logic [7:0] xdata; // = q_m[7:0];
    logic [4:0] c_one_extended; // = {1'b0,c_one};

 
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

    count_number_of_ones data_counter( // Count number of ones in data
        .data_in(q_m[7:0]),
        .c_one(c_one)
    );

    logic oz_equal; // = (c_one == 5'b00100);
    logic one_maj; // = (c_one > 5'b00100);

    always_comb begin 
        sign_running_cnt = running_cnt[4]; //((running_cnt && 5'b10000) == 5'b10000);
        xbit = q_m[8]; // ((q_m & 9'b1_0000_0000) == 9'b1_0000_0000);
        xdata = q_m[7:0];
        c_one_extended = {1'b0,c_one};
        oz_equal = (c_one == 5'b00100);
        one_maj = (c_one > 5'b00100);
    end

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin
            running_cnt <= 0;
            tmds_out <= 0;
        end else if (!ve_in) begin 
            case (control_in)
                2'b00: tmds_out = 10'b1101010100;
                2'b01: tmds_out = 10'b0010101011;
                2'b10: tmds_out = 10'b0101010100;
                2'b11: tmds_out = 10'b1010101011;
            endcase
            running_cnt <= 0;
        end else begin
            if (oz_equal || (running_cnt == 5'b00000)) begin // equal number of 0s and 1s
                case (xbit)
                    1'b0: begin 
                        tmds_out <= {~xbit, xbit, ~xdata};
                        running_cnt <= running_cnt - c_one_extended - c_one_extended + 5'b01000; // 
                    end
                    1'b1: begin 
                        tmds_out <= {~xbit, xbit, xdata};
                        running_cnt <= running_cnt + c_one_extended + c_one_extended - 5'b01000; // 
                    end
                endcase
            end else begin
                if (
                    (sign_running_cnt && (!one_maj))
                    || 
                    ((!sign_running_cnt) && one_maj)
                ) begin
                    tmds_out <= {1'b1, xbit, ~xdata};
                    running_cnt <= running_cnt + {4'b0, xbit} + {4'b0, xbit} - c_one_extended - c_one_extended + 5'b01000; // 
                end else begin 
                    tmds_out = {1'b0, xbit, xdata};
                    running_cnt <= running_cnt - {4'b0, ~xbit} - {4'b0, ~xbit} + c_one_extended + c_one_extended - 5'b01000; // 
                end
            end
        end

    end
    
    


 
  //your code here.
 
endmodule
 
`default_nettype wire