`timescale 1ns / 1ps
module DebugSnapshot #(
    parameter WIDTH = 768
)(
    input SourceCLK, SourceRESET,
    input [WIDTH-1:0] SourceData,
    input DisplayCLK, DisplayRESET,
    output reg [WIDTH-1:0] Snapshot = 0,
    output reg Updated = 0
);
    reg [WIDTH-1:0] Payload = 0;
    reg Request = 0, Acknowledge = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] AckSync = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] RequestSync = 0;
    always @(posedge SourceCLK) begin
        AckSync <= {AckSync[0], Acknowledge};
        if (SourceRESET) begin
            AckSync <= 0;
            Request <= 0;
            Payload <= 0;
        end
        else if (AckSync[1] == Request) begin
            Payload <= SourceData;
            Request <= !Request;
        end
    end
    always @(posedge DisplayCLK) begin
        RequestSync <= {RequestSync[0], Request};
        Updated <= 0;
        if (DisplayRESET) begin
            RequestSync <= 0;
            Acknowledge <= 0;
            Snapshot <= 0;
        end
        else if (RequestSync[1] != Acknowledge) begin
            Snapshot <= Payload;
            Acknowledge <= RequestSync[1];
            Updated <= 1;
        end
    end
endmodule
