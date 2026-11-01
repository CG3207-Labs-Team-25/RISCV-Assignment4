`timescale 1ns / 1ps
module BranchTrace(
    input CLK, RESET, Enable, Recover,
    input [31:0] PC_F, PC_D, PC_E,
    input [31:0] Instr_F, Instr_D, Instr_E,
    input Valid_F, Valid_D,
    input [31:0] Predicted, Actual,
    input Taken,
    output reg [292:0] Event = 0
);
    wire PredictedTaken = Predicted != PC_E + 32'd4;
    always @(posedge CLK) begin
        if (RESET) Event <= 0;
        else if (Enable && Recover) begin
            Event <= {PredictedTaken && Taken && Predicted != Actual,
                PredictedTaken != Taken, Valid_D, Valid_F, 1'b1,
                Event[287:256] + 32'd1, Actual, Predicted,
                Instr_D, PC_D, Instr_F, PC_F, Instr_E, PC_E};
        end
    end
endmodule
