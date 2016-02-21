/* ALU.v
* Author: Pravin P. Prabhu
* Last Revision: 1/5/11
* Abstract:
*	Provides functions of the arithmetic logic unit, including calculations and
* branch resolution.
*/
module alu	#(
				parameter DATA_WIDTH = 32,
				parameter CTLCODE_WIDTH = 8
			)
			(	// Inputs
				input i_Valid,							// Whether input to ALU is valid
				input [CTLCODE_WIDTH-1:0] i_ALUCTL,
				input signed [DATA_WIDTH-1:0] i_Operand1,
				input signed [DATA_WIDTH-1:0] i_Operand2,
				
				// Outputs
				output reg o_Valid,
				output reg [DATA_WIDTH-1:0] o_Result,		// The computational result
				output reg o_Branch_Valid,
				output reg o_Branch_Outcome,			// The branch result
				output reg [15:0] o_Pass_Done_Value,		// reports the value of a PASS/FAIL/DONE instruction
				output reg [1:0] o_Pass_Done_Change		// indicates the above signal is meaningful
														// 1 = pass, 2 = fail, 3 = done
			);
	
// Constants
localparam ALUCTL_NOP = 0;				// No Operation (noop)
localparam ALUCTL_ADD = 1;					// Add (signed)
localparam ALUCTL_ADDU = 2;				// Add (unsigned)
localparam ALUCTL_SUB = 3;					// Subtract (signed)
localparam ALUCTL_SUBU = 4;				// Subtract (unsigned)
localparam ALUCTL_AND = 5;					// AND
localparam ALUCTL_OR = 6;				// OR
localparam ALUCTL_XOR = 7;					// XOR
localparam ALUCTL_SLT = 8;				// Set on Less Than
localparam ALUCTL_SLTU = 9;					// Set on Less Than (unsigned)
localparam ALUCTL_SLL = 10;				// Shift Left Logical
localparam ALUCTL_SRL = 11;					// Shift Right Logical
localparam ALUCTL_SRA = 12;				// Shift Right Arithmetic
localparam ALUCTL_SLLV = 13;				// Shift Left Logical Variable
localparam ALUCTL_SRLV = 14;			// Shift Right Logical Variable
localparam ALUCTL_SRAV = 15;				// Shift Right Arithmetic Variable
localparam ALUCTL_NOR = 16;				// NOR
localparam ALUCTL_LUI = 17;					// Load Upper Immediate
localparam ALUCTL_MTCO_PASS = 18;		// Move to Coprocessor (PASS)
localparam ALUCTL_MTCO_FAIL = 19;			// Move to Coprocessor (FAIL)
localparam ALUCTL_MTCO_DONE = 20;		// Move to Coprocessor (DONE)

localparam ALUCTL_BA = 32;			// Unconditional branch
localparam ALUCTL_BEQ = 33;
localparam ALUCTL_BNE = 34;
localparam ALUCTL_BLEZ = 35;
localparam ALUCTL_BGTZ = 36;
localparam ALUCTL_BGEZ = 37;
localparam ALUCTL_BLTZ = 38;

localparam ALUCTL_J = 64;
localparam ALUCTL_JAL = 65;
localparam ALUCTL_JR = 66;
localparam ALUCTL_JALR = 67;

	// MTC0 codes - Did we pass/fail a test or reach the done state?
localparam MTC0_NOOP = 2'd0;		// No significance
localparam MTC0_PASS = 2'd1;			// Passed a test
localparam MTC0_FAIL = 2'd2;		// Failed a test
localparam MTC0_DONE = 2'd3;			// Have completed execution
	
	// Combinatorial logic - Compute ALU results asynchronously
always @(*)
begin
	// Default outputs to 0, assign them in case if need be
	o_Valid <= 0;
	o_Result <= {DATA_WIDTH{1'b0}};
	o_Branch_Valid <= 1'b0;
	o_Branch_Outcome <= 1'b0;
	o_Pass_Done_Value <= 16'b0;
	o_Pass_Done_Change <= MTC0_NOOP;							
	
	// Only act upon input if it's valid
	if( i_Valid )
	begin
		o_Valid <= 1'b1;
		
		// Case: Which opcode are we looking at? What operands do we use?
		// Produce o_Result. Also, resolve branches.
		case ( i_ALUCTL ) 
			ALUCTL_ADD: 
			begin
				o_Result <= i_Operand1 + i_Operand2;  // add
			end
			
			ALUCTL_ADDU: 
			begin
				o_Result <= i_Operand1 + i_Operand2;  // add unsigned, ignoring overflow
			end
			
			ALUCTL_SUB:
			begin
				o_Result <= i_Operand1 - i_Operand2;  // sub
			end
			
			ALUCTL_SUBU: 
			begin
				o_Result <= i_Operand1 - i_Operand2;  // sub unsigned, ignoring overflow
			end
			
			ALUCTL_AND: 
			begin
				o_Result <= i_Operand1 & i_Operand2;  // and
			end
			
			ALUCTL_OR:
			begin
				o_Result <= i_Operand1 | i_Operand2;  // or
			end
			
			ALUCTL_XOR: 
			begin
				o_Result <= i_Operand1 ^ i_Operand2;  // xor
			end
			
			ALUCTL_SLT: 
			begin
				o_Result <= $signed(i_Operand1) < $signed(i_Operand2);
				//(i_Operand1 < i_Operand2);   //slt
			end
			
			ALUCTL_SLTU: 
			begin
				o_Result <= {1'b0,i_Operand1} < {1'b0,i_Operand2}; // sltu
			end
			
			ALUCTL_SLL:
			begin
				o_Result <= i_Operand1 << $unsigned(i_Operand2);  // sll
			end
			
			ALUCTL_SRL: 
			begin
				o_Result <= i_Operand1 >> $unsigned(i_Operand2);  // srl
			end
			
			ALUCTL_SRA: 
			begin
				o_Result <= i_Operand1 >>> $unsigned(i_Operand2);  // sra
			end
			
			ALUCTL_SLLV: 
			begin
				o_Result <= i_Operand2 << i_Operand1[4:0];  // sllv	
			end
			
			ALUCTL_SRLV: 
			begin
				o_Result <= i_Operand2 >> i_Operand1[4:0];  // srlv
			end
			
			ALUCTL_SRAV: 
			begin
				o_Result <= i_Operand2 >>> i_Operand1[4:0];  // srav
			end
			
			ALUCTL_NOR: 
			begin
				o_Result <= ~(i_Operand1 | i_Operand2);  // nor
			end
			
			ALUCTL_LUI: 
			begin
				o_Result <= {i_Operand2[15:0],16'h0000};  //lui
			end

			ALUCTL_MTCO_PASS:   // MTC0 -- redefined for our purposes.
			begin
				$display("PASS test %x\n", i_Operand2);
				o_Pass_Done_Change <= MTC0_PASS;
				o_Pass_Done_Value <= i_Operand2[15:0];
			end
			
			ALUCTL_MTCO_FAIL:
			begin
				$display("FAIL test %x\n", i_Operand2);
				o_Pass_Done_Change <= MTC0_FAIL;
				o_Pass_Done_Value <= i_Operand2[15:0];				
			end
			
			ALUCTL_MTCO_DONE:
			begin
				$display("DONE test %x\n", i_Operand2);
				o_Pass_Done_Change <= MTC0_DONE;
				o_Pass_Done_Value <= i_Operand2[15:0];
			end
			
			//=========================
			// Branches
			ALUCTL_BA:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= 1;
			end
			
			ALUCTL_BEQ:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= (i_Operand1 == i_Operand2);
			end
			
			ALUCTL_BNE:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= (i_Operand1 != i_Operand2);
			end

			ALUCTL_BLEZ:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= (i_Operand1[DATA_WIDTH-1] || (i_Operand1==0));
			end
			
			ALUCTL_BGTZ:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= (!i_Operand1[DATA_WIDTH-1] && (i_Operand1!=0));
			end
			
			ALUCTL_BGEZ:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= (!i_Operand1[DATA_WIDTH-1]);
			end
			
			ALUCTL_BLTZ:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= (i_Operand1[DATA_WIDTH-1]);
			end
			
			//===========
			// Jumps
			ALUCTL_J:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= 1;
			end

			ALUCTL_JR:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= 1;
			end			
			
			ALUCTL_JAL:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= 1;
				o_Result <= i_Operand2;
			end	

			ALUCTL_JALR:
			begin
				o_Branch_Valid <= 1;
				o_Branch_Outcome <= 1;
				o_Result <= i_Operand2;				
			end						
			
			default: 
			begin
				// synthesis translate_off
				$display("%x:illegal ALU ctl code %b\n", 0, i_ALUCTL);
				// synthesis translate_on
			end
		endcase
	end
end
			
endmodule
