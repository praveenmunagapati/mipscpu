/* forwarding_unit.v
* Author: Pravin P. Prabhu
* Last Revision: 1/5/11
* Abstract:
*	Provides forwarding support to the pipeline (i.e. instructions that have
* completed in later stages can have their results forwarded to newer
* instructions that require them -- this improves performance by resolving
* data dependencies without requiring a stall).
*/
module forwarding_unit	#(	parameter DATA_WIDTH=32,
							parameter REG_ADDR_WIDTH=5
						)
						(
							//==============================================
							// Hazard in DECODE?
							input i_DEC_Uses_RS,								// DEC wants to use RS
							input [REG_ADDR_WIDTH:0] i_DEC_RS_Addr,		// RS request addr.
							input i_DEC_Uses_RT,								// DEC wants to use RT
							input [REG_ADDR_WIDTH:0] i_DEC_RT_Addr,		// RT request addr.
							input [DATA_WIDTH-1:0] i_DEC_RS_Data,
							input [DATA_WIDTH-1:0] i_DEC_RT_Data,
							
							// Feedback from EX
							input i_EX_Writes_Back,								// EX is valid for analysis
							input i_EX_Valid,								// If it's a valid ALU op or not
							input [REG_ADDR_WIDTH:0] i_EX_Write_Addr,		// What EX will write to
							input [DATA_WIDTH-1:0] i_EX_Write_Data,
							
							// Feedback from MEM
							input i_MEM_Writes_Back,								// MEM is valid for analysis
							input [REG_ADDR_WIDTH:0] i_MEM_Write_Addr,
							input [DATA_WIDTH-1:0] i_MEM_Write_Data,
							
							// Feedback from WB
							input i_WB_Writes_Back,								// WB is valid for analysis
							input [REG_ADDR_WIDTH:0] i_WB_Write_Addr,			// What WB will write to
							input [DATA_WIDTH-1:0] i_WB_Write_Data,
							
							// Feedback from Value History Table
							input i_Predict_Made,
							input [DATA_WIDTH-1:0] i_Predicted_Data,
							
							//===============================================
							// IFetch forwarding
							
								// None
								
							// DEC forwarding
							output reg [DATA_WIDTH-1:0] o_DEC_RS_Override_Data,
							output reg [DATA_WIDTH-1:0] o_DEC_RT_Override_Data
							
							// EX forwarding
							//output reg [DATA_WIDTH-1:0] ,

							// MEM forwarding
						);

	// Forwarding to DECODE
	always @(*)
	begin
		o_DEC_RS_Override_Data <= i_DEC_RS_Data;
		o_DEC_RT_Override_Data <= i_DEC_RT_Data;

		// Do we need to forward from EX back to DECODE? - RS FORWARDING
		if( i_DEC_Uses_RS &&
			i_EX_Writes_Back &&
			i_EX_Valid &&			// Is it a valid ALU op?
			(i_DEC_RS_Addr == i_EX_Write_Addr)
			)
		begin
			if (i_Predict_Made)
				o_DEC_RS_Override_Data <= i_Predicted_Data;
			else
				o_DEC_RS_Override_Data <= i_EX_Write_Data;
		end
		else if( i_DEC_Uses_RS &&	// Forward from MEM?
				 i_MEM_Writes_Back && 
				 (i_DEC_RS_Addr == i_MEM_Write_Addr)
				)
		begin
			o_DEC_RS_Override_Data <= i_MEM_Write_Data;
		end
		else if( i_DEC_Uses_RS &&
				 i_WB_Writes_Back &&
				 (i_DEC_RS_Addr == i_WB_Write_Addr) )
		begin
			o_DEC_RS_Override_Data <= i_WB_Write_Data;
		end

		// Do we need to forward from EX back to DECODE? - RT FORWARDING
		if( i_DEC_Uses_RT &&
			i_EX_Writes_Back &&
			i_EX_Valid &&
			(i_DEC_RT_Addr == i_EX_Write_Addr)
			)
			begin
				if (i_Predict_Made)
					o_DEC_RS_Override_Data <= i_Predicted_Data;
				else
				o_DEC_RT_Override_Data <= i_EX_Write_Data;
			end
		else if( i_DEC_Uses_RT &&	// Forward from MEM?
				 i_MEM_Writes_Back && 
				 (i_DEC_RT_Addr == i_MEM_Write_Addr)
				 )
		begin
			o_DEC_RT_Override_Data <= i_MEM_Write_Data;
		end
		else if( i_DEC_Uses_RT &&
				 i_WB_Writes_Back &&
				 (i_DEC_RT_Addr == i_WB_Write_Addr) )
		begin
			o_DEC_RT_Override_Data <= i_WB_Write_Data;
		end		
	end
						
endmodule
						