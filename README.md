# e-Yantra Robotics Competition 2026-27: Logic Quest

Logic Quest is the FPGA theme of eYRC 2026-27. The robot has no microcontroller. Its brain is an FPGA (Terasic DE0-Nano, Intel Cyclone IV E `EP4CE22F17C6`), and on that FPGA runs hardware we designed ourselves: a **RISC-V processor** that executes a **C program we wrote**, alongside an SPI master and a PWM generator.

This repository holds our Stage 1 work for **Task 2 and Task 3**. Here we built a 5-stage pipelined RV32I CPU in Verilog, wrote a C program that decrypts PRESENT-80 codes and plans shortest paths on the arena, compiled it with GCC for our CPU, and ran it on our own hardware in simulation.

```
 Path_Planner_Dec.c ──► riscv64-unknown-elf-gcc ──► program.hex ──► our pipelined RV32I CPU (Verilog)
   (Task 3A)              -march=rv32i -Os           machine code      runs it, writes the path
                                                                        to memory-mapped I/O (Task 3B)
```

## Results

| Task | What | Result |
|---|---|---|
| 2A | SPI master (Mode 0, MSB first, parameterised timing) | All transfers pass; 47 LEs, 36 registers |
| 2B | 5-stage pipelined RV32I CPU with hazard unit | All 38 instruction checks pass; 1,195 LEs, 342 registers |
| 3A | C program: PRESENT-80 decryption + shortest path | 49.35 / 50; uses only 31 bytes of data memory |
| 3B | Task 3A program running on our Task 2B CPU | 29.80 / 30 (the maximum possible); 1,280 LEs, 347 registers |

## Repository layout

```
Task_2/
  Task_2A/t2a_spi/               SPI master (code/t2a_spi.v)
  Task_2B/pl_riscv_cpu/          5-stage pipelined RISC-V CPU
Task_3/
  Task_3A/code/                  C program (c_programs/Path_Planner_Dec.c) + program.hex
  Task_3B/task3b_pl_riscv_cpu/   The CPU running our C program
```

Each folder is a complete Quartus Prime Lite 20.1 project. It includes the ModelSim transcript (`simulation/modelsim/msim_transcript`) and the synthesis summary (`output_files/*.map.summary`).

---

## Task 2A: SPI master

The bot's peripherals (nRF24L01 radio, RC522 RFID reader) are SPI slaves, so the FPGA must be the SPI master.

- 8-bit transfers, **Mode 0** (SCLK idles low, sample on rising edge, change on falling edge), MSB first.
- Cycle-exact timing set by the `HALF_PERIOD` parameter: SCLK = 50 MHz / (2 × HALF_PERIOD). The first rising edge comes at cycle H+1 and the transfer ends at cycle 16H+1.
- Counter widths come from `$clog2`, so any `HALF_PERIOD` works. `cs_out` and `busy` are set in the same branch, so they are always exact mirror images. Received bits go into a separate shift register, so `rx_data` changes only when the transfer ends.

## Task 2B: 5-stage pipelined RV32I CPU

We started from our single-cycle RV32I CPU (Task 1: all 37 base instructions, including LUI/AUIPC/JALR, all six branches, and byte/half-word loads and stores) and pipelined it:

```
 IF ──► IF/ID ──► ID ──► ID/EX ──► EX ──► EX/MEM ──► MEM ──► MEM/WB ──► WB
                   ▲                 ▲  forwarding: ALUResultM, ResultW, ResultW_d
                   └── hazard unit: stall on load-use, flush on taken branch/jump
```

- **Data hazards:** a 4-way forwarding mux on each ALU operand (register file / MEM / WB / WB+1), guarded by `RegWrite` and `Rd != x0`. The newest result wins.
- **Load-use hazards:** stall IF and ID for one cycle and insert a bubble in EX.
- **Control hazards:** branches and jumps are resolved in EX. A taken branch flushes IF/ID (to a NOP) and ID/EX, costing 2 cycles ("predict not taken").
- **Block RAM everywhere.** All three memories (instruction, data, register file) use synchronous reads, so Quartus maps them to M9K blocks instead of flip-flops. The instruction memory is addressed with the *next* PC, so its output register always holds the current instruction. The register file reads on the same edge it writes, so we added a WB+1 forwarding path. Result: **7,213 → 1,195 logic elements** and **3,104 → 342 registers** compared with our single-cycle design.
- **Other area savings:** a narrow PC; PC+4 recomputed in WB instead of being pipelined; branch decisions taken from the ALU's subtraction flags (zero / lt / ltu); one shared barrel shifter for SLL, SRL and SRA.

## Task 3A: our own C program for our own CPU

`Task_3/Task_3A/code/c_programs/Path_Planner_Dec.c` runs once per move of the bot:

1. It reads its inputs from **memory-mapped addresses** (`0x02000000` onwards): the current node, the next node or an encrypted code, and a flag.
2. It **decrypts** the 64-bit code with **PRESENT-80**: 31 rounds of inverse permutation and inverse S-box, with the key schedule run forward to K32 and then backwards. The result gives a message, a drop node, the next pick-up node and a done flag.
3. It **plans the shortest path** on the 36-node arena and writes it node by node to `NODE_POINT`.
4. If more moves follow, it writes the next move's inputs back into data memory, so the program can plan "drop node → next pick-up" after the CPU is reset.

The same file compiles with `gcc` on a PC (for testing) and with `riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -flto` for our CPU. The CPU constraints shaped the code:

| Constraint | How we handled it |
|---|---|
| RV32I has no multiply/divide | Only shifts and masks, e.g. PRESENT's permutation `16i mod 63` = `((i & 3) << 4) \| (i >> 2)` |
| Harvard CPU: loads cannot read instruction memory | No const tables or strings. The S-boxes are packed into 32-bit immediates (`0xDA09B65C`, `0x21748FE3`), and the arena graph is encoded as function-call arguments (code, not data) |
| Only 512 bytes of RAM, and RAM use was scored | No distance tables. The arena is three routes between N5 and N14 plus hanging trees, so the next step is computed from each node's route and offset (checked against Dijkstra on all 1,296 start/goal pairs). Planner state is packed into one `uint64_t` that lives in registers `a0/a1`, and the code is decrypted twice instead of keeping it alive across calls. |
| Memory-mapped I/O | Every I/O address is accessed through a `volatile` pointer, so the repeated writes to `NODE_POINT` really happen |

Final build: **2,968 bytes** of code (of 4,096), **0 bytes** of initialised data, **31 bytes** of RAM used (data memory scored 9.35 / 10).

Run it on a PC (from `code/c_programs`, in Ubuntu/WSL):

```bash
bash c_simulator.sh -f Path_Planner_Dec.c -c 35 -n 7 -e 0                  # path 35 30 13 14 15 7 (weight 59)
bash c_simulator.sh -f Path_Planner_Dec.c -c 7 -n E3399C2AAF0E5CA0 -e 1   # Message : HELLO, path 7 → 26
bash test.sh                                                               # 8/8 cases passed
bash generatehex.sh                                                        # writes ../program.hex for the CPU
```

## Task 3B: running our C program on our pipelined CPU

The Task 3A `program.hex` is loaded into the instruction memory of our Task 2B CPU with `$readmemh`. The testbench writes the inputs into data memory while the CPU is held in reset, then checks every node written to `NODE_POINT`, the message, and the next-move inputs. It then **resets the CPU mid-run three times** (32, 33 and 34 cycles after `CPU_DONE`) and checks the next move.

Changes made for this:
- **Data memory:** 128 words, built as four 8-bit lanes with byte enables for `sb`/`sh`/`sw`, with `lb`/`lh`/`lbu`/`lhu` formatting after the RAM read register. A simulation-only word copy (`// synthesis translate_off`) lets the testbench read `uut.datamem.data_ram`.
- **Reset:** clears every pipeline register (IF/ID gets a NOP), sends the PC to 0, and blocks memory writes, so no stale instruction can run again after a reset.
- **Instruction memory:** 1,024 words with a 12-bit PC.

Before submitting, we also checked the CPU against a reference instruction-set simulator on 600 random instruction programs and 88 whole-program runs, comparing every store.

Simulate: open `Task_3/Task_3B/task3b_pl_riscv_cpu/pl_riscv_cpu.qpf` in Quartus Prime Lite 20.1, run Analysis & Synthesis, then Tools → Run Simulation Tool → RTL Simulation. The transcript ends with `No errors encountered, congratulations!`.

## Tools

Quartus Prime Lite 20.1.1 · ModelSim Intel FPGA Edition 2020.1 · Ubuntu 22.04 on WSL · `gcc-riscv64-unknown-elf` 10.2.0 · picolibc

## Acknowledgement

Task boilerplates and testbenches are from [e-Yantra, IIT Bombay](https://github.com/eYantra-Robotics-Competition/eYRC_26-27_Logic-Quest). The CPU structure follows Harris & Harris, *Digital Design and Computer Architecture: RISC-V Edition*.
