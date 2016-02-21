/*
 * regfile for register renaming
 */
module regfile_RR       #(  parameter DATA_WIDTH = 32,
                            parameter REG_ADDR_WIDTH = 5,
                            parameter FREE_LIST_WIDTH = 3,
							parameter CHECKPOINT_WIDTH = 2)
(    // Inputs
    input i_Clk,
    input i_Stall,

    // Decode stage
    input [REG_ADDR_WIDTH-1:0] i_VRS_Addr,
    input [REG_ADDR_WIDTH-1:0] i_VRT_Addr,
    input i_DEC_Write_Enable,
    input [REG_ADDR_WIDTH-1:0] i_VRD_Addr, // for outputting physical address
    
    // WB stage
    input i_MEM_Write_Enable,
    input [REG_ADDR_WIDTH:0] i_PWrite_Addr,
    input [DATA_WIDTH-1:0] i_PWrite_Data,
    input [REG_ADDR_WIDTH-1:0] i_VWrite_Addr, // for popping from active list when instruction is done
    input [FREE_LIST_WIDTH-1:0] i_Phys_Active_List_Index, // index of active list for reverting
    
    // Prediction
    input i_DEC_Is_Branch,
    input i_EX_Is_Branch,
    input i_WB_Is_Branch,
    input i_Mem_Valid,
    input i_Mem_Read,
    // input i_EX_Mispredict,
    // input i_MEM_Mispredict,
    // input [CHECKPOINT_WIDTH-1:0] i_Revert_EX_Checkpoint, // checkpoint for that prediction
    // input [CHECKPOINT_WIDTH-1:0] i_Revert_MEM_Checkpoint, // checkpoint for that prediction
    
    // Reverting TODO
    input i_Create_Map_Checkpoint,
    input i_Create_List_Checkpoint,
    input i_Revert,
    input [CHECKPOINT_WIDTH-1:0] i_Revert_Checkpoint,
    
    // Output
    output [DATA_WIDTH-1:0] o_VRS_Data, // to be used in EX
    output [DATA_WIDTH-1:0] o_VRT_Data, // to be used in EX
    // To be used in later pipelines
    output [REG_ADDR_WIDTH:0] o_PRS_Addr, // physical register converted from virtual register
    output [REG_ADDR_WIDTH:0] o_PRT_Addr, // physical register converted from virtual register
    output [REG_ADDR_WIDTH:0] o_PRD_Addr, // physical address to write back to
    output [FREE_LIST_WIDTH-1:0] o_Phys_Active_List_Index, // index of active list to be passed along pipeline to wb
    output [CHECKPOINT_WIDTH-1:0] o_Checkpoint, // index of current checkpoint
    
    // To stall when all checkpoints are used
    output o_Stall
);
    localparam READ = 1'b1;
    localparam WRITE = 1'b0;

    // Counters
    integer i;
    
    // Internal
    // Regs & wires
    reg [DATA_WIDTH-1:0] PRegister [0:(2**REG_ADDR_WIDTH)+(2**FREE_LIST_WIDTH)-1];
    
    reg [REG_ADDR_WIDTH:0] Free_List [0:(2**FREE_LIST_WIDTH)-1];
    // reg [FREE_LIST_WIDTH-1:0] Free_List_Head; // Initialized at bottom of module
    // reg [FREE_LIST_WIDTH-1:0] Free_List_Tail; // Initialized at bottom of module
    // reg [FREE_LIST_WIDTH-1:0] Free_List_Size; // Initialized at bottom of module
    
    reg [REG_ADDR_WIDTH + CHECKPOINT_WIDTH + 1:0] Active_List [0:(2**FREE_LIST_WIDTH)-1];
    // reg [FREE_LIST_WIDTH-1:0] Active_List_Head; // Initialized at bottom of module
    // reg [FREE_LIST_WIDTH-1:0] Active_List_Tail; // Initialized at bottom of module
    // reg [FREE_LIST_WIDTH-1:0] Active_List_Size; // Initialized at bottom of module
    
    // Checkpoint regs of register file
    reg [REG_ADDR_WIDTH:0] Map_Table [0:2**CHECKPOINT_WIDTH-1][0:(2**REG_ADDR_WIDTH)-1];
    reg [FREE_LIST_WIDTH-1:0] Free_List_Head [0:2**CHECKPOINT_WIDTH-1]; // head of free list at checkpoint
    reg [FREE_LIST_WIDTH-1:0] Free_List_Tail [0:2**CHECKPOINT_WIDTH-1]; // tail of free list at checkpoint
    reg [FREE_LIST_WIDTH-1:0] Free_List_Size [0:2**CHECKPOINT_WIDTH-1];
    reg [FREE_LIST_WIDTH-1:0] Active_List_Head [0:2**CHECKPOINT_WIDTH-1]; // head of active list at checkpoint
    reg [FREE_LIST_WIDTH-1:0] Active_List_Tail [0:2**CHECKPOINT_WIDTH-1]; // tail of active list at checkpoint
    reg [FREE_LIST_WIDTH-1:0] Active_List_Size [0:2**CHECKPOINT_WIDTH-1];
    reg [CHECKPOINT_WIDTH-1:0] r_Curr_Checkpoint = 0; // index of current checkpoint
    reg [CHECKPOINT_WIDTH-1:0] r_Used_Checkpoints = 0; // number of checkpoint used
    reg [CHECKPOINT_WIDTH-1:0] r_Used_Checkpoints_n = 0;
    reg stall = 0;
    wire [CHECKPOINT_WIDTH-1:0] w_Active_Checkpoint;
    wire [REG_ADDR_WIDTH:0] w_Old_PReg_Addr;
    wire w_Done;
    wire w_Commit_Enabled = r_Used_Checkpoints == 0 ? 1 : 0;
    
    wire w_Write_Enabled = i_DEC_Write_Enable && (i_VRD_Addr != 0) && !i_Stall;
    
    assign o_PRS_Addr = Map_Table[r_Curr_Checkpoint][i_VRS_Addr];
    assign o_PRT_Addr = Map_Table[r_Curr_Checkpoint][i_VRT_Addr];
    assign o_Checkpoint = r_Curr_Checkpoint;
    assign {w_Old_PReg_Addr, w_Active_Checkpoint, w_Done} = Active_List[Active_List_Head[r_Curr_Checkpoint]];

    // Hardwired assignments - Readouts are asynch
    assign o_VRS_Data = (i_VRS_Addr == 0) ? 0 : PRegister[o_PRS_Addr];
    assign o_VRT_Data = (i_VRT_Addr == 0) ? 0 : PRegister[o_PRT_Addr];
    assign o_PRD_Addr = (i_VRD_Addr == 0) ? 0 : Free_List[Free_List_Head[r_Curr_Checkpoint]];
    assign o_Phys_Active_List_Index = Active_List_Tail[r_Curr_Checkpoint];

    assign o_Stall = stall;
    
    // Combinational logic
    always @(*)
    begin
		//TODO FOR VALUE PREDICTION
		//figure this out for not commiting to used checkpoint, also considering WB of 2 instructions ago
		//happens during EX
		
        // r_Used_Checkpoints
		if ( i_Create_Map_Checkpoint )
            r_Used_Checkpoints_n = r_Used_Checkpoints + 1;
		else
			r_Used_Checkpoints_n = r_Used_Checkpoints;
    end
    
    // Synchronous logic - Writes
    always @(posedge i_Clk)
    begin
        r_Used_Checkpoints = r_Used_Checkpoints_n;
    
        // Perform writes
        if( i_MEM_Write_Enable && (i_PWrite_Addr != 0) )
        begin
            PRegister[i_PWrite_Addr] <= i_PWrite_Data;
            Active_List[i_Phys_Active_List_Index][0] <= 1; // set done to be true
        end
        
        // Update free and active list if instruction is write-enabled
		//  Put a register from free list into active list
        if ( w_Write_Enabled )
        begin
            Free_List_Head[r_Curr_Checkpoint] <= Free_List_Head[r_Curr_Checkpoint] + 1;
            Active_List_Tail[r_Curr_Checkpoint] <= Active_List_Tail[r_Curr_Checkpoint] + 1;
            Free_List_Size[r_Curr_Checkpoint] <= Free_List_Size[r_Curr_Checkpoint] - 1;
            Active_List_Size[r_Curr_Checkpoint] <= Active_List_Size[r_Curr_Checkpoint] + 1;
            Active_List[Active_List_Tail[r_Curr_Checkpoint]] <= {Map_Table[r_Curr_Checkpoint][i_VRD_Addr], r_Curr_Checkpoint, 1'b0};
            Map_Table[r_Curr_Checkpoint][i_VRD_Addr] <= Free_List[Free_List_Head[r_Curr_Checkpoint]];
			if (w_Active_Checkpoint != r_Curr_Checkpoint)
			begin
				Free_List_Head[w_Active_Checkpoint] <= Free_List_Head[r_Curr_Checkpoint] + 1;
				Active_List_Tail[w_Active_Checkpoint] <= Active_List_Tail[r_Curr_Checkpoint] + 1;
				Free_List_Size[w_Active_Checkpoint] <= Free_List_Size[r_Curr_Checkpoint] - 1;
				Active_List_Size[w_Active_Checkpoint] <= Active_List_Size[r_Curr_Checkpoint] + 1;
				Map_Table[w_Active_Checkpoint][i_VRD_Addr] <= Free_List[Free_List_Head[r_Curr_Checkpoint]];
			end
		end
        
        // Create Checkpoint
        if ( i_Create_Map_Checkpoint )
        begin
            if ( r_Used_Checkpoints == 2**CHECKPOINT_WIDTH - 1 )
            begin
                stall <= 1;
            end
            else // Create a checkpoint
            begin
                r_Curr_Checkpoint <= r_Curr_Checkpoint + 1;
                for (i = 0; i < 2**REG_ADDR_WIDTH; i = i + 1)
                begin
                    Map_Table[r_Curr_Checkpoint + 1'b1][i] <= Map_Table[r_Curr_Checkpoint][i];
                end
            end
            
            // Updates Free and Active List variables for new checkpoint
			Free_List_Head[r_Curr_Checkpoint+1] <= Free_List_Head[r_Curr_Checkpoint];
            Free_List_Tail[r_Curr_Checkpoint+1] <= Free_List_Tail[r_Curr_Checkpoint];
            Free_List_Size[r_Curr_Checkpoint+1] <= Free_List_Size[r_Curr_Checkpoint];
            Active_List_Head[r_Curr_Checkpoint+1] <= Active_List_Head[r_Curr_Checkpoint];
            Active_List_Tail[r_Curr_Checkpoint+1] <= Active_List_Tail[r_Curr_Checkpoint];
            Active_List_Size[r_Curr_Checkpoint+1] <= Active_List_Size[r_Curr_Checkpoint];
        end
		
		// if ( i_Create_List_Checkpoint )
        // begin
            //TODO - Set registers of free list and active list
            // Free_List_Head_Checkpoint[r_Curr_Checkpoint] <= Free_List_Head;
            // Free_List_Tail_Checkpoint[r_Curr_Checkpoint] <= Free_List_Tail; // TODO
            // Free_List_Size_Checkpoint[r_Curr_Checkpoint] <= Free_List_Size; // TODO
            // Active_List_Head_Checkpoint[r_Curr_Checkpoint] <= Active_List_Head; // TODO
            // Active_List_Tail_Checkpoint[r_Curr_Checkpoint] <= Active_List_Tail;
            // Active_List_Size_Checkpoint[r_Curr_Checkpoint] <= Active_List_Size; // TODO
        // end

        // Revert Checkpoint
        if ( i_Revert )
        begin
            r_Curr_Checkpoint <= i_Revert_Checkpoint;
            // Free_List_Head <= Free_List_Head[i_Revert_Checkpoint]; //
            //Free_List_Tail <= Free_List_Tail_Checkpoint[i_Revert_Checkpoint];
            // Free_List_Size <= Free_List_Size[i_Revert_Checkpoint]; //
            //Active_List_Head <= Active_List_Head_Checkpoint[i_Revert_Checkpoint];
            // Active_List_Tail <= Active_List_Tail_Checkpoint[i_Revert_Checkpoint]; //
            // Active_List_Size <= Active_List_Size_Checkpoint[i_Revert_Checkpoint]; //
        end
        
        // Free register from active list if instruction is done and committed
        if ( w_Done == 1 && w_Commit_Enabled )
        begin
            Active_List_Head[r_Curr_Checkpoint] <= Active_List_Head[r_Curr_Checkpoint] + 1;
            Active_List_Size[r_Curr_Checkpoint] <= Active_List_Size[r_Curr_Checkpoint] - 1;
            Active_List[Active_List_Head[r_Curr_Checkpoint]][0] <= 0;
            Free_List[Free_List_Tail[r_Curr_Checkpoint]] <= w_Old_PReg_Addr;
            Free_List_Tail[r_Curr_Checkpoint] <= Free_List_Tail[r_Curr_Checkpoint] + 1;
            Free_List_Size[r_Curr_Checkpoint] <= Free_List_Size[r_Curr_Checkpoint] + 1;
        end
    end
    
    initial
    begin
        PRegister[0] <= 0;
        Active_List_Head[r_Curr_Checkpoint] <= 0;
        Active_List_Tail[r_Curr_Checkpoint] <= 0;
        Active_List_Size[r_Curr_Checkpoint] <= 0;
        Free_List_Head[r_Curr_Checkpoint] <= 0;
        Free_List_Tail[r_Curr_Checkpoint] <= 2**FREE_LIST_WIDTH-1;
        Free_List_Size[r_Curr_Checkpoint] <= 2**FREE_LIST_WIDTH-1;
        for (i = 0; i < 2**FREE_LIST_WIDTH; i = i + 1)
        begin
            Free_List[i] <= 2**REG_ADDR_WIDTH + i;
        end
        for (i = 0; i < 2**REG_ADDR_WIDTH; i = i + 1)
        begin
            Map_Table[r_Curr_Checkpoint][i] <= i;
        end
    end
endmodule