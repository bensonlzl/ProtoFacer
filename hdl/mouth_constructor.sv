module upper_mouth_boundary#(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter FACE_RES=(1<<16), 
    parameter LOG_POWER_MOD=4    
)(
    input logic clk_in,
    input logic [LOG_ROWS:0] row,
    input logic [LOG_NUM_PIXELS:0] col,
    input logic [LOG_FACE_RES-1:0] mouth_openness,
    output logic [PIXEL_SIZE-1:0] pixel_data
);
    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;

    localparam BOUNDARY_0 = 10;
    localparam BOUNDARY_1 = 20;
    localparam BOUNDARY_2 = 32;
    localparam BOUNDARY_3 = 44;
    localparam BOUNDARY_4s = 64;

    



    
    logic [31:0] boundary_01_LHS[2:0];
    logic [31:0] boundary_01_RHS[2:0];
    logic [31:0] boundary_01_in[2:0];


    logic [31:0] boundary_12_LHS[2:0];
    logic [31:0] boundary_12_RHS[2:0];
    logic [31:0] boundary_12_in[2:0];

    logic [31:0] boundary_23_LHS[2:0];
    logic [31:0] boundary_23_RHS[2:0];
    logic [31:0] boundary_23_in[2:0];

    logic [31:0] boundary_34_LHS[2:0];
    logic [31:0] boundary_34_RHS[2:0];
    logic [31:0] boundary_34_in[2:0];

    logic [31:0] boundary_in;

    always_ff @(posedge clk_in) begin 
        


        // 2(y+3) <= (-x + 10) {10 <= x <= 20}
        // 6 + c <= 10 + 2r
        boundary_01_LHS[2] <= 6 + col;
        boundary_01_LHS[1] <= boundary_01_LHS[2];
        boundary_01_RHS[2] <= 2 * (row+1);
        boundary_01_RHS[1] <= 10 + boundary_01_RHS[2];

        boundary_01_in[2] <= (col >= 10 && col < 20);
        boundary_01_in[1] <= boundary_01_in[2];
        boundary_01_in[0] <= boundary_01_in[1] && (boundary_01_LHS[1] <=  boundary_01_RHS[1]);

        // -4(y+8) >= (-x+20) {20 <= x <= 32}
        // 4r + c >= 52

        boundary_12_LHS[2] <= 4 * (row+1);
        boundary_12_LHS[1] <= boundary_12_LHS[2] + col;
        boundary_12_RHS[2] <= 52;
        boundary_12_RHS[1] <= boundary_12_RHS[2];

        boundary_12_in[2] <= (col >= 20 && col < 32);
        boundary_12_in[1] <= boundary_12_in[2];
        boundary_12_in[0] <= boundary_12_in[1]  && (boundary_12_LHS[1] >= boundary_12_RHS[1]);

        // 3(y+5) <= (-x + 32) {32 <= x <= 44}
        // c + 15 <= 3r + 32
        boundary_23_LHS[2] <= col + 15;
        boundary_23_RHS[2] <= 3 * (row+1) + 32;

        boundary_23_in[2] <= (col >= 32 && col < 44);
        boundary_23_in[1] <= boundary_23_in[2] && (boundary_23_LHS[2] <= boundary_23_RHS[2]);
        boundary_23_in[0] <= boundary_23_in[1];

        // -4(y+9) >= (-x + 44) {44 <= x <= 64}
        // 4r + c >= 84

        boundary_34_LHS[2] <= 4 * (row+1) + col;
        boundary_34_RHS[2] <= 80;

        boundary_34_in[2] <= (col >= 44 && col < 64);
        boundary_34_in[1] <= boundary_34_in[2] && (boundary_34_LHS[2] >= boundary_34_RHS[2]);
        boundary_34_in[0] <= boundary_34_in[1];

        // boundary_in <= (boundary_01_in[1] || boundary_12_in[1] || boundary_23_in[1] || boundary_34_in[1]);

        // pixel_data <= (boundary_in ? '1 : '0);
        pixel_data <= (boundary_01_in[0] || boundary_12_in[0] || boundary_23_in[0] || boundary_34_in[0]) ? '1 : '0;
        // pixel_data <= '1;

    end
endmodule

module lower_mouth_boundary#(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter FACE_RES=(1<<16), 
    parameter LOG_POWER_MOD=4    
)(
    input logic clk_in,
    input logic [LOG_ROWS:0] row,
    input logic [LOG_NUM_PIXELS:0] col,
    input logic [LOG_FACE_RES-1:0] mouth_openness,
    output logic [PIXEL_SIZE-1:0] pixel_data
);
    localparam LOG_FACE_RES = $clog2(FACE_RES);
    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;

    localparam BOUNDARY_0 = 10;
    localparam BOUNDARY_1 = 20;
    localparam BOUNDARY_2 = 32;
    localparam BOUNDARY_3 = 44;
    localparam BOUNDARY_4 = 64;

    logic [2:0][LOG_NUM_PIXELS:0] col_pipeline;
    logic [2:0][LOG_ROWS:0] row_pipeline;


    
    logic [31:0] boundary_01_LHS[2:0];
    logic [31:0] boundary_01_RHS[2:0];
    logic [31:0] boundary_01_in[2:0];


    logic [31:0] boundary_12_LHS[2:0];
    logic [31:0] boundary_12_RHS[2:0];
    logic [31:0] boundary_12_in[2:0];

    logic [31:0] boundary_23_LHS[2:0];
    logic [31:0] boundary_23_RHS[2:0];
    logic [31:0] boundary_23_in[2:0];

    logic [31:0] boundary_34_LHS[2:0];
    logic [31:0] boundary_34_RHS[2:0];
    logic [31:0] boundary_34_in[2:0];

    logic [2:0] boundary_in;

    always_ff @(posedge clk_in) begin 
        col_pipeline[2] <= col;
        col_pipeline[1] <= col_pipeline[2];
        col_pipeline[0] <= col_pipeline[1];

        row_pipeline[2] <= row;
        row_pipeline[1] <= row_pipeline[2];
        row_pipeline[0] <= row_pipeline[1];

        // (-10)(y+3) <= (-8 - z + 3)(-x + 10) {10 <= x < 20}
        // 10r + 10z + 20 <= 5c + zc
        // 20r + 10z + 40 <= 10c + zc
        boundary_01_LHS[2] <= (2 * row) + mouth_openness;
        boundary_01_LHS[1] <= 10 * boundary_01_LHS[2] + 40;

        boundary_01_RHS[2] <= 10 + mouth_openness;
        boundary_01_RHS[1] <= col_pipeline[2] * boundary_01_RHS[2];

        boundary_01_in[2] <= (col >= 10 && col < 20);
        boundary_01_in[1] <= boundary_01_in[2];
        boundary_01_in[0] <= boundary_01_in[1]  && (boundary_01_LHS[1] <= boundary_01_RHS[1]);

        // -4(y + 8 + z) <= (-x + 20) {20 <= x < 32}
        // 4r + c <= 52 + 4z
        // 8r + 2c <= 104 + 4z
        boundary_12_LHS[2] <= 8 * (row) + 2 * col;
        boundary_12_RHS[2] <= 104 + 4 * mouth_openness;

        boundary_12_in[2] <= (col >= 20 && col < 32);
        boundary_12_in[1] <= boundary_12_in[2] && (boundary_12_LHS[2] <= boundary_12_RHS[2]);
        boundary_12_in[0] <= boundary_12_in[1];

        // 300(y + 5 + z) >= (104z)(-x + 32)
        // 100c+4zc+300z+1500 <= 300r+3200+128z
        // 100c + 4zc + 172z <= 300r + 1700
        // 200c + 4zc + 172z <= 600r + 3400
        boundary_23_LHS[2] <= mouth_openness * (col + 38);
        boundary_23_LHS[1] <= 4 * boundary_23_LHS[2] + 200 * col_pipeline[2];

        boundary_23_RHS[2] <= 600 * (row);
        boundary_23_RHS[1] <= boundary_23_RHS[2] + 3400;

        boundary_23_in[2] <= (col >= 32 && col < 44);
        boundary_23_in[1] <= boundary_23_in[2];
        boundary_23_in[0] <= boundary_23_in[1] && (boundary_23_LHS[1] >= boundary_23_RHS[1]);

        // (-20)(25y + 225 + 29z) <= (125-5z)(-x + 44) {44 <= x < 64}
        // 500r + 125c <= 10000 + 360z + 5zc
        // 125(4r + c) <= 10000 + z * (360 + 5 * c)
        // 250(4r + c) <= 20000 + z * (360 + 5 * c)

        boundary_34_LHS[2] <= 1000 * (row);
        boundary_34_LHS[1] <= boundary_34_LHS[2] + 250 * col_pipeline[2];

        boundary_34_RHS[2] <= 360 + 5 * col;
        boundary_34_RHS[1] <= mouth_openness * boundary_34_RHS[2] + 20000;
                                    
        boundary_34_in[2] <= (col >= 44 && col < 64);
        boundary_34_in[1] <= boundary_34_in[2];
        boundary_34_in[0] <= boundary_34_in[1] && (boundary_34_LHS[1] <= boundary_34_RHS[1]);

        pixel_data <= (boundary_01_in[0] || boundary_12_in[0] || boundary_23_in[0] || boundary_34_in[0]) ? '1 : '0;

    end
endmodule

module mouth_constructor #(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter FACE_RES=(1<<16), 
    parameter LOG_POWER_MOD=4
)(
    input logic clk_in,
    input logic rst_in,
    input logic face_data_valid,
    input logic [LOG_FACE_RES-1:0] mouth_openness,

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
    localparam LEFT_END = 3;
    localparam RIGHT_END = 19;

    typedef enum {
        IDLE,
        DRAWING
    } MOUTH_CONSTRUCTOR_STATE;

    MOUTH_CONSTRUCTOR_STATE current_state;
    logic [LOG_FACE_RES-1:0] mouth_openness_buffer;
    logic [LOG_FACE_RES-1:0] current_mouth_openness;
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

    logic [PIXEL_SIZE-1:0] left_mouth_lower_pixel;
    lower_mouth_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD)
    ) left_mouth_lower (
        .clk_in(clk_in),
        .row(row_num),
        .col(NUM_PIXELS-1-column_counter),
        .mouth_openness(current_mouth_openness),
        .pixel_data(left_mouth_lower_pixel)
    );


    logic [PIXEL_SIZE-1:0] left_mouth_upper_pixel;
    upper_mouth_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD)
    ) left_mouth_upper (
        .clk_in(clk_in),
        .row(row_num),
        .col(NUM_PIXELS-1-column_counter),
        .mouth_openness(current_mouth_openness),
        .pixel_data(left_mouth_upper_pixel)
    );

    logic [PIXEL_SIZE-1:0] right_mouth_lower_pixel;
    lower_mouth_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD)
    ) right_mouth_lower (
        .clk_in(clk_in),
        .row(row_num),
        .col(column_counter),
        .mouth_openness(current_mouth_openness),
        .pixel_data(right_mouth_lower_pixel)
    );


    logic [PIXEL_SIZE-1:0] right_mouth_upper_pixel;
    upper_mouth_boundary#(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
        .NUM_PIXELS(NUM_PIXELS), 
        .FACE_RES(FACE_RES), 
        .LOG_POWER_MOD(LOG_POWER_MOD)
    ) right_mouth_upper (
        .clk_in(clk_in),
        .row(row_num),
        .col(column_counter),
        .mouth_openness(current_mouth_openness),
        .pixel_data(right_mouth_upper_pixel)
    );

    logic [3:0][ADDRESS_SIZE-1:0] lower_pixel_address_pipeline;
    logic [3:0] lower_pixel_valid_pipeline;
    
    always_comb begin 
        lower_pixel_data = ((left_mouth_lower_pixel & left_mouth_upper_pixel))
        | ((right_mouth_lower_pixel & right_mouth_upper_pixel));
        lower_pixel_address = lower_pixel_address_pipeline[1-1];
        lower_pixel_valid = lower_pixel_valid_pipeline[1-1];
    end


    always_ff @(posedge clk_in) begin 
        if (rst_in) begin
            valid_buffer <= 0;
            current_state <= IDLE;
            row_clock_rst <= 1;
            row_counter_rst <= 1;
            lower_pixel_address_pipeline <= '0;
            lower_pixel_valid_pipeline <= '0;
        end else begin 
            lower_pixel_address_pipeline[1-1] <= lower_pixel_address_pipeline[1];
            lower_pixel_address_pipeline[2-1] <= lower_pixel_address_pipeline[2];
            lower_pixel_address_pipeline[3-1] <= lower_pixel_address_pipeline[3];
            lower_pixel_address_pipeline[4-1] <= row_num * NUM_PIXELS + column_counter;

            lower_pixel_valid_pipeline[1-1] <= lower_pixel_valid_pipeline[1];
            lower_pixel_valid_pipeline[2-1] <= lower_pixel_valid_pipeline[2];
            lower_pixel_valid_pipeline[3-1] <= lower_pixel_valid_pipeline[3];
            lower_pixel_valid_pipeline[4-1] <= (current_state == DRAWING);

            if (!valid_buffer && face_data_valid) begin 
                valid_buffer <= face_data_valid;
                mouth_openness_buffer <= mouth_openness;
            end
            case (current_state)
                IDLE : begin 
                    // If we have a valid value in the buffer, we take that new value into the computation
                    if (valid_buffer) begin 
                        current_mouth_openness <= mouth_openness_buffer;
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