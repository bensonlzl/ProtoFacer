module counter_with_tick(     
    input wire clk_in,
    input wire rst_in,
    input wire [31:0] period_in,
    output logic tick
);
    logic [31:0] count_out;
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


module uart_transmit #(parameter INPUT_CLOCK_FREQ, parameter BAUD_RATE) (
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] data_byte_in,
    input wire trigger_in,
    output logic busy_out,
    output logic tx_wire_out
);
    localparam BAUD_BIT_PERIOD = (INPUT_CLOCK_FREQ / BAUD_RATE);
    


    // Auxiliary variables for the baud clock
    logic [31:0] baud_period = BAUD_BIT_PERIOD;
    logic baud_tick;
    logic reset_baud_counter;

    // Boolean to check if the uart is transmitting
    logic is_transmitting;

    // Boolean to check if the uart has sent the stop bit or start bit
    logic sent_start;
    logic sent_data;

    // Data to send and the 1-hot encoded pointer for which bit to send
    logic [7:0] data_byte_send;
    logic [7:0] data_byte_pointer;

    counter_with_tick baud_counter(
        .clk_in(clk_in),
        .rst_in(reset_baud_counter),
        .period_in(baud_period),
        .tick(baud_tick)
    );


    always_ff @(posedge clk_in) begin
        if (rst_in) begin // Reset the UART Transmitter
            reset_baud_counter <= 1;

            is_transmitting <= 0;

            sent_start <= 0;
            sent_data <= 0;


            data_byte_send <= 0;
            data_byte_pointer <= 0;

            busy_out <= 0;
            tx_wire_out <= 1;
        end else begin // Continue with normal operation
            if (is_transmitting) begin // Do not interrupt 
                if (baud_tick) begin // On the baud rate clock

                    // If we haven't sent start, we have just sent the start bit, move to first bit
                    if (!sent_start) begin  
                        sent_start <= 1;
                        tx_wire_out <= ((data_byte_send & data_byte_pointer) > 0); // transmits 1 if the bit at the position is a 1
                    end else if (!sent_data) begin // Otherwise, send next piece of data
                        data_byte_pointer = {data_byte_pointer[6:0],1'b0};
                        if (data_byte_pointer == 0) begin  // we have sent the last bit, send the stop bit
                            tx_wire_out <= 1;
                            sent_data <= 1;
                        end else begin
                            tx_wire_out <= ((data_byte_send & data_byte_pointer) > 0); // transmits 1 if the bit at the position is a 1
                        end
                    end else begin // end transmission
                        is_transmitting <= 0;
                        busy_out <= 0;
                        tx_wire_out <= 1;
                        reset_baud_counter <= 1;


                        sent_start <= 0;
                        sent_data <= 0;

                        data_byte_send <= 0;
                        data_byte_pointer <= 0;

                    end
                end
                
            end else begin
                if (trigger_in) begin  // Start a new transmission
                    busy_out <= 1;

                    tx_wire_out <= 0; // Send start bit

                    is_transmitting <= 1; // Start transmission

                    // Prepare data
                    data_byte_send <= data_byte_in;
                    data_byte_pointer = 8'b0000_0001;

                    // Let the counter start
                    reset_baud_counter <= 0;



                end else begin  // Idle
                    busy_out <= 0;
                    tx_wire_out <= 1;
                    reset_baud_counter <= 1;

                    is_transmitting <= 0;

                    sent_start <= 0;
                    sent_data <= 0;

                    data_byte_send <= 0;
                    data_byte_pointer <= 0;
                end

            end
        end 
    end

endmodule