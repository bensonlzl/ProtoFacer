`default_nettype none

module line_buffer (
            input wire clk_in, //system clock
            input wire rst_in, //system reset

            input wire [10:0] hcount_in, //current hcount being read
            input wire [9:0] vcount_in, //current vcount being read
            input wire [8-1:0] pixel_data_in, //incoming pixel
            input wire data_valid_in, //incoming  valid data signal

            output logic [KERNEL_SIZE-1:0][8-1:0] line_buffer_out, //output pixels of data
            output logic [10:0] hcount_out, //current hcount being read
            output logic [9:0] vcount_out, //current vcount being read
            output logic data_valid_out //valid data out signal
  );
  parameter HRES = 1280;
  parameter VRES = 720;

  // parameter HRES = 10; // TESTING ONLY 
  // parameter VRES = 7; // TESTING ONLY 

  localparam KERNEL_SIZE = 3;
  localparam KERNEL_OFFSET = KERNEL_SIZE / 2 + 1; // distance from what is currently being read to where the middle of the kernel is
  localparam KERNEL_LOG = $clog2(KERNEL_SIZE + 1) + 1;

  // to help you get started, here's a bram instantiation.
  // you'll want to create one BRAM for each row in the kernel, plus one more to
  // buffer incoming data from the wire:

  logic [KERNEL_SIZE:0] write_line_enable;

  logic [1:0][10:0] hcount_output_buffer ;
  logic [9:0] kernel_mid_vcount;
  logic [1:0][9:0] vcount_output_buffer ;
  logic [1:0] data_valid_out_buffer  ;

  // pipelining outputs
  assign hcount_out = hcount_output_buffer[1];
  assign vcount_out = vcount_output_buffer[1];
  assign data_valid_out = data_valid_out_buffer[1];


  logic [KERNEL_SIZE:0][8-1:0] line_buffer_output ;
  logic [KERNEL_SIZE-1:0][KERNEL_LOG-1:0] line_index ;  

  

  generate
    genvar i;
    for (i=0; i <KERNEL_SIZE+1; i=i+1) begin 
      xilinx_true_dual_port_read_first_1_clock_ram #(
      .RAM_WIDTH(8),
      .RAM_DEPTH(HRES),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")) line_buffer_ram (
      .clka(clk_in),     // Clock
      //writing port:
      .addra(hcount_in),   // Port A address bus,
      .dina(pixel_data_in),     // Port A RAM input data
      .wea((write_line_enable[i]) && data_valid_in),       // Port A write enable, only update if its the right line to update and the data is good
      //reading port:
      .addrb(hcount_in),   // Port B address bus,
      .doutb(line_buffer_output[i]),    // Port B RAM output data,
      .douta(),   // Port A RAM output data, width determined from RAM_WIDTH
      .dinb(0),     // Port B RAM input data, width determined from RAM_WIDTH
      .web(1'b0),       // Port B write enable
      .ena(1'b1),       // Port A RAM Enable
      .enb(1'b1),       // Port B RAM Enable,
      .rsta(1'b0),     // Port A output reset
      .rstb(1'b0),     // Port B output reset
      .regcea(1'b1), // Port A output register enable
      .regceb(1'b1) // Port B output register enable
    );
    end
  endgenerate
  
  always_ff @(posedge clk_in) begin 
    if (rst_in) begin 
      write_line_enable <= 1; // start by writing into bram[0]
      hcount_output_buffer[1] <= 0;
      hcount_output_buffer[0] <= 0;
      vcount_output_buffer[1] <= 0;
      vcount_output_buffer[0] <= 0;
      data_valid_out_buffer[1] <= 0;
      data_valid_out_buffer[0] <= 0;

    end else begin

      hcount_output_buffer[1] <= hcount_output_buffer[0]; // pipelineing the hcount
      hcount_output_buffer[0] <= hcount_in; // pipelineing the hcount
      vcount_output_buffer[1] <= vcount_output_buffer[0]; // pipelineing the vcount
      // vcount_output_buffer[0] <= kernel_mid_vcount; // pipelineing the vcount
      vcount_output_buffer[0] <= (vcount_in >= KERNEL_OFFSET ? vcount_in - KERNEL_OFFSET : (vcount_in + VRES) - KERNEL_OFFSET); // pipelineing the vcount
      data_valid_out_buffer[1] <= data_valid_out_buffer[0]; // pipelineing the data valid
      data_valid_out_buffer[0] <= data_valid_in; // pipelineing the data valid

      if (data_valid_in) begin 
        if (hcount_in + 1 == HRES) begin  // we have reached the end of the line, move to the next line
          write_line_enable <= {write_line_enable[KERNEL_SIZE-1:0], write_line_enable[KERNEL_SIZE]}; // shift to the next line
        end
      end
    end
  end

  always_comb begin 
    case (write_line_enable)
      4'b0001: begin 
        line_buffer_out[0] = line_buffer_output[1];
        line_buffer_out[1] = line_buffer_output[2];
        line_buffer_out[2] = line_buffer_output[3];
      end
      4'b0010: begin 
        line_buffer_out[0] = line_buffer_output[2];
        line_buffer_out[1] = line_buffer_output[3];
        line_buffer_out[2] = line_buffer_output[0];
      end
      4'b0100: begin 
        line_buffer_out[0] = line_buffer_output[3];
        line_buffer_out[1] = line_buffer_output[0];
        line_buffer_out[2] = line_buffer_output[1];
      end
      4'b1000: begin 
        line_buffer_out[0] = line_buffer_output[0];
        line_buffer_out[1] = line_buffer_output[1];
        line_buffer_out[2] = line_buffer_output[2];
      end
    endcase
  end 


endmodule


`default_nettype wire

