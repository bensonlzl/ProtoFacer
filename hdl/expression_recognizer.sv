
module expression_recognizer #(
    parameter HEIGHT=320, 
    parameter WIDTH=180, 
    parameter FACE_RES=(1 << 16),
    parameter PIXEL_SIZE=8,
    parameter LEFT_EYE_LEFT,
    parameter LEFT_EYE_RIGHT,
    parameter RIGHT_EYE_LEFT,
    parameter RIGHT_EYE_RIGHT,
    parameter LEFT_EYE_TOP,
    parameter LEFT_EYE_BOTTOM,    
    parameter RIGHT_EYE_TOP,
    parameter RIGHT_EYE_BOTTOM,
    parameter MOUTH_LEFT,
    parameter MOUTH_RIGHT,
    parameter MOUTH_TOP,
    parameter MOUTH_BOTTOM 
) 
(
    input logic clk_in,
    input logic rst_in,
    input logic start_search,

    output logic [FB_SIZE-1:0] pixel_address,
    output logic pixel_address_valid,
    input logic [PIXEL_SIZE-1:0] pixel_value,


    output logic [LOG_FACE_RES-1:0] left_eye_openness,
    output logic [LOG_FACE_RES-1:0] right_eye_openness,
    output logic [LOG_FACE_RES-1:0] mouth_openness,
    output logic openness_valid

);
    typedef enum {  IDLE, 
            INIT_SEARCH_LEFT, 
            SEARCHING_LEFT, 
            COMPLETE_SEARCH_LEFT,
            INIT_SEARCH_RIGHT, 
            SEARCHING_RIGHT, 
            COMPLETE_SEARCH_RIGHT,
            INIT_SEARCH_MOUTH, 
            SEARCHING_MOUTH, 
            COMPLETE_SEARCH_MOUTH,
            COMPLETE 
        } EXPRESSION_RECOGNIZER_STATE;

    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_HEIGHT = $clog2(HEIGHT);
    localparam LOG_WIDTH = $clog2(WIDTH);
    localparam FB_DEPTH = HEIGHT*WIDTH;
    localparam FB_SIZE = $clog2(FB_DEPTH);

    localparam EYE_LOW_THRESHOLD = 90;
    localparam EYE_HIGH_THRESHOLD = 160;

    localparam MOUTH_LOW_THRESHOLD = 70;
    localparam MOUTH_HIGH_THRESHOLD = 200;


    EXPRESSION_RECOGNIZER_STATE current_state;
    logic computed_eye_valid;


    logic start_eye_search;
    logic [LOG_HEIGHT-1:0] eye_start_row, eye_end_row;
    logic [LOG_WIDTH-1:0] eye_start_column, eye_end_column;
    logic [FB_SIZE-1:0] eye_pixel_address;
    logic eye_pixel_address_valid;
    logic [PIXEL_SIZE-1:0] eye_pixel_value;
    // logic [LOG_FACE_RES-1:0] computed_eye_openness;
    logic [LOG_FACE_RES-1:0] computed_left_eye_openness;
    logic [LOG_FACE_RES-1:0] computed_right_eye_openness;
    logic [LOG_FACE_RES-1:0] computed_eye_openness_buffer;
    logic [LOG_FACE_RES-1:0] sclera_eye_openness_buffer;
    logic [LOG_FACE_RES-1:0] pupil_eye_openness_buffer;

    logic eye_finder_rst;


    finder #(
        .HEIGHT(HEIGHT), 
        .WIDTH(WIDTH), 
        .FACE_RES(FACE_RES),
        .PIXEL_SIZE(PIXEL_SIZE),
        .LOW_THRESHOLD(EYE_LOW_THRESHOLD),
        .HIGH_THRESHOLD(EYE_HIGH_THRESHOLD)
    ) eye_finder (
        .clk_in(clk_in),
        .rst_in(rst_in || eye_finder_rst),
        .start_search(start_eye_search),
        .input_start_row(eye_start_row),
        .input_end_row(eye_end_row),
        .input_start_column(eye_start_column),
        .input_end_column(eye_end_column),
        .eye_pixel_address(eye_pixel_address),
        .eye_pixel_address_valid(eye_pixel_address_valid),
        .eye_pixel_value(eye_pixel_value),
        .computed_eye_valid(computed_eye_valid),
        .computed_eye_openness(computed_eye_openness_buffer),
        .computed_sclera(sclera_eye_openness_buffer),
        .computed_pupil(pupil_eye_openness_buffer)
    );

    
    logic computed_mouth_valid;
    logic mouth_finder_rst;

    logic start_mouth_search;
    logic [LOG_HEIGHT-1:0] mouth_start_row, mouth_end_row;
    logic [LOG_WIDTH-1:0] mouth_start_column, mouth_end_column;
    logic [FB_SIZE-1:0] mouth_pixel_address;
    logic mouth_pixel_address_valid;
    logic [PIXEL_SIZE-1:0] mouth_pixel_value;
    logic [LOG_FACE_RES-1:0] mouth_openness_buffer;
    logic [LOG_FACE_RES-1:0] computed_mouth_openness;
    logic [LOG_FACE_RES-1:0] computed_mouth_darkness;
    logic [LOG_FACE_RES-1:0] computed_mouth_brightness;

    finder #(
        .HEIGHT(HEIGHT), 
        .WIDTH(WIDTH), 
        .FACE_RES(FACE_RES),
        .PIXEL_SIZE(PIXEL_SIZE),
        .LOW_THRESHOLD(MOUTH_LOW_THRESHOLD),
        .HIGH_THRESHOLD(MOUTH_HIGH_THRESHOLD)
    ) mouth_finder (
        .clk_in(clk_in),
        .rst_in(rst_in || mouth_finder_rst),
        .start_search(start_mouth_search),
        .input_start_row(mouth_start_row),
        .input_end_row(mouth_end_row),
        .input_start_column(mouth_start_column),
        .input_end_column(mouth_end_column),
        .eye_pixel_address(mouth_pixel_address),
        .eye_pixel_address_valid(mouth_pixel_address_valid),
        .eye_pixel_value(mouth_pixel_value),
        .computed_eye_valid(computed_mouth_valid),
        .computed_eye_openness(mouth_openness_buffer),
        .computed_sclera(computed_mouth_brightness),
        .computed_pupil(computed_mouth_darkness)
    );

    // routing addressing to the BRAM
    always_comb begin 
        case (current_state)
            IDLE, COMPLETE, COMPLETE_SEARCH_LEFT, COMPLETE_SEARCH_RIGHT, COMPLETE_SEARCH_MOUTH: begin 
                pixel_address = 0;
                pixel_address_valid = 0;
                eye_pixel_value = 0;
                mouth_pixel_value = 0;
            end
            INIT_SEARCH_LEFT, SEARCHING_LEFT, INIT_SEARCH_RIGHT, SEARCHING_RIGHT: begin 
                pixel_address = eye_pixel_address;
                pixel_address_valid = eye_pixel_address_valid;
                eye_pixel_value = pixel_value;
                mouth_pixel_value = 0;
            end 
            INIT_SEARCH_MOUTH, SEARCHING_MOUTH: begin 
                pixel_address = mouth_pixel_address;
                pixel_address_valid = mouth_pixel_address_valid;
                eye_pixel_value = 0;
                mouth_pixel_value = pixel_value;
            end
        endcase
    end

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            eye_finder_rst <= 1;
            mouth_finder_rst <= 1;
            start_eye_search <= 0;
            eye_start_row <= 0;
            eye_end_row <= 0;
            eye_start_column <= 0;
            eye_end_column <= 0;
            start_mouth_search <= 0;
            mouth_start_row <= 0;
            mouth_end_row <= 0;
            mouth_start_column <= 0;
            mouth_end_column <= 0;
            openness_valid <= 0;
            computed_left_eye_openness <= 0;
            computed_right_eye_openness <= 0;
            computed_mouth_openness <= 0;
            current_state <= IDLE;
        end
        else begin
            case (current_state)
                IDLE: begin
                    if (start_search) begin 
                        current_state <= INIT_SEARCH_LEFT;
                    end
                    openness_valid <= 0;
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 1;
                end 

                INIT_SEARCH_LEFT: begin
                    // Initialise eye finder
                    eye_finder_rst <= 0;
                    mouth_finder_rst <= 1;
                    start_eye_search <= 1;
                    eye_start_row <= LEFT_EYE_TOP;
                    eye_end_row <= LEFT_EYE_BOTTOM;
                    eye_start_column <= LEFT_EYE_LEFT;
                    eye_end_column <= LEFT_EYE_RIGHT;

                    current_state <= SEARCHING_LEFT;
                end

                SEARCHING_LEFT: begin
                    eye_finder_rst <= 0;
                    mouth_finder_rst <= 1;
                    start_eye_search <= 0;
                    if (computed_eye_valid) begin
                        // Save values and deactivate eye finder
                        computed_left_eye_openness <= pupil_eye_openness_buffer;
                        current_state <= COMPLETE_SEARCH_LEFT;
                    end
                end

                COMPLETE_SEARCH_LEFT : begin 
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 1;
                    eye_start_row <= 0;
                    eye_end_row <= 0;
                    eye_start_column <= 0;
                    eye_end_column <= 0;
                    current_state <= INIT_SEARCH_RIGHT;
                end

                INIT_SEARCH_RIGHT: begin
                    // Initialise eye finder
                    eye_finder_rst <= 0;
                    mouth_finder_rst <= 1;
                    start_eye_search <= 1;
                    eye_start_row <= RIGHT_EYE_TOP;
                    eye_end_row <= RIGHT_EYE_BOTTOM;
                    eye_start_column <= RIGHT_EYE_LEFT;
                    eye_end_column <= RIGHT_EYE_RIGHT;
                    current_state <= SEARCHING_RIGHT;
                end

                SEARCHING_RIGHT: begin
                    eye_finder_rst <= 0;
                    mouth_finder_rst <= 1;
                    start_eye_search <= 0;
                    if (computed_eye_valid) begin
                        // Save values and deactivate eye finder
                        computed_right_eye_openness <= pupil_eye_openness_buffer;
                        current_state <= COMPLETE_SEARCH_RIGHT;
                    end
                end

                COMPLETE_SEARCH_RIGHT : begin 
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 1;
                    eye_start_row <= 0;
                    eye_end_row <= 0;
                    eye_start_column <= 0;
                    eye_end_column <= 0;
                    current_state <= INIT_SEARCH_MOUTH;
                end

                INIT_SEARCH_MOUTH: begin
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 0;
                    start_mouth_search <= 1;
                    mouth_start_row <= MOUTH_TOP;
                    mouth_end_row <= MOUTH_BOTTOM;
                    mouth_start_column <= MOUTH_LEFT;
                    mouth_end_column <= MOUTH_RIGHT;
                    current_state <= SEARCHING_MOUTH;
                end

                SEARCHING_MOUTH: begin
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 0;
                    start_mouth_search <= 0;
                    if (computed_mouth_valid) begin
                        computed_mouth_openness <= (computed_mouth_darkness >> 3);
                        current_state <= COMPLETE_SEARCH_MOUTH;
                    end
                end

                COMPLETE_SEARCH_MOUTH : begin 
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 1;
                    mouth_start_row <= 0;
                    mouth_end_row <= 0;
                    mouth_start_column <= 0;
                    mouth_end_column <= 0;
                    current_state <= COMPLETE;
                end

                COMPLETE: begin
                    eye_finder_rst <= 1;
                    mouth_finder_rst <= 1;
                    left_eye_openness <= computed_left_eye_openness;
                    right_eye_openness <= computed_right_eye_openness;
                    mouth_openness <= computed_mouth_openness;
                    openness_valid <= 1'b1;
                    current_state <= IDLE;
                end
            endcase
        end
        
    end


endmodule
