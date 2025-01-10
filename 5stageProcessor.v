module five_stage_processor(clk1,clk2);
reg[31:0] IF_ID_IR,IF_ID_NPC; //IF_ID_Latch
reg[31:0] PC;
reg[31:0] ID_EX_Imm,ID_EX_type,ID_EX_NPC,ID_EX_IR; //ID_EX_latch
reg[31:0] EX_MEM_IR,EX_MEM_cond,EX_MEM_ALUOut,EX_MEM_B,EX_MEM_type;//EX_MEM latch
reg[31:0] MEM_WB_IR,MEM_WB_LMD,MEM_WB_ALUOut,MEM_WB_type;//MEM_WB_Latch
reg[4:0] ID_EX_A,ID_EX_B;
//Register and Memory

reg[31:0] Reg[0:31];
reg[31:0] Mem[0:1023];

//Halt and brach
reg Halted,TAKEN_BRANCH;


input clk1,clk2;

//type parameter
parameter RR_ALU = 3'b000,
RM_ALU = 3'b001,
STORE = 3'b010,
LOAD = 3'b011,
BRANCH = 3'b100,
COMPARE = 3'b101,
HAlT = 3'b111;



//UP_CODE
parameter ADD = 6'b000000,
SUB     =   6'b000001,
OR      =   6'b000010,
AND     =   6'b000011,
MUL     =   6'b000100,
HLT     =   6'b111111,
LW      =   6'b000110,
SW      =   6'b000111,
ADDI    =   6'b001000,
SUBI    =   6'b001001,
BNEQZ   =   6'b001010,
BEQZ    =   6'b001011,
SLT     =   6'b001101,
SLTI    =   6'b001110,
DCR = 6'b001111,
CMP = 6'b010000,
CMPI = 6'b010001;


//IF Stage

always @(posedge clk1) begin

    if(!Halted) begin
        if((EX_MEM_cond == 1 && EX_MEM_IR[31:26] == BEQZ) || (EX_MEM_cond == 0 && EX_MEM_IR[31:26] == BNEQZ) || (EX_MEM_cond == 1 && EX_MEM_IR[31:26] == CMP) || (EX_MEM_cond == 1 && EX_MEM_IR[31:26] == CMPI)) begin
           IF_ID_IR <= Mem[EX_MEM_ALUOut];
           PC <= EX_MEM_ALUOut;
           IF_ID_NPC <= EX_MEM_ALUOut +1;
           TAKEN_BRANCH =   1;
           

        end
        else 
        IF_ID_IR = Mem[PC];
        IF_ID_NPC = PC + 1;
        PC = PC +1;
    end
end



//ID Stage
always @(posedge clk2) begin
    if(!Halted) begin
        case(IF_ID_IR[31:26])
        ADD,SUB,OR,AND,MUL,DCR   : ID_EX_type     <= RR_ALU;
        HLT                  : ID_EX_type     <= HAlT;
        ADDI,SUBI            : ID_EX_type     <= RM_ALU;
        SW                   : ID_EX_type     <= STORE;
        LW                   : ID_EX_type     <= LOAD;
        BNEQZ,BEQZ           : ID_EX_type     <= BRANCH;
        CMP,CMPI                  : ID_EX_type     <= COMPARE;
        // default : ID_EX_type <=  HAlT;
        endcase
    

    ID_EX_A      <=     IF_ID_IR[25:21];
    ID_EX_B      <=     IF_ID_IR[20:16];
    ID_EX_Imm    <=     {{16{IF_ID_IR[15]}},IF_ID_IR[15:0]};
    ID_EX_NPC    <=     IF_ID_NPC;
    ID_EX_IR     <=     IF_ID_IR;
    end
end



//Execution or ALU

always @(posedge clk1)
begin
    if(!Halted) begin
    case(ID_EX_IR[31:26])
        ADD     :   EX_MEM_ALUOut   <=  Reg[ID_EX_A] + Reg[ID_EX_B];
        SUB     :   EX_MEM_ALUOut   <=  Reg[ID_EX_A] - Reg[ID_EX_B];
        OR      :   EX_MEM_ALUOut   <=  Reg[ID_EX_A] | Reg[ID_EX_B];
        AND     :   EX_MEM_ALUOut   <=  Reg[ID_EX_A] & Reg[ID_EX_B];        
        MUL     :   EX_MEM_ALUOut   <=  Reg[ID_EX_A] * Reg[ID_EX_B]; 
        DCR     :   EX_MEM_ALUOut       <=  Reg[ID_EX_A] - 1;       
        LW,SW   :   begin EX_MEM_ALUOut   <=  Reg[ID_EX_A] + ID_EX_Imm; EX_MEM_B <= ID_EX_B;end
        ADDI    :   EX_MEM_ALUOut   <=  Reg[ID_EX_A] + ID_EX_Imm;
        SUBI    :   #2 EX_MEM_ALUOut   <=  Reg[ID_EX_A] - ID_EX_Imm;       
        BNEQZ,BEQZ: begin EX_MEM_ALUOut   <= ID_EX_Imm;    EX_MEM_cond <= (Reg[ID_EX_A] == 0);end      
        CMP     :   begin EX_MEM_ALUOut   <= ID_EX_Imm;   EX_MEM_cond <= (Reg[ID_EX_A] == Reg[ID_EX_B]);end    
        CMPI    :   begin EX_MEM_ALUOut <= ID_EX_Imm; EX_MEM_cond <= (Reg[ID_EX_A] == ID_EX_IR[20:16]);end
        SLT     :   EX_MEM_ALUOut   <=    Reg[ID_EX_A] < Reg[ID_EX_B];
        SLTI    :   EX_MEM_ALUOut   <=    Reg[ID_EX_A] < ID_EX_Imm;
        
    endcase

    EX_MEM_IR <= ID_EX_IR;
    TAKEN_BRANCH = 0;
    EX_MEM_type <= ID_EX_type;
    end
    
end


//MEM Stage
always @(posedge clk2) begin
    if(!Halted) begin
        MEM_WB_IR <= EX_MEM_IR;
        MEM_WB_type <= EX_MEM_type;
        case(EX_MEM_type)
        STORE: Mem[EX_MEM_ALUOut] <= Reg[EX_MEM_B];
        LOAD : MEM_WB_LMD <= Mem[EX_MEM_ALUOut];
        RR_ALU,RM_ALU : MEM_WB_ALUOut <= EX_MEM_ALUOut;
        endcase
    end
end


//WB stage

always @(posedge clk1) begin
    if(!Halted) begin
    case(MEM_WB_type)
    LOAD : Reg[MEM_WB_IR[20:16]] <= MEM_WB_LMD;
    HAlT : Halted <= 1'b1;
    RR_ALU: Reg[MEM_WB_IR[15:11]] <= MEM_WB_ALUOut;
    RM_ALU: Reg[MEM_WB_IR[20:16]] <= MEM_WB_ALUOut;
    // default: Halted <= 1'b1;

    endcase
    end
end

endmodule

module tb_processor;
reg clk1,clk2;
integer k;
initial
begin
    clk1 = 0;
    clk2 = 0;
    repeat(200)
    begin
        #5 clk1 = 0; #5 clk1 = 1;
        #5 clk2 = 1; #5 clk2 = 0;
    end
end
five_stage_processor m(clk1,clk2);


initial
begin
    m.PC = 0;
    m.Halted = 0;
    m.TAKEN_BRANCH =0;
    
    for(k=0;k<=31;k++)
    m.Reg[k] = 0;
    
    
    m.Mem[1000] = 10;
    
    /*      YOUR CODE HERE


    EXAMPLE CODE

    //LOOP to print form 10 to 9
    // m.Mem[0] = 32'h180103e8; //R1 = 10;
    // m.Mem[1] = 32'h08c52800; //dummy
    // m.Mem[2] = 32'h24210001; //R1 = R1 - 1; 
    // m.Mem[3] = 32'h08c52800; //dummy
    
    // m.Mem[4] = 32'h28200001; //Branch to memory location 1 when R1 != 0
    // m.Mem[5] = 32'h08c52800; //dummy
    // m.Mem[6] = 32'h08c52800; //dummy
    // m.Mem[11] = 32'hfc000000; //dummy

*/

  

    


    

    #5

    for(k=0;k<11;k++)
    $display ("   R%1d - %2d",k,m.Reg[k]);

    $monitor(" Reg %b ,%2d - Coud , ALU - %d, PC - %d, EX_MEM_IR - %h, R1 = %d  R2 = %d",m.ID_EX_A,m.EX_MEM_cond,m.EX_MEM_ALUOut,m.PC,m.EX_MEM_IR ,m.Reg[1],m.Reg[2]);

    #10000 $finish ;
end
endmodule



