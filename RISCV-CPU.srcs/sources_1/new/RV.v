`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
-- Company: NUS	
-- Engineer: (c) Rajesh Panicker  
-- 
-- Create Date: 09/22/2020 06:49:10 PM
-- Module Name: RV
-- Project Name: CG3207 Project
-- Target Devices: Nexys 4 / Basys 3
-- Tool Versions: Vivado 2019.2
-- Description: RISC-V Processor Module
-- 
-- Dependencies: NIL
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: The interface SHOULD NOT be modified (except making output reg) unless you modify Wrapper.v/vhd too. 
                        The implementation can be modified.
-- 
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post it on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh<dot>panicker<at>ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(vi) retain this notice in this file as well as any files derived from this.
----------------------------------------------------------------------------------
*/

// Change wire to reg if assigned inside a procedural (always) block. However, where it is easy enough, use assign instead of always.
// A 2-1 multiplexing can be done easily using an assign with a ternary operator
// For multiplexing with number of inputs > 2, a case construct within an always block is a natural fit. DO NOT to use nested ternary assignment operator as it hampers the readability of your code.


module RV #(
    parameter PC_INIT = 32'h00400000
)(
    input CLK,
    input RESET,
    //input Interrupt,      // for optional future use.
    input [31:0] Instr,
    input [31:0] ReadData_in,       // Name mangled to support lb/lbu/lh/lhu
    output MemRead,
    output [3:0] MemWrite_out,		// Column-wise write enable to support sb/sw. Each column is a byte.
    output [31:0] PC,
    output [31:0] ALUResult,
    output [31:0] WriteData_out		// Name mangled to support sb/sw
);

    wire [31:0] Instr_F;
    wire [31:0] PC_F;

    reg [31:0] Instr_D = 0;
    reg [31:0] PC_D = 0;
    reg Valid_D = 0;
    wire [4:0] rs1_D;
    wire [4:0] rs2_D;
    wire [4:0] rd_D;
    wire [31:0] RD1_D;
    wire [31:0] RD2_D;
    wire [24:0] InstrImm_D;
    wire [31:0] ExtImm_D;
    wire [6:0] Opcode_D;
    wire [2:0] Funct3_D;
    wire [6:0] Funct7_D;
    wire [1:0] PCS_D;
    wire RegWrite_D;
    wire MemWrite_D;
    wire [1:0] MemtoReg_D;
    wire [1:0] ALUSrcA_D;
    wire [1:0] ALUSrcB_D;
    wire [2:0] ImmSrc_D;
    wire [3:0] ALUControl_D;
    wire [1:0] MCycleOp_D;
    wire Start_D;

    reg [31:0] Instr_E = 32'h00000013;
    reg [31:0] PC_E = 0;
    reg [31:0] RD1_E = 0;
    reg [31:0] RD2_E = 0;
    reg [31:0] ExtImm_E = 0;
    reg [4:0] rd_E = 0;
    reg [2:0] Funct3_E = 0;
    reg [1:0] PCS_E = 0;
    reg RegWrite_E = 0;
    reg MemWrite_E = 0;
    reg [1:0] MemtoReg_E = 0;
    reg [1:0] ALUSrcA_E = 0;
    reg [1:0] ALUSrcB_E = 0;
    reg [3:0] ALUControl_E = 0;
    reg [1:0] MCycleOp_E = 0;
    reg Start_E = 0;
    reg Valid_E = 0;
    reg [31:0] Src_A_E;
    reg [31:0] Src_B_E;
    wire [31:0] ALUResult_E;
    wire [2:0] ALUFlags_E;
    wire [1:0] PCSrc_E;
    wire [31:0] Result1_E;
    wire [31:0] Result2_E;
    reg [31:0] ExecutionResult_E;
    wire [1:0] PCS_Active_E;
    wire Start_Active_E;
    wire Busy;

    reg [31:0] Instr_M = 32'h00000013;
    reg [31:0] PC_M = 0;
    reg [31:0] ALUResult_M = 0;
    reg [31:0] WriteData_M = 0;
    reg [4:0] rd_M = 0;
    reg RegWrite_M = 0;
    reg MemWrite_M = 0;
    reg [1:0] MemtoReg_M = 0;
    reg Valid_M = 0;
    wire [31:0] ReadData_M;

    reg [31:0] Instr_W = 32'h00000013;
    reg [31:0] PC_W = 0;
    reg [31:0] ALUResult_W = 0;
    reg [31:0] ReadData_W = 0;
    reg [4:0] rd_W = 0;
    reg RegWrite_W = 0;
    reg [1:0] MemtoReg_W = 0;
    reg Valid_W = 0;
    reg [31:0] WD_W;
    wire WE;
    wire WE_PC;
    reg [31:0] PC_Base;
    reg [31:0] PC_Offset;
    wire [31:0] PC_ALU;
    wire [31:0] PC_IN;
    wire [31:0] PC_Sum;
    reg [4:0] rs1_E = 0;
    reg [4:0] rs2_E = 0;
    reg [4:0] rs2_M = 0;
    wire LoadStall;
    wire Redirect_E;
    wire StallF;
    wire StallD;
    wire FlushD;
    wire FlushE;
    wire Forward1D;
    wire Forward2D;
    wire [1:0] ForwardAE;
    wire [1:0] ForwardBE;
    wire ForwardM;
    wire [31:0] DecodeRD1_D;
    wire [31:0] DecodeRD2_D;
    reg [31:0] ForwardRD1_E;
    reg [31:0] ForwardRD2_E;
    wire [31:0] Operand1_E;
    wire [31:0] Operand2_E;
    reg OperandsHeld_E = 0;
    reg [31:0] HeldRD1_E = 0;
    reg [31:0] HeldRD2_E = 0;
    wire Mispredict;
    wire [31:0] PrPC_F;

    assign Instr_F = Instr;
    assign PC = PC_F;
    assign rs1_D = Instr_D[19:15];
    assign rs2_D = Instr_D[24:20];
    assign rd_D = Instr_D[11:7];
    assign InstrImm_D = Instr_D[31:7];
    assign Opcode_D = Instr_D[6:0];
    assign Funct3_D = Instr_D[14:12];
    assign Funct7_D = Instr_D[31:25];

    HazardUnit HazardUnit1(
        .RESET(RESET),
        .Busy(Busy),
        .Valid_D(Valid_D),
        .Valid_E(Valid_E),
        .Valid_M(Valid_M),
        .Opcode_D(Opcode_D),
        .rs1_D(rs1_D),
        .rs2_D(rs2_D),
        .rs1_E(rs1_E),
        .rs2_E(rs2_E),
        .rs2_M(rs2_M),
        .rd_E(rd_E),
        .rd_M(rd_M),
        .rd_W(rd_W),
        .RegWrite_E(RegWrite_E),
        .RegWrite_M(RegWrite_M),
        .WE_W(WE),
        .MemWrite_M(MemWrite_M),
        .MemtoReg_E(MemtoReg_E),
        .MemtoReg_M(MemtoReg_M),
        .MemtoReg_W(MemtoReg_W),
        .PCSrc_E(PCSrc_E),
        .Mispredict(Mispredict),
        .LoadStall(LoadStall),
        .Redirect_E(Redirect_E),
        .StallF(StallF),
        .StallD(StallD),
        .FlushD(FlushD),
        .FlushE(FlushE),
        .Forward1D(Forward1D),
        .Forward2D(Forward2D),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .ForwardM(ForwardM)
    );

    assign DecodeRD1_D = Forward1D ? WD_W : RD1_D;
    assign DecodeRD2_D = Forward2D ? WD_W : RD2_D;

    always @(*) begin
        case (ForwardAE)
            2'b10: ForwardRD1_E = ALUResult_M;
            2'b01: ForwardRD1_E = WD_W;
            default: ForwardRD1_E = RD1_E;
        endcase
        case (ForwardBE)
            2'b10: ForwardRD2_E = ALUResult_M;
            2'b01: ForwardRD2_E = WD_W;
            default: ForwardRD2_E = RD2_E;
        endcase
    end

    assign Operand1_E = OperandsHeld_E ? HeldRD1_E : ForwardRD1_E;
    assign Operand2_E = OperandsHeld_E ? HeldRD2_E : ForwardRD2_E;

    always @(posedge CLK) begin
        if (RESET || !Busy) begin
            OperandsHeld_E <= 0;
            HeldRD1_E <= 0;
            HeldRD2_E <= 0;
        end
        else if (!OperandsHeld_E) begin
            OperandsHeld_E <= 1;
            HeldRD1_E <= ForwardRD1_E;
            HeldRD2_E <= ForwardRD2_E;
        end
    end

    always @(posedge CLK) begin
        if (RESET || FlushE) begin
            rs1_E <= 0;
            rs2_E <= 0;
        end
        else if (!Busy) begin
            rs1_E <= rs1_D;
            rs2_E <= rs2_D;
        end
        if (RESET || Busy) rs2_M <= 0;
        else rs2_M <= rs2_E;
    end

    always @(posedge CLK) begin
        if (RESET || FlushD) begin
            Instr_D <= 32'h00000013;
            PC_D <= 0;
            Valid_D <= 0;
        end
        else if (!StallD) begin
            Instr_D <= Instr_F;
            PC_D <= PC_F;
            Valid_D <= 1;
        end
    end

    always @(posedge CLK) begin
        if (RESET || FlushE) begin
            Instr_E <= 32'h00000013;
            PC_E <= 0;
            RD1_E <= 0;
            RD2_E <= 0;
            ExtImm_E <= 0;
            rd_E <= 0;
            Funct3_E <= 0;
            PCS_E <= 0;
            RegWrite_E <= 0;
            MemWrite_E <= 0;
            MemtoReg_E <= 0;
            ALUSrcA_E <= 0;
            ALUSrcB_E <= 0;
            ALUControl_E <= 0;
            MCycleOp_E <= 0;
            Start_E <= 0;
            Valid_E <= 0;
        end
        else if (!Busy) begin
            Instr_E <= Instr_D;
            PC_E <= PC_D;
            RD1_E <= DecodeRD1_D;
            RD2_E <= DecodeRD2_D;
            ExtImm_E <= ExtImm_D;
            rd_E <= rd_D;
            Funct3_E <= Funct3_D;
            PCS_E <= PCS_D;
            RegWrite_E <= RegWrite_D;
            MemWrite_E <= MemWrite_D;
            MemtoReg_E <= MemtoReg_D;
            ALUSrcA_E <= ALUSrcA_D;
            ALUSrcB_E <= ALUSrcB_D;
            ALUControl_E <= ALUControl_D;
            MCycleOp_E <= MCycleOp_D;
            Start_E <= Start_D;
            Valid_E <= Valid_D;
        end
    end

    always @(posedge CLK) begin
        if (RESET || Busy) begin
            Instr_M <= 32'h00000013;
            PC_M <= 0;
            ALUResult_M <= 0;
            WriteData_M <= 0;
            rd_M <= 0;
            RegWrite_M <= 0;
            MemWrite_M <= 0;
            MemtoReg_M <= 0;
            Valid_M <= 0;
        end
        else begin
            Instr_M <= Instr_E;
            PC_M <= PC_E;
            ALUResult_M <= ExecutionResult_E;
            WriteData_M <= Operand2_E;
            rd_M <= rd_E;
            RegWrite_M <= RegWrite_E;
            MemWrite_M <= MemWrite_E;
            MemtoReg_M <= MemtoReg_E;
            Valid_M <= Valid_E;
        end
    end

    always @(posedge CLK) begin
        if (RESET) begin
            Instr_W <= 32'h00000013;
            PC_W <= 0;
            ALUResult_W <= 0;
            ReadData_W <= 0;
            rd_W <= 0;
            RegWrite_W <= 0;
            MemtoReg_W <= 0;
            Valid_W <= 0;
        end
        else begin
            Instr_W <= Instr_M;
            PC_W <= PC_M;
            ALUResult_W <= ALUResult_M;
            ReadData_W <= ReadData_M;
            rd_W <= rd_M;
            RegWrite_W <= RegWrite_M;
            MemtoReg_W <= MemtoReg_M;
            Valid_W <= Valid_M;
        end
    end

    assign ALUResult = ALUResult_M;
    assign WriteData_out = ForwardM ? WD_W : WriteData_M;
    assign MemWrite_out = {4{Valid_M & MemWrite_M & ~RESET}};
    assign MemRead = Valid_M & RegWrite_M & (MemtoReg_M == 2'b10) & ~RESET;
    assign ReadData_M = ReadData_in;

    always @(*) begin
        case (MemtoReg_E)
            2'b01: ExecutionResult_E = Result2_E;
            2'b11: ExecutionResult_E = Result1_E;
            default: ExecutionResult_E = ALUResult_E;
        endcase
    end

    always @(*) begin
        case (MemtoReg_W)
            2'b10: WD_W = ReadData_W;
            default: WD_W = ALUResult_W;
        endcase
    end

    assign WE = Valid_W & RegWrite_W & ~RESET;
    assign PCS_Active_E = Valid_E && !RESET ? PCS_E : 2'b00;
    assign Start_Active_E = Valid_E & Start_E & ~RESET;

    RegFile RegFile1(
        CLK,
        WE,
        rs1_D,
        rs2_D,
        rd_W,
        WD_W,
        RD1_D,
        RD2_D
    );

    Extend Extend1(
        ImmSrc_D,
        InstrImm_D,
        ExtImm_D
    );

    Decoder Decoder1(
        Opcode_D,
        Funct3_D,
        Funct7_D,
        PCS_D,
        RegWrite_D,
        MemWrite_D,
        MemtoReg_D,
        ALUSrcA_D,
        ALUSrcB_D,
        ImmSrc_D,
        ALUControl_D,
        MCycleOp_D,
        Start_D
    );

    PC_Logic PC_Logic1(
        PCS_Active_E,
        Funct3_E,
        ALUFlags_E,
        PCSrc_E
    );

    always @(*) begin
        casez (ALUSrcA_E)
            2'b?0: Src_A_E = Operand1_E;
            2'b01: Src_A_E = 32'b0;
            2'b11: Src_A_E = PC_E;
            default: Src_A_E = Operand1_E;
        endcase
        casez (ALUSrcB_E)
            2'b?0: Src_B_E = Operand2_E;
            2'b01: Src_B_E = 32'd4;
            2'b11: Src_B_E = ExtImm_E;
            default: Src_B_E = Operand2_E;
        endcase
    end

    ALU ALU1(
        Src_A_E,
        Src_B_E,
        ALUControl_E,
        ALUResult_E,
        ALUFlags_E
    );

    MCycle #(.width(32)) MCycle1(
        CLK,
        RESET,
        Start_Active_E,
        MCycleOp_E,
        Src_A_E,
        Src_B_E,
        Result1_E,
        Result2_E,
        Busy
    );

    always @(*) begin
        PC_Offset = 32'd4;
        case (PCSrc_E)
            2'b00: PC_Base = PC_E;
            2'b01: begin
                PC_Base = PC_E;
                PC_Offset = ExtImm_E;
            end
            2'b10: PC_Base = ForwardRD1_E;
            2'b11: begin
                PC_Base = ForwardRD1_E;
                PC_Offset = ExtImm_E;
            end
            default: PC_Base = PC_E;
        endcase
    end

    assign PC_Sum = PC_Base + PC_Offset;
    assign PC_ALU = {PC_Sum[31:1], PC_Sum[0] & ~PCSrc_E[1]};
    assign WE_PC = !StallF;
    assign PC_IN = (Mispredict) ? PC_ALU : PrPC_F;

    ProgramCounter #(.PC_INIT(PC_INIT)) ProgramCounter1(
        CLK,
        RESET,
        WE_PC,
        PC_IN,
        PC_F
    );

    BranchPrediction #(.ADDRESS_BITS(8)) BranchPredictor1(
        CLK,
        RESET,
        PC_ALU, // PCNextE
        PC_F,
        PC_E,
        PCSrc_E,
        Mispredict,
        PrPC_F
    );

endmodule
