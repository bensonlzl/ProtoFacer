module face_constructor #(
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
    input logic [LOG_FACE_RES-1:0] mouth_openness,

    output logic [ADDRESS_SIZE-1:0] upper_pixel_address,
    output logic [PIXEL_SIZE-1:0] upper_pixel_data,
    output logic upper_pixel_valid,
    output logic [ADDRESS_SIZE-1:0] lower_pixel_address,
    output logic [PIXEL_SIZE-1:0] lower_pixel_data,
    output logic lower_pixel_valid
);
    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam TOTAL_ADDRESSES = NUM_BLOCK_ROWS * NUM_PIXELS;
    localparam ADDRESS_SIZE = $clog2(TOTAL_ADDRESSES);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;

    
    eye_constructor #(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD)
    ) eye_computer (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .face_data_valid(face_data_valid),
        .left_eye_openness(left_eye_openness),
        .right_eye_openness(right_eye_openness),
        .upper_pixel_address(upper_pixel_address),
        .upper_pixel_data(upper_pixel_data),
        .upper_pixel_valid(upper_pixel_valid)
    );

    mouth_constructor #(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD)
    ) mouth_computer (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .face_data_valid(face_data_valid),
        .mouth_openness(mouth_openness),
        .lower_pixel_address(lower_pixel_address),
        .lower_pixel_data(lower_pixel_data),
        .lower_pixel_valid(lower_pixel_valid)
    );
endmodule