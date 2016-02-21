/* flashreader.v
* Author: Todor Mollov
* Last Revision: 1/11/11
* Abstract:
*	After being reset, will automatically copy a given number of words (user
* specified) from flash to main memory. It is possible to specify an offset
* from which to begin the block copy from flash, but typically this should be
* left at 0. Note that it is unadvised to change the period/timing values!!
*/
module flashreader
#(
	// Params for overall access
	parameter WORDS_TO_LOAD = 32'h100000,			// the ultimate loader

	// Params for clock
	parameter CLOCK_PERIOD_PS = 10_000,		// Clock period in ps
	
	// Parameterizations for dram
	
	parameter DRAM_ADDR_WIDTH = 22,				// Bits in the whole address
	parameter DRAM_BASE_ADDR = {DRAM_ADDR_WIDTH{1'b0}},			// Base address to start dumping
	parameter DRAM_DATA_WIDTH = 32,			// Bits per data burst to the dram
	parameter DRAM_DATA_BURST_COUNT = 4,		// How many widths of data the dram expects per write
	
	// Parameterizations for flash
	parameter FLASH_BASE_ADDR = 22'd0,				// Base addr to load from flash
	parameter FLASH_ADDR_WIDTH = 22,				// How many bits in the addr. of flash
	parameter FLASH_DATA_WIDTH = 8,				// Bits per data line
	parameter FLASH_READ_WAIT_TIME_PS = 90000		// How many ps it takes after a read request to provide data
)
(
	// User interface
		// Inputs
	input i_Clk,			// Mem clk
	input i_Reset_n,			// Resets the internal state machine, initiates another copy
	
		// Outputs
	output reg o_Done,			// When finished w/ block copy, done is raised
	
	// SDRAM Interface
		// General interface
	output reg [(DRAM_ADDR_WIDTH-1):0] o_SDRAM_Addr,		// Addr we want to write to
	output reg o_SDRAM_Req_Valid,				// Whether the request is valid or not
	output o_SDRAM_Read_Write_n,					// Whether we're doing a write or not (ALWAYS WRITE)
	
		// Write input data interface
	output reg [(DRAM_DATA_WIDTH-1):0] o_SDRAM_Data,	// The data we are going to write
	input i_SDRAM_Data_Read,						// Feedback from ram - was the data read?
	input i_SDRAM_Last,									// Indicates that the ram is on the last word of the transaction
	
		// Flash interface
	output reg [(FLASH_ADDR_WIDTH-1):0] o_FL_Addr,	// Flash address
	input [(FLASH_DATA_WIDTH-1):0] i_FL_Data,			// Input data from the flash
	output o_FL_Chip_En_n,						// Chip enable
	output o_FL_Output_En_n,							// Output enable
	output o_FL_Write_En_n,							// Write enable
	output o_FL_Reset_n								// Reset
);

// Constants
localparam FLASH_READ_WAIT_CYCLES = ((FLASH_READ_WAIT_TIME_PS/CLOCK_PERIOD_PS) + 4'd1);		// How many cycles that must be waited for after issuing a read req.
localparam FLASH_READS_PER_LINE = ((DRAM_DATA_WIDTH)/(FLASH_DATA_WIDTH))*DRAM_DATA_BURST_COUNT;		// # of flash reads per line for dmem

// Hardwired assignments
	// For dmem
assign o_SDRAM_Read_Write_n = 0;		// Only do writes

	// For flash
assign o_FL_Chip_En_n = 0;							// Flash always on
assign o_FL_Output_En_n = 0;					// Always output (only reading)
assign o_FL_Write_En_n = 1;							// Never write
assign o_FL_Reset_n = 1;						// Do not request resets

// Internal registers
	// Write buffer; data is stored here temporarily before being written out to the main memory
reg [(FLASH_DATA_WIDTH-1):0] dmem_write_buf[(DRAM_DATA_WIDTH/FLASH_DATA_WIDTH)*DRAM_DATA_BURST_COUNT-1:0];

reg [(FLASH_DATA_WIDTH-1):0] FL_Data_Reg;

reg [3:0] FlashReadCount;
reg [3:0] FlashWaitCount;
reg [1:0] DRAMWriteCount;

// States
reg [1:0] State;

localparam FS_LOAD_LINE = 2'd0;
localparam FS_DMEM_REQ = 2'd1;
localparam FS_DMEM_WRITE = 2'd2;
localparam FS_DONE = 2'd3;

always @(posedge i_Clk or negedge i_Reset_n)
begin
	if( ~i_Reset_n )
	begin
		FL_Data_Reg <= 0;
		State <= FS_LOAD_LINE;
		FlashReadCount <= 0;
		FlashWaitCount <= FLASH_READ_WAIT_CYCLES;
		DRAMWriteCount <= 0;
		o_SDRAM_Addr <= DRAM_BASE_ADDR;
		
		o_Done <= 0;
		
		o_FL_Addr <= FLASH_BASE_ADDR;
		o_SDRAM_Req_Valid <= 1'b0;
	end
	else
	begin
		FL_Data_Reg <= i_FL_Data;
		case(State)
			FS_LOAD_LINE:
			begin
				if (FlashWaitCount == 0)
				begin
					o_FL_Addr <= o_FL_Addr+22'd1;
					dmem_write_buf[FlashReadCount] <= FL_Data_Reg;
					FlashReadCount <= FlashReadCount+4'd1;
					FlashWaitCount <= FLASH_READ_WAIT_CYCLES;
					
					if (FlashReadCount == (FLASH_READS_PER_LINE-1))
					begin
						State <= FS_DMEM_REQ;
					end
				end
				else
					FlashWaitCount <= FlashWaitCount-4'd1;
			end
			FS_DMEM_REQ:
			begin
				DRAMWriteCount <= DRAMWriteCount+2'd1;
				o_SDRAM_Data <= {dmem_write_buf[DRAMWriteCount*4],dmem_write_buf[DRAMWriteCount*4+1],dmem_write_buf[DRAMWriteCount*4+2],dmem_write_buf[DRAMWriteCount*4+3]};				
				o_SDRAM_Req_Valid <= 1'b1;
				State <= FS_DMEM_WRITE;
			end
			FS_DMEM_WRITE:
			begin
				if (i_SDRAM_Data_Read & !i_SDRAM_Last)
				begin
					DRAMWriteCount <= DRAMWriteCount+2'd1;
					o_SDRAM_Addr <= o_SDRAM_Addr + 22'd2;
					o_SDRAM_Data <= {dmem_write_buf[DRAMWriteCount*4],dmem_write_buf[DRAMWriteCount*4+1],dmem_write_buf[DRAMWriteCount*4+2],dmem_write_buf[DRAMWriteCount*4+3]};
				end
				else if (i_SDRAM_Last)
				begin				
					o_SDRAM_Req_Valid <= 1'b0;
					o_SDRAM_Addr <= o_SDRAM_Addr + 22'd2;
					if (o_FL_Addr[21:0] == {WORDS_TO_LOAD[19:0],2'b0})
						State <= FS_DONE;
					else
						State <= FS_LOAD_LINE;
				end
			end
			FS_DONE:
			begin
				o_Done <= 1'b1;
			end
		endcase
	end
end

endmodule

