module tm_choice (
    input wire pixel_clk_in,
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );
    logic [3:0] c_one;
    logic scheme;
    logic bitvals0;
    logic bitvals1;
    logic bitvals2;
    logic bitvals3;
    logic bitvals4;
    logic bitvals5;
    logic bitvals6;
    logic bitvals7;

    logic xor0;
    logic xor1; 
    logic xor2; 
    logic xor3; 
    logic xor4; 
    logic xor5; 
    logic xor6; 
    logic xor7; 

    logic xnor0;
    logic xnor1; 
    logic xnor2; 
    logic xnor3; 
    logic xnor4; 
    logic xnor5; 
    logic xnor6; 
    logic xnor7; 

    count_number_of_ones data_counter(
        .data_in(data_in),
        .c_one(c_one)
    );


    always_comb begin
        

        bitvals0 = ((data_in & 8'b0000_0001) == 8'b0000_0001);
        bitvals1 = ((data_in & 8'b0000_0010) == 8'b0000_0010);
        bitvals2 = ((data_in & 8'b0000_0100) == 8'b0000_0100);
        bitvals3 = ((data_in & 8'b0000_1000) == 8'b0000_1000);
        bitvals4 = ((data_in & 8'b0001_0000) == 8'b0001_0000);
        bitvals5 = ((data_in & 8'b0010_0000) == 8'b0010_0000);
        bitvals6 = ((data_in & 8'b0100_0000) == 8'b0100_0000);
        bitvals7 = ((data_in & 8'b1000_0000) == 8'b1000_0000);


        xor0 = bitvals0;
        xor1 = bitvals1 ^ xor0;
        xor2 = bitvals2 ^ xor1;
        xor3 = bitvals3 ^ xor2;
        xor4 = bitvals4 ^ xor3;
        xor5 = bitvals5 ^ xor4;
        xor6 = bitvals6 ^ xor5;
        xor7 = bitvals7 ^ xor6;

        xnor0 = bitvals0;
        xnor1 = bitvals1 ^~ xnor0;
        xnor2 = bitvals2 ^~ xnor1;
        xnor3 = bitvals3 ^~ xnor2;
        xnor4 = bitvals4 ^~ xnor3;
        xnor5 = bitvals5 ^~ xnor4;
        xnor6 = bitvals6 ^~ xnor5;
        xnor7 = bitvals7 ^~ xnor6;

        if (c_one > 4) begin 
            qm_out = {1'b0, xnor7, xnor6, xnor5, xnor4, xnor3, xnor2, xnor1, xnor0};
        end else if (c_one == 4 &&  bitvals0 == 0) begin 
            qm_out = {1'b0, xnor7, xnor6, xnor5, xnor4, xnor3, xnor2, xnor1, xnor0};
        end else begin
            qm_out = {1'b1, xor7, xor6, xor5, xor4, xor3, xor2, xor1, xor0};
        end

    end
endmodule
