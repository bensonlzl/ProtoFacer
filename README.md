# ProtoFacer (MIT 6.2050/6.111 Digital Systems Laboratory Fall 2024 Final Project)

This repository contains the files used for the ProtoFacer.

## File structure

- `data` contains the memory files used by the project, including the OV5640 rom file and static Face Image Buffers (FIB) used.
- `hdl` contains all critical SystemVerilog (`.sv`) files used in the project.
- `image_gen` contains the Python script used to generate static FIBS.
- `ip` contains the Xilinx IPs used in the project.
- `misc` contains the Python script used to receive images from the FPGA over USB, as well as the final report.
- `sim` contains the testbenches used to verify some of the modules used in the project.
- `xdc` contains the Cmod A7-35T xdc file, which indicates which pins correspond to which inputs to the top level module.
- `build.tcl` is the Vivado build file used in the project.