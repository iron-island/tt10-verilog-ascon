# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# SPI command constants
WR_REG0_COMMAND    = 0b00000
WR_REG1_COMMAND    = 0b00001
WR_REG2_COMMAND    = 0b00010
WR_OP_MODE_COMMAND = 0b00011
RD_REG0_COMMAND    = 0b10000
RD_REG1_COMMAND    = 0b10001
RD_REG2_COMMAND    = 0b10010
RD_OP_MODE_COMMAND = 0b10011
RD_S_0_COMMAND     = 0b10100
RD_S_1_COMMAND     = 0b10101
RD_S_2_COMMAND     = 0b10110
RD_S_3_COMMAND     = 0b10111
RD_S_4_COMMAND     = 0b11000

def get_reg_bit(reg, bit):
    # return reg[bit]
    return (reg >> bit) & 1

def update_bit(signal, bitval, bitstart, bitend=None):
    '''
    Wrapper function for updating bits/slices via a read-modify-write sequence
    Ref: https://github.com/cocotb/cocotb/issues/4274#issuecomment-2537077592
    '''
    temp = signal
    if (bitend == None):
        temp[bitstart] = bitval
    else:
        temp[bitstart:bitend] = bitval

    return temp

#async def spi_write_command(dut, command):
#
#    # Drive SCK low and CSB low
#    dut.uio_in.value = 0b00000000
#
#    # Wait for 1 clock cycle delay
#    await ClockCycles(dut.clk, 1)
#    temp = dut.uio_in.value
#
#    # Drive command code
#    for bit in range(4, -1, -1):
#        # Drive MOSI
#        dut.uio_in.value = update_bit(temp, get_reg_bit(command, bit), 1)
#
#        # Wait for 1 clock cycle delay
#        await ClockCycles(dut.clk, 1)
#
#        # Drive SCK posedge
#        dut.uio_in.value = update_bit(dut.uio_in.value, 1, 3)
#
#        # Wait for 1 clock cycle delay
#        await ClockCycles(dut.clk, 1)
#
#        # Drive SCK negedge
#        temp = update_bit(dut.uio_in.value, 0, 3)
#
#    dut.uio_in.value = temp

async def spi_write(dut, command, data, add_cycles=0):
    # Print to log
    dut._log.info(f'SPI write: command={command:>05b}, data = {hex(data)}')

    # Drive SCK low and CSB low
    dut.uio_in.value = 0b00000000

    # Wait for 1 clock cycle delay
    await ClockCycles(dut.clk, 1)
    temp = dut.uio_in.value

    # Drive MOSI for command
    for bit in range(4, -1, -1):
        # Drive MOSI
        dut.uio_in.value = update_bit(temp, get_reg_bit(command, bit), 1)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK posedge
        dut.uio_in.value = update_bit(dut.uio_in.value, 1, 3)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK negedge
        temp = update_bit(dut.uio_in.value, 0, 3)

    # Drive MOSI for data
    for bit in range(127, -1, -1):
        # Drive MOSI
        dut.uio_in.value = update_bit(temp, get_reg_bit(data, bit), 1)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK posedge
        dut.uio_in.value = update_bit(dut.uio_in.value, 1, 3)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK negedge
        temp = update_bit(dut.uio_in.value, 0, 3)

    dut.uio_in.value = temp

    # Wait for 1 clock cycle delay
    await ClockCycles(dut.clk, 1)

    # Drive CSB high
    dut.uio_in.value = update_bit(dut.uio_in.value, 1, 0)

    # Wait for 1+add_cycles clock cycle delay
    await ClockCycles(dut.clk, 1+add_cycles)

async def spi_read(dut, command, add_cycles=0):
    # Print to log
    dut._log.info(f'SPI read: command={command:>05b}')

    # Drive SCK low and CSB low
    dut.uio_in.value = 0b00000000

    # Wait for 1 clock cycle delay
    await ClockCycles(dut.clk, 1)
    temp = dut.uio_in.value

    # Drive MOSI for command
    for bit in range(4, -1, -1):
        # Drive MOSI
        dut.uio_in.value = update_bit(temp, get_reg_bit(command, bit), 1)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK posedge
        dut.uio_in.value = update_bit(dut.uio_in.value, 1, 3)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK negedge
        temp = update_bit(dut.uio_in.value, 0, 3)

    # Drive SCK for 128 cycles for reading
    for bit in range(127, -1, -1):
        # Drive uio_in with temp
        dut.uio_in.value = temp

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK posedge
        dut.uio_in.value = update_bit(dut.uio_in.value, 1, 3)

        # Wait for 1 clock cycle delay
        await ClockCycles(dut.clk, 1)

        # Drive SCK negedge
        temp = update_bit(dut.uio_in.value, 0, 3)

    dut.uio_in.value = temp

    # Wait for 1 clock cycle delay
    await ClockCycles(dut.clk, 1)

    # Drive CSB high
    dut.uio_in.value = update_bit(dut.uio_in.value, 1, 0)

    # Wait for 1+add_cycles clock cycle delay
    await ClockCycles(dut.clk, 1+add_cycles)

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.uio_in.value = 0b00000001;

    # Unused inputs
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    #--------------------------#
    # SPI Writing to Registers #
    #--------------------------#

    await spi_write(dut, WR_REG1_COMMAND, 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f, 10)

    #----------------------------#
    # SPI Reading from Registers #
    #----------------------------#

    await spi_read(dut, RD_REG1_COMMAND)

    # Wait for 10 arbitrary clock cycles to see the output values
    await ClockCycles(dut.clk, 10)

    # TODO: add checkers
    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    #assert dut.uo_out.value == 50

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
