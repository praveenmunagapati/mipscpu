/* mips_cpu.v
* Author: Pravin P. Prabhu and Dean Tullsen
* Last Revision: 1/5/11
* Abstract:
*    The top level module for the MIPS32 processor. This is a classic 5-stage
* MIPS pipeline architecture which is intended to follow heavily from the model
* presented in Hennessy and Patterson's Computer Organization and Design.
*/
module mips_cpu(// General     
                input CLOCK_50,    //These inputs are all pre-defined input/output pin names
                //input Global_Reset_n,        // TEMP - Remove this after testing
                input [3:0] KEY,    // which correspond to the DE2_pin_assignments,csv file.  This
                input [17:0] SW,    // way, the mapping is automatically taken care of if we get the
                output [6:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, // name right.
                output [7:0] LEDG,
                output [17:0] LEDR,
                
                //SDRAM interface
                output [11:0] DRAM_ADDR,   
                output DRAM_BA_0,
                output DRAM_BA_1,
                output DRAM_CAS_N,
                output DRAM_CKE,
                output DRAM_CLK,
                output DRAM_CS_N,
                inout [15:0] DRAM_DQ,
                output DRAM_LDQM,
                output DRAM_UDQM,
                output DRAM_RAS_N,
                output DRAM_WE_N,
                
                //Flash RAM interface
                output [21:0] FL_ADDR,        
                inout [7:0] FL_DQ,
                output FL_CE_N,
                output FL_OE_N,
                output FL_RST_N,
                output FL_WE_N,
                
                 //SRAM interface
                output [17:0] SRAM_ADDR,  
                inout [15:0] SRAM_DQ,
                output SRAM_UB_N,
                output SRAM_LB_N,
                output SRAM_WE_N,
                output SRAM_OE_N,
                output SRAM_CE_N
            );

//===================================================================
//    Internal Wiring
//===================================================================

//===================================================================
// General Signals
localparam FALSE = 1'b0;
localparam TRUE = 1'b1;
localparam ADDRESS_WIDTH = 22;
localparam DATA_WIDTH = 32;
localparam HISTORY_SIZE = 10;                                //NEW for history table
localparam COUNT_SIZE = 4;                                    //NEW for branch prediction
localparam CHECKPOINT_WIDTH = 2;                            //NEW for register renaming
//wire Global_Reset_n;            // Global reset
wire Global_Reset_n = KEY[0];

    // MTC0 codes - Did we pass/fail a test or reach the done state?
localparam MTC0_NOOP = 0;        // No significance
localparam MTC0_PASS = 1;            // Passed a test
localparam MTC0_FAIL = 2;        // Failed a test
localparam MTC0_DONE = 3;            // Have completed execution

assign LEDG[7:1] = 0;
assign LEDR[17:1] = 0;

assign SRAM_ADDR = 0;
assign SRAM_UB_N = 0;
assign SRAM_LB_N = 0;
assign SRAM_WE_N = 0;
assign SRAM_OE_N = 0;
assign SRAM_CE_N = 0;

//===================================================================
// New signals
wire [DATA_WIDTH-1:0] EX_i_Instruction;
wire EX_i_Is_Load = (EX_i_Instruction[(DATA_WIDTH-1):(DATA_WIDTH-6)] == 6'd32 
                        || EX_i_Instruction[DATA_WIDTH-1:DATA_WIDTH-6] == 6'd15
                        || EX_i_Instruction[DATA_WIDTH-1:DATA_WIDTH-6] == 6'd35);
wire i_Taken;
wire i_Was_Taken;
wire [DATA_WIDTH-1:0] DMEM_i_Instruction;

// Value History Table Signals
wire [DATA_WIDTH-1:0] Predict_Data;
wire Revert_Predict;
wire Predicted;
wire Value_Predicted;

// Branch History Table Signals
wire [1:0] DEC_o_Branch_Predictor;
wire [COUNT_SIZE-1:0] DEC_o_Branch_Pattern;
wire [1:0] EX_i_Branch_Predictor;
wire [COUNT_SIZE-1:0] EX_i_Branch_Pattern;
wire Smash_Transient_i;

//RR Signals
localparam FREE_LIST_WIDTH = 5;
wire Hazard_Create_Map_Checkpoint;
wire Hazard_Create_List_Checkpoint;
wire [ADDRESS_WIDTH-1:0] Revert_PC;
wire [CHECKPOINT_WIDTH-1:0] Revert_Checkpoint;
wire Regfile_Stall;

//===================================================================
// IFetch Signals

wire IFetch_i_Flush;            // Flush for IFetch
wire Hazard_Stall_IF;                // Stall for IFetch
wire IFetch_i_Load;            // Load signal - if high, load pc with vector
wire [ADDRESS_WIDTH-1:0] IFetch_i_PCSrc;    // Vector to branch to

wire [ADDRESS_WIDTH-1:0] IMEM_i_Address;    // Current PC


wire IMEM_o_Ready;
wire IMEM_o_Valid;
wire [DATA_WIDTH-1:0] IMEM_o_Instruction;

    //==============
    // Pipe signals: IF->ID
wire Hazard_Flush_IF;            // 1st pipe flush
wire Hazard_Stall_DEC;        // 1st pipe stall
wire imembubble_DEC;            // set if instruction coming out of icache 
                                    // was not real instruction 
//===================================================================
// Decoder Signals
localparam ALU_CTLCODE_WIDTH = 8;
localparam REG_ADDR_WIDTH = 5;
localparam MEM_MASK_WIDTH = 3;
wire [ADDRESS_WIDTH-1:0] DEC_i_PC;                    // PC of inst
wire [DATA_WIDTH-1:0] DEC_i_Instruction;                // Inst into decode
wire DEC_Noop = (DEC_i_Instruction == 32'd0);

wire DEC_o_Uses_ALU;
wire [ALU_CTLCODE_WIDTH-1:0] DEC_o_ALUCTL;            // ALU control code
wire DEC_o_Is_Branch;                                    // If it's a branch
wire [ADDRESS_WIDTH-1:0] DEC_o_Branch_Target;        // Where we will branch to
wire DEC_o_Jump_Reg;                                    // If this is a special case where we jump TO a register value

wire DEC_o_Mem_Valid;
wire DEC_o_Mem_Read_Write_n;
wire [MEM_MASK_WIDTH-1:0] DEC_o_Mem_Mask;            // Used for masking individual memory ops - such as byte and halfword transactions

wire DEC_o_Writes_Back;
wire [REG_ADDR_WIDTH-1:0] DEC_o_VWrite_Addr;
wire [REG_ADDR_WIDTH:0] DEC_o_PWrite_Addr;
wire [FREE_LIST_WIDTH-1:0] DEC_o_Phys_Active_List_Index;
wire DEC_o_Uses_RS;
wire [REG_ADDR_WIDTH-1:0] DEC_o_Read_VRegister_1;
wire DEC_o_Uses_RT;
wire [REG_ADDR_WIDTH-1:0] DEC_o_Read_VRegister_2;

wire [CHECKPOINT_WIDTH-1:0] DEC_o_Checkpoint;

wire [REG_ADDR_WIDTH:0] DEC_o_Read_PRegister_1;
wire [REG_ADDR_WIDTH:0] DEC_o_Read_PRegister_2;

wire [DATA_WIDTH-1:0] DEC_o_Read_Data_1;
wire [DATA_WIDTH-1:0] DEC_o_Read_Data_2;

wire DEC_o_Uses_Immediate;
wire [DATA_WIDTH-1:0] DEC_o_Immediate;

wire [DATA_WIDTH-1:0] FORWARD_o_Forwarded_Data_1,FORWARD_o_Forwarded_Data_2;    // Looked up regs

    //==============
    // Pipe signals: ID->EX
wire Hazard_Flush_DEC;        // 2nd pipe flush
wire Hazard_Stall_EX;            // 2nd pipe stall

wire [ADDRESS_WIDTH-1:0] DEC_o_PC;
assign DEC_o_PC = DEC_i_PC;

//===================================================================
// Execute Signals

wire [ADDRESS_WIDTH-1:0] ALU_i_PC;

wire EX_i_Is_Branch;
wire EX_i_Mem_Valid;
wire [MEM_MASK_WIDTH-1:0] EX_i_Mem_Mask;
wire EX_i_Mem_Read_Write_n;
wire [DATA_WIDTH-1:0] EX_i_Mem_Write_Data;
wire EX_i_Writes_Back;
wire [REG_ADDR_WIDTH-1:0] EX_i_VWrite_Addr;
wire [REG_ADDR_WIDTH:0] EX_i_PWrite_Addr;
wire [FREE_LIST_WIDTH-1:0] EX_i_Phys_Active_List_Index;

wire ALU_i_Valid;                                        // Whether input to ALU is valid or not
wire ALU_o_Valid;
wire [ALU_CTLCODE_WIDTH-1:0] ALU_i_ALUOp;                    // Control bus to ALU
wire [DATA_WIDTH-1:0] ALU_i_Operand1,ALU_i_Operand2;    // Ops for ALU
wire [ADDRESS_WIDTH-1:0] EX_i_Branch_Target;
wire [DATA_WIDTH-1:0] ALU_o_Result;                            // Computation of ALU
wire ALU_o_Branch_Valid;                                // Whether branch is valid or not
wire ALU_o_Branch_Outcome;                                    // Whether branch is taken or not
wire [15:0] ALU_o_Pass_Done_Value;                        // reports the value of a PASS/FAIL/DONE instruction
wire [1:0] ALU_o_Pass_Done_Change;                            // indicates the above signal is meaningful
                                                            // 1 = pass, 2 = fail, 3 = done
                                                            
wire [CHECKPOINT_WIDTH-1:0] EX_i_Checkpoint;

    // Cumulative signals
wire EX_Take_Branch = ALU_o_Valid && ALU_o_Branch_Valid && ALU_o_Branch_Outcome;        // Whether we should branch or not.

    //==============
    // Pipe signals: EX->MEM
wire Hazard_Flush_EX;        // 3rd pipe flush
wire Hazard_Stall_MEM;            // 3rd pipe stall


//===================================================================
// Memory Signals
wire [ADDRESS_WIDTH-1:0] DMEM_i_PC;

wire [DATA_WIDTH-1:0] DMEM_i_Result;                    // Result from the ALU
wire [DATA_WIDTH-1:0] DMEM_i_Mem_Write_Data;        // What we will write back to mem (if applicable)
wire DMEM_i_Mem_Valid;                                // If the memory operation is valid
wire [MEM_MASK_WIDTH-1:0] DMEM_i_Mem_Mask;        // Mem mask for sub-word operations
wire DMEM_i_Mem_Read_Write_n;                    // Type of memop
wire DMEM_i_Writes_Back;                                // If the result should be written back to regfile
wire [REG_ADDR_WIDTH-1:0] DMEM_i_VWrite_Addr;        // Which vreg in the regfile to write to
wire [REG_ADDR_WIDTH:0] DMEM_i_PWrite_Addr;        // Which preg in the regfile to write to
wire [FREE_LIST_WIDTH-1:0] DMEM_i_Phys_Active_List_Index;
wire [DATA_WIDTH-1:0] DMEM_o_Read_Data;                // The data READ from DMEM
wire DMEM_o_Mem_Ready;                            // If the DMEM is ready to service another request
wire DMEM_o_Mem_Valid;                                // If the value read from DMEM is valid
reg DMEM_o_Done;                                    // If MEM's work is finalized
reg [DATA_WIDTH-1:0] DMEM_o_Write_Data;                // Data we should write back to regfile

wire MemToReg = DMEM_i_Mem_Valid;            // Selects what we will write back -- mem or ALU result

wire [CHECKPOINT_WIDTH-1:0] MEM_i_Checkpoint;

//==============
// Mem_Prediction Signals
wire [DATA_WIDTH-1:0] r_DMEM_o_Write_Data;
			
wire r_DMEM_i_Writes_Back;
wire [REG_ADDR_WIDTH-1:0] r_DMEM_i_VWrite_Addr;
wire [REG_ADDR_WIDTH:0] r_DMEM_i_PWrite_Addr;
wire [FREE_LIST_WIDTH-1:0] r_DMEM_i_Phys_Active_List_Index;

//==============
// Pipe signals: MEM->WB
wire Hazard_Flush_MEM;        // 4th pipe flush
wire Hazard_Stall_WB;    // 4th pipe stall


//===================================================================
// Write-Back Signals
wire r_WB_i_Writes_Back;                            // If we will write back
wire [REG_ADDR_WIDTH-1:0] r_DEC_i_VWrite_Register;
wire [REG_ADDR_WIDTH:0] r_DEC_i_PWrite_Register;// Where we will write back to
wire [FREE_LIST_WIDTH-1:0] r_DEC_i_Phys_Active_List_Index;
wire [DATA_WIDTH-1:0] r_WB_i_Write_Data;            // What we will write back
wire r_Hazard_Flush_WB;                                    // Request to squash WB contents

wire WB_i_Writes_Back;                            // If we will write back
wire [REG_ADDR_WIDTH-1:0] DEC_i_VWrite_Register;
wire [REG_ADDR_WIDTH:0] DEC_i_PWrite_Register;// Where we will write back to
wire [FREE_LIST_WIDTH-1:0] DEC_i_Phys_Active_List_Index;
wire [DATA_WIDTH-1:0] WB_i_Write_Data;            // What we will write back
wire Hazard_Flush_WB;                                    // Request to squash WB contents

wire DEC_i_RegWrite = WB_i_Writes_Back && !Hazard_Flush_WB;

//===================================================================
// Flash Signals
wire o_FlashLoader_Done;                        // Raised when the loader finishes
wire o_FlashLoader_SDRAM_Read_Write_n;        // FlashLoader's actual request to dmem
wire o_FlashLoader_SDRAM_Req_Valid;                // FlashLoader's verification of request to dmem
wire [ADDRESS_WIDTH-1:0] o_FlashLoader_SDRAM_Addr;        // FlashLoader's request addrto dmem
wire [DATA_WIDTH-1:0] o_FlashLoader_SDRAM_Data;            // FlashLoader's output data
wire i_FlashLoader_SDRAM_Data_Read;            // FlashLoader's input callback from dmem
wire i_FlashLoader_SDRAM_Last;                    // ""
wire [21:0] o_FlashLoader_FL_Addr;            // FlashLoader's addr request to flash
wire [7:0] i_FlashLoader_FL_Data;                // FlashLoader's data coming back from flash
wire o_FlashLoader_FL_Chip_En_n;            // FlashLoader's chip enable to flash
wire o_FlashLoader_FL_Output_En_n;                // "" (output enable)
wire o_FlashLoader_FL_Reset_n;                // "" (flash reset)
wire o_FlashLoader_FL_Write_En_n;                // Write enable going out to flash

    // Top level connections
assign FL_ADDR = o_FlashLoader_FL_Addr;                    // Addr we're requesting to deal with
assign i_FlashLoader_FL_Data = FL_DQ;                        // Incoming data from flash (for reads)
assign FL_CE_N = o_FlashLoader_FL_Chip_En_n;            // Flash chip enable
assign FL_OE_N = o_FlashLoader_FL_Output_En_n;                // Flash output enable
assign FL_WE_N = o_FlashLoader_FL_Write_En_n;            // Flash write enable
assign FL_RST_N    = o_FlashLoader_FL_Reset_n;                    // Flash reset


//===================================================================
// Arbiter Signals
wire Arbiter_i_IMEM_Valid;
wire [ADDRESS_WIDTH-1:0] Arbiter_i_IMEM_Address;
wire Arbiter_o_IMEM_Valid;
wire Arbiter_o_IMEM_Last;
wire [DATA_WIDTH-1:0] Arbiter_o_IMEM_Data;

wire Arbiter_i_DMEM_Valid;
wire Arbiter_i_DMEM_Read_Write_n;
wire [ADDRESS_WIDTH-1:0] Arbiter_i_DMEM_Address;
wire [DATA_WIDTH-1:0] Arbiter_i_DMEM_Data;
wire [DATA_WIDTH-1:0] Arbiter_o_DMEM_Data;
wire Arbiter_o_DMEM_Data_Read;
wire Arbiter_o_DMEM_Valid;
wire Arbiter_o_DMEM_Last;

wire Arbiter_i_Flash_Valid;
wire [DATA_WIDTH-1:0] Arbiter_i_Flash_Data;
wire [ADDRESS_WIDTH-1:0] Arbiter_i_Flash_Address;
wire Arbiter_o_Flash_Data_Read;
//wire [DATA_WIDTH-1:0] Arbiter_o_Flash_Data_Read;
wire Arbiter_o_Flash_Last;

assign Arbiter_i_Flash_Valid = o_FlashLoader_SDRAM_Req_Valid;
assign Arbiter_i_Flash_Data = o_FlashLoader_SDRAM_Data;
assign Arbiter_i_Flash_Address = o_FlashLoader_SDRAM_Addr;
assign i_FlashLoader_SDRAM_Data_Read = Arbiter_o_Flash_Data_Read;
assign i_FlashLoader_SDRAM_Last = Arbiter_o_Flash_Last;


//====================================================================
// Controller Signals
wire [ADDRESS_WIDTH-1:0] SDRAM_i_Address;                // Transact address
wire SDRAM_i_Valid;                                    // If request is valid
wire SDRAM_i_Read_Write_n;                                // Request type

wire [DATA_WIDTH-1:0] SDRAM_i_Data;                    // What to write
wire SDRAM_o_Data_Read;                                    // If data was read or not

wire [DATA_WIDTH-1:0] SDRAM_o_Data;                    // Read in data from SDRAM
wire SDRAM_o_Data_Valid;                                // If read in data is valid

wire SDRAM_o_Last;                                    // If we're on the last part of the burst


wire i_Clk;
//===================================================================
// Top-level Connections
    // Clock handling for mem & processor
wire Done = (ALU_o_Pass_Done_Change == MTC0_DONE);
wire Local_Clock;
wire Internal_Reset_n;

//integer file;
//initial 
//    begin
//    file = $fopen("dumppcs");
//    end
    
    
`ifdef MODEL_TECH
assign Internal_Reset_n = Global_Reset_n;
assign Local_Clock = CLOCK_50;

`else
wire PLL_Locked;
pll my_pll(
    .areset(!Global_Reset_n),
    .inclk0(CLOCK_50),
    .c0(Local_Clock),
    .locked(PLL_Locked)
    );
assign Internal_Reset_n = PLL_Locked && Global_Reset_n;

`endif

assign i_Clk = Local_Clock;

// Performance metrics
reg [31:0] CycleCount;                    // # of cycles that have passed since reset
reg [31:0] InstructionsExecuted;    // # of insts that have went through WB stage since reset
reg displaystop;


always @(posedge i_Clk or negedge Internal_Reset_n)

begin
    if( !Internal_Reset_n )
    begin
        // Asynch. reset on counters
        CycleCount <= 32'b0;
        InstructionsExecuted <= 32'b0;
        displaystop <= 0;
    end
    else
    begin
        // If we're currently executing instructions...
        if( o_FlashLoader_Done && !Done )
        begin
            // If we have a valid instruction that is finishing up execution in Decode, then count it
            if( !Hazard_Stall_DEC && !Hazard_Flush_DEC && !DEC_Noop )
            begin
                if (!displaystop)
                begin
                    //$fwrite(file, "%h\n", (DEC_o_PC<<2) + 'h20240);
                    if (InstructionsExecuted > 1000000000)
                    begin
                        displaystop <= 1;
//                        $fflush(file);
//                        $fclose(file);
                    end
                end
                InstructionsExecuted <= InstructionsExecuted + 32'b1;
            end
            CycleCount <= CycleCount + 32'b1;    // Always count another cycle
        end
    end
end

    // Visual output
assign LEDG[0] = (Done);
assign LEDR[0] = (!Done);

reg[3:0] HEX_Buf [7:0];    // Buffers for visualization of data

always @(posedge i_Clk)
begin
    HEX_Buf[0] <= 4'd0;
    HEX_Buf[1] <= 4'd0;
    HEX_Buf[2] <= 4'd0;
    HEX_Buf[3] <= 4'd0;
    HEX_Buf[4] <= 4'd0;
    HEX_Buf[5] <= 4'd0;
    HEX_Buf[6] <= 4'd0;
    HEX_Buf[7] <= 4'd0;

    case(SW[1:0])
        2'd0:    // Default: Display Pass/Done/Fail, PC, and PDF Value information
        begin
            HEX_Buf[0] <= ALU_o_Pass_Done_Value[3:0];
            HEX_Buf[1] <= ALU_o_Pass_Done_Value[7:4];
            HEX_Buf[6] <= IMEM_i_Address[3:0];
            HEX_Buf[7] <= IMEM_i_Address[7:4];
        end        
        
        2'd1:    // Cycle Count
        begin
            HEX_Buf[0] <= CycleCount[3:0];
            HEX_Buf[1] <= CycleCount[7:4];
            HEX_Buf[2] <= CycleCount[11:8];
            HEX_Buf[3] <= CycleCount[15:12];
            HEX_Buf[4] <= CycleCount[19:16];
            HEX_Buf[5] <= CycleCount[23:20];
            HEX_Buf[6] <= CycleCount[27:24];
            HEX_Buf[7] <= CycleCount[31:28];    
        end
        
        2'd2:    // Instructions Executed
        begin
            HEX_Buf[0] <= InstructionsExecuted[3:0];
            HEX_Buf[1] <= InstructionsExecuted[7:4];
            HEX_Buf[2] <= InstructionsExecuted[11:8];
            HEX_Buf[3] <= InstructionsExecuted[15:12];
            HEX_Buf[4] <= InstructionsExecuted[19:16];
            HEX_Buf[5] <= InstructionsExecuted[23:20];
            HEX_Buf[6] <= InstructionsExecuted[27:24];
            HEX_Buf[7] <= InstructionsExecuted[31:28];        
        end
        
        2'd3: // (free for any other metric)
        begin
        end
        
    endcase
end

wire [6:0] HEX2_SSD, HEX2_PFD;
SevenSegmentDisplayDecoder SSD0 (i_Clk, HEX0, HEX_Buf[0]);
SevenSegmentDisplayDecoder SSD1 (i_Clk, HEX1, HEX_Buf[1]);
SevenSegmentDisplayDecoder SSD2 (i_Clk, HEX2_SSD, HEX_Buf[2]);
SevenSegmentDisplayDecoder SSD3 (i_Clk, HEX3, HEX_Buf[3]);
SevenSegmentDisplayDecoder SSD4 (i_Clk, HEX4, HEX_Buf[4]);
SevenSegmentDisplayDecoder SSD5 (i_Clk, HEX5, HEX_Buf[5]);
SevenSegmentDisplayDecoder SSD6 (i_Clk, HEX6, HEX_Buf[6]);
SevenSegmentDisplayDecoder SSD7 (i_Clk, HEX7, HEX_Buf[7]);
SevenSegmentPFD PFD2 (i_Clk, HEX2_PFD, ALU_o_Pass_Done_Change);    // display pass/done/fail status

    // Special case: If SW is 0, then HEX2 output comes from PFD. Else, comes from SSD.
assign HEX2 = (SW[1:0]==2'd0 ? HEX2_PFD : HEX2_SSD);

/*
SevenSegmentPFD SSD3 (i_Clk, HEX2, ALU_o_Pass_Done_Change);    // display pass/done/fail status
    
SevenSegmentDisplayDecoder SSD0 (i_Clk, HEX0, ALU_o_Pass_Done_Value[3:0]);
SevenSegmentDisplayDecoder SSD1 (i_Clk, HEX1, ALU_o_Pass_Done_Value[7:4]);

SevenSegmentDisplayDecoder SSD7 (i_Clk, HEX7, IMEM_i_Address[7:4]);
SevenSegmentDisplayDecoder SSD6 (i_Clk, HEX6, IMEM_i_Address[3:0]);

*/

//===================================================================
//    Structural Description - Overhead
//===================================================================


//===================================================================
//    Structural Description - Pipeline stages
//===================================================================

//===================================================================
//    Instruction Fetch
fetch_unit #(    .ADDRESS_WIDTH(ADDRESS_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
                )
                IFETCH
                (    // Inputs
                    .i_Clk(i_Clk),
                    .i_Reset_n(Internal_Reset_n),
                    .i_Stall(Hazard_Stall_IF),
                    
                    .i_Load(IFetch_i_Load),
                    .i_Load_Address(IFetch_i_PCSrc),
                    
                    // Outputs
                    .o_PC(IMEM_i_Address)
                );
                
i_cache    #(    .DATA_WIDTH(DATA_WIDTH)
        )
        I_CACHE
        (
            // General
            .i_Clk(i_Clk),
            .i_Reset_n(Internal_Reset_n),
            
            // Requests
            .i_Valid(o_FlashLoader_Done),
            .i_Address(IMEM_i_Address),
        
            // Mem Transaction 
            .o_MEM_Valid(Arbiter_i_IMEM_Valid),
            .o_MEM_Address(Arbiter_i_IMEM_Address),
            .i_MEM_Valid(Arbiter_o_IMEM_Valid),        // If data from main mem is valid
            .i_MEM_Last(Arbiter_o_IMEM_Last),            // If main mem is sending the last piece of data
            .i_MEM_Data(Arbiter_o_IMEM_Data),        // Data from main mem
            
            // Outputs
            .o_Ready(IMEM_o_Ready),
            .o_Valid(IMEM_o_Valid),                    // If the output is correct.
            .o_Data(IMEM_o_Instruction)                    // The data requested.        
        );

//===================================================================
//    Decode
pipe_if_dec    #(    .ADDRESS_WIDTH(ADDRESS_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            )
            PIPE_IF_DEC
            (   
				// Inputs
                .i_Clk(i_Clk),
                .i_Reset_n(Internal_Reset_n),
                .i_Flush(Hazard_Flush_IF),
                .i_Stall(Hazard_Stall_DEC),
                .i_imembubble(IMEM_o_Valid),
                
                // Pipe signals
                .i_PC(IMEM_i_Address),
                .o_PC(DEC_i_PC),
                .i_Instruction(IMEM_o_Instruction),
                .o_Instruction(DEC_i_Instruction),
                .o_imembubble(imembubble_DEC)
            );

decoder #(    .ADDRESS_WIDTH(ADDRESS_WIDTH),
            .DATA_WIDTH(DATA_WIDTH),
            .REG_ADDRESS_WIDTH(REG_ADDR_WIDTH),
            .ALUCTL_WIDTH(ALU_CTLCODE_WIDTH),
            .MEM_MASK_WIDTH(MEM_MASK_WIDTH)
        )
        DECODE
        (   // Inputs
            .i_PC(DEC_i_PC),
            .i_Instruction(DEC_i_Instruction),
            .i_Stall(Hazard_Stall_DEC),
        
            // Outputs
            .o_Uses_ALU(DEC_o_Uses_ALU),
            .o_ALUCTL(DEC_o_ALUCTL),
            .o_Is_Branch(DEC_o_Is_Branch),
            .o_Jump_Reg(DEC_o_Jump_Reg),
            
            .o_Mem_Valid(DEC_o_Mem_Valid),
            .o_Mem_Read_Write_n(DEC_o_Mem_Read_Write_n),
            .o_Mem_Mask(DEC_o_Mem_Mask),
            
            .o_Writes_Back(DEC_o_Writes_Back),
            .o_Write_Addr(DEC_o_VWrite_Addr),
            
            .o_Uses_RS(DEC_o_Uses_RS),
            .o_RS_Addr(DEC_o_Read_VRegister_1),
            .o_Uses_RT(DEC_o_Uses_RT),
            .o_RT_Addr(DEC_o_Read_VRegister_2),
            .o_Uses_Immediate(DEC_o_Uses_Immediate),
            .o_Immediate(DEC_o_Immediate),
            .o_Branch_Target(DEC_o_Branch_Target)
        );

        
regfile_RR #(    .DATA_WIDTH(DATA_WIDTH),
            .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
            .FREE_LIST_WIDTH(FREE_LIST_WIDTH),
			.CHECKPOINT_WIDTH(CHECKPOINT_WIDTH)
        )
        REGFILE
        (        // Inputs
            .i_Clk(i_Clk),
            .i_Stall(Hazard_Stall_DEC),
                    
            .i_VRS_Addr(DEC_o_Read_VRegister_1),
            .i_VRT_Addr(DEC_o_Read_VRegister_2),
            .i_DEC_Write_Enable(DEC_o_Writes_Back),
            .i_VRD_Addr(DEC_o_VWrite_Addr),
                
            .i_MEM_Write_Enable(DEC_i_RegWrite),    // Account for squashing WB stage
            .i_PWrite_Data(WB_i_Write_Data),
            .i_PWrite_Addr(DEC_i_PWrite_Register),
            .i_Phys_Active_List_Index(DEC_i_Phys_Active_List_Index),
            
            .i_VWrite_Addr(DEC_i_VWrite_Register),
            
            .i_DEC_Is_Branch(DEC_o_Is_Branch),
            .i_EX_Is_Branch(EX_i_Is_Branch), // to create a checkpoint
            .i_WB_Is_Branch(WB_i_Is_Branch),
            .i_Mem_Valid(DEC_o_Mem_Valid),
            .i_Mem_Read(DEC_o_Mem_Read_Write_n),
            
            .i_Create_Map_Checkpoint(Hazard_Create_Map_Checkpoint),
            .i_Create_List_Checkpoint(Hazard_Create_List_Checkpoint),
            .i_Revert(Revert_Predict),
            .i_Revert_Checkpoint(Revert_Checkpoint),
                    
            // Outputs
            .o_PRS_Addr(DEC_o_Read_PRegister_1),
            .o_PRT_Addr(DEC_o_Read_PRegister_2),
            .o_VRS_Data(DEC_o_Read_Data_1),
            .o_VRT_Data(DEC_o_Read_Data_2),
            .o_PRD_Addr(DEC_o_PWrite_Addr),
            .o_Phys_Active_List_Index(DEC_o_Phys_Active_List_Index),
            .o_Stall(Regfile_Stall),
            .o_Checkpoint(DEC_o_Checkpoint)
        );

//===================================================================
//    Execute
pipe_dec_ex #(    .ADDRESS_WIDTH(ADDRESS_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
                .ALU_CTLCODE_WIDTH(ALU_CTLCODE_WIDTH),
                .MEM_MASK_WIDTH(MEM_MASK_WIDTH),
                .COUNT_SIZE(COUNT_SIZE),
                .FREE_LIST_WIDTH(FREE_LIST_WIDTH),
                .CHECKPOINT_WIDTH(CHECKPOINT_WIDTH)
            )
            PIPE_DEC_EX
            (        // Inputs
                .i_Clk(i_Clk),
                .i_Reset_n(Internal_Reset_n),
                .i_Flush(Hazard_Flush_DEC),
                .i_Stall(Hazard_Stall_EX),
                            
                    // Pipeline
                .i_PC(DEC_o_PC),
                .o_PC(ALU_i_PC),
                .i_Instruction(DEC_i_Instruction),//[ADDRESS_WIDTH-1:0]),
                .o_Instruction(EX_i_Instruction),
                .i_Uses_ALU(DEC_o_Uses_ALU),
                .o_Uses_ALU(ALU_i_Valid),
                .i_ALUCTL(DEC_o_ALUCTL),
                .o_ALUCTL(ALU_i_ALUOp),
                .i_Is_Branch(DEC_o_Is_Branch),
                .o_Is_Branch(EX_i_Is_Branch),
                .i_Mem_Valid(DEC_o_Mem_Valid),
                .o_Mem_Valid(EX_i_Mem_Valid),
                .i_Mem_Mask(DEC_o_Mem_Mask),
                .o_Mem_Mask(EX_i_Mem_Mask),
                .i_Mem_Read_Write_n(DEC_o_Mem_Read_Write_n),
                .o_Mem_Read_Write_n(EX_i_Mem_Read_Write_n),
                .i_Mem_Write_Data(FORWARD_o_Forwarded_Data_2),
                .o_Mem_Write_Data(EX_i_Mem_Write_Data),
                .i_Writes_Back(DEC_o_Writes_Back),
                .o_Writes_Back(EX_i_Writes_Back),
                .i_VWrite_Addr(DEC_o_VWrite_Addr),
                .o_VWrite_Addr(EX_i_VWrite_Addr),
                .i_PWrite_Addr(DEC_o_PWrite_Addr),
                .o_PWrite_Addr(EX_i_PWrite_Addr),
                .i_Phys_Active_List_Index(DEC_o_Phys_Active_List_Index),
                .o_Phys_Active_List_Index(EX_i_Phys_Active_List_Index),
                .i_Operand1(FORWARD_o_Forwarded_Data_1),
                .o_Operand1(ALU_i_Operand1),
                .i_Operand2(DEC_o_Uses_Immediate?DEC_o_Immediate:FORWARD_o_Forwarded_Data_2),        // Convention - Operand2 mapped to immediates
                .o_Operand2(ALU_i_Operand2),
                .i_Branch_Target(DEC_o_Jump_Reg?FORWARD_o_Forwarded_Data_1[ADDRESS_WIDTH-1:0]:DEC_o_Branch_Target),
                .o_Branch_Target(EX_i_Branch_Target),
                .i_Predictor(DEC_o_Branch_Predictor),
                .o_Predictor(EX_i_Branch_Predictor),
                .i_Pattern(DEC_o_Branch_Pattern),
                .o_Pattern(EX_i_Branch_Pattern),
                .i_Checkpoint(DEC_o_Checkpoint),
                .o_Checkpoint(EX_i_Checkpoint)
            );

alu    #(    .DATA_WIDTH(DATA_WIDTH),
        .CTLCODE_WIDTH(ALU_CTLCODE_WIDTH)
    )
    ALU
    (        // Inputs
        .i_Valid(ALU_i_Valid),
        .i_ALUCTL(ALU_i_ALUOp),
        .i_Operand1(ALU_i_Operand1),
        .i_Operand2(ALU_i_Operand2),
        
            // Outputs
        .o_Valid(ALU_o_Valid),
        .o_Result(ALU_o_Result),
        .o_Branch_Valid(ALU_o_Branch_Valid),
        .o_Branch_Outcome(ALU_o_Branch_Outcome),
        .o_Pass_Done_Value(ALU_o_Pass_Done_Value),
        .o_Pass_Done_Change(ALU_o_Pass_Done_Change)
    );

//===================================================================
//    Mem
pipe_ex_mem #(    .ADDRESS_WIDTH(ADDRESS_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
                .ALU_CTLCODE_WIDTH(ALU_CTLCODE_WIDTH),
                .FREE_LIST_WIDTH(FREE_LIST_WIDTH),
                .CHECKPOINT_WIDTH(CHECKPOINT_WIDTH)
            )
            PIPE_EX_MEM
            (        // Inputs
                .i_Clk(i_Clk),
				.i_PC(ALU_i_PC),
                .i_Reset_n(Internal_Reset_n),
                .i_Flush(Hazard_Flush_EX),
                .i_Stall(Hazard_Stall_MEM),
				.i_Value_Predicted(Predicted),
                
                // Pipe in/out
				.o_PC(DMEM_i_PC),
				.o_Value_Predicted(DMEM_i_Predicted),
                .i_Instruction(EX_i_Instruction),
                .o_Instruction(DMEM_i_Instruction),
                .i_ALU_Result(ALU_o_Result),
                .o_ALU_Result(DMEM_i_Result),
                .i_Mem_Valid(EX_i_Mem_Valid),
                .o_Mem_Valid(DMEM_i_Mem_Valid),
                .i_Mem_Mask(EX_i_Mem_Mask),
                .o_Mem_Mask(DMEM_i_Mem_Mask),
                .i_Mem_Read_Write_n(EX_i_Mem_Read_Write_n),
                .o_Mem_Read_Write_n(DMEM_i_Mem_Read_Write_n),
                .i_Mem_Write_Data(EX_i_Mem_Write_Data),
                .o_Mem_Write_Data(DMEM_i_Mem_Write_Data),
                .i_Writes_Back(EX_i_Writes_Back),
                .o_Writes_Back(DMEM_i_Writes_Back),
                .i_VWrite_Addr(EX_i_VWrite_Addr),
                .o_VWrite_Addr(DMEM_i_VWrite_Addr),
                .i_PWrite_Addr(EX_i_PWrite_Addr),
                .o_PWrite_Addr(DMEM_i_PWrite_Addr),
                .i_Phys_Active_List_Index(EX_i_Phys_Active_List_Index),
                .o_Phys_Active_List_Index(DMEM_i_Phys_Active_List_Index),
                .i_Checkpoint(EX_i_Checkpoint),
                .o_Checkpoint(MEM_i_Checkpoint),
                .i_Is_Branch(EX_i_Is_Branch),
                .o_Is_Branch(MEM_i_Is_Branch)
            );

d_cache    #(    
            .DATA_WIDTH(32),
            .ADDRESS_WIDTH(ADDRESS_WIDTH),
            .MEM_MASK_WIDTH(3)
        )
        D_CACHE
        (    // Inputs
            .i_Clk(i_Clk),
            .i_Reset_n(Internal_Reset_n),
            .i_Valid(DMEM_i_Mem_Valid),
            .i_Mem_Mask(DMEM_i_Mem_Mask),
            .i_Address(DMEM_i_Result[ADDRESS_WIDTH:2]),
            .i_Read_Write_n(DMEM_i_Mem_Read_Write_n),    //1=MemRead, 0=MemWrite
            .i_Write_Data(DMEM_i_Mem_Write_Data),

            // Outputs
            .o_Ready(DMEM_o_Mem_Ready),
            .o_Valid(DMEM_o_Mem_Valid),
            .o_Data(DMEM_o_Read_Data),
            
            // Mem Transaction
            .o_MEM_Valid(Arbiter_i_DMEM_Valid),
            .o_MEM_Read_Write_n(Arbiter_i_DMEM_Read_Write_n),    
            .o_MEM_Address(Arbiter_i_DMEM_Address),
            .o_MEM_Data(Arbiter_i_DMEM_Data),
            .i_MEM_Valid(Arbiter_o_DMEM_Valid),
            .i_MEM_Data_Read(Arbiter_o_DMEM_Data_Read),
            .i_MEM_Last(Arbiter_o_DMEM_Last),
            .i_MEM_Data(Arbiter_o_DMEM_Data)
        );
        
mem_prediction	#(
					.ADDRESS_WIDTH(ADDRESS_WIDTH),
					.CHECKPOINT_WIDTH(CHECKPOINT_WIDTH),
					.DATA_WIDTH(DATA_WIDTH),
					.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
					.FREE_LIST_WIDTH(FREE_LIST_WIDTH))
		MEM_PREDICTION
		(	
			.i_Clk(i_Clk),
			.i_PC(DMEM_i_PC),
			.i_Mem_Ready(DMEM_o_Mem_Ready),
			.i_Mem_Done(DMEM_o_Mem_Valid),
			.i_Checkpoint(MEM_i_Checkpoint),
			.i_Value_Predicted(DMEM_i_Predicted),
			.o_PC(Revert_PC),
			.o_Checkpoint(Revert_Checkpoint),
			.o_Value_Predicted(Value_Predicted),
			
			.i_WriteBack_Data(DMEM_o_Write_Data),
			.o_WriteBack_Data(r_DMEM_o_Write_Data),
			.i_Writes_Back(DMEM_i_Writes_Back),
			.o_Writes_Back(r_DMEM_i_Writes_Back),
			.i_VWrite_Addr(DMEM_i_VWrite_Addr),
			.o_VWrite_Addr(r_DMEM_i_VWrite_Addr),
			.i_PWrite_Addr(DMEM_i_PWrite_Addr),
			.o_PWrite_Addr(r_DMEM_i_PWrite_Addr),
			.i_Phys_Active_List_Index(DMEM_i_Phys_Active_List_Index),
			.o_Phys_Active_List_Index(r_DMEM_i_Phys_Active_List_Index),
			.i_Is_Branch(MEM_i_Is_Branch),
			.o_Is_Branch(r_MEM_i_Is_Branch)
		);

    // Multiplexor - Select what we will write back
always @(*)
begin
    if( MemToReg )        // If it was a memory operation
    begin
        DMEM_o_Write_Data <= DMEM_o_Read_Data;        // We will write back value from memory
        DMEM_o_Done <= DMEM_o_Mem_Valid;                // Write back only if value is valid
    end
    else
    begin
        DMEM_o_Write_Data <= DMEM_i_Result;        // Else we will write back value from ALU
        DMEM_o_Done <= TRUE;
    end
end

//===================================================================
//    Write-Back
pipe_mem_wb #(    .ADDRESS_WIDTH(ADDRESS_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
                .FREE_LIST_WIDTH(FREE_LIST_WIDTH)
            )
            PIPE_MEM_WB
            (        // Inputs
                .i_Clk(i_Clk),
                .i_Reset_n(Internal_Reset_n),
                .i_Flush(Hazard_Flush_MEM),
                .i_Stall(Hazard_Stall_WB),
                            
                    // Pipe in/out
                .i_WriteBack_Data(DMEM_o_Write_Data),
                .o_WriteBack_Data(WB_i_Write_Data),
                .i_Writes_Back(DMEM_i_Writes_Back),
                .o_Writes_Back(WB_i_Writes_Back),
                .i_VWrite_Addr(DMEM_i_VWrite_Addr),
                .o_VWrite_Addr(DEC_i_VWrite_Register),
                .i_PWrite_Addr(DMEM_i_PWrite_Addr),
                .o_PWrite_Addr(DEC_i_PWrite_Register),
                .i_Phys_Active_List_Index(DMEM_i_Phys_Active_List_Index),
                .o_Phys_Active_List_Index(DEC_i_Phys_Active_List_Index),
                .i_Is_Branch(MEM_i_Is_Branch),
                .o_Is_Branch(WB_i_Is_Branch)
            );


    // Write-Back is simply wires feeding back into regfile to perform writes
    // (SEE REGFILE)

    

//===================================================================
//    Arbitration Logic

// Memory arbiter
memory_arbiter    #(    .DATA_WIDTH(DATA_WIDTH),
                    .ADDRESS_WIDTH(ADDRESS_WIDTH)
                )
                ARBITER    
                (
                    // General
                    .i_Clk(i_Clk),
                    .i_Reset_n(Internal_Reset_n),
            
                    // Requests to/from IMEM - Assume we always read
                    .i_IMEM_Valid(Arbiter_i_IMEM_Valid),                        // If IMEM request is valid
                    .i_IMEM_Address(Arbiter_i_IMEM_Address),        // IMEM request addr.
                    .o_IMEM_Valid(Arbiter_o_IMEM_Valid),
                    .o_IMEM_Last(Arbiter_o_IMEM_Last),
                    .o_IMEM_Data(Arbiter_o_IMEM_Data),
                    
                    // Requests to/from DMEM
                    .i_DMEM_Valid(Arbiter_i_DMEM_Valid),
                    .i_DMEM_Read_Write_n(Arbiter_i_DMEM_Read_Write_n),
                    .i_DMEM_Address(Arbiter_i_DMEM_Address),
                    .i_DMEM_Data(Arbiter_i_DMEM_Data),
                    .o_DMEM_Valid(Arbiter_o_DMEM_Valid),
                    .o_DMEM_Data_Read(Arbiter_o_DMEM_Data_Read),
                    .o_DMEM_Last(Arbiter_o_DMEM_Last),
                    .o_DMEM_Data(Arbiter_o_DMEM_Data),
                    
                    // Requests to/from FLASH - Assume we always write
                    .i_Flash_Valid(Arbiter_i_Flash_Valid),
                    .i_Flash_Data(Arbiter_i_Flash_Data),
                    .i_Flash_Address(Arbiter_i_Flash_Address),
                    .o_Flash_Data_Read(Arbiter_o_Flash_Data_Read),
                    .o_Flash_Last(Arbiter_o_Flash_Last),
                    
                    // Interface with SDRAM Controller
                    .o_MEM_Valid(SDRAM_i_Valid),
                    .o_MEM_Address(SDRAM_i_Address),
                    .o_MEM_Read_Write_n(SDRAM_i_Read_Write_n),
                    
                        // Write data interface
                    .o_MEM_Data(SDRAM_i_Data),
                    .i_MEM_Data_Read(SDRAM_o_Data_Read),
                    
                        // Read data interface
                    .i_MEM_Data(SDRAM_o_Data),
                    .i_MEM_Data_Valid(SDRAM_o_Data_Valid),
                    
                    .i_MEM_Last(SDRAM_o_Last)
                );

sdram_controller memory_controller(
                    .i_Clk(i_Clk),
                    .i_Reset(!Internal_Reset_n),
                    
                    // Request interface
                    .i_Addr(SDRAM_i_Address),
                    .i_Req_Valid(SDRAM_i_Valid),
                    .i_Read_Write_n(SDRAM_i_Read_Write_n),
                    
                    // Write .data interface
                    .i_Data(SDRAM_i_Data),
                    .o_Data_Read(SDRAM_o_Data_Read),
                    
                    // Read data .interface
                    .o_Data(SDRAM_o_Data),
                    .o_Data_Valid(SDRAM_o_Data_Valid),
                    
                    // output
                    .o_Last(SDRAM_o_Last),
                    
                        // SDRAM interface
                    .b_Dq(DRAM_DQ),
                    .o_Addr(DRAM_ADDR),
                    .o_Ba({DRAM_BA_0,DRAM_BA_1}),
                    .o_Clk(DRAM_CLK),
                    .o_Cke(DRAM_CKE),
                    .o_Cs_n(DRAM_CS_N),
                    .o_Ras_n(DRAM_RAS_N),
                    .o_Cas_n(DRAM_CAS_N),
                    .o_We_n(DRAM_WE_N),
                    .o_Dqm({DRAM_UDQM,DRAM_LDQM})
                );

                
// Forwarding logic
forwarding_unit    #(    .DATA_WIDTH(DATA_WIDTH),
                    .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
                )
                FORWARDING_UNIT
                (
                    // Feedback from DEC
                    .i_DEC_Uses_RS(DEC_o_Uses_RS),
                    .i_DEC_RS_Addr(DEC_o_Read_PRegister_1),
                    .i_DEC_Uses_RT(DEC_o_Uses_RT),                                // DEC wants to use RT
                    .i_DEC_RT_Addr(DEC_o_Read_PRegister_2),                            // RT request addr.
                    .i_DEC_RS_Data(DEC_o_Read_Data_1),
                    .i_DEC_RT_Data(DEC_o_Read_Data_2),
                    
                    // Feedback from EX
                    .i_EX_Writes_Back(EX_i_Writes_Back),                                // EX is valid for analysis
                    .i_EX_Valid(ALU_i_Valid),                                // If it's a valid ALU op or not
                    .i_EX_Write_Addr(EX_i_PWrite_Addr),                            // What EX will write to
                    .i_EX_Write_Data(ALU_o_Result),
                    
                    // Feedback from MEM
                    .i_MEM_Writes_Back(DMEM_i_Writes_Back),                                // MEM is valid for analysis
                    .i_MEM_Write_Addr(DMEM_i_PWrite_Addr),                            // What MEM will write to
                    .i_MEM_Write_Data(DMEM_o_Write_Data),
                    
                    // Feedback from WB
                    .i_WB_Writes_Back(WB_i_Writes_Back),                                // WB is valid for analysis
                    .i_WB_Write_Addr(DEC_i_PWrite_Register),                            // What WB will write to
                    .i_WB_Write_Data(WB_i_Write_Data),
                    
                    // Feedback from VPT
                    .i_Predict_Made(Predicted), //TODO
                    .i_Predicted_Data(Predict_Data),
                    
                    //===============================================
                    // IFetch forwarding
                    
                        // None
                    // None
                        
                    // DEC forwarding
                    .o_DEC_RS_Override_Data(FORWARD_o_Forwarded_Data_1),
                    .o_DEC_RT_Override_Data(FORWARD_o_Forwarded_Data_2)
                );
                
// Branch history table
branch_history_table #( .HISTORY_SIZE(HISTORY_SIZE), .COUNT_SIZE(COUNT_SIZE) )
                        BRANCH_HISTORY_TABLE
                        (
                            .clk_i(i_Clk),
                            .read_Branch_PC_i(DEC_i_PC[HISTORY_SIZE:1]),
                            .DEC_is_Branch_i(DEC_o_Is_Branch),
                            .EX_is_Branch_i(ALU_o_Valid && ALU_o_Branch_Valid),
                            .branch_i(EX_Take_Branch),
                            .Smash_Transient_i(Smash_Transient_i),
                            .write_Branch_PC_i(ALU_i_PC[HISTORY_SIZE:1]),
                            .old_predictor_i(EX_i_Branch_Predictor),
                            .old_pattern_i(EX_i_Branch_Pattern),
                            .predictor_o(DEC_o_Branch_Predictor),
                            .pattern_o(DEC_o_Branch_Pattern)
                        );
                        
// Value history table
value_history_table #( .DATA_WIDTH(DATA_WIDTH), .ADDRESS_WIDTH(ADDRESS_WIDTH) )
                        VALUE_HISTORY_TABLE
                        (
                            .clk_i(i_Clk),
							.ALU_PC_i(ALU_i_PC),
							.Revert_PC_i(Revert_PC),
                            .EX_is_Load_i(EX_i_Is_Load),
                            .DMEM_instruction_i(DMEM_i_Instruction),
                            .DMEM_data_i(DMEM_o_Read_Data),
							.DMEM_Read_Write_n_i(Arbiter_i_DMEM_Read_Write_n),
                            .DMEM_is_Valid_i(DMEM_o_Mem_Valid),
							.Old_Value_Predicted_i(Value_Predicted),
                            .predicted_data_o(Predict_Data),
                            .revert_predict_o(Revert_Predict),
							.predicted_o(Predicted) //TODO
                        );			

// Hazard detection unit / Stall logic
hazard_detection_unit     #(  .DATA_WIDTH(DATA_WIDTH),
                            .ADDRESS_WIDTH(ADDRESS_WIDTH),
                            .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
                        )
                        HAZARD_DETECTION_UNIT
                        (
                            .i_Clk(i_Clk),
                            .i_Reset_n(Internal_Reset_n),
                        
                            //==============================================
                            // Branch Prediction
                            .i_PC(DEC_i_PC), // for calculating branch target for predict taken
                            .i_Is_Branch(DEC_o_Is_Branch), // 
                            .i_Branch_Target(DEC_o_Branch_Target), // branch target
                            .i_DEC_Instruction(DEC_i_Instruction), // for obtaining offset of PC to get branch target for predict taken
                            .i_PC_Branch(ALU_i_PC), // revert target for mis-predictions
                            .i_Was_Branch(ALU_o_Branch_Valid), // for mis-predictions
                            .i_EX_Instruction(EX_i_Instruction),
                            .i_Taken(DEC_o_Branch_Predictor[1]),
                            .i_Was_Taken(EX_i_Branch_Predictor[1]),
                            .o_Smash_Transient(Smash_Transient_i),
                            
                            //==============================================
                            // Value Prediction
                            .i_PC_Load(ALU_i_PC),
                            .i_DMEM_Valid(DMEM_o_Mem_Valid),
                            .i_Revert_Value_Prediction(Revert_Predict),
                            .i_Regfile_Stall(Regfile_Stall),
                            .i_EX_Checkpoint(EX_i_Checkpoint),
                            .i_MEM_Checkpoint(MEM_i_Checkpoint),
                            .o_Create_Map_Checkpoint(Hazard_Create_Map_Checkpoint),
                            .o_Create_List_Checkpoint(Hazard_Create_List_Checkpoint),
                            .o_Revert(Revert_Predict),
                            //.o_Revert_Checkpoint(Hazard_Revert_Checkpoint),
                        
                            //==============================================
                            // Overall state
                            .i_FlashLoader_Done(o_FlashLoader_Done),                // Info about if flashloader is done
                            .i_Done(Done),                                                    // If we have observed the 'done' signal from the code yet
                        
                            //==============================================
                            // Hazard in DECODE?
                            .i_DEC_Uses_RS(DEC_o_Uses_RS),                                // DEC wants to use RS
                            .i_DEC_RS_Addr(DEC_o_Read_PRegister_1),                            // RS request addr.
                            .i_DEC_Uses_RT(DEC_o_Uses_RT),                                // DEC wants to use RT
                            .i_DEC_RT_Addr(DEC_o_Read_PRegister_2),                            // RT request addr.
                            .i_DEC_Branch_Instruction(DEC_o_Is_Branch),
                            
                            //===============================================
                            // Feedback from IF
                            .i_IF_Done(IMEM_o_Valid),                        // If IF's value has reached steady state
                            
                            // Feedback from EX
                            .i_EX_Writes_Back(EX_i_Writes_Back),                    // EX is valid for data dependency analysis
                            .i_EX_Uses_Mem(EX_i_Mem_Valid),
                            .i_EX_Write_Addr(EX_i_PWrite_Addr),                            // What EX will write to
                            .i_EX_Branch(EX_Take_Branch),                            // If EX says we are branching
                            .i_EX_Branch_Target(EX_i_Branch_Target),
                            
                            // Feedback from MEM
                            .i_MEM_Uses_Mem(DMEM_i_Mem_Valid),                                // If it's a memop
                            .i_MEM_Writes_Back(DMEM_i_Writes_Back),                        // MEM is valid for analysis
                            .i_MEM_Write_Addr(DMEM_i_PWrite_Addr),                            // What MEM will write to
                            .i_MEM_Done(DMEM_o_Done),                                    // If MEM's value has reached steady state                                
                            
                            // Feedback from WB
                            .i_WB_Writes_Back(WB_i_Writes_Back),
                            .i_WB_Write_Addr(DEC_i_PWrite_Register),
                            
                            //===============================================
                            // Branch hazard handling
                            .o_IF_Branch(IFetch_i_Load),
                            .o_IF_Branch_Target(IFetch_i_PCSrc),
                            
                            //===============================================
                            // IFetch validation
                            .o_IF_Stall(Hazard_Stall_IF),
                            .o_IF_Smash(Hazard_Flush_IF),
                            
                            // DECODE validation
                            .o_DEC_Stall(Hazard_Stall_DEC),
                            .o_DEC_Smash(Hazard_Flush_DEC),
                            
                            // EX validation
                            .o_EX_Stall(Hazard_Stall_EX),
                            .o_EX_Smash(Hazard_Flush_EX),
                            
                            // MEM validation
                            .o_MEM_Stall(Hazard_Stall_MEM),
                            .o_MEM_Smash(Hazard_Flush_MEM),
                            
                            .o_WB_Stall(Hazard_Stall_WB),
                            .o_WB_Smash(Hazard_Flush_WB)
                        );

                    

//===================================================================
//    Initialization

//    Flash Loader
// speed ups for simulation
`ifdef MODEL_TECH
flashreader#(.WORDS_TO_LOAD(32'h00008000),
            .FLASH_READ_WAIT_TIME_PS(0))
`else
flashreader
`endif
flashloader2(    .i_Clk(i_Clk), 
                .i_Reset_n(Internal_Reset_n),
                .o_Done(o_FlashLoader_Done),
                .o_SDRAM_Addr(o_FlashLoader_SDRAM_Addr),
                .o_SDRAM_Req_Valid(o_FlashLoader_SDRAM_Req_Valid),
                .o_SDRAM_Read_Write_n(o_FlashLoader_SDRAM_Read_Write_n),
                .o_SDRAM_Data(o_FlashLoader_SDRAM_Data),
                .i_SDRAM_Data_Read(i_FlashLoader_SDRAM_Data_Read),
                .i_SDRAM_Last(i_FlashLoader_SDRAM_Last),
                .o_FL_Addr(o_FlashLoader_FL_Addr),
                .i_FL_Data(i_FlashLoader_FL_Data),
                .o_FL_Chip_En_n(o_FlashLoader_FL_Chip_En_n),
                .o_FL_Output_En_n(o_FlashLoader_FL_Output_En_n),
                .o_FL_Write_En_n(o_FlashLoader_FL_Write_En_n),
                .o_FL_Reset_n(o_FlashLoader_FL_Reset_n)
            );

initial
begin
end

endmodule
