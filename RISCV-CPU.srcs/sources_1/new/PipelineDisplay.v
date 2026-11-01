`timescale 1ns / 1ps
module PipelineDisplay #(
    parameter DEBOUNCE_CYCLES = 1000000
)(
    input CLK, RESET,
    input Left, Right,
    input [767:0] Snapshot,
    output PixelWrite,
    output reg [6:0] PixelColumn = 0,
    output reg [5:0] PixelRow = 0,
    output reg [15:0] PixelData = 0
);
    wire LeftPulse, RightPulse;
    reg [1:0] Page = 0, FramePage = 0;
    reg [767:0] Frame = 0;
    reg [6:0] X = 0;
    reg [5:0] Y = 0;
    reg Drawing = 0;
    wire [2:0] Row = Y[5:3];
    wire Pixel;
    reg [127:0] RenderLine = 0;
    reg [15:0] LineColor = 0, CharacterColor = 0;
    reg [6:0] LineX = 0, CharacterX = 0;
    reg [5:0] LineY = 0, CharacterY = 0;
    reg [7:0] Character = 0;
    reg [2:0] FontX = 0, FontY = 0;
    reg LineValid = 0, CharacterValid = 0, OutputValid = 0;
    reg [15:0] Color;
    reg [127:0] Line;
    reg [31:0] Value;
    reg StageValid, StageHeld;
    integer Stage;
    StepController #(.STABLE_CYCLES(DEBOUNCE_CYCLES)) LeftButton(CLK, RESET, Left, LeftPulse);
    StepController #(.STABLE_CYCLES(DEBOUNCE_CYCLES)) RightButton(CLK, RESET, Right, RightPulse);
    DebugFont Font(Character, FontX, FontY, Pixel);
    assign PixelWrite = OutputValid && !RESET;

    function [7:0] hexchar;
        input [3:0] Nibble;
        begin hexchar = Nibble < 10 ? 8'd48 + Nibble : 8'd65 + Nibble - 10; end
    endfunction
    function [63:0] hexword;
        input [31:0] Word;
        integer n;
        begin
            for(n=0;n<8;n=n+1) hexword[63-n*8 -: 8]=hexchar(Word[31-n*4 -: 4]);
        end
    endfunction

    always @(*) begin
        Line = "                ";
        Color = 16'hffff;
        Value = 0;
        Stage = 0;
        StageValid = 0;
        StageHeld = 0;
        if (FramePage < 2) begin
            if (Row == 0) begin
                if (FramePage == 0) Line = "PIPELINE HEX    ";
                else Line = "PIPELINE PC     ";
            end
            else if (Row <= 5) begin
                Stage = Row - 1;
                StageValid = Frame[320+Stage];
                StageHeld = (Stage < 2 && (Frame[325] || Frame[326])) ||
                    (Stage == 2 && Frame[326]);
                case(Stage)
                    0: Line[127:104] = "IF ";
                    1: Line[127:104] = "ID ";
                    2: Line[127:104] = "EX ";
                    3: Line[127:104] = "MEM";
                    4: Line[127:104] = "WB ";
                    default: Line[127:104] = "   ";
                endcase
                if(FramePage == 0) Value = Frame[160+Stage*32 +: 32];
                else Value = Frame[Stage*32 +: 32];
                if(StageValid) Line[95:32] = hexword(Value);
                else Line[95:32] = "--------";
                if(!StageValid) Line[23:16] = "B";
                else if(StageHeld) Line[23:16] = "H";
                else Line[23:16] = "A";
                if(StageHeld && StageValid) Color = 16'hffe0;
            end
            else if(FramePage == 0) begin
                if(Row == 6) Line = {"CYC ",hexword(Frame[333+:32]),"    "};
                else if(Frame[326]) begin Line="MCYCLE HOLD     "; Color=16'hffe0; end
                else if(Frame[325]) begin Line="LOAD STALL      "; Color=16'hffe0; end
                else Line="CENTRE TO STEP  ";
            end
            else begin
                if(Row == 6) Line={"P   ",hexword(Frame[365+:32]),"    "};
                else Line={"A   ",hexword(Frame[397+:32]),"    "};
            end
        end
        else if (!Frame[717]) begin
            if(Row == 0) Line="NO FLUSH YET    ";
            else if(Row == 7) Line="CENTRE TO STEP  ";
        end
        else begin
            case(Row)
                0: Line={"FLUSH ",hexword(Frame[685+:32]),"  "};
                1: begin
                    Line={"EX  ",hexword(Frame[429+:32]),"    "};
                    if(Frame[720]) Line[23:16]="D";
                    if(Frame[721]) Line[15:8]="T";
                end
                2: begin
                    Line={"IF  ",hexword(Frame[525+:32])," X  "};
                    if(!Frame[718]) Line="IF  -------- B  ";
                end
                3: Line={"PC  ",hexword(Frame[493+:32]),"    "};
                4: begin
                    Line={"ID  ",hexword(Frame[589+:32])," X  "};
                    if(!Frame[719]) Line="ID  -------- B  ";
                end
                5: Line={"PC  ",hexword(Frame[557+:32]),"    "};
                6: Line={"P   ",hexword(Frame[621+:32]),"    "};
                7: Line={"A   ",hexword(Frame[653+:32]),"    "};
            endcase
            if(Row >= 2 && Row <= 5) Color=16'hf800;
        end
    end

    always @(posedge CLK) begin
        if(RESET) begin
            LineValid<=0;
            CharacterValid<=0;
            OutputValid<=0;
            RenderLine<=0;
            LineColor<=0;
            LineX<=0;
            LineY<=0;
            Character<=0;
            CharacterColor<=0;
            CharacterX<=0;
            CharacterY<=0;
            FontX<=0;
            FontY<=0;
            PixelColumn<=0;
            PixelRow<=0;
            PixelData<=0;
            Page<=0;
            FramePage<=0;
            Frame<=0;
            X<=0;
            Y<=0;
            Drawing<=0;
        end
        else begin
            LineValid<=Drawing;
            RenderLine<=Line;
            LineColor<=Color;
            LineX<=X;
            LineY<=Y;
            CharacterValid<=LineValid;
            Character<=RenderLine[127-(LineX/6)*8 -: 8];
            CharacterColor<=LineColor;
            CharacterX<=LineX;
            CharacterY<=LineY;
            FontX<=LineX%6;
            FontY<=LineY[2:0];
            OutputValid<=CharacterValid;
            PixelColumn<=CharacterX;
            PixelRow<=CharacterY;
            PixelData<=Pixel ? CharacterColor : 16'h0000;
            if(LeftPulse && !RightPulse) Page<=Page==0 ? 2 : Page-1'b1;
            else if(RightPulse && !LeftPulse) Page<=Page==2 ? 0 : Page+1'b1;
            if(!Drawing) begin
                if(!LineValid && !CharacterValid && !OutputValid) begin
                    Frame<=Snapshot;
                    FramePage<=Page;
                    Drawing<=1;
                    X<=0;
                    Y<=0;
                end
            end
            else if(X==95) begin
                X<=0;
                if(Y==63) begin Y<=0; Drawing<=0; end
                else Y<=Y+1'b1;
            end
            else X<=X+1'b1;
        end
    end
endmodule
