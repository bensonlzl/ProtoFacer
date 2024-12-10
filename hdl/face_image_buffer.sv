/*
Module for the face image buffer
Consists of two BRAM modules, each storing one half of the face
*/
module face_image_buffer #(
    parameter NUM_BLOCK_ROWS=16, 
    parameter NUM_PIXELS=128, 
    parameter POWER_MOD = 16,
    parameter FILE_INIT_UPPER="",
    parameter FILE_INIT_LOWER=""
) (
    input logic clk_in,
    input logic [ADDRESS_SIZE-1:0] upper_pixel_address,
    input logic [PIXEL_SIZE-1:0] upper_pixel_data,
    input logic upper_pixel_valid,

    input logic [ADDRESS_SIZE-1:0] lower_pixel_address,
    input logic [PIXEL_SIZE-1:0] lower_pixel_data,
    input logic lower_pixel_valid,

    input logic [ADDRESS_SIZE-1:0] row_0_pixel_address,
    output logic [PIXEL_SIZE-1:0] row_0_pixel_data,
    input logic row_0_data_valid,

    input logic [ADDRESS_SIZE-1:0] row_1_pixel_address,
    output logic [PIXEL_SIZE-1:0] row_1_pixel_data,
    input logic row_1_data_valid
);

    localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
    localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
    localparam TOTAL_ADDRESSES = NUM_BLOCK_ROWS * NUM_PIXELS;
    // localparam ADDRESS_SIZE = LOG_ROWS + LOG_NUM_PIXELS;
    localparam ADDRESS_SIZE = $clog2(TOTAL_ADDRESSES);
    localparam LOG_POWER_MOD=$clog2(POWER_MOD);
    localparam PIXEL_SIZE = 3*LOG_POWER_MOD;


    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(PIXEL_SIZE),
        .RAM_DEPTH(TOTAL_ADDRESSES),
        .INIT_FILE(FILE_INIT_UPPER)          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) upper_fib (
        .addra(upper_pixel_address),      // Port A address bus, width determined from RAM_DEPTH
        .addrb(row_0_pixel_address),      // Port B address bus, width determined from RAM_DEPTH
        .dina(upper_pixel_data),       // Port A RAM input data
        .dinb(0),       // Port B RAM input data
        .clka(clk_in),       // Clock
        .wea(upper_pixel_valid),        // Port A write enable
        .web(0),        // Port B write enable
        .ena(1),        // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(1),        // Port B RAM Enable, for additional power savings, disable port when not in use
        .rsta(0),       // Port A output reset (does not affect memory contents)
        .rstb(0),       // Port B output reset (does not affect memory contents)
        .regcea(0),     // Port A output register enable
        .regceb(row_0_data_valid),     // Port B output register enable
        .doutb(row_0_pixel_data)       // Port B RAM output data
    );

    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(PIXEL_SIZE),
        .RAM_DEPTH(TOTAL_ADDRESSES),
        .INIT_FILE(FILE_INIT_LOWER)          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) lower_fib (
        .addra(lower_pixel_address),      // Port A address bus, width determined from RAM_DEPTH
        .addrb(row_1_pixel_address),      // Port B address bus, width determined from RAM_DEPTH
        .dina(lower_pixel_data),       // Port A RAM input data
        .dinb(0),       // Port B RAM input data
        .clka(clk_in),       // Clock
        .wea(lower_pixel_valid),        // Port A write enable
        .web(0),        // Port B write enable
        .ena(1),        // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(1),        // Port B RAM Enable, for additional power savings, disable port when not in use
        .rsta(0),       // Port A output reset (does not affect memory contents)
        .rstb(0),       // Port B output reset (does not affect memory contents)
        .regcea(0),     // Port A output register enable
        .regceb(row_1_data_valid),     // Port B output register enable
        .doutb(row_1_pixel_data)       // Port B RAM output data
    );
    
endmodule