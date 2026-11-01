`timescale 1ns / 1ps
module test_Debugger_PostSynth;
    reg CLK=0, RESET=1, Enable=0;
    reg [15:0] DIP=0;
    wire [7:0] LED;
    wire [31:0] SevenSegment;
    wire [767:0] Debug;
    integer selection, i, enabled_cycles, n, expected;
    reg [767:0] Held;
    reg [31:0] HeldSeven;
    reg [7:0] HeldLED;
    reg done;
`ifdef DEBUGGER_NETLIST
    Wrapper dut(
`else
    Wrapper #(.IROM_FILE("Debugger_IROM.mem"), .DMEM_FILE("Debugger_DMEM.mem")) dut(
`endif
        .CLK(CLK), .RESET(RESET), .Enable(Enable), .DebugState(Debug),
        .LED_OUT(LED), .SEVENSEGHEX(SevenSegment),
        .DIP(DIP), .PB(3'd0), .UART_TX_ready(1'b1), .UART_RX(8'd0),
        .UART_RX_valid(1'b0), .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    always #20 CLK=~CLK;
    initial begin
        for(selection=0;selection<4;selection=selection+1) begin
            RESET=1; Enable=0; DIP=selection;
            repeat(5) @(negedge CLK);
            RESET=0; enabled_cycles=0; done=0;
            while(!done && enabled_cycles<320) begin
                Enable=0; #2;
                Held=Debug; HeldSeven=SevenSegment; HeldLED=LED;
                repeat(3) begin
                    @(negedge CLK); #2;
                    if(Debug !== Held || SevenSegment !== HeldSeven || LED !== HeldLED)
                        $fatal(1,"post-synthesis paused state changed");
                end
                Enable=1; #2;
                done=Debug[324] && Debug[288+:32]==32'h00100d93;
                @(negedge CLK);
                enabled_cycles=enabled_cycles+1;
            end
            n=selection+3; expected=n*(2*n+1);
            if(!done || LED !== expected || SevenSegment !== expected)
                $fatal(1,"post-synthesis DIP %d output failed", selection);
        end
        $display("ALL DEBUGGER PORT-LEVEL TESTS PASSED (4 DIP selections)");
        $finish;
    end
    initial begin #1000000; $fatal(1,"post-synthesis debugger timeout"); end
endmodule
