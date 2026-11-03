# SPI Controller with APB Interface

## Overview

This project implements an SPI (Serial Peripheral Interface) controller with an APB (Advanced Peripheral Bus) interface. The project demonstrating RTL design, digital interface concepts, and simulation-based verification.

The design integrates APB register access with SPI control, serial data transmission and reception, baud-rate generation, and slave-select control.

## Key Features

- APB-based register access
- SPI serial data transmission and reception
- Baud-rate generation
- Slave-select control
- Serial data shifting
- APB invalid-address error handling
- Testbench-based functional checks
- Simulation transcript and waveform evidence

## Design Architecture

The controller is organized into the following main RTL modules:

| Module | Purpose |
|---|---|
| `spi_interface` | Connects the design components through shared interface signals |
| `spi_apb_interface` | Handles APB transactions and SPI register access |
| `spi_baud_generator` | Generates SPI clock timing and related control signals |
| `spi_slave_select` | Controls the slave-select signal and transfer duration |
| `spi_shifter` | Handles serial data transmission and reception |
| `spi_top` | Integrates the controller modules |

The top-level testbench, `spi_top_tb.v`, connects to the controller through its APB and SPI ports.

Refer to the `docs/` directory for the design block diagram and top-level schematic.

## Tools and Technologies

- Verilog
- SystemVerilog
- ModelSim – Intel FPGA Starter Edition
- RTL simulation
- Waveform inspection and analysis

## Verification

The top-level testbench exercises APB register operations and SPI data transfer.

The demonstrated test includes:

- Writing and reading APB registers
- Checking invalid APB addresses `3'b100`, `3'b110`, and `3'b111`
- Transmitting `0xA5` through MOSI
- Receiving `0x3C` through MISO
- Comparing transmitted and received data
- Checking the slave-select signal
- Observing the SPI interrupt request

The available simulation transcript shows successful MOSI, MISO, and slave-select checks for the demonstrated transfer. The testbench also contains explicit checks for invalid-address errors; their pass status should be confirmed from the transcript.

See `results/transcript.png` and `results/waveform.png` for the available simulation evidence.

## Repository Structure

```text
SPI_GitHub/
├── docs/
│   ├── spi blocks.png
│   └── spi top.png
├── results/
│   ├── transcript.png
│   └── waveform.png
├── rtl/
│   ├── spi_interface.sv
│   ├── spi_apb_interface.sv
│   ├── spi_baud_generator.sv
│   ├── spi_slave_select.sv
│   ├── spi_shifter.sv
│   ├── spi_top.sv
│   ├── spi_apb_interface .v
│   ├── spi_baud_generator.v
│   ├── spi_slave_select.v
│   ├── spi_shifter.v
│   └── spi_top.v
├── tb/
│   └── spi_top_tb.v
└── README.md
```

The `rtl/` directory contains an interface-based SystemVerilog implementation and alternative Verilog-style implementations that use individual signals. Both sets are retained. Review the source files and their intended compilation set before running the project.

## Learning Outcomes

Through this project, I gained practical experience with:

- Integrating multiple RTL modules into a top-level design
- Understanding APB register transactions
- Implementing SPI serial data transmission and reception
- Developing a testbench for functional verification
- Checking data-transfer results
- Inspecting simulation waveforms and interpreting simulation output

## Acknowledgment

This project was developed in the context of VLSI design training at Maven Silicon. It is shared as a portfolio demonstration of my learning and practical work.

## Future Improvements

- Develop a SystemVerilog-based verification environment for the SPI controller.
- Add SystemVerilog Assertions (SVA) to verify protocol behavior, timing, and control-signal correctness.
- Improve functional coverage to track verification completeness.
- Extend verification to cover different SPI modes, baud-rate configurations, and corner cases.
