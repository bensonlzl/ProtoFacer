typedef enum {IDLE, START, DATA, STOP, TRANSMIT} receive_state;

module uart_receive #(parameter INPUT_CLOCK_FREQ = 100_000_000, parameter BAUD_RATE = 19_200) (
    input wire clk_in,
    input wire rst_in,
    input wire rx_wire_in,
    output logic new_data_out,
    output logic [7:0] data_byte_out
);

    localparam BAUD_BIT_PERIOD = (INPUT_CLOCK_FREQ / BAUD_RATE);
    localparam BAUD_BIT_READ_PERIOD = (INPUT_CLOCK_FREQ / BAUD_RATE) / 2;

    receive_state cur_state;

    // Auxiliary variables for the baud clock
    logic [31:0] baud_period = BAUD_BIT_PERIOD;
    logic baud_tick;
    logic reset_baud_counter;

    counter_with_tick baud_counter(
        .clk_in(clk_in),
        .rst_in(reset_baud_counter),
        .period_in(baud_period),
        .tick(baud_tick)
    );

    // Auxiliary variables for the reading clock
    logic [31:0] baud_read_period = BAUD_BIT_READ_PERIOD;
    logic baud_read_tick;
    logic reset_baud_read_counter;

    counter_with_tick baud_read_counter(
        .clk_in(clk_in),
        .rst_in(reset_baud_read_counter),
        .period_in(baud_read_period),
        .tick(baud_read_tick)
    );

    // Logic for good and bad start/stop bits
    logic valid_start;
    logic valid_data;
    logic valid_stop;    

    // Data to send and the 1-hot encoded pointer for which bit to send
    logic [7:0] data_byte_send;
    logic [7:0] data_byte_pointer;

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin  // Reset everything
            reset_baud_counter <= 1;
            reset_baud_read_counter <= 1;
            valid_start <= 0;
            valid_data <= 0;
            valid_stop <= 0;
            data_byte_send <= 0;
            data_byte_pointer <= 0;
            cur_state <= IDLE;

            new_data_out <= 0;
            data_byte_out <= 0;
        end else begin 
            case (cur_state)
                IDLE : begin
                    if (rx_wire_in == 1'b0) begin // Shift into start state
                        // Start the timers
                        reset_baud_counter <= 0;
                        reset_baud_read_counter <= 0;

                        cur_state <= START;
                    end else begin // Else remain idle
                        reset_baud_counter <= 1;
                        reset_baud_read_counter <= 1;
                    end
                    new_data_out <= 0;
                    data_byte_out <= 0;
                    valid_start <= 0;
                    valid_data <= 0;
                    valid_stop <= 0;
                    data_byte_send <= 0;
                    data_byte_pointer <= 0;
                end

                START: begin
                    if (baud_read_tick) begin // Sample middle bit
                        if (rx_wire_in == 1'b1) begin // invalid start bit, return to idle
                            cur_state <= IDLE;
                            reset_baud_counter <= 1;
                            data_byte_pointer <= 8'b0000_0000;
                        end else begin 
                            valid_start <= 1;
                        end
                        reset_baud_read_counter <= 1; // hold down the read counter

                    end else if (baud_tick) begin // Move on to DATA
                        cur_state <= DATA;
                        data_byte_pointer <= 8'b0000_0001;
                        reset_baud_read_counter <= 0; // Let the read counter go

                    end else if (!valid_start) begin // If we haven't received the start bit, let the read counter go
                        if (rx_wire_in == 1'b1) begin // invalid start bit, return to idle
                            cur_state <= IDLE;
                            reset_baud_counter <= 1;
                            reset_baud_read_counter <= 1;
                            data_byte_pointer <= 8'b0000_0000;
                        end else begin
                            reset_baud_read_counter <= 0;
                        end
                    end
                end

                DATA: begin
                    if (baud_read_tick) begin // Sample middle bit
                        if (rx_wire_in) begin  // If sample is 1, add bit
                            data_byte_send <= data_byte_send + data_byte_pointer;
                        end
                        valid_data <= 1;
                        data_byte_pointer <= {data_byte_pointer[6:0],1'b0}; // shift bit pointer
                        reset_baud_read_counter <= 1;
                    end else if (baud_tick) begin // Move on to DATA
                        if (data_byte_pointer == 8'b0000_0000) begin // data received, move to STOP
                            cur_state <= STOP;
                        end else begin 
                            valid_data <= 0;
                        end
                        reset_baud_read_counter <= 0;
                    end else if (!valid_data) begin
                        reset_baud_read_counter <= 0;
                    end
                end

                STOP: begin
                    if (baud_read_tick) begin // Sample middle bit
                        if (rx_wire_in == 1'b0) begin // invalid stop bit, return to idle
                            cur_state <= IDLE;
                            reset_baud_counter <= 1;
                            data_byte_pointer <= 8'b0000_0000;
                        end else begin 
                            valid_stop <= 1;
                        end
                        reset_baud_read_counter <= 1; // hold down the read counter

                    end else if (baud_tick) begin // Move on to TRANSMIT
                        cur_state <= TRANSMIT;
                        reset_baud_read_counter <= 1; 
                        reset_baud_counter <= 1; 

                    end else if (!valid_stop) begin // If we haven't received the start bit, let the read counter go
                        reset_baud_read_counter <= 0;
                    end
                end

                TRANSMIT: begin 
                    new_data_out <= 1;
                    data_byte_out <= data_byte_send;
                    cur_state <= IDLE;
                end
            endcase
        end
    end
    
   

endmodule