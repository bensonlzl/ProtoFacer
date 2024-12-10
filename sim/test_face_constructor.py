import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


@cocotb.test()
async def test_driver_output(dut):
    """cocotb test for image_sprite"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.face_data_valid.value = 1;
    dut.left_eye_openness.value = 5;
    dut.right_eye_openness.value = 2;
    dut.mouth_openness.value = 0;
    await ClockCycles(dut.clk_in,1)
    dut.face_data_valid.value = 0;


    await ClockCycles(dut.clk_in,10000)


    
                


def is_runner():
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "face_constructor.sv"]
    sources += [proj_path / "hdl" / "eye_constructor.sv"]
    sources += [proj_path / "hdl" / "mouth_constructor.sv"]
    sources += [proj_path / "hdl" / "counter_with_out_and_tick.sv"]
    sources += [proj_path / "hdl" / "evt_counter_wrap.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    parameters = {"NUM_PIXELS":128,"NUM_BLOCK_ROWS":16,"LOG_POWER_MOD":4}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="face_constructor",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="face_constructor",
        test_module="test_face_constructor",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

