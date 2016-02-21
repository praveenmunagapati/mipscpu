/* d_cache.v
* Sam Chan, Tony Medeiros, Dean Tullsen, Todor Mollov, and Pravin Prabhu
* Abstract:
*	This is code for a direct-mapped cache, with 16-byte lines and 512 lines, for 
*    an 8 KB DM cache.   16-byte cache lines are formed via four one-word (four byte)
*    banks.  This is done so that we can do a MIPS sw in a single access, rather than 2
*    accesses (read whole line, modify the correct word, write back the line).  This
*    was done so that Quartus would map the cache data to RAM blocks.  Thus, changing
*    the size of this cache is pretty easy, changing the associativity is a bit more
*    challenging, since the DM cache doesn't need any code for associativity, and 
*    changing the line size is very messy since it changes the number of banks.
*  If someone wants to clean this up (e.g., paramterize the number of banks), please
*    let me know.
*/

module d_cache	#(	
					parameter DATA_WIDTH = 32,
					//parameter TAG_WIDTH = 10,
					//parameter INDEX_WIDTH = 9,
					parameter ADDRESS_WIDTH = 22,
					parameter BLOCK_OFFSET_WIDTH = 2,
					parameter ASSOCIATIVITY = 1, // for n-way associative caching
					// TODO adjust index_width to consider associativity
					parameter INDEX_WIDTH = 12,  // number of sets in bits (size of cache)
					parameter TAG_WIDTH = 21 - INDEX_WIDTH - BLOCK_OFFSET_WIDTH,
					parameter MEM_MASK_WIDTH = 3 // What's this for?
				)
				(	// Inputs
					input i_Clk,
					input i_Reset_n,
					input i_Valid,
					input [MEM_MASK_WIDTH-1:0] i_Mem_Mask,
					input [(TAG_WIDTH+INDEX_WIDTH+BLOCK_OFFSET_WIDTH)-1:0] i_Address,	// 32-bit aligned address
					input i_Read_Write_n,
					input [DATA_WIDTH-1:0] i_Write_Data,

					// Outputs
					output o_Ready,
					output reg o_Valid,					// If done reading out a value.
					output [DATA_WIDTH-1:0] o_Data,
					
					// Mem Transaction
					output reg o_MEM_Valid,
					output reg o_MEM_Read_Write_n,
					output reg [(TAG_WIDTH+INDEX_WIDTH+BLOCK_OFFSET_WIDTH):0] o_MEM_Address,	// output 2-byte aligned addresses
					output reg [DATA_WIDTH-1:0] o_MEM_Data,
					input i_MEM_Valid,
					input i_MEM_Data_Read,
					input i_MEM_Last,
					input [DATA_WIDTH-1:0] i_MEM_Data
				);

	// consts
	localparam DEBUG = 1'b1;
	localparam FALSE = 1'b0;
	localparam TRUE = 1'b1;
	localparam UNKNOWN = 1'bx;
	
	localparam READ = 1'b1;
	localparam WRITE = 1'b0;	
	
//	localparam ADDRESS_WIDTH = TAG_WIDTH+INDEX_WIDTH+BLOCK_OFFSET_WIDTH;
	
	wire debug; 
	// Internal
		// Reg'd inputs
	reg [(TAG_WIDTH+INDEX_WIDTH+BLOCK_OFFSET_WIDTH)-1:0] r_i_Address;
	reg [BLOCK_OFFSET_WIDTH:0] r_i_BlockOffset;
	reg [INDEX_WIDTH-1:0] r_i_Index;
	reg [TAG_WIDTH-1:0] r_i_Tag;
	reg [DATA_WIDTH-1:0] r_i_Write_Data, r_o_Data;
	reg r_i_Read_Write_n;
	
		// Parsing
	wire [BLOCK_OFFSET_WIDTH-1:0] i_BlockOffset = i_Address[BLOCK_OFFSET_WIDTH-1:0];
	wire [INDEX_WIDTH-1:0] i_Index = i_Address[INDEX_WIDTH+BLOCK_OFFSET_WIDTH-1:BLOCK_OFFSET_WIDTH];
	wire [TAG_WIDTH-1:0] i_Tag = i_Address[TAG_WIDTH+INDEX_WIDTH+BLOCK_OFFSET_WIDTH-1:INDEX_WIDTH+BLOCK_OFFSET_WIDTH];
	
	// TODO add associativity to arrays
		// Tags
	reg [TAG_WIDTH-1:0] Tag_Array [0:(1<<INDEX_WIDTH)-1];
		// Data
	reg [(DATA_WIDTH*4)-1:0] Data_Array [0:(1<<INDEX_WIDTH)-1];
		// Valid
	reg Valid_Array [0:(1<<INDEX_WIDTH)-1];
		// Dirty
	reg Dirty_Array [0:(1<<INDEX_WIDTH)-1];
	
	//cache bank stuff
	wire [31:0] bank0readdata, bank1readdata, bank2readdata, bank3readdata;
	reg [31:0] bank0writedata, bank1writedata, bank2writedata, bank3writedata;
	reg bank0we, bank1we, bank2we, bank3we;
	reg finished_populate;
		// States
	reg [5:0] State;
	
	localparam STATE_READY = 0;				// Ready for incoming requests
	localparam STATE_PAUSE = 1;
	localparam STATE_POPULATE = 2;				// Cache miss - Populate cache line
	localparam STATE_WRITEOUT = 3;			// Writes out dirty cache lines
	

	// Counters
	integer i;
	reg [8:0] Gen_Count;						// General counter

		// Hardwired assignments
	assign o_Ready = (State==STATE_READY);
	
	assign debug = 0;//(i_Index == 9'h1c3);
	
	wire populate = (r_i_Read_Write_n == WRITE) && i_MEM_Valid && (Gen_Count == r_i_BlockOffset) && (State == STATE_POPULATE);
	wire [DATA_WIDTH-1:0] Populate_Data = populate ? r_i_Write_Data : i_MEM_Data;
	
	// TODO adjust for n-way associativity
	wire cache_hit = i_Valid && Valid_Array[i_Index] && (Tag_Array[i_Index] == i_Tag) && !o_Valid;
	wire cache_read_hit = cache_hit && (i_Read_Write_n == READ)&& (State == STATE_READY);
	wire cache_write_hit =  cache_hit && (i_Read_Write_n == WRITE) && (State == STATE_READY);
	wire cache_miss = !cache_hit && i_Valid && !o_Valid;
	wire valid_read = (r_i_Read_Write_n == READ) && o_Valid;
	
	
	//async config for 1 cycle write hits
	wire w_bank0we = cache_write_hit && (i_BlockOffset == 0)  || bank0we;
	wire w_bank1we = cache_write_hit && (i_BlockOffset == 1)  || bank1we;
	wire w_bank2we = cache_write_hit && (i_BlockOffset == 2)  || bank2we;
	wire w_bank3we = cache_write_hit && (i_BlockOffset == 3)  || bank3we;
	wire [DATA_WIDTH-1:0] w_bank0writedata = cache_write_hit ? i_Write_Data : bank0writedata;
	wire [DATA_WIDTH-1:0] w_bank1writedata = cache_write_hit ? i_Write_Data : bank1writedata;
	wire [DATA_WIDTH-1:0] w_bank2writedata = cache_write_hit ? i_Write_Data : bank2writedata;
	wire [DATA_WIDTH-1:0] w_bank3writedata = cache_write_hit ? i_Write_Data : bank3writedata;
	
	//mux for async read hit outputs correctly on next cycle
	assign o_Data = r_i_BlockOffset == 0 ? bank0readdata :
					r_i_BlockOffset == 1 ? bank1readdata :
					r_i_BlockOffset == 2 ? bank2readdata :
					r_i_BlockOffset == 3 ? bank3readdata :
					r_o_Data; //STATE POPULATE
	

	wire [INDEX_WIDTH-1:0] bank_Index = (State == STATE_READY) ? i_Index : r_i_Index;
	
	// TODO Add associativity size parameter
	cache_bank #(
					.INDEX_WIDTH(INDEX_WIDTH)
				)
				databank 
				(	// Inputs
					.i_Clk(i_Clk),
					.i_address(bank_Index),
					.i_writedata(w_bank0writedata),
					.i_we(w_bank0we),
					
					// Outputs
					.o_readdata(bank0readdata)
					
				);
		
	cache_bank #(
					.INDEX_WIDTH(INDEX_WIDTH)
				)
				databank1 
				(	// Inputs
					.i_Clk(i_Clk),
					.i_address(bank_Index),
					.i_writedata(w_bank1writedata),
					.i_we(w_bank1we),
					
					// Outputs
					.o_readdata(bank1readdata)
				);
				
	cache_bank #(
					.INDEX_WIDTH(INDEX_WIDTH)
				)
				databank2 
				(	// Inputs
					.i_Clk(i_Clk),
					.i_address(bank_Index),
					.i_writedata(w_bank2writedata),
					.i_we(w_bank2we),
					
					// Outputs
					.o_readdata(bank2readdata)
				);
				
	cache_bank #(
					.INDEX_WIDTH(INDEX_WIDTH)
				)
				databank3 
				(	// Inputs
					.i_Clk(i_Clk),
					.i_address(bank_Index),
					.i_writedata(w_bank3writedata),
					.i_we(w_bank3we),
					
					// Outputs
					.o_readdata(bank3readdata)
				);
	
always @(posedge i_Clk or negedge i_Reset_n)
	begin

	/*
		if (i_Valid && i_Read_Write_n && o_Valid && DebugMemory[i_Address] != o_Data)
			$display("Invalid DCache read at %x value is %x expected ", i_Address, o_Data, DebugMemory[i_Address]);
		else if (i_Valid && !i_Read_Write_n)
		begin
			DebugMemory[i_Address] <= i_Write_Data;
			$display("DCache write at %x value is %x", i_Address, i_Write_Data);
		end
		*/
		
		// Asynch. reset
		if( !i_Reset_n )
		begin
			State <= STATE_READY;
			o_MEM_Valid <= FALSE;
		end else begin
			bank0we <= FALSE;
			bank1we <= FALSE;
			bank2we <= FALSE;
			bank3we <= FALSE;
			finished_populate <= FALSE;
			o_Valid <= FALSE;
			case(State)
				STATE_READY: begin
					if(cache_read_hit) begin
					  r_i_Read_Write_n <= READ;
						o_Valid <= TRUE;
						r_i_BlockOffset <= i_BlockOffset;
						if(debug)						
							$display("read hit %x outputs %x", i_Address, r_o_Data);
					end else if(cache_write_hit) begin
						//Write hit!!
						r_i_Read_Write_n <= WRITE;
						o_Valid <= TRUE;
						// TODO adjust i_index for n-way associativity
						Dirty_Array[i_Index] <= TRUE;
						/*
						o_Data <= 0;
						case( i_BlockOffset )
							0:	Data_Array[i_Index][(DATA_WIDTH*1)-1:0] <= i_Write_Data;
							1:	Data_Array[i_Index][(DATA_WIDTH*2)-1:(DATA_WIDTH*1)] <= i_Write_Data;
							2:	Data_Array[i_Index][(DATA_WIDTH*3)-1:(DATA_WIDTH*2)] <= i_Write_Data;
							3:	Data_Array[i_Index][(DATA_WIDTH*4)-1:(DATA_WIDTH*3)] <= i_Write_Data;
							default:	$display("Warning: Invalid Gen Count value @ d_cache");						
						endcase */
						if(debug)
							$display("write hit %x to %x", i_Write_Data, i_Address);
					end else if(cache_miss) begin // miss
						//prepare registers
						r_i_Address <= i_Address;
						r_i_BlockOffset <= i_BlockOffset;
						r_i_Index <= i_Index;
						r_i_Tag <= i_Tag;
						r_i_Write_Data <= i_Write_Data;
						r_i_Read_Write_n <= i_Read_Write_n;
						o_MEM_Valid <= TRUE;
						//if the cache line isnt dirty just populate
						// TODO fix if-else statement to case statement
						if(!Valid_Array[i_Index] || !Dirty_Array[i_Index]) begin
							Gen_Count <= 0;
							State <= STATE_POPULATE;
							o_MEM_Read_Write_n <= READ;
							o_MEM_Address <= {i_Tag,i_Index,{BLOCK_OFFSET_WIDTH+1{1'b0}}};
							if(debug)
								$display("read miss on address %x", i_Address);
						end else if(Dirty_Array[i_Index]) begin
							//if its dirty write it to mem before populating!
							Gen_Count <= 0;
							State <= STATE_WRITEOUT;
							o_MEM_Address <= {Tag_Array[i_Index],i_Index,{BLOCK_OFFSET_WIDTH+1{1'b0}}};	
							if(debug)
								$display("write miss %x to %x", i_Write_Data, i_Address);
						end
					end
				end
				STATE_WRITEOUT: begin //State == 3
					o_MEM_Read_Write_n <= WRITE;
					//o_MEM_Data <= bank0readdata;
					//Gen_Count <= 1;
					if(i_MEM_Data_Read) begin
						case( Gen_Count )
							0:	o_MEM_Data <= bank1readdata; //load next bank
							1:	o_MEM_Data <= bank2readdata;
							2:	o_MEM_Data <= bank3readdata;
							3:	o_MEM_Data <= bank3readdata;		// keep displaying last one
							default:	$display("Warning: Invalid Gen Count value @ d_cache writeout");
						endcase
						
						if(i_MEM_Last) begin
							Gen_Count <= 0;
							State <= STATE_POPULATE;
							o_MEM_Valid <= TRUE;
							o_MEM_Address <= {r_i_Tag,r_i_Index,{BLOCK_OFFSET_WIDTH+1{1'b0}}};
							o_MEM_Read_Write_n <= READ;								
							Dirty_Array[r_i_Index] <= FALSE;	// Cache line was cleaned
						end else begin
							Gen_Count <= Gen_Count + 9'd1;
						end
					end
					else
					begin
						if (Gen_Count == 0)  o_MEM_Data <= bank0readdata;
					end
				end
				STATE_POPULATE: begin //State == 2
					if( i_MEM_Valid ) begin
						case( Gen_Count )
							//populate data will = r_i_Data if we are writing and on the right gen count
							//otherwise it will just be i_MEM_Data
								0:	begin
									bank0writedata <= Populate_Data;
									bank0we <= 1;
									end
								1:	begin
									bank1writedata <= Populate_Data;
									bank1we <= 1;
									end
								2:	begin
									bank2writedata <= Populate_Data;
									bank2we <= 1;
									end
								3:	begin
									bank3writedata <= Populate_Data;
									bank3we <= 1;
									end
							default:	$display("Warning: Invalid Gen Count value @ d_cache");
						endcase
						
						
			
						if((Gen_Count == r_i_BlockOffset) && (r_i_Read_Write_n == READ)) begin
							r_o_Data <= Populate_Data;
							if(debug)
								$display("Populate address %h data is %h", r_i_Address, Populate_Data);
						end
						// Account for the input
						Gen_Count <= Gen_Count + 9'd1;
					
						// If we're about to finish...
						if( i_MEM_Last )
						begin
							// TODO add associativity index
							// Record info about transaction in tags & valid bits
							Tag_Array[r_i_Index] <= r_i_Tag;
							Valid_Array[r_i_Index] <= TRUE;
							o_MEM_Valid <= FALSE;
							if( r_i_Read_Write_n == WRITE )
								Dirty_Array[r_i_Index] <= TRUE;
							else
								Dirty_Array[r_i_Index] <= FALSE;
							//tell that cache is ready
							State <= STATE_PAUSE;
							r_i_BlockOffset <= 4;
						end
					end
				end
				STATE_PAUSE: begin
					o_Valid <= TRUE;
					State <= STATE_READY;
				end
			endcase
		end
	end
							
	initial
	begin
		// Mark everything as invalid
//		debug <= 0;
		finished_populate <= FALSE;
		// TODO include associativity indices
		for(i=0;i<(1<<INDEX_WIDTH);i=i+1)
		begin
			Valid_Array[i] = FALSE;
			Dirty_Array[i] = FALSE;
		end
	end
	
endmodule

module cache_bank #(	
					parameter DATA_WIDTH = 32,
					parameter TAG_WIDTH = 10,
					parameter INDEX_WIDTH = 9,  //512 sets
					parameter BLOCK_OFFSET_WIDTH = 2,  //4 words per block
					parameter MEM_MASK_WIDTH = 3
				)
	(o_readdata, i_address, i_writedata, i_we, i_Clk);
   output reg [DATA_WIDTH-1:0] o_readdata;
   input [DATA_WIDTH-1:0] i_writedata;
   input [INDEX_WIDTH-1:0] i_address;
   input i_we, i_Clk;
   reg [DATA_WIDTH-1:0] mem [0:(1<<INDEX_WIDTH)-1];
    always @(posedge i_Clk) begin
        if (i_we)
            mem[i_address] <= i_writedata;
        o_readdata <= mem[i_address];
   end
endmodule