`timescale 1ns / 1ps
module test_DebugState;
    reg CLK = 0, RESET = 1, Enable = 1;
    wire [767:0] Debug;
    reg [767:0] Before;
    reg [31:0] expected_pc [0:4];
    reg [31:0] expected_instruction [0:4];
    reg [4:0] expected_valid;
    integer i, s, cycles = 0, stalls = 0, busy_cycles = 0;
    reg load_stall, busy, recover;
    Wrapper dut(.CLK(CLK), .RESET(RESET), .Enable(Enable), .DebugState(Debug),
        .DIP(16'd0), .PB(3'd0), .UART_TX_ready(1'b1), .UART_RX(8'd0),
        .UART_RX_valid(1'b0), .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    always #5 CLK = ~CLK;
    always @(posedge CLK) if (!RESET) begin
        Before = Debug;
        load_stall = Debug[325];
        busy = Debug[326];
        recover = Debug[327];
        stalls = stalls + load_stall;
        busy_cycles = busy_cycles + busy;
        expected_valid = Debug[324:320];
        for(s=0; s<5; s=s+1) begin
            expected_pc[s] = Debug[s*32 +: 32];
            expected_instruction[s] = Debug[160+s*32 +: 32];
        end
        if (Enable) begin
            cycles = cycles + 1;
            expected_valid[4] = Before[323];
            expected_pc[4] = Before[96 +: 32];
            expected_instruction[4] = Before[256 +: 32];
            expected_valid[3] = !busy && Before[322];
            expected_pc[3] = Before[64 +: 32];
            expected_instruction[3] = Before[224 +: 32];
            if (!busy) begin
                expected_valid[2] = !recover && !load_stall && Before[321];
                expected_pc[2] = Before[32 +: 32];
                expected_instruction[2] = Before[192 +: 32];
            end
            if (recover) expected_valid[1] = 0;
            else if (!busy && !load_stall) begin
                expected_valid[1] = 1;
                expected_pc[1] = Before[0 +: 32];
                expected_instruction[1] = Before[160 +: 32];
            end
        end
        #1;
        if (Debug[364:333] !== cycles) $fatal(1, "debug cycle count");
        for(s=1; s<5; s=s+1) begin
            if (Debug[320+s] !== expected_valid[s]) $fatal(1, "stage %d validity", s);
            if (expected_valid[s] &&
                (Debug[s*32 +: 32] !== expected_pc[s] ||
                 Debug[160+s*32 +: 32] !== expected_instruction[s]))
                $fatal(1, "stage %d progression/hold", s);
        end
    end
    initial begin
        #1;
        for(i=0;i<512;i=i+1) dut.IROM[i]=32'h13;
        dut.IROM[0]=32'h100100b7;
        dut.IROM[1]=32'h0000a103;
        dut.IROM[2]=32'h00110193;
        dut.IROM[3]=32'h02310233;
        dut.IROM[4]=32'h0000006f;
        dut.DMEM[0]=3;
        repeat(3) @(negedge CLK); RESET=0;
        repeat(90) begin
            @(negedge CLK); Enable=0;
            repeat(2) @(negedge CLK);
            Enable=1;
        end
        if (stalls == 0 || busy_cycles == 0) $fatal(1, "debug hold coverage missing");
        $display("ALL PIPELINE DEBUG STATE TESTS PASSED");
        $finish;
    end
endmodule
