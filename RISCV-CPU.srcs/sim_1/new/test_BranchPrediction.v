`timescale 1ns / 1ps
module test_BranchPrediction;
    reg CLK = 0, RESET = 1, Enable = 1, Resolve = 0;
    reg [6:0] Opcode = 7'h63;
    reg [31:0] Actual = 32'h100, Predicted = 4, Fetch = 0, Execute = 0;
    reg [1:0] Taken = 1;
    wire Miss;
    wire [31:0] Next;
    BranchPrediction #(.ADDRESS_BITS(2)) dut(
        CLK, RESET, Enable, Resolve, Opcode, Actual, Predicted,
        Fetch, Execute, Taken, Miss, Next
    );
    always #5 CLK = ~CLK;
    task tick;
        begin @(posedge CLK); #1; @(negedge CLK); end
    endtask
    initial begin
        tick; RESET = 0; #1;
        if (Next !== 4 || Miss !== 0) $fatal(1, "cold/invalid prediction");
        Resolve = 1; #1;
        if (!Miss) $fatal(1, "cold taken must recover");
        tick;
        if (Next !== 4) $fatal(1, "counter must remain weak not taken");
        tick;
        if (Next !== Actual) $fatal(1, "second taken must predict target");
        Predicted = Actual; #1;
        if (Miss) $fatal(1, "correct saved prediction must not flush");
        tick;
        if (dut.Counters[0] !== 3) $fatal(1, "correct taken must train");
        Fetch = 16; #1;
        if (Next !== 20) $fatal(1, "alias tag must miss");
        Fetch = 0; Actual = 32'h104; #1;
        if (!Miss) $fatal(1, "target change must recover");
        tick;
        Resolve = 0; Predicted = 0; #1;
        if (Miss) $fatal(1, "invalid resolution must not recover");
        Actual = 4; Taken = 0; tick;
        if (dut.Counters[0] !== 3) $fatal(1, "invalid resolution trained");
        Resolve = 1; Enable = 0; tick;
        if (dut.Counters[0] !== 3) $fatal(1, "disabled predictor trained");
        Enable = 1; tick;
        if (dut.Counters[0] !== 2) $fatal(1, "not taken must decrement");
        tick; tick; tick;
        if (dut.Counters[0] !== 0) $fatal(1, "counter must saturate");
        Execute = 16; Fetch = 16; Opcode = 7'h67; Taken = 3;
        Actual = 32'h200; Predicted = 20; tick;
        if (Next !== 32'h200) $fatal(1, "jump must predict after training");
        Fetch = 0; #1;
        if (Next !== 4) $fatal(1, "replacement must invalidate old tag");
        $display("ALL BRANCH PREDICTOR TESTS PASSED");
        $finish;
    end
endmodule

module test_Wrapper_Prediction;
    reg CLK = 0, RESET = 1;
    integer i, cycles = 0, correct = 0, misses = 0;
    Wrapper dut(.CLK(CLK), .RESET(RESET), .DIP(16'd0), .PB(3'd0),
        .UART_TX_ready(1'b1), .UART_RX(8'd0), .UART_RX_valid(1'b0),
        .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    always #5 CLK = ~CLK;
    always @(posedge CLK) if (!RESET) begin
        cycles = cycles + 1;
        if (dut.RV1.Valid_E && dut.RV1.PC_E == 32'h00400010) begin
            if (dut.RV1.Mispredict) misses = misses + 1;
            else begin
                correct = correct + 1;
                if (dut.RV1.FlushD || dut.RV1.FlushE)
                    $fatal(1, "correctly predicted branch flushed");
            end
        end
    end
    initial begin
        #1;
        for (i = 0; i < 512; i = i + 1) dut.IROM[i] = 32'h00000013;
        dut.IROM[0] = 32'h100100b7;
        dut.IROM[1] = 32'h00800113;
        dut.IROM[2] = 32'h00000193;
        dut.IROM[3] = 32'h00118193;
        dut.IROM[4] = 32'hfe21cee3;
        dut.IROM[5] = 32'h0030a023;
        dut.IROM[6] = 32'h00c0006f;
        dut.IROM[7] = 32'h0000a023;
        dut.IROM[8] = 32'h00000193;
        dut.IROM[9] = 32'h00100f93;
        dut.IROM[10] = 32'h0000006f;
        dut.DMEM[0] = 0;
        repeat (3) @(negedge CLK); RESET = 0;
        wait (dut.RV1.RegFile1.RegBank[31] === 1);
        @(negedge CLK);
        if (dut.DMEM[0] !== 8 || dut.RV1.RegFile1.RegBank[3] !== 8)
            $fatal(1, "branch path or wrong-path store corrupted result");
        if (correct < 4 || misses != 3) $fatal(1, "predictor learning coverage %d/%d", correct, misses);
        $display("ALL CPU BRANCH PREDICTION TESTS PASSED");
        $finish;
    end
    initial begin #10000; $fatal(1, "prediction timeout"); end
endmodule
