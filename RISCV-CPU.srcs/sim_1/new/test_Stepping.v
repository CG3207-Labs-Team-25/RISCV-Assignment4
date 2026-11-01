`timescale 1ns / 1ps
module test_StepController;
    reg CLK = 0, RESET = 1, Button = 0;
    wire Pulse;
    integer pulses = 0;
    StepController #(.STABLE_CYCLES(4)) dut(CLK, RESET, Button, Pulse);
    always #5 CLK = ~CLK;
    always @(posedge CLK) if (Pulse) pulses = pulses + 1;
    task waitcycles;
        input integer n;
        begin repeat(n) @(negedge CLK); end
    endtask
    initial begin
        waitcycles(3); RESET = 0; waitcycles(8);
        Button = 1; waitcycles(2); Button = 0; waitcycles(8);
        if (pulses != 0) $fatal(1, "bounce generated a step");
        Button = 1; waitcycles(20);
        if (pulses != 1) $fatal(1, "held press must produce exactly one step");
        Button = 0; waitcycles(2); Button = 1; waitcycles(10);
        if (pulses != 1) $fatal(1, "release bounce rearmed button");
        Button = 0; waitcycles(10); Button = 1; waitcycles(10);
        if (pulses != 2) $fatal(1, "second press not recognized");
        RESET = 1; waitcycles(3); RESET = 0; Button = 0; waitcycles(10);
        if (Pulse) $fatal(1, "reset generated pulse");
        $display("ALL BUTTON STEP TESTS PASSED");
        $finish;
    end
endmodule

module test_Wrapper_Stepping;
    reg CLK = 0, RESET = 1, Enable = 0;
    integer i, j, tx = 0, stores = 0;
    reg [511:0] frozen, observed;
    Wrapper dut(.CLK(CLK), .RESET(RESET), .Enable(Enable), .DIP(16'd0), .PB(3'd0),
        .UART_TX_ready(1'b1), .UART_RX(8'd0), .UART_RX_valid(1'b0),
        .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    Wrapper reference(.CLK(CLK), .RESET(RESET), .Enable(1'b1), .DIP(16'd0), .PB(3'd0),
        .UART_TX_ready(1'b1), .UART_RX(8'd0), .UART_RX_valid(1'b0),
        .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    always #5 CLK = ~CLK;
    always @(posedge CLK) if (!RESET) begin
        if (dut.UART_TX_valid) tx = tx + 1;
        if (dut.MemWrite && dut.dec_DMEM) stores = stores + 1;
        if (!Enable && (dut.MemWrite || dut.MemRead))
            $fatal(1, "paused memory transaction");
    end
    task capture_state;
        output [511:0] value;
        begin
            value = {dut.PC, dut.RV1.PC_D, dut.RV1.PC_E, dut.RV1.PC_M, dut.RV1.PC_W,
                dut.RV1.Valid_D, dut.RV1.Valid_E, dut.RV1.Valid_M, dut.RV1.Valid_W,
                dut.RV1.MCycle1.state, dut.RV1.MCycle1.count,
                dut.RV1.MCycle1.Result1, dut.RV1.MCycle1.Result2,
                dut.RV1.MCycle1.temp_sum, dut.RV1.HeldRD1_E, dut.RV1.HeldRD2_E,
                dut.RV1.RegFile1.RegBank[3], dut.DMEM[0], dut.cycle_count};
        end
    endtask
    initial begin
        #1;
        for (i=0; i<512; i=i+1) begin dut.IROM[i]=32'h13; reference.IROM[i]=32'h13; end
        dut.IROM[0]=32'h100100b7;
        dut.IROM[1]=32'h00600113;
        dut.IROM[2]=32'h00300213;
        dut.IROM[3]=32'h024101b3;
        dut.IROM[4]=32'h0030a023;
        dut.IROM[5]=32'h0000a283;
        dut.IROM[6]=32'h00128313;
        dut.IROM[7]=32'h0241c3b3;
        dut.IROM[8]=32'hffff0437;
        dut.IROM[9]=32'h06642023;
        dut.IROM[10]=32'h00640623;
        dut.IROM[11]=32'h00100f93;
        dut.IROM[12]=32'h0000006f;
        for (i=0; i<512; i=i+1) reference.IROM[i]=dut.IROM[i];
        dut.DMEM[0]=0; reference.DMEM[0]=0;
        repeat(3) @(negedge CLK); RESET=0;
        for (i=0; i<180; i=i+1) begin
            Enable=0; #1; capture_state(frozen);
            repeat(3) begin
                @(negedge CLK); #1;
                capture_state(observed);
                if (observed !== frozen) $fatal(1, "CPU changed while paused at step %d", i);
            end
            Enable=1; @(negedge CLK);
        end
        Enable=0;
        for (j=1; j<32; j=j+1)
            if (dut.RV1.RegFile1.RegBank[j] !== reference.RV1.RegFile1.RegBank[j])
                $fatal(1, "stepped register x%d differs from continuous execution", j);
        if (dut.DMEM[0] !== 18 || dut.RV1.RegFile1.RegBank[6] !== 19 ||
            dut.RV1.RegFile1.RegBank[7] !== 6 || dut.LED_OUT !== 19 ||
            tx != 1 || stores != 1)
            $fatal(1, "stepped side effects/results: TX %d stores %d LED %h", tx, stores, dut.LED_OUT);
        RESET=1; repeat(3) @(negedge CLK);
        if (dut.PC !== 32'h00400000 || dut.cycle_count !== 0 || dut.LED_OUT !== 0)
            $fatal(1, "reset while paused failed");
        $display("ALL CPU STEPPING TESTS PASSED");
        $finish;
    end
endmodule
