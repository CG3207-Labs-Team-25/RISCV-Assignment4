`timescale 1ns / 1ps


// Can change the address bits to indicate how many address to look for 
// also how many entries of this history tables
// The history replacement algorithm is direct mapping
// BHT with 2-bit accuracy
// insert stage E and F PC, translates into cache index to see the cache
module BranchPrediction #(
    parameter ADDRESS_BITS = 8,      // should be at least bigger than table entries bits for direct mapping
    parameter TABLE_ENTRIES = 2**ADDRESS_BITS
)(
    input CLK,
    input RESET,
    input [31:0] PCNext_E,          // input for PrBTA table
    input [31:0] PC_F,              // address for prediction, no need prediction just use adder
    input [31:0] PC_E,              // address for writing the BHT, should be ADDRESS_BITS
    input [1:0] PCSrc_E,
    output Mispredict,
    output [31:0] PrPCF
);

    wire [ADDRESS_BITS-1:0] PC_F_index;// index for find F stage info
    reg [31:0] PrBTA_F;            // prediction address for F stage
    wire [31:0] Direct_F;           // direct next instruction for F stage
    reg [1:0] PrTaken_F;           // taken bit for prediction

    wire [ADDRESS_BITS-1:0] PC_E_index;// index for find E stage info
    wire BTA_Mispredict;            // predict BTA is mismatch
    wire Br_Mispredict;             // Wrong predict about taking branch or not
    reg [31:0] PrBTA_E;            // previous prediction address for E stage comparision and update
    reg [1:0] PrTaken_E;           // taken bit of revious prediction
    wire Taken_E;                   // Does the branch taken ?

    // BHT with 2-bit accuracy, needs to be initialized for the PrTaken
    reg [31:0] PrBTA [0: TABLE_ENTRIES - 1];
    reg [1:0] PrTaken [0: TABLE_ENTRIES - 1];
    reg Valid [0:TABLE_ENTRIES-1];
    integer i;
    
    // assign the logic
    assign PC_E_index = PC_E[ADDRESS_BITS+1:2];
    assign PC_F_index = PC_F[ADDRESS_BITS+1:2];
    assign Direct_F = PC_F + 32'h4;
    
    assign PrPCF = (PrTaken_F[1] == 1'b1) ? PrBTA_F : Direct_F;
    assign Taken_E = PCSrc_E[0] | PCSrc_E[1];
    assign Br_Mispredict = Taken_E ^ PrTaken_E[1]; // First bit indicated if it did take,
    assign BTA_Mispredict = Taken_E && (PrBTA_E != PCNext_E); // And fail result of comparsion and Taken E
    assign Mispredict = Br_Mispredict | BTA_Mispredict;

    // Reading of BTA and accuracy
    always @(*)
    begin 
        PrBTA_F = Valid[PC_F_index] ?
                    PrBTA[PC_F_index] : 32'b0;
        PrTaken_F = PrTaken[PC_F_index];
        PrBTA_E = Valid[PC_F_index] ?
                    PrBTA[PC_F_index] : 32'b0;
        PrTaken_E = PrTaken[PC_E_index];
    end
    
    // Writing of BTA and accuracy and valid
    always @(posedge CLK) begin
        if (RESET) begin
            // Reset only valid bits and prediction counters.
            // BTA does not need to be reset.
            for (i = 0; i < TABLE_ENTRIES; i = i + 1) begin
                Valid[i] <= 1'b0;
                PrTaken[i] <= 2'b00;
            end
        end
        else begin
            if (Taken_E) begin // update when branch taken
                if (!Valid[PC_E_index] ||
                    (PrBTA[PC_E_index] != PCNext_E)) begin // either BTA mismatch or valid is failed
                    PrBTA[PC_E_index] <= PCNext_E;
                    Valid[PC_E_index] <= 1'b1;
                end
            end
            
            if (Br_Mispredict) begin // Update counter
                if (Taken_E) begin
                    // Increment: saturate at 11
                    if (PrTaken[PC_E_index] != 2'b11) begin
                        PrTaken[PC_E_index] <= PrTaken[PC_E_index] + 1'b1;
                    end
                end
                else begin
                    // Decrement: saturate at 00
                    if (PrTaken[PC_E_index] != 2'b00) begin
                        PrTaken[PC_E_index] <= PrTaken[PC_E_index] - 1'b1;
                    end
                end

            end

        end

    end
endmodule
