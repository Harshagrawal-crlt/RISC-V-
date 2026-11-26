<div align="center">

# 🔬 Custom RV32IM RISC-V Processor

### A fully synthesizable, pipelined RISC-V processor implementing the **RV32IM** ISA, designed in Verilog HDL and verified on **Xilinx Vivado 2026.1**

[![ISA](https://img.shields.io/badge/ISA-RV32IM-blue?style=for-the-badge&logo=riscv)](https://riscv.org/)
[![HDL](https://img.shields.io/badge/HDL-Verilog-orange?style=for-the-badge)](https://en.wikipedia.org/wiki/Verilog)
[![Simulator](https://img.shields.io/badge/Simulator-Vivado%20XSim-red?style=for-the-badge)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Target](https://img.shields.io/badge/Target-Xilinx%20Artix--7-green?style=for-the-badge)](https://www.xilinx.com/products/silicon-devices/fpga/artix-7.html)
[![Status](https://img.shields.io/badge/Status-Verified%20✓-brightgreen?style=for-the-badge)]()

</div>

---

## 📋 Table of Contents

- [About the Project](#-about-the-project)
- [Why RISC-V?](#-why-risc-v)
- [Architecture Overview](#-architecture-overview)
- [Module Breakdown](#-module-breakdown)
- [Supported Instructions](#-supported-instructions)
- [Project Structure](#-project-structure)
- [Simulation & Verification](#-simulation--verification)
- [Synthesis Results](#-synthesis-results)
- [Getting Started](#-getting-started)
- [How to Run Simulation](#-how-to-run-simulation)

---

## 🧠 About the Project

This project is a **custom, ground-up implementation** of a 32-bit RISC-V processor core supporting the **RV32IM** instruction set — the base integer ISA with the integer multiply/divide extension. Every hardware block was designed from scratch in **Verilog HDL** without using vendor IP cores, making this a true bare-metal processor design.

The design targets **FPGA deployment** on the Xilinx Artix-7 family and has been fully verified through directed behavioral simulation in Vivado XSim, proving correct operation across arithmetic, memory, branching, multi-cycle multiplication/division, and memory-mapped peripheral I/O.

### 🎯 Key Highlights

| Feature | Detail |
|---------|--------|
| **ISA** | RV32IM (Base Integer + Multiply/Divide Extension) |
| **Pipeline** | Custom 3-stage compressed pipeline |
| **Hazard Control** | Scoreboard-based liveness tracking |
| **Multiply/Divide** | Dedicated off-pipeline FSM accelerator |
| **Peripheral** | Memory-mapped UART TX (115200 baud) |
| **Bus Interface** | AXI4-Lite Master |
| **CSR Support** | `cycle` counter + `mepc` register |
| **Target FPGA** | Xilinx Artix-7 (xc7a35tcpg236-1) |
| **Toolchain** | Xilinx Vivado 2026.1 |
| **Simulation** | Vivado XSim — All 5 test vectors PASS |

---

## ❓ Why RISC-V?

RISC-V is an **open-standard, royalty-free ISA** that has rapidly become the de facto standard for academic processor design and is gaining major traction in industry (SiFive, Western Digital, NVIDIA, Google). Unlike proprietary ISAs (ARM, x86), RISC-V allows anyone to implement, study, modify, and manufacture processors without licensing fees.

For this project, RISC-V was chosen because:

- 📖 **Clean, orthogonal instruction encoding** — fixed bit positions for register fields make hardware decode logic elegant and efficient.
- 🔧 **Modular extension system** — start with the minimal `I` base and add `M` (multiply/divide) independently, cleanly separating design complexity.
- 🎓 **Industry-relevant** — the same ISA used in real products from RISC-V International member companies.
- 🔬 **Verifiable** — the open specification makes formal verification and test generation straightforward.
- 🌍 **Future-proof** — RISC-V is increasingly used in AI accelerators, embedded SoCs, and even server chips.

---

## 🏗 Architecture Overview

This processor implements a **custom 3-stage compressed pipeline** that collapses the classical 5-stage RISC pipeline (IF → ID → EX → MEM → WB) into three physical clock domains, reducing area while maintaining correct pipeline semantics.

```
┌─────────────────────────────────────────────────────────────────────┐
│                   RV32IM PROCESSOR PIPELINE                         │
│                                                                     │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │  STAGE 1 │    │   STAGE 2    │    │        STAGE 3           │  │
│  │          │    │              │    │                          │  │
│  │  FETCH   │───▶│ DECODE + EX  │───▶│  MEMORY + WRITE-BACK    │  │
│  │          │    │              │    │                          │  │
│  │ fetch.v  │    │  decode.v    │    │  riscv_core.v (top)     │  │
│  │          │    │  alu.v       │    │  reg_file.v             │  │
│  │          │    │  csr_unit.v  │    │  External Data Mem      │  │
│  └──────────┘    └──────────────┘    └──────────────────────────┘  │
│       │                 │                                           │
│  ┌────▼──────┐    ┌─────▼────────┐                                 │
│  │  Skid     │    │ mul_div_unit │  ◀── Off-pipeline accelerator   │
│  │  Buffer   │    │  (FSM)       │      (MUL: 3 cycles)            │
│  └───────────┘    └─────────────┘      (DIV: 34 cycles)            │
│                         │                                           │
│                   ┌─────▼────────┐                                 │
│                   │  scoreboard  │  ◀── Hazard detection            │
│                   │  (reg_busy)  │      & pipeline stalling         │
│                   └──────────────┘                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Pipeline Features

- **Stall Skid Buffer** — elastic 1-entry buffer between fetch and decode that correctly handles stall/flush without losing in-flight instructions.
- **Write-Through Bypass** — register file forwards write data to read ports in the same cycle, eliminating RAW hazards for all single-cycle instructions without a forwarding unit.
- **Scoreboard** — tracks registers locked by in-flight mul/div operations and stalls dependent instructions until results are available.
- **Branch Resolution** — branches are evaluated combinationally in the execute stage; a 1-cycle flush penalty is paid for taken branches using the skid buffer flush signal.
- **Decoupled Accelerator** — the multiply/divide unit operates independently of the main pipeline, writing back directly to the register file when done.

---

## 🔩 Module Breakdown

| Module | File | Description |
|--------|------|-------------|
| **Top-Level Core** | `riscv_core.v` | Instantiates and interconnects all submodules; contains write-back MUX and global stall logic |
| **Fetch Unit** | `fetch.v` | Program Counter with branch redirect and stall support |
| **Skid Buffer** | `stall_skid_buffer.v` | 1-entry elastic buffer; handles stall/flush between fetch and decode |
| **Decode Unit** | `decode.v` | Combinational instruction decoder; generates all control signals and sign-extended immediates |
| **Register File** | `reg_file.v` | 32×32-bit registers with write-through bypass; x0 hardwired to zero |
| **ALU** | `alu.v` | 10-operation combinational ALU (ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU) |
| **Multiply/Divide Unit** | `mul_div_unit.v` | 3-state FSM accelerator; full RV32M operation set with division-by-zero handling |
| **Scoreboard** | `scoreboard.v` | 32-bit register liveness tracker; generates `hazard_stall` for multi-cycle dependencies |
| **CSR Unit** | `csr_unit.v` | Control & Status Registers: 64-bit cycle counter + mepc; combinational reads |
| **UART TX** | `uart_tx.v` | Memory-mapped 115200-baud serial transmitter (8N1); 4-state FSM |
| **AXI4-Lite Master** | `axi_lite_master.v` | Standards-compliant AXI4-Lite bus master for SoC peripheral integration |

---

## 📟 Supported Instructions

### RV32I Base Integer Instructions

| Format | Instructions |
|--------|-------------|
| **R-type** | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU` |
| **I-type Arithmetic** | `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLTIU`, `SLLI`, `SRLI`, `SRAI` |
| **I-type Load** | `LW` |
| **S-type Store** | `SW` |
| **B-type Branch** | `BEQ`, `BNE` |
| **U-type** | `LUI`, `AUIPC` |
| **CSR** | `CSRRW` |

### RV32M Multiply/Divide Extension

| Instruction | Operation | Latency |
|-------------|-----------|---------|
| `MUL` | Lower 32 bits of product | 3 cycles |
| `MULH` | Upper 32 bits (signed × signed) | 3 cycles |
| `MULHSU` | Upper 32 bits (signed × unsigned) | 3 cycles |
| `MULHU` | Upper 32 bits (unsigned × unsigned) | 3 cycles |
| `DIV` | Signed integer division | 34 cycles |
| `DIVU` | Unsigned integer division | 34 cycles |
| `REM` | Signed remainder | 34 cycles |
| `REMU` | Unsigned remainder | 34 cycles |

> Division by zero is handled per RISC-V specification: `DIV` returns `0xFFFFFFFF`, `REM` returns the dividend unchanged.

---

## 📁 Project Structure

```
risc v/
├── 📄 risc v.xpr               ← Vivado project file (open this in Vivado)
├── 📄 .gitignore               ← Git ignore rules
├── 📄 README.md                ← This file
│
├── 📂 risc v.srcs/
│   ├── 📂 sources_1/new/       ← RTL Source Files
│   │   ├── riscv_core.v        ← Top-level processor integration
│   │   ├── fetch.v             ← Instruction Fetch / Program Counter
│   │   ├── stall_skid_buffer.v ← Elastic fetch-decode buffer
│   │   ├── decode.v            ← Instruction decoder & control unit
│   │   ├── reg_file.v          ← 32×32-bit register file
│   │   ├── alu.v               ← Arithmetic & Logic Unit
│   │   ├── mul_div_unit.v      ← Multi-cycle MUL/DIV accelerator
│   │   ├── scoreboard.v        ← Hazard detection & register liveness
│   │   ├── csr_unit.v          ← Control & Status Registers
│   │   ├── uart_tx.v           ← Memory-mapped UART transmitter
│   │   └── axi_lite_master.v   ← AXI4-Lite bus master interface
│   │
│   └── 📂 sim_1/new/           ← Simulation / Testbench Files
│       └── riscv_core_tb.v     ← Self-checking directed testbench
│
└── 📂 risc v.srcs/constrs_1/   ← Constraint files (XDC)
    └── ...
```

> **Note:** The `.cache/`, `.runs/`, `.sim/`, `.hw/`, `.ip_user_files/` directories are auto-generated by Vivado and are excluded from version control by `.gitignore`.

---

## ✅ Simulation & Verification

The testbench (`riscv_core_tb.v`) is a **self-checking directed test** that runs 5 test vectors covering all major hardware paths. Memory is modeled as a simple register array, and the UART peripheral is instantiated as a live sub-DUT.

### Test Vectors

| # | Test | Instructions Used | Expected | Validates |
|---|------|-------------------|----------|-----------|
| **TV1** | Multiply | `ADDI`, `MUL`, `SW` | `data_mem[0] = 50` | Multi-cycle MUL, scoreboard stall, write-back |
| **TV1b** | UART Output | `ADDI`, `SW` to `0x1000` | `uart_busy = 1` | Memory-mapped peripheral, ASCII transmit |
| **TV2** | Load & Subtract | `LW`, `SUB`, `SW` | `data_mem[1] = 45` | Load path, write-through bypass, R-type SUB |
| **TV3** | Hardware Division | `ADDI`, `DIV`, `SW` | `data_mem[2] = 10` | 34-cycle DIV, scoreboard lock/unlock |
| **TV4** | Branch Taken | `BEQ` (taken), skip block, `SW` | `data_mem[3] = 100` | Branch evaluation, pipeline flush, PC redirect |

### Simulation Output

```
[VIVADO SIMULATION START]
--------------------------------------------------
VERIFICATION REPORT:
Vector 1: MUL (5 * 10)       -> Data Mem [0] = 50  (Expected: 50)  [PASS]
Vector 2: LW & SUB (50 - 5)  -> Data Mem [1] = 45  (Expected: 45)  [PASS]
Vector 3: DIV (90 / 9)       -> Data Mem [2] = 10  (Expected: 10)  [PASS]
Vector 4: BEQ Branch Taken   -> Data Mem [3] = 100 (Expected: 100) [PASS]
Vector 5: Memory-Mapped UART -> Activity Flag= 1   (Expected: 1)   [PASS]
--------------------------------------------------
$finish called at time : 2020 ns
```

---

## 📊 Synthesis Results

Synthesized on **Xilinx Artix-7 (xc7a35tcpg236-1)** with Vivado default synthesis strategy.

```
Synthesis finished with 0 errors, 0 critical warnings.
synth_design completed successfully ✓
```

### Resource Utilization

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUT | ~4,588 | 20,800 | **22.1%** |
| Flip-Flops | 407 | 41,600 | **1.0%** |
| DSP48E1 | 10 | 90 | **11.1%** |
| RAM32M | 10 | — | — |
| BUFG | 1 | 32 | **3.1%** |

> The design uses only **22% of LUTs** on the Artix-7, leaving substantial headroom for additional peripherals, caches, or a second core.

### Module-Level Area

```
riscv_core (top)        5,261 cells total
├── mul_div_unit         3,267 cells  (10× DSP48E1 for multiplier tree)
├── stall_skid_buffer    1,577 cells
├── csr_unit               113 cells  (64-bit cycle counter)
├── fetch                   73 cells  (PC register + MUX)
├── scoreboard              36 cells  (32-bit reg_busy vector)
├── alu                     16 cells  (fully combinational)
└── reg_file                14 cells  (mapped to RAM32M primitives)
```

---

## 🚀 Getting Started

### Prerequisites

- [Xilinx Vivado Design Suite](https://www.xilinx.com/support/download.html) (2020.1 or later recommended)
- A Xilinx Artix-7 FPGA board (optional, for hardware deployment)
- Git (for version control)

### Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/riscv-processor.git
cd riscv-processor
```

### Open in Vivado

1. Launch **Vivado**.
2. Click **File → Open Project**.
3. Navigate to the cloned folder and select **`risc v.xpr`**.
4. Vivado will automatically find all source files from the `.srcs/` directory.

---

## 🎮 How to Run Simulation

### Method 1: Vivado GUI (Recommended)

1. Open the project in Vivado.
2. In the **Flow Navigator** (left panel), click **Run Simulation → Run Behavioral Simulation**.
3. The simulation will run to completion automatically (`run all` is pre-configured).
4. Check the **Tcl Console** at the bottom for the verification report output.

### Method 2: Vivado Tcl Console

Once simulation is open, type in the Tcl Console:

```tcl
run all
```

### Method 3: Command Line (XSim)

```bash
# Navigate to simulation directory
cd "risc v.sim/sim_1/behav/xsim"

# Compile
xvlog --incr --relax -prj riscv_core_tb_vlog.prj

# Elaborate
xelab --incr --debug typical --relax --mt 2 \
      -L xil_defaultlib --snapshot riscv_core_tb_behav \
      xil_defaultlib.riscv_core_tb xil_defaultlib.glbl

# Simulate (runs to $finish automatically)
xsim riscv_core_tb_behav -R
```

---

## 🔮 Future Improvements

- [ ] RV32C — Compressed 16-bit instruction support
- [ ] RV32F — Single-precision floating-point unit
- [ ] Hardware branch predictor (2-bit saturating counter)
- [ ] Pipelined multiplier (1-cycle MUL using DSP cascade)
- [ ] Direct-mapped instruction cache
- [ ] JTAG debug interface (RISC-V External Debug Spec)
- [ ] Physical implementation — place, route & timing closure
- [ ] Trap and exception handling (privileged architecture)

---

## 📚 References

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/) — Official unprivileged ISA spec
- [RISC-V Privileged Architecture](https://riscv.org/technical/specifications/) — CSR and trap handling
- [Xilinx Vivado Design Suite User Guide](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2021_1/ug910-vivado-getting-started.pdf)
- [Digital Design and Computer Architecture: RISC-V Edition](https://www.elsevier.com/books/digital-design-and-computer-architecture-risc-v-edition/harris/978-0-12-820064-3) — Harris & Harris

---

<div align="center">

**Built with ❤️ using Verilog HDL | Verified on Xilinx Vivado XSim**

*If this project helped you, consider giving it a ⭐ on GitHub!*

</div>
