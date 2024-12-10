module upper_eye_boundary#(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter FACE_RES=(1<<16), 
    parameter LOG_POWER_MOD=4,
    parameter LEFT_END=3,
    parameter RIGHT_END=19
)(
    input logic clk_in,
    input logic [LOG_ROWS-1:0] row,
    input logic [LOG_NUM_PIXELS:0] col,
    input logic [LOG_FACE_RES-1:0] eye_openness,
    output logic [PIXEL_SIZE-1:0] pixel_data
);
    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;
    localparam MIDDLE = (LEFT_END + RIGHT_END) / 2;

    logic [2:0] in_eye_area;

    // left side values
    logic [31:0] parabola_value;
    logic [31:0] scaled_parabola_value;
    logic [31:0] summed_parabola_value;

    logic [31:0] scaled_row;
    logic [31:0] further_scaled_row;
    logic [31:0] pipelined_scaled_row;



    always_ff @(posedge clk_in) begin 

        // left side values
        parabola_value <= (col - LEFT_END) * (RIGHT_END - col);
        scaled_parabola_value <= parabola_value * eye_openness;
        summed_parabola_value <= scaled_parabola_value + 8 * (RIGHT_END - LEFT_END);

        // right side values 
        scaled_row <= (RIGHT_END - LEFT_END)  * (NUM_BLOCK_ROWS - row);
        further_scaled_row <= 4 * scaled_row;
        pipelined_scaled_row <= further_scaled_row;

        in_eye_area[2] <= (col >= LEFT_END) && (col <= RIGHT_END);
        in_eye_area[1] <= in_eye_area[2];
        in_eye_area[0] <= in_eye_area[1];

        pixel_data <= ((in_eye_area[0] && (summed_parabola_value >= pipelined_scaled_row)) ? '1 : '0);
    end
endmodule

module lower_eye_boundary#(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter FACE_RES=(1<<16), 
    parameter LOG_POWER_MOD=4,
    parameter LEFT_END=3,
    parameter RIGHT_END=19
)(
    input logic clk_in,
    input logic [LOG_ROWS-1:0] row,
    input logic [LOG_NUM_PIXELS:0] col,
    input logic [LOG_FACE_RES-1:0] eye_openness,
    output logic [PIXEL_SIZE-1:0] pixel_data
);

    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;
    localparam MIDDLE = (LEFT_END + RIGHT_END) / 2;

    logic [2:0] in_eye_area;

    // left side values
    logic [31:0] parabola_value;
    logic [31:0] scaled_parabola_value;
    logic [31:0] summed_parabola_value;

    logic [31:0] scaled_row;
    logic [31:0] further_scaled_row;
    logic [31:0] pipelined_scaled_row;

    always_ff @(posedge clk_in) begin 

        // left side values
        parabola_value <= (col - LEFT_END - 1) * (RIGHT_END - col - 1);
        scaled_parabola_value <= parabola_value * eye_openness;
        summed_parabola_value <= scaled_parabola_value;

        // right side values 
        scaled_row <= (RIGHT_END - LEFT_END)  * (NUM_BLOCK_ROWS - row - 1);
        further_scaled_row <= 18 * scaled_row;
        pipelined_scaled_row <= further_scaled_row;

        in_eye_area[2] <= (col >= LEFT_END + 1) && (col + 1 <= RIGHT_END);
        in_eye_area[1] <= in_eye_area[2];
        in_eye_area[0] <= in_eye_area[1];

        pixel_data <= ((in_eye_area[0] && (summed_parabola_value <= pipelined_scaled_row)) ? '1 : '0);
    end

endmodule



module eye_constructor #(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter FACE_RES=(1<<16), 
    parameter LOG_POWER_MOD=4
)(
    input logic clk_in,
    input logic rst_in,
    input logic face_data_valid,
    input logic [LOG_FACE_RES-1:0] left_eye_openness,
    input logic [LOG_FACE_RES-1:0] right_eye_openness,

    output logic [ADDRESS_SIZE-1:0] upper_pixel_address,
    output logic [PIXEL_SIZE-1:0] upper_pixel_data,
    output logic upper_pixel_valid
);
    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam TOTAL_ADDRESSES = NUM_BLOCK_ROWS * NUM_PIXELS;
    localparam ADDRESS_SIZE = $clog2(TOTAL_ADDRESSES);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;
    localparam LEFT_END = 3;
    localparam RIGHT_END = 19;

    typedef enum {
        IDLE,
        DRAWING
    } EYE_CONSTRUCTOR_STATE;

    EYE_CONSTRUCTOR_STATE current_state;
    logic [LOG_FACE_RES-1:0] left_eye_openness_buffer, right_eye_openness_buffer;
    logic [LOG_FACE_RES-1:0] left_current_eye_openness, right_current_eye_openness;
    logic valid_buffer;


    logic row_clock_rst;
    logic [LOG_NUM_PIXELS:0] column_counter;
    logic row_ticker;
    counter_with_out_and_tick #(.MAX_COUNT(2*NUM_PIXELS)) row_clock (
        .clk_in(clk_in),
        .rst_in(row_clock_rst),
        .period_in(NUM_PIXELS),
        .count_out(column_counter),
        .tick(row_ticker)
    );

    logic [LOG_ROWS:0] row_num;
    logic row_counter_rst;
    evt_counter_wrap #(.MAX_EVENT(2*NUM_BLOCK_ROWS)) row_counter (
        .clk_in(clk_in),
        .rst_in(row_counter_rst),
        .evt_in(row_ticker),
        .count_out(row_num)
    );

    logic [PIXEL_SIZE-1:0] left_eye_upper_pixel;
    upper_eye_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD),
        .LEFT_END(LEFT_END),
        .RIGHT_END(RIGHT_END)
    ) left_eye_upper (
        .clk_in(clk_in),
        .row(row_num),
        .col(NUM_PIXELS-1-column_counter),
        .eye_openness(left_current_eye_openness),
        .pixel_data(left_eye_upper_pixel)
    );

    logic [PIXEL_SIZE-1:0] right_eye_upper_pixel;
    upper_eye_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD),
        .LEFT_END(LEFT_END),
        .RIGHT_END(RIGHT_END)
    ) right_eye_upper (
        .clk_in(clk_in),
        .row(row_num),
        .col(column_counter),
        .eye_openness(right_current_eye_openness),
        .pixel_data(right_eye_upper_pixel)
    );

    logic [PIXEL_SIZE-1:0] left_eye_lower_pixel;
    lower_eye_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD),
        .LEFT_END(LEFT_END),
        .RIGHT_END(RIGHT_END)
    ) left_eye_lower (
        .clk_in(clk_in),
        .row(row_num),
        .col(NUM_PIXELS-1-column_counter),
        .eye_openness(left_current_eye_openness),
        .pixel_data(left_eye_lower_pixel)
    );

    logic [PIXEL_SIZE-1:0] right_eye_lower_pixel;
    lower_eye_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD),
        .LEFT_END(LEFT_END),
        .RIGHT_END(RIGHT_END)
    ) right_eye_lower (
        .clk_in(clk_in),
        .row(row_num),
        .col(column_counter),
        .eye_openness(right_current_eye_openness),
        .pixel_data(right_eye_lower_pixel)
    );

    logic [3:0][ADDRESS_SIZE-1:0] upper_pixel_address_pipeline;
    logic [3:0] upper_pixel_valid_pipeline;
    
    always_comb begin 
        upper_pixel_data = ((left_eye_upper_pixel & left_eye_lower_pixel))
        | ((right_eye_upper_pixel & right_eye_lower_pixel));
        upper_pixel_address = upper_pixel_address_pipeline[1-1];
        upper_pixel_valid = upper_pixel_valid_pipeline[1-1];
    end


    always_ff @(posedge clk_in) begin 
        if (rst_in) begin
            valid_buffer <= 0;
            current_state <= IDLE;
            row_clock_rst <= 1;
            row_counter_rst <= 1;
            upper_pixel_address_pipeline <= '0;
            upper_pixel_valid_pipeline <= '0;
        end else begin 
            upper_pixel_address_pipeline[1-1] <= upper_pixel_address_pipeline[1];
            upper_pixel_address_pipeline[2-1] <= upper_pixel_address_pipeline[2];
            upper_pixel_address_pipeline[3-1] <= upper_pixel_address_pipeline[3];
            upper_pixel_address_pipeline[4-1] <= row_num * NUM_PIXELS + column_counter;

            upper_pixel_valid_pipeline[1-1] <= upper_pixel_valid_pipeline[1];
            upper_pixel_valid_pipeline[2-1] <= upper_pixel_valid_pipeline[2];
            upper_pixel_valid_pipeline[3-1] <= upper_pixel_valid_pipeline[3];
            upper_pixel_valid_pipeline[4-1] <= (current_state == DRAWING);

            if (!valid_buffer && face_data_valid) begin 
                valid_buffer <= face_data_valid;
                left_eye_openness_buffer <= left_eye_openness;
                right_eye_openness_buffer <= right_eye_openness;
            end
            case (current_state)
                IDLE : begin 
                    // If we have a valid value in the buffer, we take that new value into the computation
                    if (valid_buffer) begin 
                        left_current_eye_openness <= left_eye_openness_buffer;
                        right_current_eye_openness <= right_eye_openness_buffer;
                        valid_buffer <= 0; // reset the buffer
                        current_state <= DRAWING;
                        row_clock_rst <= 0;
                        row_counter_rst <= 0;
                    end else begin 
                        row_clock_rst <= 1;
                        row_counter_rst <= 1;
                    end
                end
                DRAWING : begin 
                    if ((row_num + 1 == NUM_BLOCK_ROWS) && row_ticker) begin  // we have written the last pixel, stop drawing
                        row_clock_rst <= 1;
                        row_counter_rst <= 1;
                        current_state <= IDLE;
                    end 
                end 
            endcase
        end
    end

endmodule