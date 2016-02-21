/*
Value history table for value prediction
*/
module value_history_table #( parameter DATA_WIDTH, parameter ADDRESS_WIDTH )
(
	input clk_i,
	input [ADDRESS_WIDTH-1:0] ALU_PC_i,
	input [ADDRESS_WIDTH-1:0] Revert_PC_i,
	input EX_is_Load_i,
	input [DATA_WIDTH-1:0] DMEM_instruction_i,
	input [DATA_WIDTH-1:0] DMEM_data_i,
	input DMEM_is_Valid_i,
	input DMEM_Read_Write_n_i,			//1 for read, 0 for write
	input Old_Value_Predicted_i,
	output [DATA_WIDTH-1:0] predicted_data_o,
	output revert_predict_o,
	output predicted_o //TODO
);
localparam INDEX_WIDTH = 8;
localparam TAG_WIDTH = ADDRESS_WIDTH-INDEX_WIDTH;
localparam MRU = 1;
localparam CONFIDENCE = 2;

reg [TAG_WIDTH+MRU+CONFIDENCE-1:0] Table [0:(2**INDEX_WIDTH)-1];
reg [DATA_WIDTH-1:0] PLVT [0:(2**INDEX_WIDTH)-1];

reg [DATA_WIDTH-1:0] r_predicted_data;
reg r_predict;
reg r_revert_predict;

assign predicted_o = r_predict;	
assign predicted_data_o = r_predicted_data;
assign revert_predict_o = r_revert_predict;

assign revert_predict_o = DMEM_data_i != r_predicted_data;

wire [INDEX_WIDTH-1:0] w_EX_Index;
wire [TAG_WIDTH-1:0] w_EX_Tag;
wire [MRU-1:0] w_EX_MRU;
wire [CONFIDENCE-1:0] w_EX_Confidence;
assign w_EX_Index = ALU_PC_i[INDEX_WIDTH-1:0];
assign {w_EX_Tag,w_EX_MRU,w_EX_Confidence} = Table[w_EX_Index];

wire [INDEX_WIDTH-1:0] w_MEM_Index;
wire [TAG_WIDTH-1:0] w_MEM_Tag;
wire [MRU-1:0] w_MEM_MRU;
wire [CONFIDENCE-1:0] w_MEM_Confidence;
assign w_MEM_Index = Revert_PC_i[INDEX_WIDTH-1:0];
assign {w_MEM_Tag,w_MEM_MRU,w_MEM_Confidence} = Table[w_MEM_Index];

reg [CONFIDENCE-1:0] r_MEM_Confidence_n;

integer i;
initial
begin
	//initialize both tables to zero
	for ( i = 0; i < (2**INDEX_WIDTH); i = i + 1 )
	begin
		Table[i] = 0;
		PLVT[i] = 0;
	end
end

always@(*)
begin
	if (DMEM_data_i == PLVT[w_MEM_Index])
		if (w_MEM_Confidence + 1 != 0)
			r_MEM_Confidence_n = w_MEM_Confidence + 1;
		else
			r_MEM_Confidence_n = w_MEM_Confidence;
	else
	begin
		r_MEM_Confidence_n = w_MEM_Confidence - 1;
	end
end
	
always@(posedge clk_i)
begin
	r_revert_predict <= 1'b0;
	r_predict <= 1'b0;
	if (EX_is_Load_i)
	begin
		//take the PC and index into Table and check tag
		if (w_EX_Tag == ALU_PC_i[INDEX_WIDTH +: TAG_WIDTH])
			//if confidence is greater than threshold
			if (w_EX_Confidence[CONFIDENCE-1] == 1)
			begin
				r_predicted_data <= PLVT[w_EX_Index];
				r_predict <= 1'b1;
			end
	end
	if (DMEM_is_Valid_i && DMEM_Read_Write_n_i && Old_Value_Predicted_i)
	begin
		//check if cache hit matches prediction
		if (w_MEM_Tag == Revert_PC_i[INDEX_WIDTH +: TAG_WIDTH])
			Table[w_MEM_Index][CONFIDENCE-1:0] <= r_MEM_Confidence_n;
			if (DMEM_data_i != PLVT[w_MEM_Index])
				if (w_MEM_Confidence + 1 != 0)
					Table[w_MEM_Index][CONFIDENCE-1:0] <= w_MEM_Confidence + 1;
				else
					Table[w_MEM_Index][CONFIDENCE-1:0] <= w_MEM_Confidence;
			else
			begin
				r_revert_predict <= 1;
				Table[w_MEM_Index][CONFIDENCE-1:0] <= w_MEM_Confidence - 1;
				if (r_MEM_Confidence_n[CONFIDENCE-1] == 0)
					PLVT[w_MEM_Index] = DMEM_data_i;
			end
		//update confidence bits and PLVT value accordingly
	end
end

endmodule 