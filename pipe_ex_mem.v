// Pipeline stage
module pipe_ex_mem	#(					
						parameter ADDRESS_WIDTH = 32,
						parameter DATA_WIDTH = 32,
						parameter REG_ADDR_WIDTH = 5,
						parameter ALU_CTLCODE_WIDTH = 8,
						parameter MEM_MASK_WIDTH = 3,
						parameter FREE_LIST_WIDTH = 3,
						parameter CHECKPOINT_WIDTH = 2
					)							
					(	
						// Inputs
						input i_Clk,
						input i_Reset_n,	// Async reset (highest priority)
						input i_Flush,			// Flush (2nd highest priority)
						input i_Stall,		// Stall (lowest priority)
						
						// Pipe in/out
						input [ADDRESS_WIDTH-1:0] i_PC,
						output reg [ADDRESS_WIDTH-1:0] o_PC,
						input i_Value_Predicted,		//if we value predicted
						output reg o_Value_Predicted,
						input	[DATA_WIDTH-1:0] i_Instruction,
						output reg [DATA_WIDTH-1:0] o_Instruction,
						input [DATA_WIDTH-1:0] i_ALU_Result,
						output reg [DATA_WIDTH-1:0] o_ALU_Result,
						input i_Mem_Valid,
						output reg o_Mem_Valid,
						input [MEM_MASK_WIDTH-1:0] i_Mem_Mask,
						output reg [MEM_MASK_WIDTH-1:0] o_Mem_Mask,
						input i_Mem_Read_Write_n,
						output reg o_Mem_Read_Write_n,
						input [DATA_WIDTH-1:0] i_Mem_Write_Data,
						output reg [DATA_WIDTH-1:0] o_Mem_Write_Data,
						input i_Writes_Back,
						output reg o_Writes_Back,
						input [REG_ADDR_WIDTH-1:0] i_VWrite_Addr,
						output reg [REG_ADDR_WIDTH-1:0] o_VWrite_Addr,
						input [REG_ADDR_WIDTH:0] i_PWrite_Addr,
						output reg [REG_ADDR_WIDTH:0] o_PWrite_Addr,
						input [FREE_LIST_WIDTH-1:0] i_Phys_Active_List_Index,
						output reg [FREE_LIST_WIDTH-1:0] o_Phys_Active_List_Index,
						input [CHECKPOINT_WIDTH-1:0] i_Checkpoint,
						output reg [CHECKPOINT_WIDTH-1:0] o_Checkpoint,
						input i_Is_Branch,
						output reg o_Is_Branch
					);
		
		// Asynchronous output driver
	always @(posedge i_Clk or negedge i_Reset_n)
	begin
		if( !i_Reset_n )
		begin
			// Initialize outputs to 0s
			o_PC <= 0;
			o_Value_Predicted <= 0;
			o_Instruction <= 0;
			o_ALU_Result <= 0;
			o_Mem_Valid <= 0;
			o_Mem_Read_Write_n <= 0;
			o_Mem_Write_Data <= 0;
			o_Writes_Back <= 0;
			o_PWrite_Addr <= 0;
			o_VWrite_Addr <= 0;
			o_Mem_Mask <= 0;
			o_Phys_Active_List_Index <= 0;
			o_Checkpoint <= 0;
			o_Is_Branch <= 0;
		end
		else
		begin
			if( !i_Stall )
			begin
				if( i_Flush )
				begin
					// Pass through all 0s
					o_PC <= 0;
					o_Value_Predicted <= 0;
					o_Instruction <= 0;
					o_ALU_Result <= 0;
					o_Mem_Valid <= 0;
					o_Mem_Read_Write_n <= 0;
					o_Mem_Write_Data <= 0;
					o_Writes_Back <= 0;
					o_PWrite_Addr <= 0;
					o_VWrite_Addr <= 0;
					o_Mem_Mask <= 0;
					o_Phys_Active_List_Index <= 0;
					o_Checkpoint <= 0;
					o_Is_Branch <= 0;
				end
				else
				begin
					// Pass through signals
					o_PC <= i_PC;
					o_Value_Predicted <= i_Value_Predicted;
					o_Instruction <= i_Instruction;
					o_ALU_Result <= i_ALU_Result;
					o_Mem_Valid <= i_Mem_Valid;
					o_Mem_Mask <= i_Mem_Mask;
					o_Mem_Read_Write_n <= i_Mem_Read_Write_n;
					o_Mem_Write_Data <= i_Mem_Write_Data;
					o_Writes_Back <= i_Writes_Back;
					o_VWrite_Addr <= i_VWrite_Addr;
					o_PWrite_Addr <= i_PWrite_Addr;
					o_Phys_Active_List_Index <= i_Phys_Active_List_Index;
					o_Checkpoint <= i_Checkpoint;
					o_Is_Branch <= i_Is_Branch;
				end
			end
		end
	end
	
endmodule
		