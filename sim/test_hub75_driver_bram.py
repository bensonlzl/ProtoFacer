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


    await ClockCycles(dut.clk_in,1000000)


    
                


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "hub75_driver_bram.sv"]
    sources += [proj_path / "hdl" / "pwm.sv"]
    sources += [proj_path / "hdl" / "fixed_proto_face.sv"]
    sources += [proj_path / "hdl" / "evt_counter_wrap.sv"]
    sources += [proj_path / "hdl" / "counter_with_out_and_tick.sv"]
    build_test_args = ["-Wall"]
    parameters = {"NUM_PIXELS":128,"NUM_BLOCK_ROWS":16,"POWER_MOD":16}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="hub75_driver_bram",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="hub75_driver_bram",
        test_module="test_hub75_driver_bram",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

