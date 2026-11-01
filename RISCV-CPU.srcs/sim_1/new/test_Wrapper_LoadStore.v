`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/01/2026 10:56:14 AM
// Design Name: 
// Module Name: test_Wrapper_LoadStore
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_Wrapper_LoadStore #(
    parameter N_LEDs_OUT = 8,
    parameter N_DIPs = 16,
    parameter N_PBs = 3,
    parameter init_DIPs = 16'ha80f,
    parameter [31:0] DMEM_BASE = 32'h10010000   // <-- set to your data memory base address
);
    reg CLK = 0;
    reg RESET = 1;
    wire [N_LEDs_OUT-1:0] LED_OUT;
    integer checks = 0;
    integer error_count = 0;
    integer index;
    integer pc_i;
    reg [3:0] exp_en;

    Wrapper #(.N_LEDs_OUT(N_LEDs_OUT), .N_DIPs(N_DIPs), .N_PBs(N_PBs)) dut(
        .DIP(init_DIPs), .PB({N_PBs{1'b0}}), .LED_OUT(LED_OUT),
        .UART_TX_ready(1'b1), .UART_RX(8'd0), .UART_RX_valid(1'b0),
        .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0), .RESET(RESET), .CLK(CLK)
    );

    always #5 CLK = ~CLK;

    // ---------------------------------------------------------------
    // Tiny assembler: each task encodes one instruction into IROM
    // ---------------------------------------------------------------
    task emit; input [31:0] w;
        begin dut.IROM[pc_i] = w; pc_i = pc_i + 1; end
    endtask
    task LD;   input [2:0] f3; input [4:0] rd;  input [11:0] imm; input [4:0] rs1;
        begin emit({imm, rs1, f3, rd, 7'h03}); end
    endtask
    task ST;   input [2:0] f3; input [4:0] rs2; input [11:0] imm; input [4:0] rs1;
        begin emit({imm[11:5], rs2, rs1, f3, imm[4:0], 7'h23}); end
    endtask
    task ADDI; input [4:0] rd; input [4:0] rs1; input [11:0] imm;
        begin emit({imm, rs1, 3'b000, rd, 7'h13}); end
    endtask
    task ADD;  input [4:0] rd; input [4:0] rs1; input [4:0] rs2;
        begin emit({7'b0, rs2, rs1, 3'b000, rd, 7'h33}); end
    endtask
    task LUI;  input [4:0] rd; input [19:0] imm;
        begin emit({imm, rd, 7'h37}); end
    endtask

    localparam [2:0] F_B = 3'b000, F_H = 3'b001, F_W = 3'b010, F_BU = 3'b100, F_HU = 3'b101;

    task check32;
        input [31:0] actual, expected;
        input [255:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s expected %h, got %h", label, expected, actual);
                error_count = error_count + 1;
            end
            else
                $display("PASS: %0s = %h", label, actual);
            checks = checks + 1;
        end
    endtask

    // ---------------------------------------------------------------
    // Monitor: every store seen at the memory interface (M stage)
    // checks that the byte enables match the store size / address.
    // ---------------------------------------------------------------
    always @(posedge CLK) begin
        if (!RESET && dut.RV1.MemWrite_out !== 4'b0000) begin
            case (dut.RV1.Funct3_M[1:0])
                2'b00:   exp_en = 4'b0001 << dut.RV1.ALUResult[1:0];                 // sb
                2'b01:   exp_en = dut.RV1.ALUResult[1] ? 4'b1100 : 4'b0011;          // sh
                default: exp_en = 4'b1111;                                           // sw
            endcase
            $display("STORE @%h  data=%h  en=%b  (funct3=%b, PC=%h)",
                     dut.RV1.ALUResult, dut.RV1.WriteData_out, dut.RV1.MemWrite_out,
                     dut.RV1.Funct3_M, dut.RV1.PC_M);
            if (dut.RV1.MemWrite_out !== exp_en) begin
                $display("FAIL: byte enable mismatch, expected %b", exp_en);
                error_count = error_count + 1;
            end
            if (dut.RV1.Funct3_M[1:0] == 2'b01 && dut.RV1.ALUResult[0] !== 1'b0) begin
                $display("FAIL: misaligned sh at %h", dut.RV1.ALUResult);
                error_count = error_count + 1;
            end
            if (dut.RV1.Funct3_M[1:0] == 2'b10 && dut.RV1.ALUResult[1:0] !== 2'b00) begin
                $display("FAIL: misaligned sw at %h", dut.RV1.ALUResult);
                error_count = error_count + 1;
            end
        end
    end

    // Monitor: trace every load as it writes back (W stage), after extension
    always @(posedge CLK) begin
        if (!RESET && dut.RV1.Valid_W && dut.RV1.WE && dut.RV1.Instr_W[6:0] == 7'h03)
            $display("LOAD  x%0d <= %h  (addr=%h, funct3=%b, raw word=%h, PC=%h)",
                     dut.RV1.rd_W, dut.RV1.WD_W, dut.RV1.ALUResult_W,
                     dut.RV1.Funct3_W, dut.RV1.ReadData_W, dut.RV1.PC_W);
    end

    initial begin
        #1;
        // ---------------- Instruction memory ----------------
        for (index = 0; index < 128; index = index + 1) dut.IROM[index] = 32'h00000013; // nop
        pc_i = 0;

        // x1 = DMEM_BASE
        LUI (5'd1, (DMEM_BASE + 32'h800) >> 12);
        ADDI(5'd1, 5'd1, DMEM_BASE[11:0]);

        // ---- Load tests. DMEM[0]=807FFF81 (bytes 81,FF,7F,80), DMEM[1]=12347FFE ----
        LD(F_B,  5'd5,  12'd0, 5'd1);   // lb  x5  <- byte0 0x81 -> FFFFFF81
        LD(F_B,  5'd6,  12'd1, 5'd1);   // lb  x6  <- byte1 0xFF -> FFFFFFFF
        LD(F_B,  5'd7,  12'd2, 5'd1);   // lb  x7  <- byte2 0x7F -> 0000007F
        LD(F_B,  5'd8,  12'd3, 5'd1);   // lb  x8  <- byte3 0x80 -> FFFFFF80
        LD(F_BU, 5'd9,  12'd0, 5'd1);   // lbu x9  -> 00000081
        LD(F_BU, 5'd10, 12'd1, 5'd1);   // lbu x10 -> 000000FF
        LD(F_BU, 5'd11, 12'd2, 5'd1);   // lbu x11 -> 0000007F
        LD(F_BU, 5'd12, 12'd3, 5'd1);   // lbu x12 -> 00000080
        LD(F_H,  5'd13, 12'd0, 5'd1);   // lh  x13 <- 0xFF81 -> FFFFFF81
        LD(F_H,  5'd14, 12'd2, 5'd1);   // lh  x14 <- 0x807F -> FFFF807F
        LD(F_HU, 5'd15, 12'd0, 5'd1);   // lhu x15 -> 0000FF81
        LD(F_HU, 5'd16, 12'd2, 5'd1);   // lhu x16 -> 0000807F
        LD(F_H,  5'd17, 12'd4, 5'd1);   // lh  x17 <- 0x7FFE -> 00007FFE (positive)
        LD(F_HU, 5'd18, 12'd6, 5'd1);   // lhu x18 <- 0x1234 -> 00001234
        LD(F_W,  5'd19, 12'd0, 5'd1);   // lw  x19 -> 807FFF81
        LD(F_B,  5'd20, 12'd4, 5'd1);   // lb  x20 <- 0xFE -> FFFFFFFE

        // ---- Load-use / forwarding of EXTENDED data ----
        LD(F_B,  5'd21, 12'd0, 5'd1);   // lb  x21 = FFFFFF81
        ST(F_B,  5'd21, 12'd28, 5'd1);  // sb x21 -> DMEM[7] byte0 (store data forwarded from load)
        ADD (5'd22, 5'd21, 5'd21);      // x22 = FFFFFF02 (load-use at distance 2)
        LD(F_BU, 5'd23, 12'd1, 5'd1);   // lbu x23 = 000000FF
        ADDI(5'd24, 5'd23, 12'd1);      // x24 = 00000100 (load-use at distance 1)

        // ---- Store tests ----
        LUI (5'd25, 20'hA1B2C);
        ADDI(5'd25, 5'd25, 12'h3D4);    // x25 = A1B2C3D4
        ADDI(5'd26, 5'd0, 12'h11);
        ADDI(5'd27, 5'd0, 12'h22);
        ADDI(5'd28, 5'd0, 12'h33);
        ADDI(5'd29, 5'd0, 12'h44);
        ST(F_B, 5'd26, 12'd8,  5'd1);   // sb -> DMEM[2] byte0
        ST(F_B, 5'd27, 12'd9,  5'd1);   // sb -> DMEM[2] byte1
        ST(F_B, 5'd28, 12'd10, 5'd1);   // sb -> DMEM[2] byte2
        ST(F_B, 5'd29, 12'd11, 5'd1);   // sb -> DMEM[2] byte3   => 44332211
        LD(F_W, 5'd2,  12'd8,  5'd1);   // lw right after the store (store-to-load) => 44332211
        ST(F_B, 5'd26, 12'd13, 5'd1);   // sb -> DMEM[3] byte1 only      => FFFF11FF
        ST(F_H, 5'd25, 12'd16, 5'd1);   // sh -> DMEM[4] lower half      => FFFFC3D4
        ST(F_H, 5'd25, 12'd22, 5'd1);   // sh -> DMEM[5] upper half      => C3D4FFFF
        ST(F_W, 5'd25, 12'd24, 5'd1);   // sw -> DMEM[6]                 => A1B2C3D4

        // ---- Read back what was stored through the load path ----
        LD(F_B,  5'd3,  12'd10, 5'd1);  // lb  x3  <- 0x33 -> 00000033
        LD(F_H,  5'd30, 12'd16, 5'd1);  // lh  x30 <- 0xC3D4 -> FFFFC3D4
        LD(F_HU, 5'd4,  12'd22, 5'd1);  // lhu x4  -> 0000C3D4

        // Let the pipeline drain, then raise the done sentinel and park
        ADDI(5'd0, 5'd0, 12'd0);
        ADDI(5'd0, 5'd0, 12'd0);
        ADDI(5'd0, 5'd0, 12'd0);
        ADDI(5'd0, 5'd0, 12'd0);
        ADDI(5'd31, 5'd0, 12'd1);       // x31 = 1 -> done
        emit(32'h0000006F);             // jal x0, 0  (loop forever)

        // ---------------- Data memory ----------------
        for (index = 0; index < 128; index = index + 1) dut.DMEM[index] = 0;
        dut.DMEM[0] = 32'h807FFF81;
        dut.DMEM[1] = 32'h12347FFE;
        dut.DMEM[2] = 32'hDEADBEEF;     // fully overwritten by 4x sb
        dut.DMEM[3] = 32'hFFFFFFFF;     // only byte1 must change
        dut.DMEM[4] = 32'hFFFFFFFF;     // only lower half must change
        dut.DMEM[5] = 32'hFFFFFFFF;     // only upper half must change
        dut.DMEM[6] = 32'h5A5A5A5A;     // fully overwritten by sw
        dut.DMEM[7] = 32'hFFFFFFFF;     // only byte0 must change

        repeat (3) @(negedge CLK);
        RESET = 0;
        wait (dut.RV1.RegFile1.RegBank[31] === 32'd1);
        repeat (2) @(negedge CLK);

        // ---------------- Register checks ----------------
        check32(dut.RV1.RegFile1.RegBank[5],  32'hFFFFFF81, "lb  byte0 neg");
        check32(dut.RV1.RegFile1.RegBank[6],  32'hFFFFFFFF, "lb  byte1 neg");
        check32(dut.RV1.RegFile1.RegBank[7],  32'h0000007F, "lb  byte2 pos");
        check32(dut.RV1.RegFile1.RegBank[8],  32'hFFFFFF80, "lb  byte3 neg");
        check32(dut.RV1.RegFile1.RegBank[9],  32'h00000081, "lbu byte0");
        check32(dut.RV1.RegFile1.RegBank[10], 32'h000000FF, "lbu byte1");
        check32(dut.RV1.RegFile1.RegBank[11], 32'h0000007F, "lbu byte2");
        check32(dut.RV1.RegFile1.RegBank[12], 32'h00000080, "lbu byte3");
        check32(dut.RV1.RegFile1.RegBank[13], 32'hFFFFFF81, "lh  low neg");
        check32(dut.RV1.RegFile1.RegBank[14], 32'hFFFF807F, "lh  high neg");
        check32(dut.RV1.RegFile1.RegBank[15], 32'h0000FF81, "lhu low");
        check32(dut.RV1.RegFile1.RegBank[16], 32'h0000807F, "lhu high");
        check32(dut.RV1.RegFile1.RegBank[17], 32'h00007FFE, "lh  pos");
        check32(dut.RV1.RegFile1.RegBank[18], 32'h00001234, "lhu pos");
        check32(dut.RV1.RegFile1.RegBank[19], 32'h807FFF81, "lw");
        check32(dut.RV1.RegFile1.RegBank[20], 32'hFFFFFFFE, "lb  next word");
        check32(dut.RV1.RegFile1.RegBank[22], 32'hFFFFFF02, "load-use dist 2 (lb)");
        check32(dut.RV1.RegFile1.RegBank[24], 32'h00000100, "load-use dist 1 (lbu)");
        check32(dut.RV1.RegFile1.RegBank[2],  32'h44332211, "store->load lw");
        check32(dut.RV1.RegFile1.RegBank[3],  32'h00000033, "readback lb");
        check32(dut.RV1.RegFile1.RegBank[30], 32'hFFFFC3D4, "readback lh");
        check32(dut.RV1.RegFile1.RegBank[4],  32'h0000C3D4, "readback lhu");

        // ---------------- Memory checks ----------------
        check32(dut.DMEM[2], 32'h44332211, "sb x4 lanes");
        check32(dut.DMEM[3], 32'hFFFF11FF, "sb only byte1");
        check32(dut.DMEM[4], 32'hFFFFC3D4, "sh lower half");
        check32(dut.DMEM[5], 32'hC3D4FFFF, "sh upper half");
        check32(dut.DMEM[6], 32'hA1B2C3D4, "sw");
        check32(dut.DMEM[7], 32'hFFFFFF81, "sb from loaded reg (fwd)");
        check32(dut.DMEM[0], 32'h807FFF81, "source word untouched");
        check32(dut.DMEM[1], 32'h12347FFE, "source word 1 untouched");

        if (error_count != 0)
            $fatal(1, "%0d load/store test failure(s)", error_count);
        $display("ALL LOAD/STORE TESTS PASSED (%0d checks)", checks);
        $finish;
    end

    initial begin
        #200_000;
        $fatal(1, "Load/store testbench timeout");
    end
endmodule