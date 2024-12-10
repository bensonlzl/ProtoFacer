`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"../data/X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module top_level(
  input wire clk_sys,

  // output logic [15:0] led,
   // camera bus
   input wire [7:0]    camera_d, // 8 parallel data wires
   output logic        cam_xclk, // XC driving camera
   input wire          cam_hsync, // camera hsync wire
   input wire          cam_vsync, // camera vsync wire
   input wire          cam_pclk, // camera pixel clock
   inout wire          i2c_scl, // i2c inout clock
   inout wire          i2c_sda, // i2c inout data
  input wire [4:0] sw, //all 16 input slide switches
  input wire [1:0] btn, //all four momentary button switches
//   output logic [15:0] led, //16 green output LEDs (located right above switches)
  // output logic [2:0] rgb0, //RGB channels of RGB LED0
  // output logic [2:0] rgb1, //RGB channels of RGB LED1
//   output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
//   output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
//   output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
//   output logic [6:0] ss1_c, //cathod controls for the segments of lower four digits
  output logic [1:0] red,
  output logic [1:0] green,
  output logic [1:0] blue,
  output logic [3:0] addr,
  output logic clk_hub,
  output logic output_en,
  output logic latch,
  	 output logic 				 uart_rxd_out, // UART computer-FPGA
	 input wire 			 uart_txd_in // UART FPGA-computer

  );

  // assign rgb0 = 0;
  // assign rgb1 = 0;

  // hub75_driver #(
  //   .NUM_PIXELS(128),
  //   .NUM_LINES(16)
  // ) led_driver (
  //   .clk_in(clk_sys),
  //   .rst_in(btn[0] || sw[0]),
  //   .addr(addr),
  //   .output_enable(output_en),
  //   .latch(latch),
  //   .r0(red[0]),
  //   .r1(red[1]),
  //   .g0(green[0]),
  //   .g1(green[1]),
  //   .b0(blue[0]),
  //   .b1(blue[1]),
  //   .clk_drive(clk_hub)
  // );

  // shut up those RGBs
  // assign rgb0 = 0;
  // assign rgb1 = 0;

  // Clock and Reset Signals
  logic          sys_rst_camera;
  logic          sys_rst_pixel;

  logic          clk_camera;
  logic          clk_pixel;
  logic          clk_5x;
  logic          clk_xc;

  logic          clk_100_passthrough;

  // clocking wizards to generate the clock speeds we need for our different domains
  // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
  cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .clk_tmds(clk_5x),
     .reset(0));

  cmoda735t_clocking_wizard  wizard_migcam
    (.clk_in1(clk_sys),
     .clk_camera(clk_camera),
     .clk_xc(clk_xc),
     .clk_100(clk_100_passthrough),
     .reset(0));

  // assign camera's xclk to pmod port: drive the operating clock of the camera!
  // this port also is specifically set to high drive by the XDC file.
  assign cam_xclk = clk_xc;

  assign sys_rst_camera = btn[0]; //use for resetting camera side of logic
  assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic


  // video signal generator signals
  logic          hsync_hdmi;
  logic          vsync_hdmi;
  logic [10:0]  hcount_hdmi;
  logic [9:0]    vcount_hdmi;
  logic          active_draw_hdmi;
  logic          new_frame_hdmi;
  logic [5:0]    frame_count_hdmi;
  logic          nf_hdmi;

  // rgb output values
  // logic [7:0]          red,green,blue;

  // ** Handling input from the camera **

  // synchronizers to prevent metastability
  logic [7:0]    camera_d_buf [1:0];
  logic          cam_hsync_buf [1:0];
  logic          cam_vsync_buf [1:0];
  logic          cam_pclk_buf [1:0];

  always_ff @(posedge clk_camera) begin
     camera_d_buf <= {camera_d, camera_d_buf[1]};
     cam_pclk_buf <= {cam_pclk, cam_pclk_buf[1]};
     cam_hsync_buf <= {cam_hsync, cam_hsync_buf[1]};
     cam_vsync_buf <= {cam_vsync, cam_vsync_buf[1]};
  end

  logic [10:0] camera_hcount;
  logic [9:0]  camera_vcount;
  logic [8-1:0] camera_pixel;
  logic        camera_valid;

  // your pixel_reconstruct module, from week 5 and 6
  // hook it up to buffered inputs.
  //same as it ever was.

  pixel_reconstruct pixel_reconstructor
    (.clk_in(clk_camera),
     .rst_in(sys_rst_camera),
     .camera_pclk_in(cam_pclk_buf[0]),
     .camera_hs_in(cam_hsync_buf[0]),
     .camera_vs_in(cam_vsync_buf[0]),
     .camera_data_in(camera_d_buf[0]),
     .pixel_valid_out(camera_valid),
     .pixel_hcount_out(camera_hcount),
     .pixel_vcount_out(camera_vcount),
     .pixel_data_out(camera_pixel));

  //----------------BEGIN NEW STUFF FOR LAB 07------------------

  //clock domain cross (from clk_camera to clk_pixel)
  //switching from camera clock domain to pixel clock domain early
  //this lets us do convolution on the 74.25 MHz clock rather than the
  //200 MHz clock domain that the camera lives on.
  logic empty;
  logic cdc_valid;
  logic [8-1:0] cdc_pixel;
  logic [10:0] cdc_hcount;
  logic [9:0] cdc_vcount;

  //cdc fifo (AXI IP). Remember to include that IP folder.
  fifo cdc_fifo
    (.wr_clk(clk_camera),
     .full(),
     .din({camera_hcount, camera_vcount, camera_pixel}),
     .wr_en(camera_valid),

     .rd_clk(clk_pixel),
     .empty(empty),
     .dout({cdc_hcount, cdc_vcount, cdc_pixel}),
     .rd_en(1) //always read
    );
  assign cdc_valid = ~empty; //watch when empty. Ready immediately if something there

  //----
  //Filter 0: 1280x720 convolution of gaussian blur
  logic [10:0] f0_hcount;  //hcount from filter0 module
  logic [9:0] f0_vcount; //vcount from filter0 module
  logic [8-1:0] f0_pixel; //pixel data from filter0 module
  logic f0_valid; //valid signals for filter0 module
  //full resolution filter
  filter #(.K_SELECT(1),.HRES(WIDTH),.VRES(HEIGHT))
    filtern(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_valid_in(cdc_valid),
    .pixel_data_in(cdc_pixel),
    .hcount_in(cdc_hcount),
    .vcount_in(cdc_vcount),
    .data_valid_out(f0_valid),
    .pixel_data_out(f0_pixel),
    .hcount_out(f0_hcount),
    .vcount_out(f0_vcount)
  );

  //----
  logic [10:0] lb_hcount;  //hcount to filter modules
  logic [9:0] lb_vcount; //vcount to filter modules
  logic [8-1:0] lb_pixel; //pixel data to filter modules
  logic lb_valid; //valid signals to filter modules

  //selection logic to either go through (btn[1]=1)
  //or bypass (btn[1]==0) the first filter
  //in the first part of lab as you develop line buffer, you'll want to bypass
  //since your filter won't be working, but it would be good to test the
  //downsampling line buffer below on its own
  always_ff @(posedge clk_pixel) begin
    if (0)begin
      ds_hcount = cdc_hcount;
      ds_vcount = cdc_vcount;
      ds_pixel = cdc_pixel;
      ds_valid = cdc_valid;
    end else begin
      ds_hcount = f0_hcount;
      ds_vcount = f0_vcount;
      ds_pixel = f0_pixel;
      ds_valid = f0_valid;
    end
  end

  //----
  //A line buffer that, in conjunction with the control signal will down sample
  //the camera (or f0 filter) values from 1280x720 to 320x180
  //in reality we could get by without this, but it does make things a little easier
  //and we've also added it since it gives us a means of testing the line buffer
  //design outside of the filter.
  logic [2:0][8-1:0] lb_buffs; //grab output of down sample line buffer
  logic ds_control; //controlling when to write (every fourth pixel and line)
  logic [10:0] ds_hcount;  //hcount to downsample line buffer
  logic [9:0] ds_vcount; //vcount to downsample line buffer
  logic [8-1:0] ds_pixel; //pixel data to downsample line buffer
  logic ds_valid; //valid signals to downsample line buffer
  assign ds_control = ds_valid;//&&(ds_hcount[1:0]==2'b0)&&(ds_vcount[1:0]==2'b0);
  line_buffer #(.HRES(WIDTH),
                .VRES(HEIGHT))
    ds_lbuff (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_valid_in(ds_control),
    .pixel_data_in(ds_pixel),
    .hcount_in(ds_hcount),
    .vcount_in(ds_vcount),
    .data_valid_out(lb_valid),
    .line_buffer_out(lb_buffs),
    .hcount_out(lb_hcount),
    .vcount_out(lb_vcount)
  );

  assign lb_pixel = lb_buffs[1]; //pass on only the middle one.

  //----
  //Create six different filters that all exist in parallel
  //The outputs of all six filters are fed into the unpacked arrays below:
  logic [10:0] f_hcount [5:0];  //hcount from filter modules
  logic [9:0] f_vcount [5:0]; //vcount from filter modules
  logic [8-1:0] f_pixel [5:0]; //pixel data from filter modules
  logic f_valid [5:0]; //valid signals for filter modules

  //using generate/genvar, create five *Different* instances of the
  //filter module (you'll write that).  Each filter will implement a different
  //kernel
  generate
    genvar i;
    for (i=0; i<6; i=i+1)begin
      filter #(.K_SELECT(i),.HRES(WIDTH),.VRES(HEIGHT))
        filterm(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_valid_in(lb_valid),
        .pixel_data_in(lb_pixel),
        .hcount_in(lb_hcount),
        .vcount_in(lb_vcount),
        .data_valid_out(f_valid[i]),
        .pixel_data_out(f_pixel[i]),
        .hcount_out(f_hcount[i]),
        .vcount_out(f_vcount[i])
      );
    end
  endgenerate

  //combine hor and vert signals from filters 4 and 5 for special signal:
  logic [8-1:0] fcomb;
  assign fcomb = (f_pixel[4]+f_pixel[5])>>1;

  //------
  //Choose which filter to use
  //based on values of sw[2:0] select which filter output gets handed on to the
  //next module. We must make sure to route hcount, vcount, pixels and valid signal
  // for each module.  Could have done this with a for loop as well!  Think
  // about it!
  logic [10:0] fmux_hcount; //hcount from filter mux
  logic [9:0]  fmux_vcount; //vcount from filter mux
  logic [8-1:0] fmux_pixel; //pixel data from filter mux
  logic fmux_valid; //data valid from filter mux

  //000 Identity Kernel
  //001 Gaussian Blur
  //010 Sharpen
  //011 Ridge Detection
  //100 Sobel Y-axis Edge Detection
  //101 Sobel X-axis Edge Detection
  //110 Total Sobel Edge Detection
  //111 Output of Line Buffer Directly (Helpful for debugging line buffer in first part)
  always_ff @(posedge clk_pixel)begin
    case (sw[2:0])
      // 3'b000: begin
      //   fmux_hcount <= f_hcount[0];
      //   fmux_vcount <= f_vcount[0];
      //   fmux_pixel <= f_pixel[0];
      //   fmux_valid <= f_valid[0];
      // end
      // 3'b001: begin
      //   fmux_hcount <= f_hcount[1];
      //   fmux_vcount <= f_vcount[1];
      //   fmux_pixel <= f_pixel[1];
      //   fmux_valid <= f_valid[1];
      // end
      // 3'b010: begin
      //   fmux_hcount <= f_hcount[2];
      //   fmux_vcount <= f_vcount[2];
      //   fmux_pixel <= f_pixel[2];
      //   fmux_valid <= f_valid[2];
      // end
      // 3'b011: begin
      //   fmux_hcount <= f_hcount[3];
      //   fmux_vcount <= f_vcount[3];
      //   fmux_pixel <= f_pixel[3];
      //   fmux_valid <= f_valid[3];
      // end
      // 3'b100: begin
      //   fmux_hcount <= f_hcount[4];
      //   fmux_vcount <= f_vcount[4];
      //   fmux_pixel <= f_pixel[4];
      //   fmux_valid <= f_valid[4];
      // end
      // 3'b101: begin
      //   fmux_hcount <= f_hcount[5];
      //   fmux_vcount <= f_vcount[5];
      //   fmux_pixel <= f_pixel[5];
      //   fmux_valid <= f_valid[5];
      // end
      // 3'b110: begin
      //   fmux_hcount <= f_hcount[4];
      //   fmux_vcount <= f_vcount[4];
      //   fmux_pixel <= fcomb;
      //   fmux_valid <= f_valid[4]&&f_valid[5];
      // end
      default: begin
        fmux_hcount <= lb_hcount;
        fmux_vcount <= lb_vcount;
        fmux_pixel <= lb_pixel;
        fmux_valid <= lb_valid;
      end
    endcase
  end

  localparam WIDTH = 180;
  localparam HEIGHT = 320;
  localparam FB_DEPTH = HEIGHT*WIDTH;
  localparam FB_SIZE = $clog2(FB_DEPTH);
  localparam LOG_FACE_RES = $clog2(FACE_RES);




  logic [FB_SIZE-1:0] addra; //used to specify address to write to in frame buffer
  logic valid_camera_mem; //used to enable writing pixel data to frame buffer
  logic [8-1:0] camera_mem; //used to pass pixel data into frame buffer

  //because the down sampling already happened upstream, there's no need to do here.
  always_ff @(posedge clk_pixel) begin
    if(fmux_valid) begin
      addra <= fmux_hcount + fmux_vcount * WIDTH;
      camera_mem <= +fmux_pixel;
      valid_camera_mem <= 1;
    end else begin
      valid_camera_mem <= 0;
    end
  end

  logic [FB_SIZE-1:0] pixel_address;
  logic pixel_address_valid;
  logic [PIXEL_SIZE-1:0] pixel_value;
  logic [LOG_FACE_RES-1:0] left_eye_openness_buffer;
  logic [LOG_FACE_RES-1:0] right_eye_openness_buffer;
  logic [LOG_FACE_RES-1:0] mouth_openness_buffer;
  logic [LOG_FACE_RES-1:0] left_eye_openness;
  logic [LOG_FACE_RES-1:0] right_eye_openness;
  logic [LOG_FACE_RES-1:0] mouth_openness;
  logic openness_valid;

  expression_recognizer #(
    .HEIGHT(HEIGHT), 
    .WIDTH(WIDTH), 
    .FACE_RES(FACE_RES),
    .PIXEL_SIZE(PIXEL_SIZE),
    .LEFT_EYE_LEFT(LEFT_EYE_LEFT >> 1),
    .LEFT_EYE_RIGHT(LEFT_EYE_RIGHT >> 1),
    .RIGHT_EYE_LEFT(RIGHT_EYE_LEFT >> 1),
    .RIGHT_EYE_RIGHT(RIGHT_EYE_RIGHT >> 1),
    .LEFT_EYE_TOP(LEFT_EYE_TOP >> 1),
    .LEFT_EYE_BOTTOM(LEFT_EYE_BOTTOM >> 1),
    .RIGHT_EYE_TOP(RIGHT_EYE_TOP >> 1),
    .RIGHT_EYE_BOTTOM(RIGHT_EYE_BOTTOM >> 1),
    .MOUTH_LEFT(MOUTH_LEFT >> 1),
    .MOUTH_RIGHT(MOUTH_RIGHT >> 1),
    .MOUTH_TOP(MOUTH_TOP >> 1),
    .MOUTH_BOTTOM(MOUTH_BOTTOM >> 1)
  ) face_expression_recognizer
  (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .start_search(1), // always keep searching
    .pixel_address(pixel_address),
    .pixel_address_valid(pixel_address_valid),
    .pixel_value(pixel_value),
    .left_eye_openness(left_eye_openness_buffer),
    .right_eye_openness(right_eye_openness_buffer),
    .mouth_openness(mouth_openness_buffer),
    .openness_valid(openness_valid)
  );

  logic ssc_tick;
  logic [31:0] ssc_counter;
  counter_with_out_and_tick #(
    .MAX_COUNT((1 << 31))
  ) ssc_ticker (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .period_in(200000),
    .count_out(ssc_counter),
    .tick(ssc_tick)
  );

  logic [LOG_FACE_RES-1:0] display_left_eye_openness;
  logic [LOG_FACE_RES-1:0] display_right_eye_openness;
  logic [LOG_FACE_RES-1:0] display_mouth_openness;

  always_ff @(posedge clk_pixel) begin
    if (openness_valid) begin 
      left_eye_openness <= left_eye_openness_buffer;
      right_eye_openness <= right_eye_openness_buffer;
      mouth_openness <= mouth_openness_buffer;
    end
    if (ssc_tick) begin 
      display_left_eye_openness <= (btn[1] ? 0 : ((left_eye_openness > 30) ? 15 : left_eye_openness >> 1));
      display_right_eye_openness <= (btn[1] ? 0 : ((right_eye_openness > 30) ? 15 : right_eye_openness >> 1));
      display_mouth_openness <= ((mouth_openness > 70) ? 10 : ((mouth_openness > 30) ? ((mouth_openness - 30) >> 2) : 0));
    end
  end

  // assign computed_eye_openness = 16'habcd;

  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8),                       // Specify RAM data width
    .RAM_DEPTH(57600),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE") // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
  ) face_buffer (
    .addra(addra),  // Port A address bus, width determined from RAM_DEPTH
    .addrb(  pixel_address),  // Port B address bus, width determined from RAM_DEPTH
    .dina(camera_mem),           // Port A RAM input data
    .dinb(0),           // Port B RAM input data
    .clka(clk_pixel),                           // Port A clock
    .clkb(clk_pixel),                           // Port B clock
    .wea(valid_camera_mem),                            // Port A write enable
    .web(0),                            // Port B write enable
    .ena(1),                            // Port A RAM Enable, for additional power savings, disable port when not in use
    .enb(1),                            // Port B RAM Enable, for additional power savings, disable port when not in use
    .rsta(0),                           // Port A output reset (does not affect memory contents)
    .rstb(0),                           // Port B output reset (does not affect memory contents)
    .regcea(1),                         // Port A output register enable
    .regceb(1),                         // Port B output register enable
    .douta(),         // Port A RAM output data
    .doutb(pixel_value)          // Port B RAM output data
  );

  // Uncomment this section to send an image back over uart!
  // BEGIN UART SECTION
  

//   logic [FB_SIZE-1:0] uart_pixel_address;

//   logic [10:0] uart_hcount;
//   logic [9:0] uart_vcount;

//   assign uart_pixel_address = (uart_vcount < HEIGHT ? uart_vcount : HEIGHT - 1) * WIDTH +  uart_hcount;

//   logic [8-1:0] uart_pixel_value;
//   logic [8-1:0] uart_edge_pixel_value;
//   logic [8-1:0] uart_final_pixel_value;
// logic                      sample_waiting;

//    logic [7:0]                uart_data_in;
//    logic [7:0]                uart_data_buffer;
//    logic                      uart_data_valid;
//    logic                      uart_busy;

//   logic                       uart_trigger;

//   logic left_eye_border;
//   logic right_eye_border;
//   logic mouth_border;
//   assign left_eye_border = ((
//     (uart_vcount == (LEFT_EYE_TOP >> 1)) || (uart_vcount == (LEFT_EYE_BOTTOM >> 1))
//   ) && ((uart_hcount >= (LEFT_EYE_LEFT >> 1)) && (uart_hcount <= (LEFT_EYE_RIGHT >> 1))))
//   || ((
//     (uart_hcount == (LEFT_EYE_LEFT >> 1)) || (uart_hcount == (LEFT_EYE_RIGHT >> 1))
//   ) && ((uart_vcount >= (LEFT_EYE_TOP >> 1)) && (uart_vcount <= (LEFT_EYE_BOTTOM >> 1))));

//   assign right_eye_border = ((
//     (uart_vcount == (RIGHT_EYE_TOP >> 1)) || (uart_vcount == (RIGHT_EYE_BOTTOM >> 1))
//   ) && ((uart_hcount >= (RIGHT_EYE_LEFT >> 1)) && (uart_hcount <= (RIGHT_EYE_RIGHT >> 1))))
//   || ((
//     (uart_hcount == (RIGHT_EYE_LEFT >> 1)) || (uart_hcount == (RIGHT_EYE_RIGHT >> 1))
//   ) && ((uart_vcount >= (RIGHT_EYE_TOP >> 1)) && (uart_vcount <= (RIGHT_EYE_BOTTOM >> 1))));

//   assign mouth_border = ((
//     (uart_vcount == (MOUTH_TOP >> 1)) || (uart_vcount == (MOUTH_BOTTOM >> 1))
//   ) && ((uart_hcount >= (MOUTH_LEFT >> 1)) && (uart_hcount <= (MOUTH_RIGHT >> 1))))
//   || ((
//     (uart_hcount == (MOUTH_LEFT >> 1)) || (uart_hcount == (MOUTH_RIGHT >> 1))
//   ) && ((uart_vcount >= (MOUTH_TOP >> 1)) && (uart_vcount <= (MOUTH_BOTTOM >> 1))));

//   assign uart_final_pixel_value = (
//     (left_eye_border || right_eye_border || mouth_border) ? 8'h00 : 
//     uart_pixel_value
//   );

//   localparam SYNC_TIME = 100;
//   localparam DROP_SYNC_TIME = 20;

//   xilinx_true_dual_port_read_first_2_clock_ram #(
//     .RAM_WIDTH(8),                       // Specify RAM data width
//     .RAM_DEPTH(57600),                     // Specify RAM depth (number of entries)
//     .RAM_PERFORMANCE("HIGH_PERFORMANCE") // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
// ) uart_image_buffer (
//     .addra(addra),  // Port A address bus, width determined from RAM_DEPTH
//     .addrb(uart_pixel_address) ,  // Port B address bus, width determined from RAM_DEPTH
//     .dina(camera_mem),           // Port A RAM input data
//     .dinb(0),           // Port B RAM input data
//     .clka(clk_pixel),                           // Port A clock
//     .clkb(clk_pixel),                           // Port B clock
//     .wea(valid_camera_mem),                            // Port A write enable
//     .web(0),                            // Port B write enable
//     .ena(1),                            // Port A RAM Enable, for additional power savings, disable port when not in use
//     .enb(1),                            // Port B RAM Enable, for additional power savings, disable port when not in use
//     .rsta(0),                           // Port A output reset (does not affect memory contents)
//     .rstb(0),                           // Port B output reset (does not affect memory contents)
//     .regcea(1),                         // Port A output register enable
//     .regceb(1),                         // Port B output register enable
//     .douta(),         // Port A RAM output data
//     .doutb(uart_pixel_value)          // Port B RAM output data
//   );


  
  //   always_ff @(posedge clk_pixel) begin 
  //     if (sys_rst) begin 
  //       uart_hcount <= 0;
  //       uart_vcount <= 0;
  //       uart_data_in <= 0;
  //       uart_data_buffer <= 0;
  //       sample_waiting <= 0;
  //       uart_trigger <= 0;
  //     end else if (!uart_busy && sample_waiting) begin // audio is waiting and can be sent, go
  //         uart_data_in <= uart_data_buffer;
  //         uart_data_valid <= 1;
  //         sample_waiting <= 0;
  //         uart_trigger <= 1;
  //     end else begin
  //       uart_trigger <= 0;
  //       uart_data_valid <= 0;
  //       if (!sample_waiting) begin
  //         uart_data_buffer <= ((!btn[1]) ? (uart_vcount < HEIGHT ? uart_final_pixel_value : (uart_vcount < HEIGHT + SYNC_TIME ? 8'hff : 8'h00)) : display_mouth_openness); // sw[1] prints left eye over uart
  //         sample_waiting <= 1;
  //         if (uart_hcount + 1 == WIDTH) begin
  //           uart_hcount <= 0;
  //           if (uart_vcount + 1 == HEIGHT + SYNC_TIME + DROP_SYNC_TIME) begin 
  //             uart_vcount <= 0;
  //           end else begin 
  //             uart_vcount <= uart_vcount + 1;
  //           end
  //         end else begin 
  //           uart_hcount <= uart_hcount + 1;
  //         end
  //       end
  //     end
      
  //   end

  // uart_transmit #(.INPUT_CLOCK_FREQ(74_250_000), .BAUD_RATE(115200)) uart_audio_transmitter  (
  //   .clk_in(clk_pixel),
  //   .rst_in(sys_rst),
  //   .data_byte_in(uart_data_in),
  //   .trigger_in(uart_trigger),
  //   .busy_out(uart_busy),
  //   .tx_wire_out(uart_rxd_out)
  // );

  // END UART SECTION


  localparam LEFT_EYE_LEFT =    12'b0000_0111_0000;
  localparam LEFT_EYE_RIGHT =   12'b0000_1010_1000;
  localparam LEFT_EYE_TOP =          11'b001_0000_0000;
  localparam LEFT_EYE_BOTTOM =       11'b001_0011_0000;
  localparam RIGHT_EYE_LEFT =   12'b0000_1111_0000;
  localparam RIGHT_EYE_RIGHT =  12'b0001_0010_1000;
  localparam RIGHT_EYE_TOP =          11'b000_1111_0000;
  localparam RIGHT_EYE_BOTTOM =       11'b001_0010_0000;
  localparam MOUTH_LEFT =       12'b0000_1000_0000;
  localparam MOUTH_RIGHT =      12'b0001_0010_0000;
  localparam MOUTH_TOP =        11'b001_1010_0000;
  localparam MOUTH_BOTTOM =     11'b010_0010_0000;



   // Nothing To Touch Down Here:
   // register writes to the camera

   // The OV5640 has an I2C bus connected to the board, which is used
   // for setting all the hardware settings (gain, white balance,
   // compression, image quality, etc) needed to start the camera up.
   // We've taken care of setting these all these values for you:
   // "rom.mem" holds a sequence of bytes to be sent over I2C to get
   // the camera up and running, and we've written a design that sends
   // them just after a reset completes.

   // If the camera is not giving data, press your reset button.

   logic  busy, bus_active;
   logic  cr_init_valid, cr_init_ready;

   logic  recent_reset;
   always_ff @(posedge clk_camera) begin
      if (sys_rst_camera) begin
         recent_reset <= 1'b1;
         cr_init_valid <= 1'b0;
      end
      else if (recent_reset) begin
         cr_init_valid <= 1'b1;
         recent_reset <= 1'b0;
      end else if (cr_init_valid && cr_init_ready) begin
         cr_init_valid <= 1'b0;
      end
   end

   logic [23:0] bram_dout;
   logic [7:0]  bram_addr;

   // ROM holding pre-built camera settings to send
   xilinx_single_port_ram_read_first
     #(
       .RAM_WIDTH(24),
       .RAM_DEPTH(256),
       .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
       .INIT_FILE("benson_portrait_greyscale_rom.mem")
       ) registers
       (
        .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
        .clka(clk_camera),     // Clock
        .wea(1'b0),            // Write enable
        .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst_camera), // Output reset (does not affect memory contents)
        .regcea(1'b1),         // Output register enable
        .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
        );

   logic [23:0] registers_dout;
   logic [7:0]  registers_addr;
   assign registers_dout = bram_dout;
   assign bram_addr = registers_addr;

   logic       con_scl_i, con_scl_o, con_scl_t;
   logic       con_sda_i, con_sda_o, con_sda_t;

   // NOTE these also have pullup specified in the xdc file!
   // access our inouts properly as tri-state pins
   IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
   IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

   // provided module to send data BRAM -> I2C
   camera_registers crw
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .init_valid(cr_init_valid),
      .init_ready(cr_init_ready),
      .scl_i(con_scl_i),
      .scl_o(con_scl_o),
      .scl_t(con_scl_t),
      .sda_i(con_sda_i),
      .sda_o(con_sda_o),
      .sda_t(con_sda_t),
      .bram_dout(registers_dout),
      .bram_addr(registers_addr));

   // a handful of debug signals for writing to registers
  //  assign led[0] = crw.bus_active;
  //  assign led[1] = cr_init_valid;
  //  assign led[2] = cr_init_ready;
  //  assign led[8-1:3] = 0;

  localparam NUM_BLOCK_ROWS=16;
  localparam NUM_PIXELS=128;
  localparam FACE_RES=(1<<16);
  localparam POWER_MOD = 16;
  localparam LOG_ROWS = $clog2(NUM_BLOCK_ROWS);
  localparam LOG_NUM_PIXELS = $clog2(NUM_PIXELS);
  localparam TOTAL_ADDRESSES = NUM_BLOCK_ROWS * NUM_PIXELS;
  localparam ADDRESS_SIZE = $clog2(TOTAL_ADDRESSES);
  localparam LOG_POWER_MOD=$clog2(POWER_MOD);
  localparam PIXEL_SIZE = 3*LOG_POWER_MOD;

  logic sys_rst;
  assign sys_rst = btn[0];

  logic row_0_data_valid;
  logic [ADDRESS_SIZE-1:0] row_0_pixel_address;
  logic [PIXEL_SIZE-1:0] row_0_pixel_data;
  logic row_1_data_valid;
  logic [ADDRESS_SIZE-1:0] row_1_pixel_address;
  logic [PIXEL_SIZE-1:0] row_1_pixel_data;

  hub75_driver_bram #(
      .NUM_PIXELS(NUM_PIXELS), 
      .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS),
      .POWER_MOD(POWER_MOD)
  ) hub75_driver_bram_top_level
  (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .addr(addr),
      .output_enable(output_en),
      .latch(latch),
      .r0(red[0]),
      .r1(red[1]),
      .g0(green[0]),
      .g1(green[1]),
      .b0(blue[0]),
      .b1(blue[1]),
      .clk_drive(clk_hub),
      .row_0_data_valid(row_0_data_valid),
      .row_0_pixel_address(row_0_pixel_address),
      .row_0_pixel_data(row_0_pixel_data),
      .row_1_data_valid(row_1_data_valid),    
      .row_1_pixel_address(row_1_pixel_address),
      .row_1_pixel_data(row_1_pixel_data)
  );

  
  
  logic [PIXEL_SIZE-1:0] image_0_row_0_pixel_data;
  logic [PIXEL_SIZE-1:0] image_0_row_1_pixel_data;
  face_image_buffer #(
    .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), .NUM_PIXELS(NUM_PIXELS), .POWER_MOD(POWER_MOD),
    .FILE_INIT_UPPER(`FPATH(protogen_happy_1_upper.mem)), .FILE_INIT_LOWER(`FPATH(protogen_happy_1_lower.mem))
  ) image_0_fib (
    .clk_in(clk_pixel),
    .upper_pixel_address(),
    .upper_pixel_data(),
    .upper_pixel_valid(),
    .lower_pixel_address(),
    .lower_pixel_data(),
    .lower_pixel_valid(),
    .row_0_pixel_address(row_0_pixel_address),
    .row_0_pixel_data(image_0_row_0_pixel_data),
    .row_0_data_valid(row_0_data_valid),
    .row_1_pixel_address(row_1_pixel_address),
    .row_1_pixel_data(image_0_row_1_pixel_data),  
    .row_1_data_valid(row_1_data_valid)
  );


  logic [PIXEL_SIZE-1:0] image_1_row_0_pixel_data;
  logic [PIXEL_SIZE-1:0] image_1_row_1_pixel_data;
  face_image_buffer #(
    .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), .NUM_PIXELS(NUM_PIXELS), .POWER_MOD(POWER_MOD),
    .FILE_INIT_UPPER(`FPATH(rainbow_upper.mem)), .FILE_INIT_LOWER(`FPATH(rainbow_lower.mem))
  ) image_1_fib (
    .clk_in(clk_pixel),
    .upper_pixel_address(),
    .upper_pixel_data(),
    .upper_pixel_valid(),
    .lower_pixel_address(),
    .lower_pixel_data(),
    .lower_pixel_valid(),
    .row_0_pixel_address(row_0_pixel_address),
    .row_0_pixel_data(image_1_row_0_pixel_data),
    .row_0_data_valid(row_0_data_valid),
    .row_1_pixel_address(row_1_pixel_address),
    .row_1_pixel_data(image_1_row_1_pixel_data),  
    .row_1_data_valid(row_1_data_valid)
  );

  logic [PIXEL_SIZE-1:0] image_2_row_0_pixel_data;
  logic [PIXEL_SIZE-1:0] image_2_row_1_pixel_data;
  face_image_buffer #(
    .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), .NUM_PIXELS(NUM_PIXELS), .POWER_MOD(POWER_MOD),
    .FILE_INIT_UPPER(`FPATH(hello_upper.mem)), .FILE_INIT_LOWER(`FPATH(world_lower.mem))
  ) image_2_fib (
    .clk_in(clk_pixel),
    .upper_pixel_address(),
    .upper_pixel_data(),
    .upper_pixel_valid(),
    .lower_pixel_address(),
    .lower_pixel_data(),
    .lower_pixel_valid(),
    .row_0_pixel_address(row_0_pixel_address),
    .row_0_pixel_data(image_2_row_0_pixel_data),
    .row_0_data_valid(row_0_data_valid),
    .row_1_pixel_address(row_1_pixel_address),
    .row_1_pixel_data(image_2_row_1_pixel_data),  
    .row_1_data_valid(row_1_data_valid)
  );


  logic [PIXEL_SIZE-1:0] image_3_row_0_pixel_data;
  logic [PIXEL_SIZE-1:0] image_3_row_1_pixel_data;
  face_image_buffer #(
    .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), .NUM_PIXELS(NUM_PIXELS), .POWER_MOD(POWER_MOD),
    .FILE_INIT_UPPER(`FPATH(noise_upper.mem)), .FILE_INIT_LOWER(`FPATH(noise_lower.mem))
  ) image_3_fib (
    .clk_in(clk_pixel),
    .upper_pixel_address(),
    .upper_pixel_data(),
    .upper_pixel_valid(),
    .lower_pixel_address(),
    .lower_pixel_data(),
    .lower_pixel_valid(),
    .row_0_pixel_address(row_0_pixel_address),
    .row_0_pixel_data(image_3_row_0_pixel_data),
    .row_0_data_valid(row_0_data_valid),
    .row_1_pixel_address(row_1_pixel_address),
    .row_1_pixel_data(image_3_row_1_pixel_data),  
    .row_1_data_valid(row_1_data_valid)
  );

  logic [PIXEL_SIZE-1:0] image_4_row_0_pixel_data;
  logic [PIXEL_SIZE-1:0] image_4_row_1_pixel_data;
  face_image_buffer #(
    .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), .NUM_PIXELS(NUM_PIXELS), .POWER_MOD(POWER_MOD),
    .FILE_INIT_UPPER(`FPATH(joe_video_lecture_upper.mem)), .FILE_INIT_LOWER(`FPATH(joe_video_lecture_lower.mem))
  ) image_4_fib (
    .clk_in(clk_pixel),
    .upper_pixel_address(),
    .upper_pixel_data(),
    .upper_pixel_valid(),
    .lower_pixel_address(),
    .lower_pixel_data(),
    .lower_pixel_valid(),
    .row_0_pixel_address(row_0_pixel_address),
    .row_0_pixel_data(image_4_row_0_pixel_data),
    .row_0_data_valid(row_0_data_valid),
    .row_1_pixel_address(row_1_pixel_address),
    .row_1_pixel_data(image_4_row_1_pixel_data),  
    .row_1_data_valid(row_1_data_valid)
  );

  face_constructor #(
      .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), 
      .NUM_PIXELS(NUM_PIXELS), 
      .FACE_RES(FACE_RES), 
      .LOG_POWER_MOD(LOG_POWER_MOD)
  ) protogen_face_maker (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .face_data_valid(1),
      .left_eye_openness(display_left_eye_openness),
      .right_eye_openness(display_right_eye_openness),
      .mouth_openness(display_mouth_openness),
      .upper_pixel_address(upper_pixel_address),
      .upper_pixel_data(upper_pixel_data),
      .upper_pixel_valid(upper_pixel_valid),
      .lower_pixel_address(lower_pixel_address),
      .lower_pixel_data(lower_pixel_data),
      .lower_pixel_valid(lower_pixel_valid)
  );

  logic [ADDRESS_SIZE-1:0] upper_pixel_address;
  logic [PIXEL_SIZE-1:0] upper_pixel_data;
  logic upper_pixel_valid;
  logic [ADDRESS_SIZE-1:0] lower_pixel_address;
  logic [PIXEL_SIZE-1:0] lower_pixel_data;
  logic lower_pixel_valid;


  logic [PIXEL_SIZE-1:0] gen_image_row_0_pixel_data;
  logic [PIXEL_SIZE-1:0] gen_image_row_1_pixel_data;
  face_image_buffer #(
    .NUM_BLOCK_ROWS(NUM_BLOCK_ROWS), .NUM_PIXELS(NUM_PIXELS), .POWER_MOD(POWER_MOD),
    .FILE_INIT_UPPER(), .FILE_INIT_LOWER()
  ) proto_face_fib (
    .clk_in(clk_pixel),
    .upper_pixel_address(upper_pixel_address),
    .upper_pixel_data(upper_pixel_data),
    .upper_pixel_valid(upper_pixel_valid),
    .lower_pixel_address(lower_pixel_address),
    .lower_pixel_data(lower_pixel_data),
    .lower_pixel_valid(lower_pixel_valid),
    .row_0_pixel_address(row_0_pixel_address),
    .row_0_pixel_data(gen_image_row_0_pixel_data),
    .row_0_data_valid(row_0_data_valid),
    .row_1_pixel_address(row_1_pixel_address),
    .row_1_pixel_data(gen_image_row_1_pixel_data),  
    .row_1_data_valid(row_1_data_valid)
  );


  always_comb begin 
    case (sw)
      5'b00001: begin 
        row_0_pixel_data = image_0_row_0_pixel_data;
        row_1_pixel_data = image_0_row_1_pixel_data;
      end
      5'b00010: begin 
        row_0_pixel_data = image_1_row_0_pixel_data;
        row_1_pixel_data = image_1_row_1_pixel_data;

      end
      5'b00011: begin 
        row_0_pixel_data = image_2_row_0_pixel_data;
        row_1_pixel_data = image_2_row_1_pixel_data;

      end
      5'b00100: begin 
        row_0_pixel_data = image_3_row_0_pixel_data;
        row_1_pixel_data = image_3_row_1_pixel_data;
      end
      5'b00101: begin
        row_0_pixel_data = image_4_row_0_pixel_data;
        row_1_pixel_data = image_4_row_1_pixel_data;
      end

      default: begin 
        row_0_pixel_data = gen_image_row_0_pixel_data;
        row_1_pixel_data = gen_image_row_1_pixel_data;
      end
    endcase
  end

 
endmodule // top_level

// reset the default net type to wire, sometimes other code expects this.
`default_nettype wire