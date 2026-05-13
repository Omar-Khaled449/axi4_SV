# SystemVerilog Verification for AXI4 Memory-Mapped Slave

## Overview
[cite_start]This directory contains a Coverage-Driven Verification (CDV) environment built entirely in SystemVerilog[cite: 278]. [cite_start]It verifies an AXI4-compliant slave interface and an internal 4KB RAM[cite: 169, 173].

## Methodology
* [cite_start]**Constrained Randomization:** Generates valid and edge-case AXI4 stimulus (e.g., varying burst lengths, addressing) to stress 4KB boundary limits[cite: 285, 286].
* [cite_start]**Interfaces & Modports:** Ensures clean signal routing and access management between the testbench components and the DUT[cite: 288, 289].
* [cite_start]**Assertion-Based Verification:** Concurrent SystemVerilog Assertions (SVA) monitor strict compliance with the AXI4 `VALID`/`READY` handshake protocol across all five channels[cite: 294, 295].

## Verification Goals
The SV environment targets 100% closure across sign-off metrics:
* [cite_start]**Functional Coverage:** Covering all protocol features, including burst lengths, data sizes, and address regions[cite: 290, 292].
* [cite_start]**Code Coverage:** Ensuring maximum execution across line, toggle, branch, and condition metrics[cite: 298, 313].
* [cite_start]**Assertion Coverage:** Validating all protocol rules[cite: 299].
