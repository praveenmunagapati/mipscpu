/* branch_history_table.v
* Supports bimodal predictor and local prediction
*/
module branch_history_table 
#(
	parameter HISTORY_SIZE, // Size of prediction table
	parameter COUNT_SIZE // Size of bimodal_table
)
(
	input clk_i,
	input [HISTORY_SIZE-1:0] read_Branch_PC_i,
	input DEC_is_Branch_i,
	input EX_is_Branch_i,
	input branch_i,
	input Smash_Transient_i,
	input [HISTORY_SIZE-1:0] write_Branch_PC_i,
	input [1:0] old_predictor_i,
	input [COUNT_SIZE-1:0] old_pattern_i,
	output [1:0] predictor_o,
	//output was_taken_o,
	output [COUNT_SIZE-1:0] pattern_o
);
	localparam BIMODAL = 2'd0;
	localparam LOCAL = 2'd1;
	localparam GSHARE = 2'd2;
	localparam PREDICTION = LOCAL;
	
	localparam BIMODAL_SIZE = 	PREDICTION == LOCAL ? COUNT_SIZE : // LOCAL
										HISTORY_SIZE; // 
	localparam PREDICTOR_SIZE = 3;
	
	integer int_history_mispredicts = 0;
	integer int_history_branches = 0;

	reg [COUNT_SIZE-1:0] history_table [0:(2**HISTORY_SIZE)-1];
	reg [1:0] bimodal_table [0:(2**BIMODAL_SIZE)-1]; // 00 - strongly not taken
																	 // 01 - weakly not taken
																	 // 10 - weakly taken
																	 // 11 - strongly taken
	
	assign pattern_o = 	PREDICTION == LOCAL ? history_table[read_Branch_PC_i] : // LOCAL
								PREDICTION == GSHARE ? history_table[0] : // GSHARE
								history_table[read_Branch_PC_i]; // default

	// Index for speculative updating prediction table
	wire [HISTORY_SIZE-1:0] w_read_bimodal_index =  PREDICTION == BIMODAL ? read_Branch_PC_i : // BIMODAL
																   PREDICTION == LOCAL ? pattern_o : // LOCAL
																	pattern_o ^ read_Branch_PC_i; // GSHARE
	wire [HISTORY_SIZE-1:0] w_read_history_index = PREDICTION == LOCAL ? read_Branch_PC_i : // LOCAL
																	0; // GSHARE
																	
	// Index for fixing mispredicts
	wire [HISTORY_SIZE-1:0] w_write_bimodal_index = PREDICTION == BIMODAL ? write_Branch_PC_i : // BIMODAL
																	PREDICTION == LOCAL ? old_pattern_i : // LOCAL
																	old_pattern_i ^ write_Branch_PC_i; // GSHARE
	wire [HISTORY_SIZE-1:0] w_write_history_index = PREDICTION == LOCAL ? write_Branch_PC_i : // LOCAL
																	0; // GSHARE
	
	assign predictor_o = bimodal_table[w_read_bimodal_index];
	
	integer i;
	initial
	begin
		for ( i = 0; i < (2**BIMODAL_SIZE); i = i + 1 )
		begin
			bimodal_table[i] = 2'b10;
		end
		for ( i = 0; i < (2**HISTORY_SIZE); i = i + 1 )
		begin
			history_table[i] = 0;
		end
	end
	
	always@(posedge clk_i)
	begin
		if (DEC_is_Branch_i) // If branch, do prediction
		begin
			int_history_branches <= int_history_branches + 1;
			if (predictor_o[1] == 1) // Predict taken
			begin
				if (predictor_o[0] != 1'b1) // Increment counter
				begin
					bimodal_table[w_read_bimodal_index] <= predictor_o + 1'b1;
				end
				history_table[w_read_history_index] <= pattern_o << 1 | 1'b1;
			end
			else if (predictor_o[1] == 0) // Predict not taken
			begin
				if (predictor_o[0] != 1'b0) // Decrement counter
				begin
					bimodal_table[w_read_bimodal_index] <= predictor_o - 1'b1;
				end
				history_table[w_read_history_index] <= pattern_o << 1 | 1'b0;
			end
			else // default
			begin
				bimodal_table[w_read_bimodal_index] <= predictor_o;
				history_table[w_read_history_index] <= pattern_o;
			end
		end
		if (EX_is_Branch_i) // Check if prediction was correct or not
		begin
			/*if (Smash_Transient_i)
			begin
				bimodal_table[w_write_bimodal_index] <= old_predictor_i;
				history_table[write_Branch_PC_i] <= old_pattern_i;
			end
			else */if (!(branch_i ^ old_predictor_i[1])) // if prediction was correct
			begin
			end
			else if (branch_i ^ old_predictor_i[1]) // if prediction was incorrect
			begin
				int_history_mispredicts <= int_history_mispredicts + 1;
				if (branch_i == 1) // Need to increment counter, using the old predictor value
				begin
					//if (predictor_o[0] != 1'd1)
						bimodal_table[w_write_bimodal_index] <= old_predictor_i + 2'b1;
				end
				else if (branch_i == 0) // Need to decrement counter, using the old predictor value
				begin
					//if (predictor_o[0] != 1'd0)
						bimodal_table[w_write_bimodal_index] <= old_predictor_i - 2'b1;
				end
				else // default
				begin
					bimodal_table[w_write_bimodal_index] <= old_predictor_i;
				end
				history_table[w_write_history_index] <= old_pattern_i << 1 | branch_i;
			end
			else
			begin
			end
		end
	end

endmodule 