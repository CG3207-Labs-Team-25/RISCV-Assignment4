`timescale 1ns / 1ps

module BranchPrediction #(
    parameter ADDRESS_BITS = 8,
    parameter TABLE_ENTRIES = 2**ADDRESS_BITS
)(
    input CLK,
    input RESET,
    input Enable,
    input Resolve_E,
    input [6:0] Opcode_E,
    input [31:0] PCNext_E,
    input [31:0] PredictedNext_E,
    input [31:0] PC_F,
    input [31:0] PC_E,
    input [1:0] PCSrc_E,
    output Mispredict,
    output [31:0] PrPCF
);
    wire [ADDRESS_BITS-1:0] FIndex = PC_F[ADDRESS_BITS+1:2];
    wire [ADDRESS_BITS-1:0] EIndex = PC_E[ADDRESS_BITS+1:2];
    wire Taken_E = |PCSrc_E;
    wire Conditional_E = Opcode_E == 7'h63;
    wire Jump_E = Opcode_E == 7'h6f || Opcode_E == 7'h67;
    reg [31:0] Targets [0:TABLE_ENTRIES-1];
    reg [29-ADDRESS_BITS:0] Tags [0:TABLE_ENTRIES-1];
    reg [1:0] Counters [0:TABLE_ENTRIES-1];
    reg Valid [0:TABLE_ENTRIES-1];
    wire Hit_F = Valid[FIndex] && Tags[FIndex] == PC_F[31:ADDRESS_BITS+2];
    wire Hit_E = Valid[EIndex] && Tags[EIndex] == PC_E[31:ADDRESS_BITS+2];
    integer i;

    assign PrPCF = Hit_F && Counters[FIndex][1] ? Targets[FIndex] : PC_F + 32'd4;
    assign Mispredict = Resolve_E && !RESET && PredictedNext_E != PCNext_E;

    always @(posedge CLK) begin
        if (RESET) begin
            for (i = 0; i < TABLE_ENTRIES; i = i + 1) begin
                Valid[i] <= 0;
                Counters[i] <= 0;
            end
        end
        else if (Enable && Resolve_E && (Conditional_E || Jump_E)) begin
            Valid[EIndex] <= 1;
            Tags[EIndex] <= PC_E[31:ADDRESS_BITS+2];
            if (Taken_E) Targets[EIndex] <= PCNext_E;
            if (Jump_E) Counters[EIndex] <= 2'b11;
            else if (!Hit_E) Counters[EIndex] <= Taken_E ? 2'b01 : 2'b00;
            else if (Taken_E && Counters[EIndex] != 2'b11)
                Counters[EIndex] <= Counters[EIndex] + 1'b1;
            else if (!Taken_E && Counters[EIndex] != 2'b00)
                Counters[EIndex] <= Counters[EIndex] - 1'b1;
        end
    end
endmodule
