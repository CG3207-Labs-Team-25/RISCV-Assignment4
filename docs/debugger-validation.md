# Debugger validation

The user reran all 16 behavioral test tops successfully in Vivado 2023.2 after the renderer timing repair. Wrapper synthesis completed with zero errors and zero critical warnings, and its functional netlist simulation passed for all four DIP selections. The repaired full TOP build completed at 15:26 on November 1, 2026, generated a bitstream, and passed final setup and hold checks. After connecting and discussing the OLED debugger, the user reported that it all works and accepted the result. Individual physical checklist observations were not supplied.

## Local results

The full local suite passed with Icarus Verilog:

- Predictor unit tests and CPU branch prediction tests.
- Button debounce, CPU stepping, pipeline state, flush capture, and snapshot transfer.
- OLED rendering and the integrated demo for all four DIP selections.
- The port-only post-synthesis testbench, exercised against RTL.
- Original pipeline tests: 40 programs and 202 checks.
- Original CPU multicycle tests: 226 programs and 452 retirements.
- Basic functionality: 22 checks; assigned instructions; original FPGA demo: 195 checks; load/store: 30 checks.
- Standalone multicycle: 1534 checks; 32-bit RTL evaluation: 1686 checks.

GHDL syntax analysis passed for the VHDL board top and existing peripheral files. It also accepted the board top under VHDL-93. The user's full TOP build confirmed mixed-language binding. Tcl parsing alone did not detect Vivado's XDC restriction on conditional commands.

After the timing repair, all 16 local test tops passed again. All four existing screen captures matched the previous PPM files byte for byte, including the integrated loop-exit event. The display test also checks pixel order, frame stability, and reset while pixels are in flight.

## First full-board build and timing repair

The routed timing report dated November 1, 2026 reported setup WNS of -1.629 ns, TNS of -5.285 ns, and 21 failing endpoints in the 100 MHz display clock domain. The worst path ran from PipelineDisplay1/FramePage_reg[0] to PmodOLEDrgb_bitmap1/datin_dly_reg[10], with 11.659 ns data delay against a 10 ns requirement. The 25 MHz CPU domain passed setup timing with 12.945 ns worst slack. Hold timing passed in both domains.

The renderer now registers line selection, character selection, and pixel output separately. Coordinates, colors, and write validity travel with each pixel. It drains the output pipeline before accepting another frame snapshot. The visible layout and CPU stepping behavior are unchanged. The final routed timing summary supplied by the user at 15:27:43 reports WNS +1.409 ns, WHS +0.018 ns, zero total setup/hold violations, and zero failing endpoints across 17,068 timed endpoints. The clocks are 100 MHz for the display and 25 MHz for the CPU. CPU setup slack is +13.275 ns; both directions between the two clocks also pass setup and hold.

Vivado also rejected the conditional commands in debugger.xdc. The file now uses declarative commands to constrain only first-stage synchronizer D pins. The rebuilt design parsed this file without warnings. No exception was added to the renderer path.

The latest user-supplied log reports zero DRC errors and successful bitstream generation. The final timing report confirms no missing internal clocks, unconstrained internal endpoints, or combinational loops. The methodology summary lists distributed RAM mapping and missing external I/O delay warnings; the earlier setup violation warning is gone. The CDC report lists 738 safely timed inter-clock endpoints and three safe input synchronizer endpoints, with no unsafe, unknown, or missing-ASYNC_REG endpoints among analyzed crossings. Inputs without delay constraints are skipped by CDC analysis. External I/O timing remains outside this internal timing sign-off: 22 inputs and 42 outputs lack delay constraints.

The first build had no DRC errors, no missing internal clocks, and no unconstrained internal endpoints. Its CDC report said all analyzed paths were safely timed. The timing report still listed 22 inputs and 42 outputs without delay constraints; these external peripheral paths need separate review.

Reproduce the local checks from the repository root:

```sh
python3 scripts/build_debugger_images.py --check
python3 scripts/run_tests.py
python3 scripts/render_previews.py
```

The runner uses installed Icarus tools or the existing unpacked tools under temp/tools/iverilog. Logs, executables, and screen previews go to temp/debugger-tests. The demo-loop-exit.png preview comes from the executing CPU through the snapshot bridge and renderer.

## Vivado

Use Vivado 2023.2 from a terminal with its settings loaded. Start each command from the repository root in a fresh process:

```sh
mkdir -p temp/debugger-vivado
vivado -mode batch -log temp/debugger-vivado/behavioral.log -journal temp/debugger-vivado/behavioral.jou -source scripts/vivado_debugger.tcl -tclargs behavioral
vivado -mode batch -log temp/debugger-vivado/postsynth.log -journal temp/debugger-vivado/postsynth.jou -source scripts/vivado_debugger.tcl -tclargs postsynth
vivado -mode batch -log temp/debugger-vivado/build.log -journal temp/debugger-vivado/build.jou -source scripts/vivado_debugger.tcl -tclargs build
```

Behavioral runs all 16 test tops and requires their pass markers. The helper restores the simulation settings afterward. Post-synthesis creates a separate in-memory Wrapper design using the debugger images, writes a functional netlist, and runs the port-only testbench against that netlist. It checks stepping and results for all DIP selections without hierarchical references. This is CPU functional netlist simulation; the physical board check covers the OLED.

Both post-synthesis testbenches default to RTL for manual behavioral runs. Netlist compilation requires DEBUGGER_NETLIST for the wrapper testbench or MCYCLE_NETLIST for the standalone multicycle testbench. The post-synthesis helper sets DEBUGGER_NETLIST automatically.

Build opens RISCV-CPU.xpr, selects TOP with DEBUGGER_ENABLE=true, resets synthesis, and runs through bitstream generation. It retains the existing 100 MHz board clock and 25 MHz generated CPU clock. Reports go to temp/debugger-vivado. The bitstream is RISCV-CPU.runs/impl_1/TOP.bit.

Review the following before programming the board:

- The expected 10 ns board clock and 40 ns CPU clock are present.
- Routed setup and hold slack are nonnegative, with zero failing endpoints.
- There are no unconstrained internal clocks or endpoints. Inspect the external I/O timing omissions inherited from the board constraints separately; a passing internal timing summary does not establish peripheral timing.
- DRC has no errors. Review methodology warnings and the snapshot/button/reset crossings.
- The new CDC exception reaches only the first synchronizer stage D pins. The payload-to-snapshot path, second synchronizer stages, and CPU/display logic remain timed. No clock-group exception is added.
- Post-synthesis simulation contains ALL DEBUGGER PORT-LEVEL TESTS PASSED and no failure markers.

The project source list includes the new RTL, testbenches, debugger memory images, and implementation-only debugger.xdc. Existing evaluation.xdc remains guarded for standalone multicycle evaluation.

## Board check

Connect the PmodOLEDrgb to the existing JB mapping. Program TOP.bit and press Down. Allow the OLED initialization sequence to complete.

1. Check that CYC stays at zero while idle.
2. Press Centre once; CYC must increase by one. Hold Centre: it must increase only once. Release fully and press again.
3. Change pages with Left/Right while paused. Confirm that the CPU cycle count stays fixed.
4. Reset with DIP[1:0]=00 and follow the cycle-40/cycle-43 walkthrough in pipeline-debugger.md. Check that a correct taken prediction preserves younger instructions and that the loop exit shows discarded instructions in red.
5. Finish each DIP-selected calculation and compare LEDs and seven-segment output with the result table. Check reset during a multiply/divide hold and while a flush event is displayed.
6. Record OLED orientation/readability and button behavior. Changing a page must not step the CPU; holding any navigation button must not auto-repeat.

Validation record:

```text
Vivado behavioral: all 16 test tops passed (user-provided Vivado 2023.2 logs)
Wrapper functional netlist simulation: passed (all four DIP selections)
Routed setup / hold: passed, WNS +1.409 ns / WHS +0.018 ns, zero failing endpoints
DRC / CDC / unconstrained-path review: zero DRC errors; analyzed CDC crossings safe; no unconstrained internal endpoints; external I/O delays remain unspecified
Physical board: user reported it all works; individual OLED/button/DIP checklist results not recorded
```

Step 7 records these results with the commit: Document and validate the FPGA pipeline debugger.

## Debug interface

RV and Wrapper accept Enable and export DebugState[767:0]. Normal execution ties Enable high. Reset takes priority over Enable; CPU transactions occur only on enabled cycles. UART and OLED output strobes clear on the next ordinary CPU clock to avoid repeating a transaction while paused.

The packed debug bus uses the following layout. Stage order is IF, ID, EX, MEM, WB, with IF in the lowest bits of each stage vector.

| Bits | Value |
| --- | --- |
| 159:0 | Five 32-bit PCs |
| 319:160 | Five 32-bit instructions |
| 324:320 | Five valid bits |
| 325 | Load-use stall |
| 326 | Multicycle busy |
| 327 | Current Execute recovery request |
| 329:328 | ForwardAE |
| 331:330 | ForwardBE |
| 332 | ForwardM |
| 364:333 | Enabled CPU cycle count |
| 396:365 | Saved Execute predicted next PC |
| 428:397 | Execute actual next PC |
| 460:429 | Last recovery's resolving PC |
| 492:461 | Resolving instruction |
| 524:493 | Discarded IF PC |
| 556:525 | Discarded IF instruction |
| 588:557 | Discarded ID PC |
| 620:589 | Discarded ID instruction |
| 652:621 | Event predicted next PC |
| 684:653 | Event actual next PC |
| 716:685 | Recovery count |
| 717 | Event valid |
| 718 | Discarded IF valid |
| 719 | Discarded ID valid |
| 720 | Event direction mismatch |
| 721 | Event target mismatch |
| 767:722 | Reserved, zero |

The snapshot bridge holds its source payload until the destination acknowledges it. The renderer then holds a complete snapshot for each render pass. There is no event queue; each recovery replaces the previous event.
