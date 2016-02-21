// Fetch Unit
//	Author: Pravin P. Prabhu
//	Version: 1.0
//	Last Revision: 7/10/10
//	Abstract:
//		This module provides instructions to the rest of the pipeline.

module fetch_unit	#(	
					parameter ADDRESS_WIDTH = 32,
					parameter DATA_WIDTH = 32
				)
				(	// Inputs
					input i_Clk,
					input i_Reset_n,
					input i_Stall,
					
					input i_Load,
					input [ADDRESS_WIDTH-1:0] i_Load_Address,
					
					// Outputs
					output reg [ADDRESS_WIDTH-1:0] o_PC
				);
	
	// PC incrementing state machine
always @(posedge i_Clk or negedge i_Reset_n)
begin
	if( !i_Reset_n )
	begin
		o_PC <= 0;
	end
	else
	begin
		if( !i_Stall )
		begin
			// If not stalled, we can change the PC
			if( i_Load )
			begin
				o_PC <= i_Load_Address;
			end
			else
			begin
				o_PC <= o_PC + 1'b1;
			end
		end
	end
end

endmodule
