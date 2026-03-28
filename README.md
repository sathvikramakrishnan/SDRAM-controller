# SDRAM Controller (Verilog HDL implementation)

## Overview
Synthesizable SDRAM controller in Verilog based on the **Micron 16Mb x 4 SDRAM** specification.  
Supports read/write operations, refresh, and power down mode.

## Features
- Single & burst read/write operations
- Periodic auto-refresh
- Power-down mode  
- FSM-based control logic to sequence different operations

## Architecture
- **Init**: PRECHARGE -> AUTO REFRESH -> MODE REGISTER LOAD  
- **Read/Write**: Handles CAS latency and burst transfers  
- **Refresh**: Periodic auto-refresh logic and self-refresh logic in power-down mode  

## SDRAM Model
Includes `sdram_model.v` (Micron behavioral model) for:
- Functional verification  
- Timing violation detection  

## Simulation
Tools: Icarus Verilog + GTKWave 

```bash
iverilog -I config/ -o out src/* tb_sdram_top.v sdram_top.v
vvp out
gtkwave sdram_top.vcd
```

## Synthesis
Tool: Yosys
RTL -> Gate-level netlist  
Post-synthesis verification done

```bash
yosys -s synth.ys > results/synth_top.txt
iverilog -o gls_sim netlist.v tb_sdram_top.v src/sdram_model.v /usr/share/yosys/simlib.v
vvp gls_sim
gtkwave sdram_top.vcd
```
