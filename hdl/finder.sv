module finder #(
    parameter HEIGHT=320, 
    parameter WIDTH=180, 
    parameter FACE_RES=(1 << 16),
    parameter PIXEL_SIZE=8,
    parameter LOW_THRESHOLD,
    parameter HIGH_THRESHOLD
) (
    input logic clk_in,
    input logic rst_in,
    input logic start_search,
    input logic [LOG_HEIGHT-1:0] input_start_row,
    input logic [LOG_HEIGHT-1:0] input_end_row,
    input logic [LOG_WIDTH-1:0] input_start_column,
    input logic [LOG_WIDTH-1:0] input_end_column,

    output logic [FB_SIZE-1:0] eye_pixel_address,
    output logic eye_pixel_address_valid,
    input logic [PIXEL_SIZE-1:0] eye_pixel_value,

    output logic computed_eye_valid,
    output logic [LOG_FACE_RES-1:0] computed_eye_openness,
    output logic [INTERNAL_LOG_EYE_SIZE-1:0] computed_sclera,
    output logic [INTERNAL_LOG_EYE_SIZE-1:0] computed_pupil
);

    typedef enum {
        IDLE,
        INIT_COLUMN,
        SEARCHING_COLUMN,
        COMPLETE_COLUMN,
        COMPLETE_MIN,
        INIT_EYE_COUNTING,
        SEARCHING_EYE,
        COMPLETE_EYE,
        COMPLETE_SEARCH
    } FINDER_STATE;

    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam INTERNAL_LOG_EYE_SIZE = 16;
    localparam LOG_HEIGHT = $clog2(HEIGHT);
    localparam LOG_WIDTH = $clog2(WIDTH);
    localparam FB_DEPTH = HEIGHT*WIDTH;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    localparam EDGE_THRESHOLD = (1 << (PIXEL_SIZE - 2)); // half full brightness edge counts as an edge
    // localparam LOW_THRESHOLD = 90; // anything below 80 is dark enough to be a pupil
    // localparam HIGH_THRESHOLD = 160; // anything above 192 is light enough to be an sclera
    localparam DIFF_THRESHOLD = (1 << (PIXEL_SIZE/2)); // for 256 brightness levels, diff of 16 means they are about the same color
    localparam COUNT_THRESHOLD = 20; // number of pixels expected to be covered if the eye is closed

    logic [LOG_HEIGHT-1:0] start_row, current_row, buffered_row, end_row;
    logic [LOG_WIDTH-1:0] start_column, current_column, end_column;
    logic [INTERNAL_LOG_EYE_SIZE-1:0] sclera_eye_size_counter; // compute white pixels
    logic [INTERNAL_LOG_EYE_SIZE-1:0] pupil_eye_size_counter; // compute black pixels
    logic [INTERNAL_LOG_EYE_SIZE-1:0] eye_size_counter;
    logic [INTERNAL_LOG_EYE_SIZE-1:0] column_eye_size_counter;

    logic [PIXEL_SIZE-1:0] min_pixel_value;
    logic [PIXEL_SIZE-1:0] max_pixel_value;

    localparam BUFFER_TIME = 2;
    localparam SEARCH_WINDOW = 7;
    localparam SCLERA_SEARCH_WINDOW = 3;
    localparam PUPIL_SEARCH_WINDOW = 3;
    logic [SEARCH_WINDOW-1:0][PIXEL_SIZE-1:0] min_edge_data;
    logic [SEARCH_WINDOW-1:0][PIXEL_SIZE-1:0] max_edge_data;
    logic [PIXEL_SIZE-1:0] pixel_max;
    logic [PIXEL_SIZE-1:0] pixel_min;

    // Algorithm overview
    // We perform a sliding window max over the edge detection.
    // If the maximum of SEARCH_WINDOW pixels is high, we have high confidence that we are in an edge.
    // Compute how many pixels we are in an edge for and tune later

    FINDER_STATE current_state;

    always_comb begin 
        eye_pixel_address = (buffered_row * WIDTH + current_column);
        eye_pixel_address_valid = 1;
        pixel_max = (max_edge_data[7-PUPIL_SEARCH_WINDOW] > eye_pixel_value) ? max_edge_data[7-PUPIL_SEARCH_WINDOW] : eye_pixel_value;
        pixel_min = (min_edge_data[7-SCLERA_SEARCH_WINDOW] < eye_pixel_value) ? min_edge_data[7-SCLERA_SEARCH_WINDOW] : eye_pixel_value;
        computed_eye_openness = eye_size_counter;
        computed_sclera = sclera_eye_size_counter;
        computed_pupil = pupil_eye_size_counter;
    end



    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            start_row <= 0;
            current_row <= 0;
            end_row <= 0;
            start_column <= 0;
            current_column <= 0;
            end_column <= 0;
            computed_eye_valid <= 0;
            eye_size_counter <= 0;
            column_eye_size_counter <= 0;
            max_edge_data <= '1;
            min_edge_data <= '0;
            sclera_eye_size_counter <= 0;
            pupil_eye_size_counter <= 0;
            min_pixel_value <= '1;
            max_pixel_value <= '0;
            current_state <= IDLE;
        end else begin 
            case (current_state)
                IDLE : begin 
                    computed_eye_valid <= 0;
                    eye_size_counter <= 0;
                    if (start_search) begin 
                        start_row <= input_start_row;
                        current_row <= input_start_row;
                        end_row <= input_end_row;
                        start_column <= input_start_column;
                        current_column <= input_start_column;
                        end_column <= input_end_column;
                        eye_size_counter <= 0;
                        column_eye_size_counter <= 0;
                        max_edge_data <= '1;
                        min_pixel_value <= LOW_THRESHOLD;
                        max_pixel_value <= HIGH_THRESHOLD;
                        min_edge_data <= '0;
                        sclera_eye_size_counter <= 0;
                        pupil_eye_size_counter <= 0;
                        buffered_row <= input_start_row;
                        current_state <= INIT_COLUMN;
                    end
                end

                INIT_COLUMN: begin // 2 cycle delay
                    column_eye_size_counter <= 0;
                    max_edge_data <= '1;
                    min_edge_data <= '0;
                    buffered_row <= current_row + 1;
                    current_row <= current_row + 1;
                    if (current_row == start_row + BUFFER_TIME - 1) begin 
                        current_state <= SEARCHING_COLUMN;
                    end
                end

                SEARCHING_COLUMN: begin 
                    
                    // Updating sliding window max in parallel!
                    max_edge_data[7-1] <= eye_pixel_value;
                    max_edge_data[6-1] <= (max_edge_data[6] > eye_pixel_value) ? max_edge_data[6] : eye_pixel_value;
                    max_edge_data[5-1] <= (max_edge_data[5] > eye_pixel_value) ? max_edge_data[5] : eye_pixel_value;
                    max_edge_data[4-1] <= (max_edge_data[4] > eye_pixel_value) ? max_edge_data[4] : eye_pixel_value;
                    max_edge_data[3-1] <= (max_edge_data[3] > eye_pixel_value) ? max_edge_data[3] : eye_pixel_value;
                    max_edge_data[2-1] <= (max_edge_data[2] > eye_pixel_value) ? max_edge_data[2] : eye_pixel_value;
                    max_edge_data[1-1] <= (max_edge_data[1] > eye_pixel_value) ? max_edge_data[1] : eye_pixel_value;

                    min_edge_data[7-1] <= eye_pixel_value;
                    min_edge_data[6-1] <= (min_edge_data[6] < eye_pixel_value) ? min_edge_data[6] : eye_pixel_value;
                    min_edge_data[5-1] <= (min_edge_data[5] < eye_pixel_value) ? min_edge_data[5] : eye_pixel_value;
                    min_edge_data[4-1] <= (min_edge_data[4] < eye_pixel_value) ? min_edge_data[4] : eye_pixel_value;
                    min_edge_data[3-1] <= (min_edge_data[3] < eye_pixel_value) ? min_edge_data[3] : eye_pixel_value;
                    min_edge_data[2-1] <= (min_edge_data[2] < eye_pixel_value) ? min_edge_data[2] : eye_pixel_value;
                    min_edge_data[1-1] <= (min_edge_data[1] < eye_pixel_value) ? min_edge_data[1] : eye_pixel_value;

                    min_pixel_value <= ((min_pixel_value < eye_pixel_value) ? min_pixel_value : eye_pixel_value);
                    max_pixel_value <= ((max_pixel_value > eye_pixel_value) ? max_pixel_value : eye_pixel_value);

                    // if (pixel_max >= EDGE_THRESHOLD) begin 
                    //     column_eye_size_counter <= column_eye_size_counter + 1;
                    // end

                    // if (pixel_max <= LOW_THRESHOLD) begin 
                    //     pupil_eye_size_counter <= pupil_eye_size_counter + 1;
                    // end 

                    // if (pixel_min >= HIGH_THRESHOLD) begin 
                    //     sclera_eye_size_counter <= sclera_eye_size_counter + 1;
                    // end 

                    if (current_row == end_row + BUFFER_TIME) begin // If we have processed all rows including the 2 cycle buffer, end column search 
                        current_state <= COMPLETE_COLUMN;
                    end else if (current_row < end_row) begin  // If we have yet to finish sending data
                        buffered_row <= current_row + 1;
                    end 
                    current_row <= current_row + 1;

                end

                COMPLETE_COLUMN: begin 
                    max_edge_data <= '0;
                    max_edge_data <= '1;
                    if (column_eye_size_counter >= COUNT_THRESHOLD) begin 
                        eye_size_counter <= eye_size_counter + (column_eye_size_counter - COUNT_THRESHOLD);
                    end
                    if (current_column == end_column) begin  // We are done with the search, we should return
                        current_state <= COMPLETE_MIN;
                    end else begin 
                        current_column <= current_column + 1;
                        current_row <= start_row;
                        current_state <= INIT_COLUMN;
                    end
                end

                COMPLETE_MIN: begin 
                    start_row <= input_start_row;
                    current_row <= input_start_row;
                    end_row <= input_end_row;
                    start_column <= input_start_column;
                    current_column <= input_start_column;
                    end_column <= input_end_column;
                    max_edge_data <= '1;
                    min_edge_data <= '0;
                    buffered_row <= input_start_row;
                    current_state <= INIT_EYE_COUNTING;
                end



                INIT_EYE_COUNTING: begin // 2 cycle delay
                    column_eye_size_counter <= 0;
                    max_edge_data <= '1;
                    min_edge_data <= '0;
                    buffered_row <= current_row + 1;
                    current_row <= current_row + 1;
                    if (current_row == start_row + BUFFER_TIME - 1) begin 
                        current_state <= SEARCHING_EYE;
                    end
                end

                SEARCHING_EYE: begin 
                    
                    // Updating sliding window max in parallel!
                    max_edge_data[7-1] <= eye_pixel_value;
                    max_edge_data[6-1] <= (max_edge_data[6] > eye_pixel_value) ? max_edge_data[6] : eye_pixel_value;
                    max_edge_data[5-1] <= (max_edge_data[5] > eye_pixel_value) ? max_edge_data[5] : eye_pixel_value;
                    max_edge_data[4-1] <= (max_edge_data[4] > eye_pixel_value) ? max_edge_data[4] : eye_pixel_value;
                    max_edge_data[3-1] <= (max_edge_data[3] > eye_pixel_value) ? max_edge_data[3] : eye_pixel_value;
                    max_edge_data[2-1] <= (max_edge_data[2] > eye_pixel_value) ? max_edge_data[2] : eye_pixel_value;
                    max_edge_data[1-1] <= (max_edge_data[1] > eye_pixel_value) ? max_edge_data[1] : eye_pixel_value;

                    min_edge_data[7-1] <= eye_pixel_value;
                    min_edge_data[6-1] <= (min_edge_data[6] < eye_pixel_value) ? min_edge_data[6] : eye_pixel_value;
                    min_edge_data[5-1] <= (min_edge_data[5] < eye_pixel_value) ? min_edge_data[5] : eye_pixel_value;
                    min_edge_data[4-1] <= (min_edge_data[4] < eye_pixel_value) ? min_edge_data[4] : eye_pixel_value;
                    min_edge_data[3-1] <= (min_edge_data[3] < eye_pixel_value) ? min_edge_data[3] : eye_pixel_value;
                    min_edge_data[2-1] <= (min_edge_data[2] < eye_pixel_value) ? min_edge_data[2] : eye_pixel_value;
                    min_edge_data[1-1] <= (min_edge_data[1] < eye_pixel_value) ? min_edge_data[1] : eye_pixel_value;

                    // min_pixel_value <= ((min_pixel_value < pixel_max) ? min_pixel_value : pixel_max);

                    // if (pixel_max >= EDGE_THRESHOLD) begin 
                    //     column_eye_size_counter <= column_eye_size_counter + 1;
                    // end

                    if (pixel_max <= min_pixel_value + DIFF_THRESHOLD) begin 
                        pupil_eye_size_counter <= pupil_eye_size_counter + 1;
                    end 

                    if (pixel_min + DIFF_THRESHOLD >= max_pixel_value) begin 
                        sclera_eye_size_counter <= sclera_eye_size_counter + 1;
                    end 



                    if (current_row == end_row + BUFFER_TIME) begin // If we have processed all rows including the 2 cycle buffer, end column search 
                        current_state <= COMPLETE_EYE;
                    end else if (current_row < end_row) begin  // If we have yet to finish sending data
                        buffered_row <= current_row + 1;
                    end 
                    current_row <= current_row + 1;

                end

                COMPLETE_EYE: begin 
                    max_edge_data <= '0;
                    max_edge_data <= '1;
                    eye_size_counter <= pupil_eye_size_counter + sclera_eye_size_counter;
                    // if (column_eye_size_counter >= COUNT_THRESHOLD) begin 
                    //     eye_size_counter <= eye_size_counter + (column_eye_size_counter - COUNT_THRESHOLD);
                    // end
                    if (current_column == end_column) begin  // We are done with the search, we should return
                        current_state <= COMPLETE_SEARCH;
                    end else begin 
                        current_column <= current_column + 1;
                        current_row <= start_row;
                        current_state <= INIT_EYE_COUNTING;
                    end
                end

                
                COMPLETE_SEARCH: begin 
                    computed_eye_valid <= 1;
                    current_state <= IDLE;
                end
            endcase
        end
    end

    
endmodule