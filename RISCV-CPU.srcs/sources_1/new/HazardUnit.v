`timescale 1ns / 1ps

module HazardUnit(
    input RESET,
    input Busy,
    input Valid_D,
    input Valid_E,
    input Valid_M,
    input [6:0] Opcode_D,
    input [4:0] rs1_D,
    input [4:0] rs2_D,
    input [4:0] rs1_E,
    input [4:0] rs2_E,
    input [4:0] rs2_M,
    input [4:0] rd_E,
    input [4:0] rd_M,
    input [4:0] rd_W,
    input RegWrite_E,
    input RegWrite_M,
    input WE_W,
    input MemWrite_M,
    input [1:0] MemtoReg_E,
    input [1:0] MemtoReg_M,
    input [1:0] MemtoReg_W,
    input [1:0] PCSrc_E,
    input Mispredict,
    output LoadStall,
    output Redirect_E,
    output StallF,
    output StallD,
    output FlushD,
    output FlushE,
    output Forward1D,
    output Forward2D,
    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE,
    output ForwardM
);
    wire UsesRs1_D;
    wire UsesRs2_D;

    assign UsesRs1_D = (Opcode_D == 7'h33) || (Opcode_D == 7'h13) ||
                       (Opcode_D == 7'h03) || (Opcode_D == 7'h23) ||
                       (Opcode_D == 7'h63) || (Opcode_D == 7'h67);
    assign UsesRs2_D = (Opcode_D == 7'h33) || (Opcode_D == 7'h63);
    assign LoadStall = Valid_D && Valid_E && RegWrite_E &&
                       (MemtoReg_E == 2'b10) && (rd_E != 0) &&
                       ((UsesRs1_D && rs1_D == rd_E) || (UsesRs2_D && rs2_D == rd_E));
    assign Redirect_E = Valid_E && !RESET && !Busy && (PCSrc_E != 2'b00);
    assign StallF = Busy || LoadStall;
    assign StallD = Busy || LoadStall;
    assign FlushD = Redirect_E || Mispredict;
    assign FlushE = !Busy && (LoadStall || Redirect_E || Mispredict);
    assign Forward1D = WE_W && (rd_W != 0) && (rs1_D == rd_W);
    assign Forward2D = WE_W && (rd_W != 0) && (rs2_D == rd_W);
    assign ForwardM = Valid_M && MemWrite_M && WE_W && (MemtoReg_W == 2'b10) &&
                      (rd_W != 0) && (rs2_M == rd_W);

    always @(*) begin
        ForwardAE = 2'b00;
        ForwardBE = 2'b00;
        if (Valid_E && rs1_E != 0) begin
            if (Valid_M && RegWrite_M && rd_M == rs1_E) begin
                if (MemtoReg_M != 2'b10) ForwardAE = 2'b10;
            end
            else if (WE_W && rd_W == rs1_E) ForwardAE = 2'b01;
        end
        if (Valid_E && rs2_E != 0) begin
            if (Valid_M && RegWrite_M && rd_M == rs2_E) begin
                if (MemtoReg_M != 2'b10) ForwardBE = 2'b10;
            end
            else if (WE_W && rd_W == rs2_E) ForwardBE = 2'b01;
        end
    end
endmodule
