module is_eye #(parameter NUM_PIXELS=128, parameter NUM_LINES = 32)(
    input logic [$clog2(NUM_PIXELS):0] pixel_counter,
    input logic [$clog2(NUM_LINES):0] line_counter,
    output logic in_sprite
);
    assign in_sprite = (
        (line_counter >= 7 && pixel_counter >= 7 && 
            (line_counter - 7) * (line_counter - 7) + (pixel_counter - 7) * (pixel_counter - 7) < 40)
        || 

        (line_counter < 7 && pixel_counter >= 7 && 
            (7 - line_counter) * (7 - line_counter) + (pixel_counter - 7) * (pixel_counter - 7) < 40)
        ||
        (line_counter >= 7 && pixel_counter < 7 && 
            (line_counter - 7) * (line_counter - 7) + (7 - pixel_counter) * (7 - pixel_counter) < 40)
        || 

        (line_counter < 7 && pixel_counter < 7 && 
            (7 - line_counter) * (7 - line_counter) + (7 - pixel_counter) * (7 - pixel_counter) < 40)
    ) && (
        line_counter > 4
    );
endmodule

module is_nose #(parameter NUM_PIXELS=128, parameter NUM_LINES = 32)(
    input logic [$clog2(NUM_PIXELS):0] pixel_counter,
    input logic [$clog2(NUM_LINES):0] line_counter,
    output logic in_sprite
);
    assign in_sprite = (
        ((pixel_counter > 50 && pixel_counter < 64) && (pixel_counter + 3 * line_counter > 73)) &&
        ((pixel_counter > 50 && pixel_counter < 64) && (pixel_counter > 45 + 2 * line_counter))
    );
endmodule

module is_mouth #(parameter NUM_PIXELS=128, parameter NUM_LINES = 32)(
    input logic [$clog2(NUM_PIXELS):0] pixel_counter,
    input logic [$clog2(NUM_LINES):0] line_counter,
    output logic in_sprite
);
    assign in_sprite = (
        ((pixel_counter >= 15) && (pixel_counter < 30) && ((line_counter == 7) || (line_counter == 8))) ||
        ((pixel_counter >= 30) && (pixel_counter < 60) && 
            (4 * line_counter + pixel_counter < 65) &&  (4 * line_counter + pixel_counter > 55))
    );
endmodule


module fixed_proto_face #(parameter NUM_PIXELS=128, parameter NUM_LINES = 32) (
    input logic [$clog2(NUM_PIXELS):0] pixel_counter,
    input logic [$clog2(NUM_LINES):0] line_counter,
    output logic [2:0] rgb0,
    output logic [2:0] rgb1
);
    logic in_right_eye;
    logic in_left_eye;

    logic in_right_nose;
    logic in_left_nose;

    logic in_right_mouth;
    logic in_left_mouth;

    is_eye #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES))right_eye(
        .pixel_counter(pixel_counter),
        .line_counter(line_counter),
        .in_sprite(in_right_eye)
    );

    is_eye #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES))left_eye(
        .pixel_counter(NUM_PIXELS - pixel_counter - 1),
        .line_counter(line_counter),
        .in_sprite(in_left_eye)
    );

    is_nose #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES))right_nose(
        .pixel_counter(pixel_counter),
        .line_counter(line_counter),
        .in_sprite(in_right_nose)
    );

    is_nose #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES))left_nose(
        .pixel_counter(NUM_PIXELS - pixel_counter - 1),
        .line_counter(line_counter),
        .in_sprite(in_left_nose)
    );

    is_mouth #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES))right_mouth(
        .pixel_counter(pixel_counter),
        .line_counter(line_counter),
        .in_sprite(in_right_mouth)
    );

    is_mouth #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES))left_mouth(
        .pixel_counter(NUM_PIXELS - pixel_counter - 1),
        .line_counter(line_counter),
        .in_sprite(in_left_mouth)
    );
    
    always_comb begin 
        rgb0 = 7 * (in_right_eye || in_left_eye || in_right_nose || in_left_nose);
        rgb1 = 7 * (in_right_mouth || in_left_mouth);
    end
endmodule