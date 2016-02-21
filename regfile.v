/* regfile.v
* Author: Pravin P. Prabhu
* Last Revision: 1/5/11
* Abstract:
*	The register file for the cpu. The regfile contains 32 registers that be
* read/written from one at a time. The regfile provides two operands on the same
* cycle as requested.
*/
module regfile	#(	parameter DATA_WIDTH = 32,
					parameter REG_ADDR_WIDTH = 5
			)
			(	// Inputs
				input i_Clk,
				
				input [REG_ADDR_WIDTH-1:0] i_RS_Addr,
				input [REG_ADDR_WIDTH-1:0] i_RT_Addr,

				input i_Write_Enable,
				input [REG_ADDR_WIDTH-1:0] i_Write_Addr,
				input [DATA_WIDTH-1:0] i_Write_Data,

				
				// Output
				output [DATA_WIDTH-1:0] o_RS_Data,
				output [DATA_WIDTH-1:0] o_RT_Data
			);
			
	// Internal
		// Regs & wires
	reg [DATA_WIDTH-1:0] Register[0:(2**REG_ADDR_WIDTH)-1];
			
		// Hardwired assignments - Readouts are asynch
	assign o_RS_Data = (i_RS_Addr == 0) ? 0 : Register[i_RS_Addr];
	assign o_RT_Data = (i_RT_Addr == 0) ? 0 : Register[i_RT_Addr];
	
	// Synchronous logic - Writes
	always @(posedge i_Clk)
	begin
		// Perform writes
		if( i_Write_Enable && (i_Write_Addr != 0) )
		begin
			Register[i_Write_Addr] <= i_Write_Data;
		end
	end
	
	initial
	begin
		Register[0] <= 0;
	end
	
endmodule
