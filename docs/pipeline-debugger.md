# Pipeline debugger

The debugger starts paused. Press the centre button once to execute one CPU cycle. A multiply or divide needs several presses because its internal iterations advance with the CPU. Hold a button for at least 10 ms; holding it longer still produces one action.

Left and right select the display page. Down resets the CPU, predictor, event history, and page selection. Up has no function in debugger mode. Set DIP[1:0] before stepping through the input load; reset to restart with another value.

## Display

The instruction page shows IF, ID, EX, MEM, and WB with raw instruction hex. A means active, B means bubble, and H means held. Yellow marks a held stage. CYC counts enabled CPU cycles. The PC page shows the full address of each stage; P and A show the current Execute instruction's predicted and actual next PC.

The flush page retains the most recent recovery. EX gives the resolving instruction's PC. IF and ID give the discarded instructions, with their PCs on the following rows. Red marks discarded instructions. P is the saved prediction; A is the corrected next PC. D marks a direction mismatch and T a target mismatch. The flush count includes conditional branches and jumps.

The live pages show state after the last step. A load stall or multicycle hold shown there describes why the next step will hold stages. Flush history records the instructions present immediately before the recovery edge. A later recovery replaces that history.

The OLED keeps refreshing while the CPU is paused. A complete render pass uses one snapshot. This is a pipeline viewer with single-cycle stepping; it has no register editor, breakpoints, or execution history beyond the last flush.

## Demonstration

`asm_src/Pipeline_Debugger.asm` reads the two low DIP bits and sets n to 3, 4, 5, or 6. It sums 1 through n twice, calculates n squared, and publishes their sum, n × (2n + 1), to LEDs and the seven-segment display.

| DIP[1:0] | n | Decimal result | Seven-segment hex | Steps to publication/done |
| --- | --- | --- | --- | --- |
| 00 | 3 | 21 | 00000015 | 150 |
| 01 | 4 | 36 | 00000024 | 154 |
| 10 | 5 | 55 | 00000037 | 160 |
| 11 | 6 | 78 | 0000004E | 166 |

These step counts come from behavioral simulation with a fresh reset. They include pipeline filling, stalls, recoveries, and multicycle iterations.

For the shortest walkthrough, set DIP[1:0] to 00 and reset:

1. Step to cycle 15. The cold branch at 0040002C recovers to 00400024. Open the flush page to see the discarded instructions.
2. Cycles 20 and 25 show another cold taken recovery and the first loop exit. The loop runs a second time to reuse its predictor entry.
3. After cycle 39, view the pipeline page. The next press resolves the learned taken branch. Cycle 40 advances the correct target instructions without flushing. The flush count stays fixed.
4. Cycle 43 exits the loop against a taken prediction. Open the flush page: P is 00400024 and A is 00400030.
5. Continue through the load-use hold and multiply/divide instructions. Their PCs are 00400058–00400068. MEM and WB can drain while Execute is held.
6. The jump at 0040006C skips stores at 00400070 and 00400074. The word at 10010004 stays CAFEBABE.
7. At cycle 150, the LED result is 15 hex. The CPU then parks in a self-jump. Its first resolution can replace the last flush event.

The program also checks byte/halfword paths with signed and unsigned loads of -128. No padding NOPs are inserted between its instructions. Unused instruction memory is padded with NOPs.

## Images and local checks

The wrapper defaults to the original AA_IROM.mem and AA_DMEM.mem. The board top defaults to DEBUGGER_ENABLE = True and selects Debugger_IROM.mem and Debugger_DMEM.mem. Setting the top generic to False restores continuous execution and software OLED writes with the original images.

Run from the repository root:

```sh
python3 scripts/build_debugger_images.py --check
python3 scripts/run_tests.py test_PipelineDebugger
```

The image builder uses `temp/tools/rars.jar`; pass `--rars /path/to/rars.jar` to use another installation. It writes assembled files and an instruction listing under `temp/debugger-images`. The tracked debugger images contain 512 instruction words and 128 data words.

The integration test checks every button press, all DIP selections, signed/unsigned loads, multiply/divide results, predictor learning, loop-exit recovery, and absence of wrong-path stores. Existing functionality and FPGA demo programs keep their own images.
