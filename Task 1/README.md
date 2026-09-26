# Single-Cycle RV32I Processor Design (e-Yantra Logic Quest 2026-27)

Implementation and verification of a complete 32-bit single-cycle RISC-V (RV32I) processor core using Verilog HDL, targeted for Cyclone IV FPGAs and verified on Altera ModelSim.

---

## Overview

This repository contains the design, control logic, and datapath extensions implemented across Task 1B and Task 1C of the Logic Quest competition.

---

## Implemented Tasks

### Task 1B: Upper Immediate & Jump Architecture
* Target Instructions: `LUI`, `AUIPC`, `JALR`
* Core Additions:
  * Extended immediate generator (`imm_extend.v`) to support U-type (20-bit upper) format.
  * Added multiplexed ALU A-input selection for PC-relative operations (`AUIPC`).
  * Implemented indirect register jumping with LSB clearing for byte alignment (`JALR`).
  * Expanded writeback stage using a 4-to-1 multiplexer to route immediate values directly to destination registers (`LUI`).
  * Configured top-level `.qsf` constraints (`VIRTUAL_PIN`) to satisfy Cyclone IV FPGA I/O limits during full compilation.

### Task 1C: Complete RV32I Base Instruction Set
* Target Scope: Full implementation of Table B.1 RV32I specifications (38 verified instructions).
* Core Additions:
  * Branch Handling: Generalized branch evaluation to handle `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, and `BGEU` using signed and unsigned comparative evaluations.
  * Full ALU Execution: Expanded ALU control to 4 bits to support all shift and arithmetic operations: `SLL`/`SLLI`, `SRL`/`SRLI`, `SRA`/`SRAI`, `XOR`/`XORI`, and `SLTU`/`SLTIU`.
  * Sub-Word Memory Access: Integrated byte- and half-word load/store formatting (`LB`, `LBU`, `LH`, `LHU`, `LW`, `SB`, `SH`, `SW`) with sign/zero extension based on memory address offsets.

---

## Verification & Results

* Simulation Suite: Altera ModelSim (`tb_1b.v`, `tb_1c.v`)
* Synthesis & Fitting: Quartus Prime (Cyclone IV E)
* Results:
  * Task 1B: 15/15 checkpoints passed (`0 Faulty Instructions`)
  * Task 1C: 38/38 checkpoints passed (`0 Faulty Instructions`)
