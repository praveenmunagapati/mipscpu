module mem_prediction	#( parameter ADDRESS_WIDTH,
						   parameter CHECKPOINT_WIDTH,
						   parameter DATA_WIDTH,
						   parameter REG_ADDR_WIDTH,
						   parameter FREE_LIST_WIDTH
 )
	(	
		// Inputs
		input i_Clk,
		input [ADDRESS_WIDTH-1:0] i_PC,
		input i_Mem_Ready,
		input i_Mem_Done,
		input [CHECKPOINT_WIDTH-1:0] i_Checkpoint,
		input i_Value_Predicted,
		
		output [ADDRESS_WIDTH-1:0] o_PC,
		output [CHECKPOINT_WIDTH-1:0] o_Checkpoint,
		output o_Value_Predicted,
		
		input [DATA_WIDTH-1:0] i_WriteBack_Data,
		output reg [DATA_WIDTH-1:0] o_WriteBack_Data,
		input i_Writes_Back,
		output reg o_Writes_Back,
		input [REG_ADDR_WIDTH-1:0] i_VWrite_Addr,
		output reg [REG_ADDR_WIDTH-1:0] o_VWrite_Addr,
		input [REG_ADDR_WIDTH:0] i_PWrite_Addr,
		output reg [REG_ADDR_WIDTH:0] o_PWrite_Addr,
		input [FREE_LIST_WIDTH-1:0] i_Phys_Active_List_Index,
		output reg [FREE_LIST_WIDTH-1:0] o_Phys_Active_List_Index,
		input i_Is_Branch,
		output reg o_Is_Branch
	);
	
	reg [ADDRESS_WIDTH-1:0] r_PC;
	assign o_PC = r_PC;
	
	reg r_Checkpoint;
	assign o_Checkpoint = r_Checkpoint;
	
	reg r_Value_Predicted;
	assign o_Value_Predicted = r_Value_Predicted;
	
	reg [DATA_WIDTH-1:0] r_WriteBack_Data;
	reg r_Writes_Back;
	reg [REG_ADDR_WIDTH-1:0] r_VWrite_Addr;
	reg [REG_ADDR_WIDTH:0] r_PWrite_Addr;
	reg [FREE_LIST_WIDTH-1:0] r_Phys_Active_List_Index;
	reg r_Is_Branch;

	always @(posedge i_Clk)
	begin
		if(i_Mem_Ready)
		begin
			r_Checkpoint <= i_Checkpoint;
			r_PC <= i_PC;
			r_Value_Predicted <= i_Value_Predicted;
			
			r_WriteBack_Data <= i_WriteBack_Data;
			r_Writes_Back <= i_Writes_Back;
			r_VWrite_Addr <= i_VWrite_Addr;
			r_PWrite_Addr <= i_PWrite_Addr;
			r_Phys_Active_List_Index <= i_Phys_Active_List_Index;
			r_Is_Branch <= i_Is_Branch;
		end
	end
	
	always@(*)
	begin
		// if ( i_Mem_Done ) // MEM finishes processing a cache miss
		// begin
			// o_WriteBack_Data = r_WriteBack_Data;
			// o_Writes_Back = r_Writes_Back;
			// o_VWrite_Addr = r_VWrite_Addr;
			// o_PWrite_Addr = r_PWrite_Addr;
			// o_Phys_Active_List_Index = r_Phys_Active_List_Index;
			// o_Is_Branch = r_Is_Branch;
		// end
		// else
		// begin
			o_WriteBack_Data = i_WriteBack_Data;
			o_Writes_Back = i_Writes_Back;
			o_VWrite_Addr = i_VWrite_Addr;
			o_PWrite_Addr = i_PWrite_Addr;
			o_Phys_Active_List_Index = i_Phys_Active_List_Index;
			o_Is_Branch = i_Is_Branch;
		// end
	end

	
endmodule
		