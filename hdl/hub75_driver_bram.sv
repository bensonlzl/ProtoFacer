
module hub75_driver_bram #(
    parameter NUM_PIXELS = 128, 
    parameter NUM_BLOCK_ROWS = 16,
    parameter POWER_MOD = 16
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
    output logic clk_drive,

    output logic row_0_data_valid,
    output logic [ADDRESS_SIZE-1:0] row_0_pixel_address,
    input logic [PIXEL_SIZE-1:0] row_0_pixel_data,

    output logic row_1_data_valid,    
    output logic [ADDRESS_SIZE-1:0] row_1_pixel_address,
    input logic [PIXEL_SIZE-1:0] row_1_pixel_data
);
    localparam CLK_TIME = 10; // 10 cycles per hub clock
    localparam HALF_CLK_TIME = CLK_TIME / 2; // 5 cycles per rising / falling
    localparam DATA_TIME = CLK_TIME * NUM_PIXELS; // Time needed to send all pixels

    localparam STARTUP_TIME = HALF_CLK_TIME; 
    localparam LATCH_TIME = 10; // 10 cycles to latch
    localparam DELAY = 1; // 1 cycle delay after each row
    localparam END_DELAY = 10; // 10 cycle end delay after each power frame

    localparam ROW_TIME = STARTUP_TIME + DATA_TIME + LATCH_TIME + DELAY; // total time needed to send a row
    localparam ACTIVE_TIME = ROW_TIME * NUM_BLOCK_ROWS; // total time needed to send all rows
    localparam TOTAL_TIME = ACTIVE_TIME + END_DELAY; // total time needed to send all rows

    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam TOTAL_ADDRESSES = NUM_BLOCK_ROWS * NUM_PIXELS;
    localparam ADDRESS_SIZE = $clog2(TOTAL_ADDRESSES);
    localparam LOG_POWER_MOD=$clog2(POWER_MOD);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;


    // All the clocks!
    // Clock for the LED Board
    logic half_clock_tick;
    logic half_clock_reset;
    counter_with_out_and_tick #(.MAX_COUNT(HALF_CLK_TIME)) edge_time_clock (
        .clk_in(clk_in),
        .rst_in(half_clock_reset),
        .period_in(HALF_CLK_TIME),
        .count_out(),
        .tick(half_clock_tick)
    );

     // Clock for the each row
    logic [$clog2(ROW_TIME)-1:0] row_time_counter;
    logic row_clock_tick;
    logic row_time_rst;
    counter_with_out_and_tick #(.MAX_COUNT(ROW_TIME)) row_time_clock (
        .clk_in(clk_in),
        .rst_in(row_time_rst),
        .period_in(ROW_TIME),
        .count_out(row_time_counter),
        .tick(row_clock_tick)
    );

    // Clock for the whole frame
    logic [$clog2(TOTAL_TIME)-1:0] total_time_counter;
    logic total_clock_tick;
    logic total_time_rst;
    counter_with_out_and_tick #(.MAX_COUNT(TOTAL_TIME)) total_time_clock (
        .clk_in(clk_in),
        .rst_in(total_time_rst),
        .period_in(TOTAL_TIME),
        .count_out(total_time_counter),
        .tick(total_clock_tick)
    );


    // Counter for the pixels
    logic [LOG_NUM_PIXELS-1:0] pixel_counter;
    logic pixel_rst;
    evt_counter_wrap #(.MAX_EVENT(NUM_PIXELS)) pixel_clock_counter (
        .clk_in(clk_in),
        .rst_in(pixel_rst),
        .evt_in((half_clock_tick && clock_value)),
        .count_out(pixel_counter)
    );

    logic [LOG_ROWS-1:0] row_counter;    
    logic row_rst;
    evt_counter_wrap #(.MAX_EVENT(NUM_BLOCK_ROWS)) row_clock_counter (
        .clk_in(clk_in),
        .rst_in(row_rst),
        .evt_in(row_clock_tick),
        .count_out(row_counter)
    );

    logic [LOG_POWER_MOD-1:0] power_counter;
    logic power_rst;
    evt_counter_wrap #(.MAX_EVENT(POWER_MOD)) power_clock_counter (
        .clk_in(clk_in),
        .rst_in(power_rst),
        .evt_in(total_clock_tick),
        .count_out(power_counter)
    );

    logic [2:0] pixel_0_rgb;
    logic [2:0] pixel_1_rgb;
    logic pixel_data_valid;

    assign r0 = pixel_0_rgb[0];
    assign g0 = pixel_0_rgb[1];
    assign b0 = pixel_0_rgb[2];
    assign r1 = pixel_1_rgb[0];
    assign g1 = pixel_1_rgb[1];
    assign b1 = pixel_1_rgb[2];

    hub75_pwm #(
        .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS),
        .NUM_PIXELS(NUM_PIXELS),
        .POWER_MOD(POWER_MOD)
    ) power_modulator (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .power_counter(power_counter),
        .row_counter(row_counter),
        .pixel_counter(pixel_counter),
        .pixel_0_rgb(pixel_0_rgb),
        .pixel_1_rgb(pixel_1_rgb),
        .row_0_pixel_address(row_0_pixel_address),
        .row_1_pixel_address(row_1_pixel_address),
        .row_0_pixel_data(row_0_pixel_data),
        .row_1_pixel_data(row_1_pixel_data)
    );


    logic clock_value;
    logic latch_val;
    logic [3:0] addr_val;
    logic out_en;

    assign clk_drive = clock_value;
    assign latch = latch_val;
    assign addr = addr_val;
    assign output_enable = !out_en;

    // fixed_proto_face #(.NUM_PIXELS(NUM_PIXELS), .NUM_LINES(NUM_LINES)) happy_face (
    //     .pixel_counter(pixel_counter),
    //     .line_counter(line_counter),
    //     .rgb0({r0,g0,b0}),
    //     .rgb1({r1,g1,b1})
    // );

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            // Reset all clocks
            half_clock_reset <= 1;
            row_time_rst <= 1;
            total_time_rst <= 1;

            // Reset all counters
            pixel_rst <= 1;
            row_rst <= 1;
            power_rst <= 1;
            
            // reset all outputs
            out_en <= 0;
            clock_value <= 0;
            latch_val <= 0;
            
            // data is not valid
            row_0_data_valid <= 0;
            row_1_data_valid <= 0;
            addr_val <= NUM_BLOCK_ROWS - 1;

        end if (total_time_counter < ACTIVE_TIME) begin  // we are sending signals!
            power_rst <= 0;

            if (row_time_counter < STARTUP_TIME) begin 
                // ensure all clocks are running
                half_clock_reset <= 0;
                row_time_rst <= 0;
                total_time_rst <= 0;

                // ensure all counters are running
                
                pixel_rst <= 0;
                row_rst <= 0;
                power_rst <= 0;

                // start clock at 0
                clock_value <= 0;
                latch_val <= 0;
                

                row_0_data_valid <= 1;
                row_1_data_valid <= 1;


            end else if (row_time_counter < STARTUP_TIME + DATA_TIME) begin 
                out_en <= 1;
                // flip clock on every half cycle
                if (half_clock_tick) begin 
                    clock_value <= !clock_value;
                end
            end else if (row_time_counter < STARTUP_TIME + DATA_TIME + LATCH_TIME) begin 
                // stop the cycle clock
                half_clock_reset <= 1;
                out_en <= 0;

                // reset pixel counter
                pixel_rst <= 1;

                clock_value <= 0;
                // latch
                latch_val <= 1;

                row_0_data_valid <= 0;
                row_1_data_valid <= 0;
            end else begin 
                addr_val <= addr_val + 1;
                out_en <= 0;
                half_clock_reset <= 1;
                pixel_rst <= 1;
                latch_val <= 0;

            end

        end else begin // reset for the next power frame 
            // Reset all clocks
            half_clock_reset <= 1;
            row_time_rst <= 1;

            // Reset all counters
            pixel_rst <= 1;
            row_rst <= 1;
            
            // reset all outputs
            out_en <= 0;
            clock_value <= 0;
            latch_val <= 0;
            addr_val <= NUM_BLOCK_ROWS - 1;

        end
    end 



endmodule