/* decoder.v
* Author: Pravin P. Prabhu
* Last Revision: 1/5/11
* Abstract:
*	Provides decoding of instructions to control signals.
*/
module decoder	#(
					parameter ADDRESS_WIDTH = 32,
					parameter DATA_WIDTH = 32,
					parameter REG_ADDRESS_WIDTH = 5,
					parameter ALUCTL_WIDTH = 8,
					parameter MEM_MASK_WIDTH = 3,
					parameter DEBUG = 0
				)
				(	// Inputs
					input [ADDRESS_WIDTH-1:0] i_PC,
					input [DATA_WIDTH-1:0] i_Instruction,
					input i_Stall,	// Not actually used for logic -- used in debugging statements
					
					// Outputs
					
					// Control signals
					output reg o_Uses_ALU,
					output reg [ALUCTL_WIDTH-1:0] o_ALUCTL,
					output reg o_Is_Branch,
					output reg [ADDRESS_WIDTH-1:0] o_Branch_Target,
					output reg o_Jump_Reg,
					
					output reg o_Mem_Valid,
					output reg [MEM_MASK_WIDTH-1:0] o_Mem_Mask,
					output reg o_Mem_Read_Write_n,
					
					output reg o_Uses_RS,
					output reg [REG_ADDRESS_WIDTH-1:0] o_RS_Addr,
					output reg o_Uses_RT,
					output reg [REG_ADDRESS_WIDTH-1:0] o_RT_Addr,
					
					output reg o_Uses_Immediate,
					output reg [DATA_WIDTH-1:0] o_Immediate,
					
					output reg o_Writes_Back,
					output reg [REG_ADDRESS_WIDTH-1:0] o_Write_Addr
				);
				
	// Constants
		// T/F
	localparam TRUE = 1'b1;
	localparam FALSE = 1'b0;
	
	localparam READ = 1'b1;
	localparam WRITE = 1'b0;
	
	localparam ALUCTL_NOP = 8'd0;				// No Operation (noop)
	localparam ALUCTL_ADD = 8'd1;					// Add (signed)
	localparam ALUCTL_ADDU = 8'd2;				// Add (unsigned)
	localparam ALUCTL_SUB = 8'd3;					// Subtract (signed)
	localparam ALUCTL_SUBU = 8'd4;				// Subtract (unsigned)
	localparam ALUCTL_AND = 8'd5;					// AND
	localparam ALUCTL_OR = 8'd6;				// OR
	localparam ALUCTL_XOR = 8'd7;					// XOR
	localparam ALUCTL_SLT = 8'd8;				// Set on Less Than
	localparam ALUCTL_SLTU = 8'd9;					// Set on Less Than (unsigned)
	localparam ALUCTL_SLL = 8'd10;				// Shift Left Logical
	localparam ALUCTL_SRL = 8'd11;					// Shift Right Logical
	localparam ALUCTL_SRA = 8'd12;				// Shift Right Arithmetic
	localparam ALUCTL_SLLV = 8'd13;				// Shift Left Logical Variable
	localparam ALUCTL_SRLV = 8'd14;			// Shift Right Logical Variable
	localparam ALUCTL_SRAV = 8'd15;				// Shift Right Arithmetic Variable
	localparam ALUCTL_NOR = 8'd16;				// NOR
	localparam ALUCTL_LUI = 8'd17;					// Load Upper Immediate
	localparam ALUCTL_MTCO_PASS = 8'd18;		// Move to Coprocessor (PASS)
	localparam ALUCTL_MTCO_FAIL = 8'd19;			// Move to Coprocessor (FAIL)
	localparam ALUCTL_MTCO_DONE = 8'd20;		// Move to Coprocessor (DONE)

	localparam ALUCTL_BA = 8'd32;			// Unconditional branch
	localparam ALUCTL_BEQ = 8'd33;
	localparam ALUCTL_BNE = 8'd34;
	localparam ALUCTL_BLEZ = 8'd35;
	localparam ALUCTL_BGTZ = 8'd36;
	localparam ALUCTL_BGEZ = 8'd37;
	localparam ALUCTL_BLTZ = 8'd38;
	
	localparam ALUCTL_J = 8'd64;
	localparam ALUCTL_JAL = 8'd65;
	localparam ALUCTL_JR = 8'd66;
	localparam ALUCTL_JALR = 8'd67;
	
		// Combinatorial logic - Obtain control signals
	always @(*)
	begin
		// Set defaults to avoid latch inference
		o_Uses_ALU <= FALSE;
		o_ALUCTL <= ALUCTL_NOP;
		o_Is_Branch <= FALSE;
		o_Branch_Target <= 0;
		o_Jump_Reg <= FALSE;
		o_Mem_Valid <= FALSE;
		o_Mem_Read_Write_n <= READ;
		o_Uses_RS <= FALSE;
		o_RS_Addr <= 0;
		o_Uses_RT <= FALSE;
		o_RT_Addr <= 0;
		o_Uses_Immediate <= FALSE;
		o_Immediate <= 0;
		o_Writes_Back <= FALSE;
		o_Write_Addr <= 0;
		o_Mem_Mask <= 0;
		
		case(i_Instruction[31:26])
		6'h0:  //r-type
		begin

			case (i_Instruction[5:0])
				6'h20: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;
					o_ALUCTL <= ALUCTL_ADD; 	// add
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
				end
				
				6'h21: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;
					o_ALUCTL <= ALUCTL_ADDU;	// addu
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
				end
				
				6'h22: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SUB;	// sub
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];					
				end
				
				6'h23: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SUBU;	// subu
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];					
				end
				
				6'h24: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_AND;	// and
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
				end
				
				6'h25: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_OR;	// or
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
				end
				
				6'h26: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_XOR;	// xor
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
				end
				
				6'h27: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_NOR;	// nor
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
				end
				
				6'h00: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SLL;  // sll
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
					o_Uses_Immediate <= TRUE;
					o_Immediate <= {{27{1'b0}},i_Instruction[10:6]};
				end
				
				6'h02: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SRL;  // srl
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
					o_Uses_Immediate <= TRUE;
					o_Immediate <= {{27{1'b0}},i_Instruction[10:6]};
				end
				
				6'h03: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SRA;  // sra
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];
					o_Uses_Immediate <= TRUE;
					o_Immediate <= {{27{1'b0}},i_Instruction[10:6]};
				end
				
				6'h04: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SLLV;  // sllv
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];					
				end
				
				6'h06: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SRLV;  // srlv
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];					
				end
				
				6'h07: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SRAV;  // srav
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];							
				end
				
				6'h2a: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SLT;	// slt
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];							
				end
				
				6'h2b: 
				begin
					o_Uses_ALU <= TRUE;
					o_Writes_Back <= TRUE;				
					o_ALUCTL <= ALUCTL_SLTU;	// sltu
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Uses_RT <= TRUE;
					o_RT_Addr <= i_Instruction[20:16];
					o_Write_Addr <= i_Instruction[15:11];							
				end
				
				6'h08: 	// JR
				begin
					o_Is_Branch <= TRUE;
					o_Uses_ALU <= TRUE;
					o_ALUCTL <= ALUCTL_JR;
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Jump_Reg <= TRUE;
					if( !i_Stall && DEBUG )
						$display("%x: %x (Jump Register)",i_PC,i_Instruction);
				end
				
				6'h09: 
				begin  //jalr
					o_Is_Branch <= TRUE;
					o_Uses_ALU <= TRUE;
					o_ALUCTL <= ALUCTL_JR;
					o_Uses_RS <= TRUE;
					o_RS_Addr <= i_Instruction[25:21];
					o_Jump_Reg <= TRUE;
					o_Uses_Immediate <= TRUE;
					o_Immediate <= (i_PC + 2);
					o_Writes_Back <= TRUE;
					o_Write_Addr <= 31;			// Jump And Link always stores the PC into reg 31.
					if( !i_Stall && DEBUG )
						$display("%x: %x (Jump and Link Register)",i_PC,i_Instruction);
				end
					
				6'h18:  // mul
				begin
					if( !i_Stall && DEBUG )
						$display("Multiply is unsupported");
					//o_Uses_ALU <= TRUE;
					//o_Writes_Back <= TRUE;				
					//o_ALUCTL <= ALUCTL_NOP;	
				end
				
				6'h19:  //mulu
				begin
					if( !i_Stall && DEBUG )
						$display("Multiply Unsigned is unsupported");
					//o_Uses_ALU <= TRUE;
					//o_Writes_Back <= TRUE;				
					//o_ALUCTL <= ALUCTL_NOP;
				end
				
				6'h1a:  //div
				begin
					if( !i_Stall && DEBUG )
						$display("Divide is unsupported");
					//o_Uses_ALU <= TRUE;
					//o_Writes_Back <= TRUE;				
					//o_ALUCTL <= ALUCTL_NOP;
				end
				
				6'h1b:  //divu
				begin
					if( !i_Stall && DEBUG )
						$display("Divide Unsigned is unsupported");
					//o_Uses_ALU <= TRUE;
					//o_Writes_Back <= TRUE;				
					//o_ALUCTL <= ALUCTL_NOP;
				end
				
				default:
				begin
					if( !i_Stall && DEBUG )
						$display("illegal i_Instruction[5:0] code %b\n", i_Instruction[5:0]);
				end
			endcase
		end
		
		6'h08:  		//addi
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_ADD;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;			
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
		end
		
		6'h09:  //addiu
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_ADDU;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;			
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
		end	
		
		6'h0c:  //andi
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_AND;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{1'b0}},i_Instruction[15:0]};
		end							
	
		6'h0d:  //ori
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_OR;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{1'b0}},i_Instruction[15:0]};
		end			
		
		6'h0e:  //xori
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_XOR;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{1'b0}},i_Instruction[15:0]};
		end			

		6'h0a:  //slti
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_SLT;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
		end			

		6'h0b:  //sltiu
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_SLTU;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
		end	

		6'h0f:  //lui
		begin
			o_Uses_ALU <= TRUE;
			o_Writes_Back <= TRUE;				
			o_ALUCTL <= ALUCTL_OR;					// Implemented as A = 0 | Immediate
			o_RS_Addr <= 0;
			o_Write_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {i_Instruction[15:0],{16{1'b0}}};
		end			
		
		6'h04:  //beq
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];
			o_ALUCTL <= ALUCTL_BEQ;
			o_Branch_Target <= i_PC + 22'd1 + {{(ADDRESS_WIDTH-16){i_Instruction[15]}},i_Instruction[15:0]};
			if( !i_Stall && DEBUG )
				$display("%x: %x (Branch on Equal)",i_PC,i_Instruction);
		end

		6'h05:  //bne
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];			
			o_ALUCTL <= ALUCTL_BNE;
			o_Branch_Target <= i_PC + 22'd1 + {{(ADDRESS_WIDTH-16){i_Instruction[15]}},i_Instruction[15:0]};
			if( !i_Stall && DEBUG )
				$display("%x: %x (Branch on Not Equal)",i_PC,i_Instruction);
		end

		6'h06:  //blez
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];			
			o_ALUCTL <= ALUCTL_BLEZ;
			o_Branch_Target <= i_PC + 22'd1 + {{(ADDRESS_WIDTH-16){i_Instruction[15]}},i_Instruction[15:0]};
			if( !i_Stall && DEBUG )
				$display("%x: %x (Branch on Less or Equal)",i_PC,i_Instruction);
		end

		6'h01:  //bgez or bltz
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];			
			if( i_Instruction[16] )
			begin
				o_ALUCTL <= ALUCTL_BGEZ;
				if( !i_Stall && DEBUG )
					$display("%x: %x (Branch on Greater or Equal)",i_PC,i_Instruction);
			end
			else
			begin
				o_ALUCTL <= ALUCTL_BLTZ;
				if( !i_Stall && DEBUG )
					$display("%x: %x (Branch on Less or Equal)",i_PC,i_Instruction);
			end
			//o_ALUCTL <= i_Instruction[16]? ALUCTL_BGEZ: ALUCTL_BLTZ;  // 1 <=> bgez : 0 <=> bltz	
			o_Branch_Target <= i_PC + 22'd1 + {{(ADDRESS_WIDTH-16){i_Instruction[15]}},i_Instruction[15:0]};		
		end
		
		6'h07:  //bgtz
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];			
			o_ALUCTL <= ALUCTL_BGTZ;
			o_Branch_Target <= i_PC + 22'd1 + {{(ADDRESS_WIDTH-16){i_Instruction[15]}},i_Instruction[15:0]};
			if( !i_Stall && DEBUG )
				$display("%x: %x (Branch on Greater)",i_PC,i_Instruction);
		end				

		6'h02:  // j
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_J;
			//o_Branch_Target <= {i_PC[31:26],i_Instruction[25:0]};
			o_Branch_Target <= i_Instruction[21:0];
			if( !i_Stall && DEBUG )
				$display("%x: %x (Jump)",i_PC,i_Instruction);
		end

		6'h03:  // jal
		begin
			o_Is_Branch <= TRUE;
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_JAL;
			//o_Branch_Target <= {i_PC[31:26],i_Instruction[25:0]};
			o_Branch_Target <= i_Instruction[21:0];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= (i_PC + 2);
			o_Writes_Back <= TRUE;
			o_Write_Addr <= 31;			// Jump And Link always stores the PC into reg 31.
			if( !i_Stall && DEBUG )
				$display("%x: %x (Jump and Link)",i_PC,i_Instruction);
		end
		
		6'h20: //lb
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= READ;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Writes_Back <= TRUE;
			o_Write_Addr <= i_Instruction[20:16];
			o_Mem_Mask <= 0;
		end
		
		6'h24: //lbu
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= READ;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Writes_Back <= TRUE;
			o_Write_Addr <= i_Instruction[20:16];
			o_Mem_Mask <= 1;
		end

		6'h21: //lh
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= READ;
			o_Uses_Immediate <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Writes_Back <= TRUE;
			o_Write_Addr <= i_Instruction[20:16];
			o_Mem_Mask <= 2;
		end

		6'h25: //lhu
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= READ;
			o_Uses_Immediate <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Writes_Back <= TRUE;
			o_Write_Addr <= i_Instruction[20:16];
			o_Mem_Mask <= 3;
		end
	
		6'h23: //lw
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= READ;
			o_Uses_Immediate <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Writes_Back <= TRUE;
			o_Write_Addr <= i_Instruction[20:16];
			o_Mem_Mask <= 4;
		end

		6'h28:  //sb
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= WRITE;
			o_Uses_Immediate <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Mem_Mask <= 0;
		end

		6'h29:  //sh
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= WRITE;
			o_Uses_Immediate <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Mem_Mask <= 2;
		end

		6'h2b:  //sw
		begin
			o_Uses_ALU <= TRUE;
			o_ALUCTL <= ALUCTL_ADD;
			o_Mem_Valid <= TRUE;
			o_Mem_Read_Write_n <= WRITE;
			o_Uses_Immediate <= TRUE;
			o_Uses_RS <= TRUE;
			o_RS_Addr <= i_Instruction[25:21];
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];
			o_Uses_Immediate <= TRUE;
			o_Immediate <= {{16{i_Instruction[15]}},i_Instruction[15:0]};
			o_Mem_Mask <= 4;
		end

		6'h10:  //mtc0
		begin
			
			o_Uses_ALU <= TRUE;
			o_Uses_RT <= TRUE;
			o_RT_Addr <= i_Instruction[20:16];
			casex(i_Instruction[15:11])
				5'h17:	
				begin
					o_ALUCTL <= ALUCTL_MTCO_PASS;
					if( !i_Stall && DEBUG )
						$display("%x: %x (MTC0 Pass)",i_PC,i_Instruction);
				end
				
				5'h18:	
				begin
					o_ALUCTL <= ALUCTL_MTCO_FAIL;
					if( !i_Stall && DEBUG )
						$display("%x: %x (MTC0 Fail)",i_PC,i_Instruction);
				end
				
				5'h19:	
				begin
					o_ALUCTL <= ALUCTL_MTCO_DONE;
					if( !i_Stall && DEBUG )
						$display("%x: %x (MTC0 Done)",i_PC,i_Instruction);
				end
				
				default:
				begin
					o_ALUCTL <= ALUCTL_NOP;
					$display("%t Invalid MTC0 value %X",$realtime, i_Instruction[15:11]);
				end
			endcase
		end

		default:
		begin
			// synthesis translate_off
			if( !i_Stall && DEBUG )
				$display("illegal i_Instruction[31:26] %b\n", i_Instruction[31:26]);
			// synthesis translate_on
		end
	endcase
end				

endmodule
