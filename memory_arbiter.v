/* memory_arbiter.v
* Author: Pravin P. Prabhu
* Last Revision: 1/5/11
* Abstract:
*	Provides arbitration amongst sources that all wish to request from main
* memory. Will service sources in order of priority, which is:
* (high)
* flashloader
* imem
* vga -- (to be included)
* dmem
* (low)
*/
module memory_arbiter	#(	parameter DATA_WIDTH=32,
							parameter ADDRESS_WIDTH=22
						)
						(
							// General
							input i_Clk,
							input i_Reset_n,
							
							// Requests to/from IMEM - Assume we always read
							input i_IMEM_Valid,						// If IMEM request is valid
							input [ADDRESS_WIDTH-1:0] i_IMEM_Address,		// IMEM request addr.
							output reg o_IMEM_Valid,
							output reg o_IMEM_Last,
							output reg [DATA_WIDTH-1:0] o_IMEM_Data,
							
							// Requests to/from DMEM
							input i_DMEM_Valid,
							input i_DMEM_Read_Write_n,
							input [ADDRESS_WIDTH-1:0] i_DMEM_Address,
							input [DATA_WIDTH-1:0] i_DMEM_Data,
							output reg o_DMEM_Valid,
							output reg o_DMEM_Data_Read,
							output reg o_DMEM_Last,
							output reg [DATA_WIDTH-1:0] o_DMEM_Data,
							
							// Requests to/from FLASH - Assume we always write
							input i_Flash_Valid,
							input [DATA_WIDTH-1:0] i_Flash_Data,
							input [ADDRESS_WIDTH-1:0] i_Flash_Address,
							output reg o_Flash_Data_Read,
							output reg o_Flash_Last,
							
							// Interface with SDRAM Controller
							output reg o_MEM_Valid,
							output reg [ADDRESS_WIDTH-1:0] o_MEM_Address,
							output reg o_MEM_Read_Write_n,
							
								// Write data interface
							output reg [DATA_WIDTH-1:0] o_MEM_Data,
							input i_MEM_Data_Read,
							
								// Read data interface
							input [DATA_WIDTH-1:0] i_MEM_Data,
							input i_MEM_Data_Valid,
							
							input i_MEM_Last				// If we're on the last piece of the transaction
						);
	
	// Consts
	localparam TRUE = 1'b1;
	localparam FALSE = 1'b0;
	localparam READ = 1'b1;
	localparam WRITE = 1'b0;	
	
	// State of the arbiter
	localparam STATE_READY = 4'd0;
	localparam STATE_SERVICING_FLASH = 4'd1;
	localparam STATE_SERVICING_IMEM = 4'd2;
	localparam STATE_SERVICING_DMEM = 4'd3;
	localparam STATE_SERVICING_VGA = 4'd4;
	
	reg [3:0] State;

	always @(*)
	begin
		o_IMEM_Valid <= FALSE;
		o_IMEM_Last <= FALSE;
		o_IMEM_Data <= {32{1'bx}};
		o_DMEM_Valid <= FALSE;
		o_DMEM_Data_Read <= FALSE;
		o_DMEM_Last <= FALSE;
		o_DMEM_Data <= {32{1'bx}};
		o_Flash_Data_Read <= FALSE;
		o_Flash_Last <= FALSE;
		o_MEM_Valid <= FALSE;
		o_MEM_Address <= {ADDRESS_WIDTH{1'bx}};
		o_MEM_Read_Write_n <= READ;
		o_MEM_Data <= {32{1'bx}};

		case(State)
			//=======================
			// Accept State
			STATE_READY:
			begin
			end
			
			//=======================
			// Services States
			STATE_SERVICING_FLASH:
			begin
				// Servicing flash: Bridge flash I/O
				o_MEM_Valid <= TRUE;
				o_MEM_Address <= i_Flash_Address;
				o_MEM_Read_Write_n <= WRITE;
				o_MEM_Data <= i_Flash_Data;
				o_Flash_Data_Read <= i_MEM_Data_Read;
				o_Flash_Last <= i_MEM_Last;
			end
			
			STATE_SERVICING_IMEM:
			begin
				o_MEM_Valid <= TRUE;
				o_MEM_Address <= i_IMEM_Address;
				o_MEM_Read_Write_n <= READ;
				o_IMEM_Valid <= i_MEM_Data_Valid;
				o_IMEM_Last <= i_MEM_Last;
				o_IMEM_Data <= i_MEM_Data;			
			end
			
			STATE_SERVICING_DMEM:
			begin
				o_MEM_Valid <= TRUE;
				o_MEM_Address <= i_DMEM_Address;
				o_MEM_Read_Write_n <= i_DMEM_Read_Write_n;
				o_MEM_Data <= i_DMEM_Data;
				o_DMEM_Valid <= i_MEM_Data_Valid;
				o_DMEM_Data_Read <= i_MEM_Data_Read;
				o_DMEM_Last <= i_MEM_Last;
				o_DMEM_Data <= i_MEM_Data;
			end
		endcase
	end
	
	// State driver
	always @(posedge i_Clk or negedge i_Reset_n)
	begin
		if( !i_Reset_n )
		begin
			// Defaults			
			State <= STATE_READY;	
		end
		else
		begin
			case(State)
				//=======================
				// Accept State
				STATE_READY:
				begin
					if( i_Flash_Valid )
					begin
						State <= STATE_SERVICING_FLASH;
					end
					else if( i_IMEM_Valid )
					begin
						State <= STATE_SERVICING_IMEM;
					end
					else if( i_DMEM_Valid )
					begin
						State <= STATE_SERVICING_DMEM;
					end
				end
				
				//=======================
				// Services States
				STATE_SERVICING_FLASH:
				begin
					// See if we're done transacting
					if( i_MEM_Last )
						State <= STATE_READY;				
				end
				
				STATE_SERVICING_IMEM:
				begin
					// See if we're done transacting
					if( i_MEM_Last )
						State <= STATE_READY;				
				end
				
				STATE_SERVICING_DMEM:
				begin
					// See if we're done transacting
					if( i_MEM_Last )
						State <= STATE_READY;
				end
				
				// Remain in current state by default
				default:
				begin
				end
			endcase
		end	
	end
		
endmodule
						