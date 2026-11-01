`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
Self-checking testbench for the assigned RV32I instructions:
sll, srl, sra, slli, srli, srai, auipc, jal, and jalr.
----------------------------------------------------------------------------------
*/

module test_Wrapper_assigned;
	reg [15:0] DIP = 16'd0;
	reg [2:0] PB = 3'd0;
	wire [7:0] LED_OUT;
	wire [6:0] LED_PC;
	wire [31:0] SEVENSEGHEX;
	wire [7:0] UART_TX;
	reg UART_TX_ready = 1'b0;
	wire UART_TX_valid;
	reg [7:0] UART_RX = 8'd0;
	reg UART_RX_valid = 1'b0;
	wire UART_RX_ack;
	wire OLED_Write;
	wire [6:0] OLED_Col;
	wire [5:0] OLED_Row;
	wire [23:0] OLED_Data;
	reg [31:0] ACCEL_Data = 32'd0;
	reg ACCEL_DReady = 1'b0;
	reg RESET = 1'b1;
	reg CLK = 1'b0;
	integer errors = 0;
	integer index;

	Wrapper dut(
		.DIP(DIP),
		.PB(PB),
		.LED_OUT(LED_OUT),
		.LED_PC(LED_PC),
		.SEVENSEGHEX(SEVENSEGHEX),
		.UART_TX(UART_TX),
		.UART_TX_ready(UART_TX_ready),
		.UART_TX_valid(UART_TX_valid),
		.UART_RX(UART_RX),
		.UART_RX_valid(UART_RX_valid),
		.UART_RX_ack(UART_RX_ack),
		.OLED_Write(OLED_Write),
		.OLED_Col(OLED_Col),
		.OLED_Row(OLED_Row),
		.OLED_Data(OLED_Data),
		.ACCEL_Data(ACCEL_Data),
		.ACCEL_DReady(ACCEL_DReady),
		.RESET(RESET),
		.CLK(CLK), .Enable(1'b1)
	);

	function [31:0] encode_u;
		input [19:0] imm20;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			encode_u = {imm20, rd, opcode};
		end
	endfunction

	function [31:0] encode_r;
		input [6:0] funct7;
		input [4:0] rs2;
		input [4:0] rs1;
		input [2:0] funct3;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			encode_r = {funct7, rs2, rs1, funct3, rd, opcode};
		end
	endfunction

	function [31:0] encode_i;
		input [11:0] imm12;
		input [4:0] rs1;
		input [2:0] funct3;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			encode_i = {imm12, rs1, funct3, rd, opcode};
		end
	endfunction

	function [31:0] encode_j;
		input [20:0] offset;
		input [4:0] rd;
		begin
			encode_j = {offset[20], offset[10:1], offset[11],
			            offset[19:12], rd, 7'b1101111};
		end
	endfunction

	task check32;
		input [383:0] label;
		input [31:0] actual;
		input [31:0] expected;
		begin
			if(actual !== expected) begin
				$display("FAIL: %0s expected %h, got %h", label, expected, actual);
				errors = errors + 1;
			end
			else
				$display("PASS: %0s = %h", label, actual);
		end
	endtask

	always #5 CLK = ~CLK;

	initial begin

		#1;
        for (index = 0; index < 512; index = index + 1)
            dut.IROM[index] = 32'h00000013;
		dut.IROM[0]  = encode_u(20'h80000, 5'd1, 7'b0010111);
		dut.IROM[4]  = encode_u(20'h00000, 5'd2, 7'b0010111);
		dut.IROM[8]  = encode_r(7'b0000000, 5'd2, 5'd1, 3'b001, 5'd3, 7'b0110011);
		dut.IROM[12]  = encode_r(7'b0000000, 5'd2, 5'd1, 3'b101, 5'd4, 7'b0110011);
		dut.IROM[16]  = encode_r(7'b0100000, 5'd2, 5'd1, 3'b101, 5'd5, 7'b0110011);
		dut.IROM[20]  = encode_i(12'h004, 5'd1, 3'b001, 5'd6, 7'b0010011);
		dut.IROM[24]  = encode_i(12'h004, 5'd1, 3'b101, 5'd7, 7'b0010011);
		dut.IROM[28]  = encode_i(12'h404, 5'd1, 3'b101, 5'd8, 7'b0010011);
		dut.IROM[32]  = encode_j(21'd32, 5'd0);
		dut.IROM[36]  = encode_u(20'h11111, 5'd20, 7'b0010111);
		dut.IROM[40] = encode_j(21'd32, 5'd9);
		dut.IROM[44] = encode_u(20'h22222, 5'd20, 7'b0010111);
		dut.IROM[48] = encode_u(20'h00000, 5'd10, 7'b0010111);
		dut.IROM[52] = encode_i(12'h031, 5'd10, 3'b000, 5'd11, 7'b1100111);
		dut.IROM[56] = encode_u(20'h33333, 5'd20, 7'b0010111);
		dut.IROM[60] = encode_j(21'd0, 5'd0);


		dut.RV1.RegFile1.RegBank[0] = 32'hDEAD_BEEF;
		dut.RV1.RegFile1.RegBank[20] = 32'hCAFE_BABE;

		#11 RESET = 1'b0;
		wait (dut.RV1.Valid_W && dut.RV1.PC_W == 32'h004000f0);
		#1;

		check32("auipc source value", dut.RV1.RegFile1.RegBank[1], 32'h8040_0000);
		check32("register shift amount", dut.RV1.RegFile1.RegBank[2], 32'h0040_0010);
		check32("sll result", dut.RV1.RegFile1.RegBank[3], 32'h0000_0000);
		check32("srl result", dut.RV1.RegFile1.RegBank[4], 32'h0000_8040);
		check32("sra result", dut.RV1.RegFile1.RegBank[5], 32'hFFFF_8040);
		check32("slli result", dut.RV1.RegFile1.RegBank[6], 32'h0400_0000);
		check32("srli result", dut.RV1.RegFile1.RegBank[7], 32'h0804_0000);
		check32("srai result", dut.RV1.RegFile1.RegBank[8], 32'hF804_0000);
		check32("jal link", dut.RV1.RegFile1.RegBank[9], 32'h0040_00A4);
		check32("jalr base", dut.RV1.RegFile1.RegBank[10], 32'h0040_00C0);
		check32("jalr link", dut.RV1.RegFile1.RegBank[11], 32'h0040_00D4);
		check32("jalr target", dut.RV1.PC_W, 32'h0040_00F0);
		check32("skipped fall-through instructions", dut.RV1.RegFile1.RegBank[20], 32'hCAFE_BABE);
		check32("x0 write suppression", dut.RV1.RegFile1.RegBank[0], 32'hDEAD_BEEF);

		if(errors == 0)
			$display("ALL ASSIGNED-INSTRUCTION TESTS PASSED");
		else
			$fatal(1, "TEST FAILED WITH %0d ERROR(S)", errors);
		$finish;
	end

	initial begin
		#3000;
		$display("FAIL: testbench timeout");
		$fatal(1, "Assigned-instruction testbench timeout");
	end
endmodule

module test_Wrapper_MCycle #(
    parameter FINISH_ON_DONE = 1
)(
    output reg done = 0
);
    localparam [31:0] PC_BASE = 32'h00400000;
    reg CLK = 0;
    reg RESET = 1;
    reg monitoring = 0;
    reg [31:0] reference_regs [0:31];
    reg [31:0] reference_pc = PC_BASE;
    reg [31:0] reference_memory;
    reg [31:0] edge_values [0:8];
    reg [2:0] operations [0:6];
    integer words = 0;
    integer busy_cycles = 0;
    integer retirements = 0;
    integer programs = 0;
    integer multicycle_checks = 0;
    integer i, j, op;

    Wrapper dut(
        .DIP(16'd0),
        .PB(3'd0),
        .UART_TX_ready(1'b1),
        .UART_RX(8'd0),
        .UART_RX_valid(1'b0),
        .ACCEL_Data(32'd0),
        .ACCEL_DReady(1'b0),
        .RESET(RESET),
        .CLK(CLK), .Enable(1'b1)
    );

    always #5 CLK = ~CLK;

    function [31:0] encode_m;
        input [2:0] funct3;
        input [4:0] rd, rs1, rs2;
        begin
            encode_m = {7'b0000001, rs2, rs1, funct3, rd, 7'h33};
        end
    endfunction

    function [31:0] read_reference;
        input [4:0] index;
        begin
            read_reference = (index == 0) ? 32'd0 : reference_regs[index];
        end
    endfunction

    function [31:0] m_result;
        input [2:0] funct3;
        input [31:0] a, b;
        reg signed [63:0] signed_a, signed_b;
        reg [63:0] product;
        begin
            signed_a = {{32{a[31]}}, a};
            signed_b = {{32{b[31]}}, b};
            case (funct3)
                3'b000, 3'b001: begin
                    product = signed_a * signed_b;
                    m_result = (funct3 == 0) ? product[31:0] : product[63:32];
                end
                3'b011: begin
                    product = {32'd0, a} * {32'd0, b};
                    m_result = product[63:32];
                end
                3'b100, 3'b110: begin
                    if (b == 0) $fatal(1, "Zero signed divisor in CPU test");
                    m_result = (funct3 == 4) ? signed_a / signed_b : signed_a % signed_b;
                end
                3'b101, 3'b111: begin
                    if (b == 0) $fatal(1, "Zero unsigned divisor in CPU test");
                    m_result = (funct3 == 5) ? a / b : a % b;
                end
                default: $fatal(1, "Unsupported M instruction in CPU test");
            endcase
        end
    endfunction

    always @(posedge CLK) begin : scoreboard
        reg [31:0] instruction, a, b, result, address, stalled_pc;
        reg [4:0] rd;
        reg write_expected, was_busy;
        integer expected_cycles;
        integer reg_index;
        if (monitoring && !RESET) begin
            was_busy = dut.RV1.Busy;
            stalled_pc = dut.PC;
            if (dut.RV1.Busy === 1'b1) begin
                if (!dut.RV1.Valid_E || !dut.RV1.Start_E || dut.RV1.WE_PC !== 0)
                    $fatal(1, "Incorrect multicycle execution stall");
                busy_cycles = busy_cycles + 1;
            end
            else if (dut.RV1.Busy === 1'b0 && busy_cycles > 0) begin
                expected_cycles = (dut.RV1.Funct3_E == 0 || dut.RV1.Funct3_E == 1) ? 16 : 32;
                if (busy_cycles != expected_cycles)
                    $fatal(1, "CPU M instruction cycles=%0d expected=%0d", busy_cycles, expected_cycles);
                multicycle_checks = multicycle_checks + 1;
                busy_cycles = 0;
            end
            else if (dut.RV1.Busy !== 1'b0)
                $fatal(1, "Unknown CPU Busy signal");

            if (dut.RV1.Valid_M) begin
                if (dut.RV1.Instr_M[6:0] == 7'h23 && dut.MemWrite_out !== 4'b1111)
                    $fatal(1, "Missing M-stage store enable");
                if (dut.RV1.Instr_M[6:0] == 7'h03 && dut.MemRead !== 1'b1)
                    $fatal(1, "Missing M-stage load enable");
            end
            else if (dut.MemWrite_out !== 0 || dut.MemRead !== 0)
                $fatal(1, "Invalid M-stage entry accessed memory");

            if (dut.RV1.Valid_W) begin
                if (dut.RV1.PC_W !== reference_pc)
                    $fatal(1, "Retirement PC mismatch: actual=%h expected=%h", dut.RV1.PC_W, reference_pc);
                instruction = dut.RV1.Instr_W;
                a = read_reference(instruction[19:15]);
                b = read_reference(instruction[24:20]);
                rd = instruction[11:7];
                result = 0;
                write_expected = 0;
                case (instruction[6:0])
                    7'h37: begin
                        result = {instruction[31:12], 12'd0};
                        write_expected = 1;
                    end
                    7'h13: begin
                        if (instruction[14:12] != 0) $fatal(1, "Unsupported immediate instruction");
                        result = a + {{20{instruction[31]}}, instruction[31:20]};
                        write_expected = 1;
                    end
                    7'h33: begin
                        write_expected = 1;
                        if (instruction[31:25] == 7'h01) begin
                            result = m_result(instruction[14:12], a, b);
                            retirements = retirements + 1;
                        end
                        else begin
                            if (instruction[31:25] != 0 || instruction[14:12] != 0)
                                $fatal(1, "Unsupported register instruction");
                            result = a + b;
                        end
                    end
                    7'h23: begin
                        address = a + {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                        if (address !== 32'h10010000 || instruction[14:12] != 2)
                            $fatal(1, "Incorrect dependent store");
                        reference_memory = b;
                        if (dut.DMEM[0] !== reference_memory) $fatal(1, "Dependent store result mismatch");
                    end
                    7'h03: begin
                        address = a + {{20{instruction[31]}}, instruction[31:20]};
                        if (address !== 32'h10010000 || instruction[14:12] != 2)
                            $fatal(1, "Incorrect dependent load");
                        result = reference_memory;
                        write_expected = 1;
                    end
                    7'h6f: begin
                        if (instruction !== 32'h0000006f) $fatal(1, "Unsupported jump in CPU test");
                        result = dut.RV1.PC_W + 4;
                        write_expected = 1;
                    end
                    default: $fatal(1, "Unknown CPU instruction: %h", instruction);
                endcase
                if (dut.RV1.WE !== write_expected)
                    $fatal(1, "Incorrect retirement write enable");
                if (write_expected && dut.RV1.WD_W !== result)
                    $fatal(1, "Writeback data mismatch: actual=%h expected=%h", dut.RV1.WD_W, result);
                if (write_expected && rd != 0) reference_regs[rd] = result;
                if (instruction[6:0] != 7'h6f) reference_pc = reference_pc + 4;
            end
            else if (dut.RV1.WE !== 0)
                $fatal(1, "Invalid W-stage entry wrote a register");
            #1;
            if (was_busy && dut.PC !== stalled_pc) $fatal(1, "PC advanced while Busy");
            for (reg_index = 0; reg_index < 32; reg_index = reg_index + 1)
                if (dut.RV1.RegFile1.RegBank[reg_index] !== reference_regs[reg_index])
                    $fatal(1, "Register x%0d mismatch: actual=%h expected=%h",
                        reg_index, dut.RV1.RegFile1.RegBank[reg_index], reference_regs[reg_index]);
        end
    end

    task prepare_program;
        integer index;
        begin
            @(negedge CLK);
            monitoring = 0;
            RESET = 1;
            for (index = 0; index < 512; index = index + 1)
                dut.IROM[index] = 32'h00000013;
            for (index = 0; index < 32; index = index + 1) begin
                reference_regs[index] = 32'hcafe0000 + index;
                dut.RV1.RegFile1.RegBank[index] = reference_regs[index];
            end
            reference_memory = 32'hdeadbeef;
            dut.DMEM[0] = reference_memory;
            reference_pc = PC_BASE;
            words = 0;
            busy_cycles = 0;
            retirements = 0;
            @(posedge CLK);
            #2;
        end
    endtask

    task emit;
        input [31:0] instruction;
        begin
            if (words >= 512) $fatal(1, "CPU test program exceeds instruction memory");
            dut.IROM[words] = instruction;
            words = words + 1;
        end
    endtask

    task load_constant;
        input [4:0] rd;
        input [31:0] value;
        reg [31:0] upper;
        begin
            upper = value + 32'h800;
            emit({upper[31:12], rd, 7'h37});
            emit({value[11:0], rd, 3'b000, rd, 7'h13});
        end
    endtask

    task execute_program;
        input integer expected_retirements;
        reg [31:0] stop_pc;
        begin : execution
            stop_pc = PC_BASE + 4*words;
            emit(32'h0000006f);
            @(negedge CLK);
            monitoring = 1;
            RESET = 0;
            repeat (1000) begin
                @(posedge CLK);
                #2;
                if (dut.RV1.Valid_W && dut.RV1.PC_W === stop_pc) begin
                    if (retirements != expected_retirements || busy_cycles != 0)
                        $fatal(1, "Incorrect retirement count: %0d expected=%0d", retirements, expected_retirements);
                    monitoring = 0;
                    programs = programs + 1;
                    disable execution;
                end
            end
            $fatal(1, "CPU test program did not finish");
        end
    endtask

    task product_program;
        input [31:0] a, b;
        input [2:0] funct3;
        input [4:0] rd, rs1, rs2;
        begin
            prepare_program;
            load_constant(1, a);
            load_constant(2, b);
            load_constant(10, 32'h10010000);
            emit(encode_m(funct3, rd, rs1, rs2));
            emit({7'd0, 5'd1, rd, 3'b000, 5'd20, 7'h33});
            emit(encode_m(3'b000, 5'd21, 5'd20, 5'd2));
            emit({7'd0, 5'd21, 5'd10, 3'b010, 5'd0, 7'h23});
            emit({12'd0, 5'd10, 3'b010, 5'd22, 7'h03});
            emit({12'd1, 5'd22, 3'b000, 5'd23, 7'h13});
            execute_program(2);
        end
    endtask

    task reset_program;
        input integer completed_iterations;
        integer reg_index;
        begin
            prepare_program;
            load_constant(1, 32'h80000000);
            load_constant(2, 32'h7fffffff);
            emit(encode_m(3'b000, 5'd3, 5'd1, 5'd2));
            emit(32'h0000006f);
            @(negedge CLK);
            monitoring = 1;
            RESET = 0;
            wait (busy_cycles == completed_iterations);
            @(negedge CLK);
            if (dut.RV1.Busy !== 1'b1) $fatal(1, "Reset test missed multiplication");
            monitoring = 0;
            RESET = 1;
            #1;
            if (dut.RV1.Busy !== 1'b0) $fatal(1, "CPU Busy did not clear during reset");
            @(posedge CLK);
            #2;
            if (dut.PC !== PC_BASE) $fatal(1, "CPU PC did not reset");
            for (reg_index = 0; reg_index < 32; reg_index = reg_index + 1)
                if (dut.RV1.RegFile1.RegBank[reg_index] !== reference_regs[reg_index])
                    $fatal(1, "Stale writeback during reset to x%0d", reg_index);
            product_program(32'hfffffff9, 32'd2, 3'b000, 5'd3, 5'd1, 5'd2);
        end
    endtask

    initial begin
        edge_values[0] = 0;
        edge_values[1] = 1;
        edge_values[2] = 32'hffffffff;
        edge_values[3] = 2;
        edge_values[4] = 32'hfffffffe;
        edge_values[5] = 32'h80000000;
        edge_values[6] = 32'h7fffffff;
        edge_values[7] = 32'h55555555;
        edge_values[8] = 32'haaaaaaaa;
        operations[0] = 0;
        operations[1] = 1;
        operations[2] = 3;
        operations[3] = 4;
        operations[4] = 5;
        operations[5] = 6;
        operations[6] = 7;
        #1;
        for (op = 0; op < 2; op = op + 1) begin
            for (i = 0; i < 9; i = i + 1)
                for (j = 0; j < 9; j = j + 1)
                    product_program(edge_values[i], edge_values[j], op, 5'd3, 5'd1, 5'd2);
            product_program(32'h80000000, 32'hffffffff, op, 5'd1, 5'd1, 5'd2);
            product_program(32'h80000000, 32'hffffffff, op, 5'd2, 5'd1, 5'd2);
            product_program(32'h80000000, 32'hffffffff, op, 5'd3, 5'd1, 5'd1);
            product_program(32'h80000000, 32'hffffffff, op, 5'd3, 5'd0, 5'd2);
            product_program(32'h80000000, 32'hffffffff, op, 5'd3, 5'd1, 5'd0);
            product_program(32'h80000000, 32'hffffffff, op, 5'd0, 5'd1, 5'd2);
        end
        for (i = 0; i < 7; i = i + 1)
            for (j = 0; j < 7; j = j + 1) begin
                prepare_program;
                load_constant(1, 32'h80000000);
                load_constant(2, 32'hffffffff);
                emit(encode_m(operations[i], 5'd3, 5'd1, 5'd2));
                emit(encode_m(operations[j], 5'd4, 5'd3, 5'd2));
                emit({12'd1, 5'd4, 3'b000, 5'd5, 7'h13});
                execute_program(2);
            end
        reset_program(1);
        reset_program(8);
        reset_program(15);
        $display("ALL CPU MCYCLE TESTS PASSED (%0d programs, %0d multicycle retirements)", programs, multicycle_checks);
        done = 1;
        if (FINISH_ON_DONE) $finish;
    end

    initial begin
        #2_000_000;
        if (!done) $fatal(1, "CPU multicycle testbench timeout");
    end
endmodule
