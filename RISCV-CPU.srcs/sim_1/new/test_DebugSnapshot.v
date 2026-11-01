`timescale 1ns / 1ps
module test_DebugSnapshot;
    reg SourceCLK=0, DisplayCLK=0, RESET=1;
    reg [767:0] SourceData=0;
    wire [767:0] Snapshot;
    wire Updated;
    integer received=0, i;
    reg [767:0] Expected=0, Held=0;
    reg was_pending=0;
    DebugSnapshot dut(SourceCLK, RESET, SourceData, DisplayCLK, RESET, Snapshot, Updated);
    always #7 SourceCLK=~SourceCLK;
    always #5 DisplayCLK=~DisplayCLK;
    always @(negedge SourceCLK) if (!RESET) SourceData=SourceData+{24{32'h01020305}};
    always @(posedge SourceCLK) begin
        if (!RESET && was_pending && dut.Payload !== Held)
            $fatal(1, "payload changed before acknowledgment");
        #1;
        Expected=dut.Payload;
        Held=dut.Payload;
        was_pending=!RESET && dut.AckSync[1] != dut.Request;
    end
    always @(negedge DisplayCLK) if (!RESET && Updated) begin
        if (Snapshot !== Expected) $fatal(1, "torn snapshot");
        received=received+1;
    end
    initial begin
        #100; RESET=0; #4000;
        if(received<20) $fatal(1, "snapshot handshake stalled");
        RESET=1; #100; RESET=0; #2000;
        if(received<40) $fatal(1, "snapshot reset recovery stalled");
        $display("ALL DEBUG SNAPSHOT TESTS PASSED");
        $finish;
    end
endmodule

module test_BranchTrace;
    reg CLK=0, RESET=1, Enable=1;
    wire [767:0] Debug;
    reg [31:0] epc,einst,fpc,finst,dpc,dinst,pred,actual;
    reg dv, recover;
    integer i, events=0;
    Wrapper dut(.CLK(CLK), .RESET(RESET), .Enable(Enable), .DebugState(Debug),
        .DIP(16'd0), .PB(3'd0), .UART_TX_ready(1'b1), .UART_RX(8'd0),
        .UART_RX_valid(1'b0), .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    always #5 CLK=~CLK;
    always @(posedge CLK) if(!RESET && Enable) begin
        recover=Debug[327];
        epc=Debug[64+:32]; einst=Debug[224+:32];
        fpc=Debug[0+:32]; finst=Debug[160+:32];
        dpc=Debug[32+:32]; dinst=Debug[192+:32]; dv=Debug[321];
        pred=Debug[365+:32]; actual=Debug[397+:32];
        if(recover) events=events+1;
        #1;
        if(Debug[685+:32] !== events) $fatal(1,"event count");
        if(recover) begin
            if(Debug[429+:256] !== {actual,pred,dinst,dpc,finst,fpc,einst,epc})
                $fatal(1,"discarded instruction capture");
            if(!Debug[717] || Debug[718] !== 1 || Debug[719] !== dv)
                $fatal(1,"discarded instruction validity");
            if(Debug[321] || Debug[322]) $fatal(1,"recovery did not flush D/E");
        end
    end
    initial begin
        #1;
        for(i=0;i<512;i=i+1) dut.IROM[i]=32'h13;
        dut.IROM[0]=32'h0080006f;
        dut.IROM[1]=32'h00100093;
        dut.IROM[2]=32'h0000006f;
        repeat(3) @(negedge CLK); RESET=0;
        repeat(20) @(negedge CLK);
        Enable=0; pred=Debug[685+:32];
        repeat(10) @(negedge CLK);
        if(events!=2 || Debug[685+:32] !== 2) $fatal(1,"correct jump/paused event duplicated");
        RESET=1; repeat(3) @(negedge CLK);
        if(Debug[717] || Debug[685+:32] !== 0) $fatal(1,"event reset");
        $display("ALL BRANCH FLUSH CAPTURE TESTS PASSED");
        $finish;
    end
endmodule
