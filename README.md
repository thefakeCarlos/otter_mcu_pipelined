# Pipelined RISC-V OTTER MCU

A 5-stage pipelined implementation of the [OTTER](https://github.com/jmconno/OTTER) (Open Tools for Teaching Embedded RISC-V) MCU, written in SystemVerilog and targeting the Basys3 FPGA. Supports the RV32I base integer instruction set.

**Authors:** Carlos Diaz, Nathan Hernandez
**Course:** CPE 333 — Cal Poly San Luis Obispo

## Architecture

Classic 5-stage RISC pipeline:

```
IF  →  ID  →  EX  →  MEM  →  WB
```

| Stage | Responsibilities |
|-------|------------------|
| **IF** (Instruction Fetch) | PC register, BRAM instruction memory, next-PC selection |
| **ID** (Decode) | Control decoder, immediate generator, register file read, hazard detection |
| **EX** (Execute) | ALU, branch address generation (BAG), branch condition (BCG), branch decision, forwarding muxes |
| **MEM** (Memory) | Data memory / MMIO access |
| **WB** (Write-Back) | Register file write |

### Hazard handling

- **Data hazards:** Resolved via a 3-input forwarding unit (forwardA, forwardB) bypassing EX/MEM and MEM/WB stages back into EX. A separate `forwardC` path handles WB→MEM forwarding for store data.
- **Load-use hazards:** Detected combinationally in ID; insert a 1-cycle stall by freezing PC and IF/ID, while injecting a bubble into ID/EX.
- **Control hazards:** Branches and jumps resolve in EX. A 2-cycle bubble (via `flush` + `hold_flush`) kills speculatively-fetched instructions while the BRAM instruction memory catches up to the redirected PC.

### Memory map

| Address | Region |
|---------|--------|
| `0x00000000 – 0x0000FFFF` | BRAM (instructions + data) |
| `0x11000000` | Switches (read) |
| `0x11080000` | LEDs (write) |
| `0x110C0000` | 7-segment display (write) |

## File overview

| File | Description |
|------|-------------|
| `otter_mcu_pipeline_template_v2.sv` | Top-level pipelined CPU |
| `OTTER_Wrapper_v1_02.sv` | Board-level wrapper (clocks, IO, debouncers) |
| `otter_memory_v1_07.sv` | Dual-port BRAM with MMIO |
| `PC.sv`, `PC_REG.sv`, `PC_MUX.sv` | Program counter + next-PC mux |
| `REG_FILE.sv` | 32×32 register file (negedge write) |
| `ALU.sv` | Arithmetic/logic unit |
| `CU_DCDR.sv` | Main control decoder |
| `CU_BRANCH_DCDR.sv` | Branch condition decoder |
| `BAG.sv` | Branch address generator |
| `BCG.sv` | Branch condition generator |
| `ImmediateGenerator.sv` | Sign-extends immediates for all instruction formats |
| `HAZARD_DETECTION.sv` | Load-use hazard detector |
| `FORWARDING_UNIT.sv` | Data-hazard forwarding controller |
| `TwoMux.sv`, `FourMux.sv` | Generic muxes |
| `otter_tb.sv` | Testbench |
| `dump.mem` | Instruction memory image (RV32I test program) |

## Build & simulate

1. Set `otter_tb.sv` as the simulation top
2. Run **Behavioral Simulation**
3. Watch `leds`, `segs`, and `IOBUS_*` to verify each test passes

The test program (`test_all`) exercises every RV32I instruction across ~24 sub-tests. On success, the 7-segment display increments through each test number (`0` → `1` → `2` …). On failure, the display shows `-1`. The LED bargraph tracks per-test progress within each instruction's sub-tests.



## Known design choices

- **BRAM with 1-cycle data latency:** The data memory output (`MEM_DOUT2`) is registered inside the BRAM, so the WB stage reads the live `mem_data` rather than a separately registered copy — matches the Xilinx Block RAM read pattern.
- **Register file writes on negedge:** Allows same-cycle write-then-read on the next posedge, reducing forwarding pressure.
- **`hold_flush` for back-to-back redirects:** Because BRAM has a 1-cycle output delay, the instruction fetched the cycle *after* a branch redirect is still stale. `hold_flush` extends the bubble one extra cycle so this stale instruction never reaches EX.
- **Selective bubble:** On flush/stall, only `opcode`, `regWrite`, and `memWrite` are zeroed in the ID/EX register. Other fields (rs1, rs2, etc.) pass through, which is harmless because the zeroed control bits suppress all side effects.

## License

Educational use. Built on the OTTER framework by Cal Poly CPE faculty.
