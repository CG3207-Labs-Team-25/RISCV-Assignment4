`timescale 1ns / 1ps
module test_PipelineDebugger;
    reg CLK=0, DisplayCLK=0, RESET=1, Button=0;
    reg [15:0] DIP=0;
    wire Enable;
    wire [767:0] Debug, Snapshot;
    wire Updated;
    reg Right=0;
    wire PixelWrite;
    wire [6:0] PixelX;
    wire [5:0] PixelY;
    wire [15:0] PixelData;
    reg [2047:0] PreviewDirectory="../temp/debugger-tests";
    reg [4095:0] PreviewPath;
    integer preview_file, pixel_count;
    integer selection, steps, before_cycle, good, exits, stalls, multicycle, n, result, j;
    Wrapper #(.IROM_FILE("Debugger_IROM.mem"), .DMEM_FILE("Debugger_DMEM.mem")) dut(
        .CLK(CLK), .RESET(RESET), .Enable(Enable), .DebugState(Debug),
        .DIP(DIP), .PB(3'd0), .UART_TX_ready(1'b1), .UART_RX(8'd0),
        .UART_RX_valid(1'b0), .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0));
    StepController #(.STABLE_CYCLES(3)) Controller(CLK, RESET, Button, Enable);
    DebugSnapshot Bridge(CLK, RESET, Debug, DisplayCLK, RESET, Snapshot, Updated);
    PipelineDisplay #(.DEBOUNCE_CYCLES(3)) Display(
        DisplayCLK, RESET, 1'b0, Right, Snapshot, PixelWrite, PixelX, PixelY, PixelData);
    always #20 CLK=~CLK;
    always #5 DisplayCLK=~DisplayCLK;
    always @(posedge CLK) if(!RESET && Enable) begin
        stalls=stalls+dut.RV1.LoadStall;
        multicycle=multicycle+dut.RV1.Busy;
        if(dut.RV1.Valid_E && dut.RV1.PC_E==32'h0040002c) begin
            if(selection==0) $display("TRACE: step=%0d branch=%h actual=%h recover=%b",
                dut.cycle_count+1, dut.RV1.PC_E, dut.RV1.PC_ALU, dut.RV1.Mispredict);
            if(dut.RV1.PCSrc_E!=0 && !dut.RV1.Mispredict) good=good+1;
            if(dut.RV1.PCSrc_E==0 && dut.RV1.Mispredict) exits=exits+1;
        end
        if(dut.MemWrite && dut.ALUResult==32'h10010004)
            $fatal(1,"wrong-path sentinel write committed");
    end
    task step;
        begin
            before_cycle=dut.cycle_count;
            Button=1; repeat(12) @(negedge CLK);
            Button=0; repeat(12) @(negedge CLK);
            if(dut.cycle_count !== before_cycle+1)
                $fatal(1,"centre press did not execute exactly one CPU cycle");
            if(Snapshot[364:333] !== dut.cycle_count)
                $fatal(1,"display snapshot did not catch up while paused");
        end
    endtask
    task capture_exit;
        begin
            repeat(2) begin
                Right=1; repeat(12) @(negedge DisplayCLK);
                Right=0; repeat(12) @(negedge DisplayCLK);
            end
            wait(!Display.Drawing);
            wait(Display.Drawing); @(negedge DisplayCLK);
            if(Display.FramePage!=2 || Display.Frame[429+:32] !== 32'h0040002c ||
                Display.Frame[621+:32] !== 32'h00400024 ||
                Display.Frame[653+:32] !== 32'h00400030)
                $fatal(1,"OLED did not receive the actual loop-exit event");
            @(negedge DisplayCLK);
            while(!(PixelWrite && PixelX==0 && PixelY==0)) @(negedge DisplayCLK);
            $sformat(PreviewPath,"%0s/demo-loop-exit.ppm",PreviewDirectory);
            preview_file=$fopen(PreviewPath,"w");
            if(!preview_file) $fatal(1,"cannot open integrated OLED preview");
            $fwrite(preview_file,"P3\n96 64\n255\n");
            pixel_count=0;
            while(pixel_count<6144) begin
                @(posedge DisplayCLK);
                if(PixelWrite) begin
                    if(PixelX !== pixel_count%96 || PixelY !== pixel_count/96)
                        $fatal(1,"integrated OLED pixel position/bounds");
                    $fwrite(preview_file,"%0d %0d %0d\n",{PixelData[15:11],3'b0},
                        {PixelData[10:5],2'b0},{PixelData[4:0],3'b0});
                    pixel_count=pixel_count+1;
                end
            end
            $fclose(preview_file);
            @(negedge CLK);
        end
    endtask
    initial begin
        if($value$plusargs("PREVIEW_DIR=%s",PreviewDirectory)) begin end
        for(selection=0;selection<4;selection=selection+1) begin
            RESET=1; Button=0; DIP=selection;
            good=0; exits=0; stalls=0; multicycle=0;
            repeat(5) @(negedge CLK);
            RESET=0; repeat(8) @(negedge CLK);
            repeat(6) step;
            steps=6;
            while(dut.RV1.RegFile1.RegBank[27] !== 1 && steps<320) begin
                step; steps=steps+1;
                if(selection==0 && steps==43) capture_exit;
            end
            n=selection+3; result=n*(2*n+1);
            if(steps==320 || dut.LED_OUT !== result || dut.SEVENSEGHEX !== result)
                $fatal(1,"DIP %d demo output mismatch",selection);
            if(dut.DMEM[0] !== n*(n+1) || dut.DMEM[1] !== 32'hcafebabe ||
                dut.DMEM[2] !== 32'hff800080)
                $fatal(1,"DIP %d demo memory mismatch",selection);
            if(dut.RV1.RegFile1.RegBank[29] !== 32'hffffff80 ||
                dut.RV1.RegFile1.RegBank[30] !== 32'h80 ||
                dut.RV1.RegFile1.RegBank[31] !== 32'hffffff80 ||
                dut.RV1.RegFile1.RegBank[11] !== 32'hff80 ||
                dut.RV1.RegFile1.RegBank[12] !== n*(n+1)+1 ||
                dut.RV1.RegFile1.RegBank[13] !== n*n ||
                dut.RV1.RegFile1.RegBank[14] !== n ||
                dut.RV1.RegFile1.RegBank[15] !== 0)
                $fatal(1,"DIP %d demo instruction result mismatch",selection);
            if(good==0 || exits!=2 || stalls<2 || multicycle==0)
                $fatal(1,"DIP %d missing enhancement coverage %d/%d/%d/%d",
                    selection,good,exits,stalls,multicycle);
            $display("PASS: DIP=%d n=%d result=%d steps=%d correct taken=%d exits=%d",
                selection,n,result,steps,good,exits);
        end
        $display("ALL INTERACTIVE PIPELINE DEBUGGER TESTS PASSED (4 DIP selections)");
        $finish;
    end
    initial begin #3000000; $fatal(1,"debugger timeout"); end
endmodule
