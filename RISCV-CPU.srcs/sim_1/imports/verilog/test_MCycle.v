`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NUS
// Engineer: Shahzor Ahmad, Rajesh C Panicker
// 
// Create Date: 27.09.2016 16:55:23
// Design Name: 
// Module Name: test_MCycle
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
/* 
----------------------------------------------------------------------------------
--	(c) Shahzor Ahmad, Rajesh C Panicker
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post it on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(iv) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(v) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

//module test_MCycle(

//    );
    
//    // DECLARE INPUT SIGNALs
//    reg CLK = 0 ;
//    reg RESET = 0 ;
//    reg Start = 0 ;
//    reg [1:0] MCycleOp = 0 ;
//    reg [3:0] Operand1 = 0 ;
//    reg [3:0] Operand2 = 0 ;

//    // DECLARE OUTPUT SIGNALs
//    wire [3:0] Result1 ;
//    wire [3:0] Result2 ;
//    wire Busy ;
    
//    // INSTANTIATE DEVICE/UNIT UNDER TEST (DUT/UUT)
//    MCycle dut( 
//        CLK, 
//        RESET, 
//        Start, 
//        MCycleOp, 
//        Operand1, 
//        Operand2, 
//        Result1, 
//        Result2, 
//        Busy
//        ) ;
    
//    // STIMULI
//    initial begin
//        // hold reset state for 100 ns.
//        #10 ;    
//        MCycleOp = 2'b00 ;
//        Operand1 = 4'b1111 ;
//        Operand2 = 4'b1111 ;
//        Start = 1'b1 ; // Start is asserted continously(Operations are performed back to back). To try a non-continous Start, you can uncomment the commented lines.    

//        wait(Busy) ; // suspend initial block till condition becomes true  ;
//        wait(~Busy) ;
////        #10 ;
////        Start = 1'b0 ;
////        #10 ;
//        Operand1 = 4'b1110 ;
//        Operand2 = 4'b1111 ;
////        Start = 1'b1 ;
        
//        wait(Busy) ; 
//        wait(~Busy) ;
////        #10 ;
////        Start = 1'b0 ;
////        #10 ;
//        MCycleOp = 2'b01 ;
//        Operand1 = 4'b1111 ;
//        Operand2 = 4'b1111 ;
////        Start = 1'b1 ;

//        wait(Busy) ; 
//        wait(~Busy) ; 
////        #10 ;
////        Start = 1'b0 ;
////        #10 ;
//        Operand1 = 4'b1110 ;
//        Operand2 = 4'b1111 ;
////        Start = 1'b1 ;

//        wait(Busy) ; 
//        wait(~Busy) ; 
//        Start = 1'b0 ;
//    end
     
//    // GENERATE CLOCK       
//    always begin 
//        #5 CLK = ~CLK ; 
//        // invert CLK every 5 time units 
//    end
    
//endmodule

module test_MCycle(

    );

    // DECLARE INPUT SIGNALs
    reg CLK = 0 ;
    reg RESET = 0 ;
    reg Start = 0 ;
    reg [1:0] MCycleOp = 0 ;
    reg [3:0] Operand1 = 0 ;
    reg [3:0] Operand2 = 0 ;

    // DECLARE OUTPUT SIGNALs
    wire [3:0] Result1 ;
    wire [3:0] Result2 ;
    wire Busy ;

    // INSTANTIATE DEVICE/UNIT UNDER TEST (DUT/UUT)
    MCycle #(.width(4)) dut(
        .CLK(CLK), .Enable(1'b1),
        .RESET(RESET),
        .Start(Start),
        .MCycleOp(MCycleOp),
        .Operand1(Operand1),
        .Operand2(Operand2),
        .Result1(Result1),
        .Result2(Result2),
        .Busy(Busy)
        ) ;

    // GENERATE CLOCK
    always begin
        #5 CLK = ~CLK ;
        // invert CLK every 5 time units
    end

    // WATCHDOG: abort if the DUT ever hangs (Busy stuck high)
    initial begin
        #20_000_000 ;
        $display("TIMEOUT: simulation hung, Busy probably never fell") ;
        $fatal(1, "MCycle testbench timeout") ;
    end

    // ------------------------------------------------------------------
    // Bookkeeping
    // ------------------------------------------------------------------
    integer errors = 0 ;
    integer checks = 0 ;
    integer busy_cycles = 0 ;   // number of clock edges at which Busy was high
    reg     verbose = 1'b1 ;    // print a line for every check (turned off for the big sweeps)

    // Count how many cycles Busy stays high. Sampled at the clock edge, i.e. before
    // the DUT's non-blocking updates take effect.
    always @(posedge CLK)
        if (Busy) busy_cycles = busy_cycles + 1 ;

    // Reference model scratch variables
    integer sa, sb, pq, pr, exp_cycles ;
    reg [7:0] exp_prod ;
    reg [3:0] exp_q, exp_r ;      // expected Result1 / Result2

    // ------------------------------------------------------------------
    // run_op: apply one operation and check everything about it.
    //   hold = 0 : Start is dropped after the operation, one idle cycle follows
    //              (non-continuous Start)
    //   hold = 1 : Start is left high, so the next call runs back to back
    // Checks: Result1, Result2, number of busy cycles, Busy rising with Start (when
    // starting from idle), Busy low and results held in the idle cycle afterwards.
    // ------------------------------------------------------------------
    task run_op(input [1:0] op, input [3:0] a, input [3:0] b, input hold);
        reg started_from_idle;
        begin
            // ---- reference model ----
            sa = a[3] ? a - 16 : a ;     // signed value of a
            sb = b[3] ? b - 16 : b ;
            case (op)
                2'b00: begin
                    pq = sa * sb ;
                    exp_prod = pq[7:0] ;
                    exp_q = exp_prod[3:0] ;
                    exp_r = exp_prod[7:4] ;
                    exp_cycles = 2 ;
                end
                2'b01: begin // unsigned multiply, width cycles
                    pq = a * b ;
                    exp_prod = pq[7:0] ;
                    exp_q = exp_prod[3:0] ;
                    exp_r = exp_prod[7:4] ;
                    exp_cycles = 4 ;
                end
                2'b10: begin // signed divide (truncates toward zero, remainder takes sign of dividend)
                    pq = sa / sb ;       // -8 / -1 = 8 -> truncates to 4'b1000 = -8, as RISC-V specifies
                    pr = sa % sb ;
                    exp_q = pq[3:0] ;
                    exp_r = pr[3:0] ;
                    exp_cycles = 4 ;
                end
                2'b11: begin // unsigned divide
                    pq = a / b ;
                    pr = a % b ;
                    exp_q = pq[3:0] ;
                    exp_r = pr[3:0] ;
                    exp_cycles = 4 ;
                end
            endcase

            // ---- apply stimulus ----
            started_from_idle = (dut.state == 1'b0) ;
            MCycleOp = op ;
            Operand1 = a ;
            Operand2 = b ;
            busy_cycles = 0 ;
            Start = 1'b1 ;

            if (started_from_idle) begin
                #1 ;
                if (Busy !== 1'b1) begin   // Mealy output: Busy must rise as soon as Start does
                    errors = errors + 1 ;
                    $display("FAIL: Busy did not rise immediately with Start (op=%b a=%0d b=%0d)", op, a, b) ;
                end
            end

            wait(Busy) ;
            wait(~Busy) ;
            #1 ;                           // let the registered results settle

            // ---- check results ----
            checks = checks + 1 ;
            if (Result1 !== exp_q || Result2 !== exp_r || busy_cycles !== exp_cycles) begin
                errors = errors + 1 ;
                $display("FAIL: op=%b a=%0d(%0d) b=%0d(%0d) | R1=%0d R2=%0d (expected %0d %0d) | cycles=%0d (expected %0d)",
                         op, a, sa, b, sb, $signed(Result1), $signed(Result2),
                         $signed(exp_q), $signed(exp_r), busy_cycles, exp_cycles) ;
            end
            else if (verbose)
                // $display("PASS: op=%b a=%0d b=%0d | R1=%0d R2=%0d | cycles=%0d", op, a, sa == sa ? b : b, $signed(Result1), $signed(Result2), busy_cycles) ;
                $display("PASS: op=%b a=%0d b=%0d | R1=%0d R2=%0d | cycles=%0d", op, a, b, $signed(Result1), $signed(Result2), busy_cycles) ;

            // ---- idle cycle after the operation ----
            if (!hold) begin
                Start = 1'b0 ;
                @(posedge CLK) ;
                #1 ;
                if (Busy !== 1'b0) begin
                    errors = errors + 1 ;
                    $display("FAIL: Busy still high in the idle cycle after the operation") ;
                end
                if (Result1 !== exp_q || Result2 !== exp_r) begin
                    errors = errors + 1 ;
                    $display("FAIL: results changed in the idle cycle (op=%b a=%0d b=%0d)", op, a, b) ;
                end
            end
        end
    endtask

    // ------------------------------------------------------------------
    // STIMULI
    // ------------------------------------------------------------------
    reg [1:0] op_r ;
    reg [3:0] a_r, b_r ;
    reg [3:0] hold_r1, hold_r2 ;
    reg [31:0] rnd1, rnd2, rnd3 ;
    integer i, j, k ;

    initial begin
        #10 ;

        // ==============================================================
        // 1. Your original stimuli (multiply). Expected:
        //    signed   -1 * -1 =   1  -> R2:R1 = 0000_0001
        //    signed   -2 * -1 =   2  -> R2:R1 = 0000_0010
        //    unsigned 15 * 15 = 225  -> R2:R1 = 1110_0001
        //    unsigned 14 * 15 = 210  -> R2:R1 = 1101_0010
        // ==============================================================
        $display("--- 1. original multiply stimuli ---") ;
        run_op(2'b00, 4'b1111, 4'b1111, 1'b0) ;
        run_op(2'b00, 4'b1110, 4'b1111, 1'b0) ;
        run_op(2'b01, 4'b1111, 4'b1111, 1'b0) ;
        run_op(2'b01, 4'b1110, 4'b1111, 1'b0) ;

        // ==============================================================
        // 2. More multiply corner cases
        // ==============================================================
        $display("--- 2. multiply corner cases ---") ;
        run_op(2'b00, 4'd7,  4'd7,  1'b0) ;   // 49
        run_op(2'b00, 4'd8,  4'd8,  1'b0) ;   // -8 * -8 = 64
        run_op(2'b00, 4'd8,  4'd7,  1'b0) ;   // -8 * 7 = -56
        run_op(2'b00, 4'd7,  4'd8,  1'b0) ;   // 7 * -8
        run_op(2'b00, 4'd0,  4'd13, 1'b0) ;   // 0 * x
        run_op(2'b01, 4'd15, 4'd1,  1'b0) ;   // 15
        run_op(2'b01, 4'd0,  4'd15, 1'b0) ;   // 0

        // ==============================================================
        // 3. Unsigned divide (divisor never 0)
        //    quotient in Result1, remainder in Result2
        // ==============================================================
        $display("--- 3. unsigned divide ---") ;
        run_op(2'b11, 4'd7,  4'd2,  1'b0) ;   // 3 r1
        run_op(2'b11, 4'd15, 4'd1,  1'b0) ;   // 15 r0
        run_op(2'b11, 4'd15, 4'd15, 1'b0) ;   // 1 r0
        run_op(2'b11, 4'd3,  4'd7,  1'b0) ;   // 0 r3  (dividend < divisor)
        run_op(2'b11, 4'd0,  4'd5,  1'b0) ;   // 0 r0
        run_op(2'b11, 4'd15, 4'd2,  1'b0) ;   // 7 r1  (MSB of dividend set)
        run_op(2'b11, 4'd14, 4'd15, 1'b0) ;   // 0 r14 (divisor MSB set)
        run_op(2'b11, 4'd9,  4'd9,  1'b0) ;   // 1 r0

        // ==============================================================
        // 4. Signed divide (divisor never 0)
        // ==============================================================
        $display("--- 4. signed divide ---") ;
        run_op(2'b10, 4'd7,  4'd2,  1'b0) ;   //  7 /  2 =  3 r  1
        run_op(2'b10, -4'sd7, 4'd2, 1'b0) ;   // -7 /  2 = -3 r -1
        run_op(2'b10, 4'd7, -4'sd2, 1'b0) ;   //  7 / -2 = -3 r  1
        run_op(2'b10, -4'sd7, -4'sd2, 1'b0) ; // -7 / -2 =  3 r -1
        run_op(2'b10, 4'b1000, 4'b1111, 1'b0) ; // -8 / -1 = -8 r 0 (overflow case)
        run_op(2'b10, 4'b1000, 4'd1, 1'b0) ;  // -8 /  1 = -8 r 0
        run_op(2'b10, 4'b1000, 4'd3, 1'b0) ;  // -8 /  3 = -2 r -2
        run_op(2'b10, 4'd0, -4'sd3, 1'b0) ;   //  0 / -3 =  0 r  0
        run_op(2'b10, 4'd3, 4'd7, 1'b0) ;     //  3 /  7 =  0 r  3
        run_op(2'b10, -4'sd3, 4'd7, 1'b0) ;   // -3 /  7 =  0 r -3

        // ==============================================================
        // 5. Results must be held while idle, whatever the operands do
        // ==============================================================
        $display("--- 5. results held while idle ---") ;
        run_op(2'b10, -4'sd7, 4'd2, 1'b0) ;
        hold_r1 = Result1 ;
        hold_r2 = Result2 ;
        Operand1 = 4'hA ;
        Operand2 = 4'h5 ;
        MCycleOp = 2'b01 ;
        repeat (5) @(posedge CLK) ;
        #1 ;
        checks = checks + 1 ;
        if (Result1 !== hold_r1 || Result2 !== hold_r2 || Busy !== 1'b0) begin
            errors = errors + 1 ;
            $display("FAIL: results or Busy changed while idle") ;
        end
        else
            $display("PASS: results and Busy stable for 5 idle cycles") ;

        // ==============================================================
        // 6. Back to back operations (Start held high), switching between
        //    multiply and divide, signed and unsigned
        // ==============================================================
        $display("--- 6. back-to-back, Start held high ---") ;
        run_op(2'b00, 4'b1111, 4'b1111, 1'b1) ;  // signed mult
        run_op(2'b11, 4'd15,   4'd2,    1'b1) ;  // unsigned div
        run_op(2'b01, 4'd15,   4'd15,   1'b1) ;  // unsigned mult
        run_op(2'b10, -4'sd7,  4'd2,    1'b1) ;  // signed div
        run_op(2'b10, 4'b1000, 4'b1111, 1'b1) ;  // signed div overflow
        run_op(2'b00, 4'd7,    4'd7,    1'b1) ;  // signed mult
        run_op(2'b11, 4'd7,    4'd2,    1'b0) ;  // unsigned div, last one drops Start

        // ==============================================================
        // 7. RESET in the middle of a division
        // ==============================================================
        $display("--- 7. reset during an operation ---") ;
        MCycleOp = 2'b11 ;
        Operand1 = 4'd13 ;
        Operand2 = 4'd3 ;
        Start = 1'b1 ;
        repeat (2) @(posedge CLK) ;
        #1 ;
        RESET = 1'b1 ;
        #1 ;
        checks = checks + 1 ;
        if (Busy !== 1'b0) begin
            errors = errors + 1 ;
            $display("FAIL: Busy should be low while RESET is high") ;
        end
        else
            $display("PASS: Busy low during RESET") ;
        @(posedge CLK) ;
        #1 ;
        Start = 1'b0 ;
        RESET = 1'b0 ;
        @(posedge CLK) ;
        #1 ;
        if (Busy !== 1'b0) begin
            errors = errors + 1 ;
            $display("FAIL: Busy not low after RESET released") ;
        end
        run_op(2'b11, 4'd13, 4'd3, 1'b0) ;      // 4 r1, unit must work normally after reset
        run_op(2'b00, 4'd5,  4'd3, 1'b0) ;      // and multiply too

        // ==============================================================
        // 8. Random back-to-back mix (Start held high), 500 operations
        // ==============================================================
        $display("--- 8. random back-to-back mix ---") ;
        verbose = 1'b0 ;
        for (i = 0; i < 500; i = i + 1) begin
            rnd1 = $urandom ;
            rnd2 = $urandom ;
            rnd3 = $urandom ;
            op_r = rnd1[1:0] ;
            a_r  = rnd2[3:0] ;
            b_r  = rnd3[3:0] ;
            if (op_r[1] && b_r == 4'd0) b_r = 4'd1 ;   // divisor is never zero
            run_op(op_r, a_r, b_r, 1'b1) ;
        end
        run_op(2'b00, 4'd1, 4'd1, 1'b0) ;               // drop Start
        verbose = 1'b1 ;

        // ==============================================================
        // 9. Exhaustive sweep: all 4 operations x 16 x 16 operand pairs
        //    (divisor 0 skipped for divides)
        // ==============================================================
        $display("--- 9. exhaustive sweep ---") ;
        verbose = 1'b0 ;
        for (k = 0; k < 4; k = k + 1)
            for (i = 0; i < 16; i = i + 1)
                for (j = 0; j < 16; j = j + 1)
                    if (!(k >= 2 && j == 0)) begin
                        op_r = k ;
                        a_r  = i ;
                        b_r  = j ;
                        run_op(op_r, a_r, b_r, 1'b0) ;
                    end
        verbose = 1'b1 ;

        // ==============================================================
        // Summary
        // ==============================================================
        #20 ;
        $display("==================================================") ;
        if (errors == 0)
            $display("ALL TESTS PASSED (%0d result checks)", checks) ;
        else
            $display("%0d ERROR(S) in %0d result checks", errors, checks) ;
        $display("==================================================") ;
        if (errors != 0)
            $fatal(1, "%0d MCycle test failure(s)", errors) ;
        $finish ;
    end

endmodule

module test_MCycle_Booth #(parameter WIDTH = 32);
    localparam BOOTH_CYCLES = (WIDTH+1)/2;
    localparam [7:0] REQUIRED_RECODES = (WIDTH == 3) ? 8'hd7 : 8'hff;
    localparam [WIDTH-1:0] MIN_SIGNED = {1'b1, {(WIDTH-1){1'b0}}};
    localparam [WIDTH-1:0] MAX_SIGNED = {1'b0, {(WIDTH-1){1'b1}}};

    reg CLK = 0;
    reg RESET = 1;
    reg Start = 0;
    reg [1:0] MCycleOp = 0;
    reg [WIDTH-1:0] Operand1 = 0;
    reg [WIDTH-1:0] Operand2 = 0;
    wire [WIDTH-1:0] Result1;
    wire [WIDTH-1:0] Result2;
    wire Busy;
    integer checks = 0;
    integer busy_cycles = 0;
    reg [7:0] recodes_seen = 0;
    reg [31:0] random_state = 32'h00003207;
    reg [WIDTH-1:0] edge_values [0:8];
    reg [WIDTH-1:0] alternating = 0;
    reg [WIDTH-1:0] random_a, random_b;
    reg [1:0] random_op;
    integer i, j;

    MCycle #(.width(WIDTH)) dut(
        CLK, RESET, Start, MCycleOp, Operand1, Operand2,
        Result1, Result2, Busy, 1'b1
    );

    always #5 CLK = ~CLK;

    always @(posedge CLK) begin
        if (Busy) begin
            busy_cycles = busy_cycles + 1;
            if (MCycleOp == 2'b00) begin
                if (dut.state == 1'b0)
                    recodes_seen[{Operand2[1:0], 1'b0}] = 1'b1;
                else
                    recodes_seen[dut.booth_p[2:0]] = 1'b1;
            end
        end
    end

    function [31:0] next_random;
        input [31:0] previous;
        reg [31:0] value;
        begin
            value = previous ^ (previous << 13);
            value = value ^ (value >> 17);
            next_random = value ^ (value << 5);
        end
    endfunction

    task run_op;
        input [1:0] op;
        input [WIDTH-1:0] a, b;
        input hold;
        reg signed [2*WIDTH-1:0] signed_a, signed_b;
        reg [2*WIDTH-1:0] product;
        reg [WIDTH-1:0] expected1, expected2;
        reg started_from_idle;
        integer expected_cycles;
        begin
            signed_a = {{WIDTH{a[WIDTH-1]}}, a};
            signed_b = {{WIDTH{b[WIDTH-1]}}, b};
            case (op)
                2'b00: begin
                    product = signed_a * signed_b;
                    expected1 = product[WIDTH-1:0];
                    expected2 = product[2*WIDTH-1:WIDTH];
                    expected_cycles = BOOTH_CYCLES;
                end
                2'b01: begin
                    product = {{WIDTH{1'b0}}, a} * {{WIDTH{1'b0}}, b};
                    expected1 = product[WIDTH-1:0];
                    expected2 = product[2*WIDTH-1:WIDTH];
                    expected_cycles = WIDTH;
                end
                2'b10: begin
                    if (b == 0) $fatal(1, "Zero divisor in test");
                    expected1 = signed_a / signed_b;
                    expected2 = signed_a % signed_b;
                    expected_cycles = WIDTH;
                end
                2'b11: begin
                    if (b == 0) $fatal(1, "Zero divisor in test");
                    expected1 = a / b;
                    expected2 = a % b;
                    expected_cycles = WIDTH;
                end
            endcase
            @(negedge CLK);
            started_from_idle = (dut.state == 1'b0);
            MCycleOp = op;
            Operand1 = a;
            Operand2 = b;
            busy_cycles = 0;
            Start = 1;
            #1;
            if (started_from_idle) begin
                if (Busy !== 1'b1) $fatal(1, "Busy did not rise from idle");
            end
            else begin
                if (Busy !== 1'b0) $fatal(1, "Missing completion interval");
                @(posedge CLK);
                #1;
                if (Busy !== 1'b1) $fatal(1, "Back-to-back operation not accepted");
            end
            wait (Busy === 1'b1);
            wait (Busy === 1'b0);
            #1;
            checks = checks + 1;
            if (Result1 !== expected1 || Result2 !== expected2 || busy_cycles != expected_cycles)
                $fatal(1, "WIDTH=%0d op=%b a=%h b=%h result=%h:%h expected=%h:%h cycles=%0d expected_cycles=%0d",
                    WIDTH, op, a, b, Result2, Result1, expected2, expected1, busy_cycles, expected_cycles);
            if (!hold) begin
                Start = 0;
                @(posedge CLK);
                #1;
                if (Busy !== 1'b0 || Result1 !== expected1 || Result2 !== expected2)
                    $fatal(1, "Idle result retention failed");
            end
        end
    endtask

    task check_idle;
        reg [WIDTH-1:0] saved1, saved2;
        integer step;
        begin
            saved1 = Result1;
            saved2 = Result2;
            for (step = 0; step < 5; step = step + 1) begin
                @(negedge CLK);
                Operand1 = ~Operand1;
                Operand2 = Operand2 + 1'b1;
                MCycleOp = MCycleOp + 1'b1;
                @(posedge CLK);
                #1;
                if (Busy !== 1'b0 || Result1 !== saved1 || Result2 !== saved2)
                    $fatal(1, "Results changed with inputs while idle");
            end
        end
    endtask

    task reset_multiply;
        input integer completed_iterations;
        begin
            @(negedge CLK);
            MCycleOp = 2'b00;
            Operand1 = MIN_SIGNED;
            Operand2 = MAX_SIGNED;
            Start = 1;
            #1;
            if (Busy !== 1'b1) $fatal(1, "Reset test did not start");
            repeat (completed_iterations) @(posedge CLK);
            #1;
            if (Busy !== 1'b1) $fatal(1, "Reset test reached completion too early");
            RESET = 1;
            #1;
            if (Busy !== 1'b0) $fatal(1, "Busy did not clear during reset");
            @(posedge CLK);
            #1;
            Start = 0;
            RESET = 0;
            @(posedge CLK);
            #1;
            if (Busy !== 1'b0) $fatal(1, "Busy did not remain idle after reset");
            run_op(2'b00, MIN_SIGNED, {WIDTH{1'b1}}, 1'b0);
            run_op(2'b11, MAX_SIGNED, {{(WIDTH-1){1'b0}}, 1'b1}, 1'b0);
        end
    endtask

    initial begin
        if (WIDTH < 3 || WIDTH > 32) $fatal(1, "Test supports widths 3 through 32");
        for (i = 0; i < WIDTH; i = i + 1)
            alternating[i] = i % 2;
        edge_values[0] = 0;
        edge_values[1] = 1;
        edge_values[2] = {WIDTH{1'b1}};
        edge_values[3] = 2;
        edge_values[4] = -2;
        edge_values[5] = MIN_SIGNED;
        edge_values[6] = MAX_SIGNED;
        edge_values[7] = alternating;
        edge_values[8] = ~alternating;
        #11;
        RESET = 0;

        for (i = 0; i < 9; i = i + 1)
            for (j = 0; j < 9; j = j + 1)
                run_op(2'b00, edge_values[i], edge_values[j], 1'b0);
        check_idle;

        if (WIDTH <= 5)
            for (i = 0; i < (1 << WIDTH); i = i + 1)
                for (j = 0; j < (1 << WIDTH); j = j + 1)
                    run_op(2'b00, i, j, 1'b0);

        for (i = 0; i < WIDTH; i = i + 1) begin
            run_op(2'b00, MIN_SIGNED, {{(WIDTH-1){1'b0}}, 1'b1} << i, 1'b1);
            run_op(2'b00, MAX_SIGNED, -({{(WIDTH-1){1'b0}}, 1'b1} << i), 1'b0);
        end

        for (i = 0; i < 1000; i = i + 1) begin
            random_state = next_random(random_state);
            random_a = random_state;
            random_state = next_random(random_state);
            random_b = random_state;
            run_op(2'b00, random_a, random_b, 1'b1);
        end
        run_op(2'b00, MIN_SIGNED, MIN_SIGNED, 1'b0);

        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                run_op(i, MIN_SIGNED, MAX_SIGNED, 1'b1);
                run_op(j, MAX_SIGNED, {WIDTH{1'b1}}, 1'b1);
            end
        run_op(2'b00, MIN_SIGNED, {WIDTH{1'b1}}, 1'b0);

        for (i = 0; i < 500; i = i + 1) begin
            random_state = next_random(random_state);
            random_op = random_state[1:0];
            random_state = next_random(random_state);
            random_a = random_state;
            random_state = next_random(random_state);
            random_b = random_state;
            if (random_op[1] && random_b == 0) random_b = 1;
            run_op(random_op, random_a, random_b, 1'b1);
        end
        run_op(2'b00, 1, 1, 1'b0);

        reset_multiply(1);
        reset_multiply(BOOTH_CYCLES/2);
        reset_multiply(BOOTH_CYCLES-1);
        check_idle;
        if (recodes_seen !== REQUIRED_RECODES) $fatal(1, "Missing Booth recodes: %b", recodes_seen);
        $display("ALL BOOTH TESTS PASSED (WIDTH=%0d, %0d result checks, recodes=%b)", WIDTH, checks, recodes_seen);
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "Booth testbench timeout");
    end
endmodule
