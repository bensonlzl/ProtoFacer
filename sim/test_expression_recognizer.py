import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

START_ROW = 0x10
END_ROW = 0x50
START_COLUMN = 0x30
END_COLUMN = 0x80

@cocotb.test()
async def test_eye_finder(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)

    dut.start_search.value = 1

    await ClockCycles(dut.clk_in, 1)
    dut.start_search.value = 0


    for i in range(10000):
        dut.eye_pixel_value.value = random.randint(0,50)
        await ClockCycles(dut.clk_in, 1)

    # for i in range(1000):
    #     dut.eye_pixel_value.value = random.randint(150,250)
    #     await ClockCycles(dut.clk_in, 1)

    # for i in range(10000):
    #     dut.eye_pixel_value.value = random.randint(0,255)
    #     await ClockCycles(dut.clk_in, 1)








        

def spi_con_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "expression_recognizer.sv"]
    sources += [proj_path / "hdl" / "eye_finder.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="expression_recognizer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="expression_recognizer",
        test_module="test_expression_recognizer",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    spi_con_runner()
