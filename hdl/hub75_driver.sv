
module hub75_driver #(parameter NUM_PIXELS = 128, parameter NUM_LINES = 16
    )
(
    input wire clk_in,
    input wire rst_in,

    output logic [3:0] addr,
    output logic output_enable,
    output logic latch,
    output logic r0,
    output logic r1,
    output logic g0,
    output logic g1,
    output logic b0,
    output logic b1,
    output logic clk_drive
);
    localparam CLK_TIME = 10; // 100 cycles per hub clock
    localparam HALF_CLK_TIME = CLK_TIME / 2; // 50 cycles per rising / falling
    localparam DATA_TIME = CLK_TIME * NUM_PIXELS;

    localparam STARTUP_TIME = HALF_CLK_TIME;
    localparam LATCH_TIME = 10; // 
    localparam DELAY = 1; // 1 cyle delay 

    localparam TOTAL_TIME = STARTUP_TIME + DATA_TIME + LATCH_TIME + DELAY;

    logic [5:0] rgbvals;
    // assign r0 = rgbvals[0];
    // assign r1 = rgbvals[1];
    // assign g0 = rgbvals[2];
    // assign g1 = rgbvals[3];
    // assign b0 = rgbvals[4];
    // assign b1 = rgbvals[5];

    logic out_en;

    // logic half_clock_tick;
    logic [$clog2(TOTAL_TIME)-1:0] total_counter;
    logic [$clog2(TOTAL_TIME)-1:0] total_time;
    logic [$clog2(HALF_CLK_TIME)-1:0] half_time;

    assign total_time = TOTAL_TIME;
    assign half_time = HALF_CLK_TIME;

    logic total_clock_tick;
    logic half_clock_tick;
    logic half_clock_reset;
    logic clock_value;
    logic latch_val;

    assign latch = latch_val;

    counter_with_out_and_tick #(.MAX_COUNT(HALF_CLK_TIME)) edge_clock (
        .clk_in(clk_in),
        .rst_in(half_clock_reset),
        .period_in(half_time),
        .count_out(),
        .tick(half_clock_tick)
    );

    counter_with_out_and_tick #(.MAX_COUNT(TOTAL_TIME)) total_clock (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .period_in(total_time),
        .count_out(total_counter),
        .tick(total_clock_tick)
    );

    logic [$clog2(NUM_PIXELS):0] pixel_time;
    assign pixel_time = NUM_PIXELS;
    logic [$clog2(NUM_PIXELS):0] pixel_counter;
    logic pixel_rst;
    logic row_tick;


    evt_counter_wrap #(.MAX_EVENT(2 * NUM_PIXELS)) pixel_clock (
        .clk_in(clk_in),
        .rst_in(pixel_rst),
        .evt_in((half_clock_tick && clock_value)),
        .count_out(pixel_counter)
    );

    logic [$clog2(NUM_LINES):0] line_counter;

    evt_counter_wrap #(.MAX_EVENT(2*NUM_LINES)) row_clock (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(row_tick),
        .count_out(line_counter)
    );

    logic [3:0] addr_val;

    assign addr = addr_val;

    assign clk_drive = clock_value;
    
    assign output_enable = !out_en;

    fixed_proto_face #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES)) happy_face (
        .pixel_counter(pixel_counter),
        .line_counter(line_counter),
        .rgb0({r0,g0,b0}),
        .rgb1({r1,g1,b1})
    );

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            row_tick <= 0;
            half_clock_reset <= 1;
            out_en <= 0;
            clock_value <= 0;
            latch_val <= 0;
            addr_val <= 0;
            pixel_rst <= 1;
        end else if (total_counter < STARTUP_TIME) begin 

            row_tick <= 0;
            latch_val <= 0;
            half_clock_reset <= 0;
            clock_value <= 0;
            rgbvals <= {
                addr[0] ^ total_counter[0+7],
                addr[1] ^ total_counter[1+7],
                addr[2] ^ total_counter[2+7],
                addr[0] ^ total_counter[3+7],
                addr[1] ^ total_counter[4+7],
                addr[2] ^ total_counter[5+7]
            };
            pixel_rst <= 1;

        end else if (total_counter < STARTUP_TIME + DATA_TIME) begin 
            out_en <= 1;
            pixel_rst <= 0;

            if (half_clock_tick) begin 
                clock_value <= !clock_value;
                rgbvals <= {
                    addr[0] ^ total_counter[0],
                    addr[1] ^ total_counter[1],
                    addr[2] ^ total_counter[2],
                    addr[0] ^ total_counter[3],
                    addr[1] ^ total_counter[4],
                    addr[2] ^ total_counter[5]
                };
            end
        end else if (total_counter < STARTUP_TIME + DATA_TIME + LATCH_TIME) begin 
            if (half_clock_tick) begin 
                half_clock_reset <= 1;
                addr_val <= addr_val + 1;
            end
            clock_value <= 0;
            pixel_rst <= 1;
            latch_val <= 1;
        end else begin 
            out_en <= 0;
            half_clock_reset <= 1;
            pixel_rst <= 1;
            row_tick <= 1;

        end
    end 



endmodule