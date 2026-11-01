`timescale 1ns / 1ps

module test_Wrapper_BF #(
    parameter N_LEDs_OUT = 8,
    parameter N_DIPs = 16,
    parameter N_PBs = 3,
    parameter init_DIPs = 16'ha80f
);
    reg CLK = 0;
    reg RESET = 1;
    wire [N_LEDs_OUT-1:0] LED_OUT;
    wire booth_tests_done;
    wire pipeline_tests_done;
    reg [31:0] jal_link = 0;
    reg [31:0] jalr_link = 0;
    reg signed [63:0] product;
    reg signed [31:0] product_low, product_high;
    integer checks = 0;
    integer error_count = 0;
    integer link_checks = 0;
    integer index;
    reg [1023:0] image_path;

    Wrapper #(.N_LEDs_OUT(N_LEDs_OUT), .N_DIPs(N_DIPs), .N_PBs(N_PBs)) dut(
        .DIP(init_DIPs), .PB({N_PBs{1'b0}}), .LED_OUT(LED_OUT),
        .UART_TX_ready(1'b1), .UART_RX(8'd0), .UART_RX_valid(1'b0),
        .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0), .RESET(RESET), .CLK(CLK), .Enable(1'b1)
    );

    test_Wrapper_MCycle #(.FINISH_ON_DONE(0)) booth_tests(.done(booth_tests_done));
    test_Wrapper_Pipeline_checks pipeline_tests(.done(pipeline_tests_done));

    always #5 CLK = ~CLK;

    function [1023:0] find_image;
        input [127:0] name;
        integer descriptor;
        reg [1023:0] candidate;
        begin
            $sformat(candidate, "asm_mem/basic_functionality/%0s", name);
            descriptor = $fopen(candidate, "r");
            if (!descriptor) begin
                $sformat(candidate, "basic_functionality/%0s", name);
                descriptor = $fopen(candidate, "r");
            end
            if (!descriptor) begin
                $sformat(candidate, "../../../../asm_mem/basic_functionality/%0s", name);
                descriptor = $fopen(candidate, "r");
            end
            if (!descriptor) $fatal(1, "Cannot locate functionality image %s", name);
            $fclose(descriptor);
            find_image = candidate;
        end
    endfunction

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

    always @(posedge CLK) begin
        if (!RESET && dut.RV1.Valid_W && dut.RV1.WE && dut.RV1.rd_W != 0) begin
            if (dut.RV1.Instr_W[6:0] == 7'h6f) begin
                check32(dut.RV1.WD_W, dut.RV1.PC_W + 4, "jal link");
                jal_link = dut.RV1.PC_W + 4;
                link_checks = link_checks + 1;
            end
            if (dut.RV1.Instr_W[6:0] == 7'h67) begin
                check32(dut.RV1.WD_W, dut.RV1.PC_W + 4, "jalr link");
                jalr_link = dut.RV1.PC_W + 4;
                link_checks = link_checks + 1;
            end
        end
    end

    initial begin
        #1;
        image_path = find_image("AA_IROM.mem");
        $readmemh(image_path, dut.IROM);
        for (index = 0; index < 128; index = index + 1) dut.DMEM[index] = 0;
        image_path = find_image("AA_DMEM.mem");
        $readmemh(image_path, dut.DMEM);
        repeat (3) @(negedge CLK);
        RESET = 0;
        wait (dut.RV1.RegFile1.RegBank[23] === 32'd1);
        @(negedge CLK);
        check32(dut.RV1.RegFile1.RegBank[8], 32'hffff0000, "branch sentinels");
        check32(dut.RV1.RegFile1.RegBank[14], 32'h40, "and");
        check32(dut.RV1.RegFile1.RegBank[15], 32'h58, "andi");
        check32(dut.RV1.RegFile1.RegBank[16], 32'hfffffff8, "or");
        check32(dut.RV1.RegFile1.RegBank[17], 32'h404, "ori");
        check32(dut.RV1.RegFile1.RegBank[24], 1, "slt");
        check32(dut.RV1.RegFile1.RegBank[25], 0, "slt false");
        check32(dut.RV1.RegFile1.RegBank[21], 3, "xor and sltiu");
        check32(dut.RV1.RegFile1.RegBank[22], 5, "xori");
        check32(dut.RV1.RegFile1.RegBank[31], 4, "auipc spacing");
        check32(dut.DMEM[0], 2, "load subtract store");
        check32(LED_OUT, init_DIPs & 8'hff, "DIP to LED");
        check32(link_checks, 2, "jump link coverage");
        product = $signed({1'b0, jal_link}) * $signed(32'hffff0060);
        product_low = product[31:0];
        product_high = product[63:32];
        check32(dut.RV1.RegFile1.RegBank[10], product_low, "mul");
        check32(dut.RV1.RegFile1.RegBank[5], product_high, "mulh");
        product = {32'b0, jal_link} * 64'hffff0060;
        check32(dut.RV1.RegFile1.RegBank[7], product[63:32], "mulhu");
        check32(dut.RV1.RegFile1.RegBank[19], product_low / product_high, "div");
        check32(dut.RV1.RegFile1.RegBank[20], product_low % product_high, "rem");
        check32(dut.RV1.RegFile1.RegBank[26], jalr_link / 85, "divu");
        check32(dut.RV1.RegFile1.RegBank[27], jalr_link % 85, "remu");
        wait (booth_tests_done);
        wait (pipeline_tests_done);
        if (error_count != 0)
            $fatal(1, "%0d basic-functionality test failure(s)", error_count);
        $display("ALL BASIC FUNCTIONALITY TESTS PASSED (%0d checks)", checks);
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "Basic-functionality testbench timeout");
    end
endmodule
module test_Wrapper_Pipeline_checks(output reg done = 0);
    reg CLK = 0;
    reg RESET = 1;
    wire [7:0] LED_OUT;
    wire [7:0] UART_TX;
    wire UART_TX_valid, UART_RX_ack;
    integer words, checks = 0, programs = 0;
    integer stores = 0, reads = 0, tx_count = 0, rx_count = 0;
    integer writes [0:31];
    integer cycle = 0, previous_write_cycle = -1;
    reg check_consecutive = 0;
    integer condition, taken;
    integer load_stalls = 0;
    integer redirects = 0;
    integer store_forwards = 0;
    reg [31:0] model_regs [0:31];
    reg [31:0] model_memory [0:7];
    reg [31:0] model_a, model_b, model_result, model_immediate;
    integer trial, step, kind, destination, source1, source2, location;
    integer random_seed = 3207;

    Wrapper dut(
        .DIP(16'h1234), .PB(3'd0), .LED_OUT(LED_OUT),
        .UART_TX(UART_TX), .UART_TX_valid(UART_TX_valid), .UART_RX_ack(UART_RX_ack),
        .UART_TX_ready(1'b1), .UART_RX(8'hab), .UART_RX_valid(1'b1),
        .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0), .RESET(RESET), .CLK(CLK), .Enable(1'b1)
    );

    always #5 CLK = ~CLK;

    function [31:0] immediate;
        input [11:0] value;
        input [4:0] rs1, rd;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            immediate = {value, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] register_op;
        input [6:0] funct7;
        input [4:0] rs2, rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            register_op = {funct7, rs2, rs1, funct3, rd, 7'h33};
        end
    endfunction

    function [31:0] store;
        input [11:0] offset;
        input [4:0] rs2, rs1;
        begin
            store = {offset[11:5], rs2, rs1, 3'b010, offset[4:0], 7'h23};
        end
    endfunction

    function [31:0] branch;
        input [2:0] funct3;
        input [4:0] rs1, rs2;
        begin
            branch = {7'b0000000, rs2, rs1, funct3, 5'b10000, 7'h63};
        end
    endfunction

    task check32;
        input [31:0] actual, expected;
        input [255:0] label;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: actual=%h expected=%h", label, actual, expected);
            checks = checks + 1;
        end
    endtask

    task raw;
        input [31:0] instruction;
        begin
            if (words >= 512) $fatal(1, "Pipeline program too large");
            dut.IROM[words] = instruction;
            words = words + 1;
        end
    endtask

    task emit;
        input [31:0] instruction;
        begin
            raw(instruction);
        end
    endtask

    task prepare;
        integer index;
        begin
            @(negedge CLK);
            RESET = 1;
            repeat (2) @(negedge CLK);
            for (index = 0; index < 512; index = index + 1) dut.IROM[index] = 32'h00000013;
            for (index = 0; index < 32; index = index + 1) begin
                dut.RV1.RegFile1.RegBank[index] = 0;
                writes[index] = 0;
            end
            dut.RV1.RegFile1.RegBank[0] = 32'hdeadbeef;
            dut.RV1.RegFile1.RegBank[1] = 7;
            dut.RV1.RegFile1.RegBank[2] = -3;
            dut.RV1.RegFile1.RegBank[10] = 32'h10010000;
            dut.RV1.RegFile1.RegBank[11] = 32'hffff0000;
            dut.DMEM[0] = 0;
            words = 0;
            stores = 0;
            reads = 0;
            tx_count = 0;
            rx_count = 0;
            load_stalls = 0;
            redirects = 0;
            store_forwards = 0;
            previous_write_cycle = -1;
        end
    endtask

    task execute;
        integer attempts;
        begin
            emit(immediate(1, 0, 31, 0, 7'h13));
            emit(32'h0000006f);
            @(negedge CLK);
            RESET = 0;
            attempts = 0;
            while (dut.RV1.RegFile1.RegBank[31] !== 1 && attempts < 1000) begin
                @(negedge CLK);
                attempts = attempts + 1;
            end
            if (attempts == 1000)
                $fatal(1, "Pipeline program %0d completion timeout, PC=%h", programs + 1, dut.PC);
            programs = programs + 1;
        end
    endtask

    always @(posedge CLK) begin : monitor
        reg stalled;
        reg load_stalled;
        reg [31:0] held_pc, held_d, held_e, held_a, held_b;
        reg [31:0] held_src_a, held_src_b;
        cycle = cycle + 1;
        if (!RESET) begin
            stalled = dut.RV1.Busy;
            load_stalled = dut.RV1.LoadStall && !stalled;
            held_pc = dut.PC;
            held_d = dut.RV1.Instr_D;
            held_e = dut.RV1.Instr_E;
            held_a = dut.RV1.RD1_E;
            held_b = dut.RV1.RD2_E;
            held_src_a = dut.RV1.Src_A_E;
            held_src_b = dut.RV1.Src_B_E;
            if (load_stalled) load_stalls = load_stalls + 1;
            if (dut.RV1.Redirect_E) redirects = redirects + 1;
            if (dut.RV1.ForwardM) store_forwards = store_forwards + 1;
            if (dut.MemWrite_out != 0) stores = stores + 1;
            if (dut.MemRead) reads = reads + 1;
            if (!dut.RV1.Valid_M && (dut.MemRead !== 0 || dut.MemWrite_out !== 0))
                $fatal(1, "Invalid memory-stage side effect");
            if (!dut.RV1.Valid_W && dut.RV1.WE !== 0)
                $fatal(1, "Invalid writeback-stage side effect");
            if (dut.RV1.WE && dut.RV1.rd_W != 0) begin
                writes[dut.RV1.rd_W] = writes[dut.RV1.rd_W] + 1;
                if (check_consecutive && dut.RV1.rd_W >= 12 && dut.RV1.rd_W <= 14) begin
                    if (previous_write_cycle >= 0 && cycle != previous_write_cycle + 1)
                        $fatal(1, "Independent instructions did not retire consecutively");
                    previous_write_cycle = cycle;
                end
            end
            #1;
            if (UART_TX_valid) tx_count = tx_count + 1;
            if (UART_RX_ack) rx_count = rx_count + 1;
            if (stalled) begin
                if (dut.PC !== held_pc || dut.RV1.Instr_D !== held_d ||
                    dut.RV1.Instr_E !== held_e || dut.RV1.RD1_E !== held_a || dut.RV1.RD2_E !== held_b)
                    $fatal(1, "Front-end or operands changed during MCycle stall");
                if (dut.RV1.Valid_M !== 0) $fatal(1, "Busy execution did not insert a bubble");
                if (dut.RV1.Src_A_E !== held_src_a || dut.RV1.Src_B_E !== held_src_b)
                    $fatal(1, "Forwarded MCycle operands changed while Busy");
            end
            if (load_stalled) begin
                if (dut.PC !== held_pc || dut.RV1.Instr_D !== held_d || dut.RV1.Valid_E !== 0)
                    $fatal(1, "Load-use stall did not hold F/D and bubble E");
            end
        end
    end

    initial begin
        #1;
        prepare;
        check_consecutive = 1;
        raw(immediate(11, 0, 12, 0, 7'h13));
        raw(immediate(22, 0, 13, 0, 7'h13));
        raw(immediate(33, 0, 14, 0, 7'h13));
        repeat (3) raw(32'h00000013);
        emit(immediate(15, 0, 0, 0, 7'h13));
        emit(32'hffffffff);
        emit(32'h0220a1b3);
        execute;
        check_consecutive = 0;
        check32(dut.RV1.RegFile1.RegBank[12], 11, "independent result 1");
        check32(dut.RV1.RegFile1.RegBank[13], 22, "independent result 2");
        check32(dut.RV1.RegFile1.RegBank[14], 33, "independent result 3");
        check32(dut.RV1.RegFile1.RegBank[0], 32'hdeadbeef, "x0 writes ignored");
        check32(writes[3], 0, "unsupported M operation ignored");
        check32(stores, 0, "unsupported instructions do not store");
        check32(reads, 0, "unsupported instructions do not load");

        prepare;
        raw(immediate(11, 0, 12, 0, 7'h13));
        raw({7'd0, 5'd1, 5'd10, 3'b010, 5'd0, 7'h23});
        raw({7'h01, 5'd2, 5'd1, 3'b000, 5'd3, 7'h33});
        raw({7'h01, 5'd2, 5'd1, 3'b100, 5'd4, 7'h33});
        emit({7'd0, 5'd1, 5'd1, 3'b000, 5'd5, 7'h33});
        emit(immediate(0, 10, 6, 2, 7'h03));
        emit(immediate(4, 11, 7, 2, 7'h03));
        emit({7'd0, 5'd1, 5'd11, 3'b010, 5'd12, 7'h23});
        emit({7'd3, 5'd5, 5'd11, 3'b010, 5'd0, 7'h23});
        execute;
        check32(dut.RV1.RegFile1.RegBank[3], -21, "mul");
        check32(dut.RV1.RegFile1.RegBank[4], -2, "back-to-back div");
        check32(dut.RV1.RegFile1.RegBank[5], 14, "instruction after MCycle");
        check32(dut.RV1.RegFile1.RegBank[6], 7, "stored load");
        check32(dut.RV1.RegFile1.RegBank[7], 32'hab, "UART receive data");
        check32(writes[12], 1, "older writeback occurs once");
        check32(writes[3], 1, "mul writeback occurs once");
        check32(writes[4], 1, "div writeback occurs once");
        check32(stores, 3, "stores occur once");
        check32(reads, 2, "loads occur once");
        check32(tx_count, 1, "UART transmit occurs once");
        check32(rx_count, 1, "UART acknowledgement occurs once");
        check32(UART_TX, 7, "UART transmit data");
        check32(LED_OUT, 14, "LED store data");

        for (condition = 0; condition < 6; condition = condition + 1) begin
            for (taken = 0; taken < 2; taken = taken + 1) begin
                prepare;
                case (condition)
                    0: raw(branch(0, 1, taken ? 1 : 2));
                    1: raw(branch(1, 1, taken ? 2 : 1));
                    2: raw(branch(4, taken ? 2 : 1, taken ? 1 : 2));
                    3: raw(branch(5, taken ? 1 : 2, taken ? 2 : 1));
                    4: raw(branch(6, taken ? 1 : 2, taken ? 2 : 1));
                    5: raw(branch(7, taken ? 2 : 1, taken ? 1 : 2));
                endcase
                repeat (2) raw(32'h00000013);
                emit(immediate(123, 0, 20, 0, 7'h13));
                execute;
                check32(dut.RV1.RegFile1.RegBank[20], taken ? 0 : 123, "branch outcome");
            end
        end

        prepare;
        raw(immediate(9, 0, 3, 0, 7'h13));
        raw(immediate(13, 0, 3, 0, 7'h13));
        raw(register_op(0, 3, 3, 0, 4));
        raw(register_op(0, 1, 3, 0, 5));
        raw(immediate(5, 0, 6, 0, 7'h13));
        raw(immediate(1, 0, 7, 0, 7'h13));
        raw(immediate(2, 0, 8, 0, 7'h13));
        raw(register_op(0, 6, 6, 0, 9));
        raw(store(4, 4, 10));
        execute;
        check32(dut.RV1.RegFile1.RegBank[4], 26, "M forwarding and newest writer");
        check32(dut.RV1.RegFile1.RegBank[5], 20, "W to E forwarding");
        check32(dut.RV1.RegFile1.RegBank[9], 10, "W to D forwarding");
        check32(dut.DMEM[1], 26, "forwarded store data");
        check32(load_stalls, 0, "ALU dependencies need no stalls");

        prepare;
        dut.DMEM[0] = 32'h10010004;
        dut.DMEM[1] = 37;
        raw(immediate(0, 10, 3, 2, 7'h03));
        raw(immediate(0, 3, 4, 2, 7'h03));
        raw(register_op(0, 4, 4, 0, 5));
        raw(store(8, 5, 10));
        raw(immediate(4, 10, 6, 2, 7'h03));
        raw(store(12, 6, 10));
        raw(immediate(4, 10, 0, 2, 7'h03));
        raw(register_op(0, 0, 0, 0, 7));
        execute;
        check32(dut.RV1.RegFile1.RegBank[5], 74, "load-use both ALU operands");
        check32(dut.DMEM[2], 74, "ALU to store forwarding");
        check32(dut.DMEM[3], 37, "load to store forwarding");
        check32(dut.RV1.RegFile1.RegBank[7], 0, "x0 never forwarded");
        check32(load_stalls, 2, "load base and ALU each stall once");
        check32(store_forwards, 1, "load store data bypass without stall");

        prepare;
        dut.DMEM[0] = 9;
        raw(immediate(0, 10, 3, 2, 7'h03));
        raw(immediate(3, 0, 4, 0, 7'h13));
        raw(32'h000031b7);
        raw(immediate(0, 10, 5, 2, 7'h03));
        raw(32'h00005237);
        raw(immediate(0, 10, 6, 2, 7'h03));
        raw(32'h00603397);
        execute;
        check32(load_stalls, 0, "unused source fields do not stall");
        check32(dut.RV1.RegFile1.RegBank[3], 32'h3000, "lui ignores forwarding");
        check32(dut.RV1.RegFile1.RegBank[4], 32'h5000, "lui ignores source match");
        check32(dut.RV1.RegFile1.RegBank[7], 32'h00a03018, "auipc keeps PC operand");

        prepare;
        raw(immediate(9, 0, 3, 0, 7'h13));
        raw(immediate(4, 0, 4, 0, 7'h13));
        raw(register_op(1, 4, 3, 0, 5));
        raw(register_op(0, 5, 5, 0, 6));
        raw(register_op(1, 4, 6, 4, 7));
        raw(register_op(1, 4, 7, 6, 8));
        raw(store(4, 8, 10));
        execute;
        check32(dut.RV1.RegFile1.RegBank[5], 36, "forwarded multiply operands");
        check32(dut.RV1.RegFile1.RegBank[6], 72, "multiply result forwarding");
        check32(dut.RV1.RegFile1.RegBank[7], 18, "dependent divide");
        check32(dut.RV1.RegFile1.RegBank[8], 2, "dependent remainder");
        check32(dut.DMEM[1], 2, "remainder forwarded into store");

        prepare;
        dut.DMEM[0] = 21;
        raw(immediate(0, 10, 3, 2, 7'h03));
        raw(register_op(1, 1, 3, 0, 4));
        raw(register_op(1, 1, 4, 5, 5));
        execute;
        check32(dut.RV1.RegFile1.RegBank[4], 147, "load-use before multiply");
        check32(dut.RV1.RegFile1.RegBank[5], 21, "dependent unsigned divide");
        check32(load_stalls, 1, "load to MCycle single stall");

        for (condition = 0; condition < 6; condition = condition + 1) begin
            for (taken = 0; taken < 2; taken = taken + 1) begin
                prepare;
                raw(immediate(7, 0, 3, 0, 7'h13));
                raw(immediate(-3, 0, 4, 0, 7'h13));
                case (condition)
                    0: raw(branch(0, 3, taken ? 3 : 4));
                    1: raw(branch(1, 3, taken ? 4 : 3));
                    2: raw(branch(4, taken ? 4 : 3, taken ? 3 : 4));
                    3: raw(branch(5, taken ? 3 : 4, taken ? 4 : 3));
                    4: raw(branch(6, taken ? 3 : 4, taken ? 4 : 3));
                    5: raw(branch(7, taken ? 4 : 3, taken ? 3 : 4));
                endcase
                raw(immediate(123, 0, 20, 0, 7'h13));
                raw(store(0, 1, 10));
                raw(register_op(1, 2, 1, 0, 21));
                execute;
                check32(dut.RV1.RegFile1.RegBank[20], taken ? 0 : 123, "forwarded branch outcome");
                check32(dut.DMEM[0], taken ? 0 : 7, "branch squashes wrong-path store");
                check32(writes[21], taken ? 0 : 1, "branch squashes wrong-path MCycle");
            end
        end

        prepare;
        raw(32'h010001ef);
        raw(store(0, 1, 10));
        raw(register_op(1, 2, 1, 0, 21));
        raw(immediate(99, 0, 20, 0, 7'h13));
        raw(immediate(1, 3, 4, 0, 7'h13));
        raw(32'h00000297);
        raw(immediate(21, 5, 5, 0, 7'h13));
        raw(immediate(0, 5, 6, 0, 7'h67));
        raw(store(0, 1, 10));
        raw(register_op(1, 2, 1, 0, 21));
        raw(immediate(1, 6, 7, 0, 7'h13));
        execute;
        check32(dut.RV1.RegFile1.RegBank[3], 32'h00400004, "jal link");
        check32(dut.RV1.RegFile1.RegBank[4], 32'h00400005, "jal link used at target");
        check32(dut.RV1.RegFile1.RegBank[6], 32'h00400020, "jalr link");
        check32(dut.RV1.RegFile1.RegBank[7], 32'h00400021, "jalr link used at target");
        check32(stores, 0, "jumps squash stores");
        check32(writes[21], 0, "jumps squash MCycle");
        check32(dut.RV1.RegFile1.RegBank[20], 0, "jal skips third fall-through");

        prepare;
        dut.DMEM[0] = 32'h00400011;
        raw(immediate(0, 10, 3, 2, 7'h03));
        raw(immediate(0, 3, 4, 0, 7'h67));
        raw(store(4, 1, 10));
        raw(register_op(1, 2, 1, 0, 21));
        raw(immediate(1, 4, 5, 0, 7'h13));
        execute;
        check32(load_stalls, 1, "load to jalr stalls once");
        check32(dut.RV1.RegFile1.RegBank[5], 32'h00400009, "loaded jalr base and link");
        check32(stores, 0, "loaded jump squashes store");

        prepare;
        dut.DMEM[0] = 7;
        raw(immediate(0, 10, 3, 2, 7'h03));
        raw(branch(0, 3, 1));
        raw(store(4, 1, 10));
        raw(register_op(1, 2, 1, 0, 21));
        raw(immediate(99, 0, 20, 0, 7'h13));
        execute;
        check32(load_stalls, 1, "load to branch stalls once");
        check32(stores, 0, "loaded branch squashes store");
        check32(writes[21], 0, "loaded branch squashes MCycle");
        check32(dut.RV1.RegFile1.RegBank[20], 0, "loaded branch target");

        for (trial = 0; trial < 6; trial = trial + 1) begin
            prepare;
            for (step = 0; step < 32; step = step + 1) model_regs[step] = 0;
            model_regs[1] = 7;
            model_regs[2] = -3;
            for (step = 0; step < 8; step = step + 1) begin
                model_memory[step] = $random(random_seed);
                dut.DMEM[step] = model_memory[step];
            end
            for (step = 0; step < 96; step = step + 1) begin
                kind = ($random(random_seed) & 32'h7fffffff) % 16;
                destination = 3 + ($random(random_seed) & 32'h7fffffff) % 7;
                source1 = ($random(random_seed) & 32'h7fffffff) % 10;
                source2 = ($random(random_seed) & 32'h7fffffff) % 10;
                location = ($random(random_seed) & 32'h7fffffff) % 8;
                model_a = model_regs[source1];
                model_b = model_regs[source2];
                model_immediate = $random(random_seed) & 32'hfff;
                model_immediate = {{20{model_immediate[11]}}, model_immediate[11:0]};
                case (kind)
                    0: begin
                        raw(register_op(0, source2, source1, 0, destination));
                        model_result = model_a + model_b;
                    end
                    1: begin
                        raw(register_op(7'h20, source2, source1, 0, destination));
                        model_result = model_a - model_b;
                    end
                    2: begin
                        raw(register_op(0, source2, source1, 4, destination));
                        model_result = model_a ^ model_b;
                    end
                    3: begin
                        raw(register_op(0, source2, source1, 6, destination));
                        model_result = model_a | model_b;
                    end
                    4: begin
                        raw(register_op(0, source2, source1, 7, destination));
                        model_result = model_a & model_b;
                    end
                    5: begin
                        raw(register_op(0, source2, source1, 1, destination));
                        model_result = model_a << model_b[4:0];
                    end
                    6: begin
                        raw(register_op(0, source2, source1, 5, destination));
                        model_result = model_a >> model_b[4:0];
                    end
                    7: begin
                        raw(register_op(7'h20, source2, source1, 5, destination));
                        model_result = $signed(model_a) >>> model_b[4:0];
                    end
                    8: begin
                        raw(register_op(0, source2, source1, 2, destination));
                        model_result = $signed(model_a) < $signed(model_b);
                    end
                    9: begin
                        raw(register_op(0, source2, source1, 3, destination));
                        model_result = model_a < model_b;
                    end
                    10: begin
                        raw(immediate(model_immediate[11:0], source1, destination, 0, 7'h13));
                        model_result = model_a + model_immediate;
                    end
                    11: begin
                        raw(immediate(model_immediate[11:0], source1, destination, 7, 7'h13));
                        model_result = model_a & model_immediate;
                    end
                    12: begin
                        raw(immediate(4*location, 10, destination, 2, 7'h03));
                        model_result = model_memory[location];
                    end
                    13: begin
                        raw(store(4*location, source2, 10));
                        model_memory[location] = model_b;
                        model_result = model_regs[destination];
                    end
                    14: begin
                        raw(register_op(1, source2, source1, 0, destination));
                        model_result = model_a * model_b;
                    end
                    15: begin
                        raw(register_op(1, source2, source1, 4, destination));
                        if (model_b == 0) model_result = 32'hffffffff;
                        else if (model_a == 32'h80000000 && model_b == 32'hffffffff)
                            model_result = 32'h80000000;
                        else model_result = $signed(model_a) / $signed(model_b);
                    end
                endcase
                model_regs[destination] = model_result;
            end
            execute;
            for (step = 3; step < 10; step = step + 1)
                check32(dut.RV1.RegFile1.RegBank[step], model_regs[step], "random dense register result");
            for (step = 0; step < 8; step = step + 1)
                check32(dut.DMEM[step], model_memory[step], "random dense memory result");
        end

        prepare;
        emit({7'h01, 5'd2, 5'd1, 3'b000, 5'd3, 7'h33});
        @(negedge CLK);
        RESET = 0;
        wait (dut.RV1.Busy === 1);
        repeat (3) @(negedge CLK);
        RESET = 1;
        #1;
        check32(dut.MemWrite_out, 0, "reset blocks stores");
        check32(dut.MemRead, 0, "reset blocks loads");
        check32(dut.RV1.WE, 0, "reset blocks writeback");
        repeat (2) @(negedge CLK);
        check32(dut.PC, 32'h00400000, "reset PC");
        check32({dut.RV1.Valid_D, dut.RV1.Valid_E, dut.RV1.Valid_M, dut.RV1.Valid_W}, 0, "reset clears validity");
        check32(dut.RV1.RegFile1.RegBank[3], 0, "reset cancels MCycle result");
        $display("ALL PIPELINE TESTS PASSED (%0d programs, %0d checks)", programs, checks);
        done = 1;
    end

    initial begin
        #1_000_000;
        if (!done) $fatal(1, "Pipeline testbench timeout");
    end
endmodule
