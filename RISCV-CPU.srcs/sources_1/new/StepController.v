`timescale 1ns / 1ps
module StepController #(
    parameter STABLE_CYCLES = 250000
)(
    input CLK,
    input RESET,
    input Button,
    output reg Pulse = 0
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] Sync = 0;
    reg Stable = 0;
    reg Armed = 0;
    reg [$clog2(STABLE_CYCLES+1)-1:0] Count = 0;
    always @(posedge CLK) begin
        Sync <= {Sync[0], Button};
        Pulse <= 0;
        if (RESET) begin
            Sync <= 0;
            Stable <= 0;
            Armed <= 0;
            Count <= 0;
        end
        else if (Sync[1] != Stable) begin
            if (Count == STABLE_CYCLES-1) begin
                Stable <= Sync[1];
                Count <= 0;
                if (Sync[1]) begin
                    Pulse <= Armed;
                    Armed <= 0;
                end
                else Armed <= 1;
            end
            else Count <= Count + 1'b1;
        end
        else begin
            Count <= 0;
            if (!Stable) Armed <= 1;
        end
    end
endmodule
