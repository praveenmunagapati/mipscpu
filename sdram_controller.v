/* sdram_controller.v
* Author: Todor Mollov
* Last Revision: 1/11/11
* Abstract:
*	Provides a high level interface to the SDRAM on the board. Provides
* four words in a burst per read/write request (and thus works nicely with
* caches).
*/
module sdram_controller
#(
	parameter ROW_ADDR_WIDTH = 12,
	parameter BANK_ADDR_WIDTH = 2,
	parameter COL_ADDR_WIDTH = 8,
	parameter DATA_WIDTH = 16
)

(
	input i_Clk,
	input i_Reset,
	
	// Request interface
	input [ROW_ADDR_WIDTH+BANK_ADDR_WIDTH+COL_ADDR_WIDTH-1:0] i_Addr,
	input i_Req_Valid,
	input i_Read_Write_n,
	
	// Write input data interface
	input [31:0] i_Data,
	output reg o_Data_Read,
	
	// Read data output interface
	output reg [31:0] o_Data,
	output reg o_Data_Valid,
	
	// output
	output reg o_Last,
	
	// SDRAM interface
	inout     [DATA_WIDTH - 1 : 0] b_Dq,
    output reg [ROW_ADDR_WIDTH - 1 : 0] o_Addr,
    output reg [BANK_ADDR_WIDTH-1 : 0] o_Ba,
    output                             o_Clk,
    output reg                         o_Cke,
    output reg                         o_Cs_n,
    output reg                         o_Ras_n,
    output reg                         o_Cas_n,
    output reg                         o_We_n,
    output reg  [DATA_WIDTH/8 - 1 : 0] o_Dqm
);

assign o_Clk = i_Clk;

reg [DATA_WIDTH -1 : 0] DQ;
reg DQ_Drive;

reg [COL_ADDR_WIDTH-1:0] ColAddr;
reg [BANK_ADDR_WIDTH-1:0] BankAddr;

assign b_Dq = DQ_Drive ? DQ : {DATA_WIDTH{1'bz}};

// define tasks for operations

task active;
    input  [1 : 0] bank;
    input [11 : 0] row;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 0;
        o_Cas_n <= 1;
        o_We_n  <= 1;
        o_Ba    <= bank;
        o_Addr  <= row;
        DQ    <= {DATA_WIDTH{1'bx}};
        DQ_Drive <= 0;
    end
endtask

task auto_refresh;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 0;
        o_Cas_n <= 0;
        o_We_n  <= 1;
        //o_Ba    <= 0;
        //o_Addr  <= 0;
        DQ    <= {DATA_WIDTH{1'bx}};
        DQ_Drive <= 0;
    end
endtask

task load_mode_reg;
    input [13 : 0] op_code;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 0;
        o_Cas_n <= 0;
        o_We_n  <= 0;
        o_Ba    <= op_code [13 : 12];
        o_Addr  <= op_code [11 :  0];
        DQ    <= {DATA_WIDTH{1'bx}};
        DQ_Drive <= 0;
    end
endtask

task nop;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 1;
        o_Cas_n <= 1;
        o_We_n  <= 1;
        //o_Ba    <= 0;
        //o_Addr  <= 0;
        DQ    <= {DATA_WIDTH{1'bx}};
        DQ_Drive <= 0;
    end
endtask

task precharge_all_bank;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 0;
        o_Cas_n <= 1;
        o_We_n  <= 0;
        o_Ba    <= 0;
        o_Addr  <= 1024;            // A10 <= 1
        DQ    <= {DATA_WIDTH{1'bx}};
        DQ_Drive <= 0;
    end
endtask

task read;
    input  [1 : 0] bank;
    input [11 : 0] column;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 1;
        o_Cas_n <= 0;
        o_We_n  <= 1;
        o_Ba    <= bank;
        o_Addr  <= column;
        DQ    <= {DATA_WIDTH{1'bx}};
        DQ_Drive <= 0;
    end
endtask

task write;
    input  [1 : 0] bank;
    input [11 : 0] column;
    input [15 : 0] dq_in;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 1;
        o_Cas_n <= 0;
        o_We_n  <= 0;
        o_Ba    <= bank;
        o_Addr  <= column;
        DQ    <= dq_in;
        DQ_Drive <= 1;
    end
endtask


task write_data;
    input [15 : 0] dq_in;
    begin
        o_Cke   <= 1;
        o_Cs_n  <= 0;
        o_Ras_n <= 1;
        o_Cas_n <= 1;
        o_We_n  <= 1;
        //o_Ba    <= 0;
        //o_Addr  <= 0;
        DQ    <= dq_in;
        DQ_Drive <= 1;
    end
endtask

// timings for 166MHz
localparam tRP = 3;
localparam tRC = 10;
localparam tRSC = 2;
localparam tRCD = 3;

//`ifdef MODEL_TECH
	localparam tCL = 3;
/*`else
	localparam tCL = 4;
`endif
*/
localparam tREF = 11'd700; //1600;	// our auto refresh rate ~ 12us


reg [14:0] Wait_Counter;
reg [10:0] Refresh_Counter;
reg NeedRefresh;
// general purpose counter
reg [3:0] Gen_Count;

reg [3:0] State;
reg [3:0] NextState;
localparam STATE_RESET = 4'd0;
localparam STATE_INIT1 = 4'd1;
localparam STATE_INIT2 = 4'd2;
localparam STATE_INIT3 = 4'd3;
localparam STATE_READY = 4'd4;
localparam STATE_READ1 = 4'd5;
localparam STATE_READ2 = 4'd6;
localparam STATE_READ3 = 4'd7;
localparam STATE_WRITE1 = 4'd8;
localparam STATE_WRITE2 = 4'd9;
localparam STATE_WRITE3 = 4'd10;
localparam STATE_WAIT = 4'd15;

task wait_next_state;
	input [3:0] next_state;
	input [14:0] wait_time;
	begin
		State <= STATE_WAIT;
		NextState <= next_state;
		Wait_Counter <= wait_time-15'd1;
	end

endtask


always @(posedge i_Clk, posedge i_Reset)
begin
	if (i_Reset)
	begin
		o_Data <= 0;
		o_Data_Valid <= 0;
		o_Last <= 0;
		o_Data_Read <= 0;
		State <= STATE_RESET;
		Gen_Count <= 9;
		o_Dqm <= 2'b11;
		Wait_Counter <= 0;
		ColAddr <= 0;
		NeedRefresh <= 0;
		Refresh_Counter <= 0;
		nop();
	end
	else
	begin
	
		//refresh counter
		if (Refresh_Counter != 0)
			Refresh_Counter <= Refresh_Counter-11'd1;
			
		if (Refresh_Counter == 0)
			NeedRefresh <= 1;
	
		case (State)
			STATE_RESET:
			begin
				nop();
				o_Dqm <= 2'b11;
				wait_next_state(STATE_INIT1, 15'b111_1111_1111_1111);
			end
			STATE_INIT1:
			begin
				o_Dqm <= 2'b11;
				precharge_all_bank();
				wait_next_state(STATE_INIT2, tRP);
			end
			STATE_INIT2:
			begin
				o_Dqm <= 2'b11;
				Gen_Count <= Gen_Count-4'd1;
				if (Gen_Count == 0)
				begin
					State <= STATE_INIT3;
					nop();
				end
				else
				begin
					wait_next_state(STATE_INIT2, tRC);
					auto_refresh();
				end
			end
			STATE_INIT3:
			begin
				o_Dqm <= 2'b11;
				load_mode_reg(14'b0000_0_00_011_0_011);
				wait_next_state(STATE_READY, tRSC);
			end
			STATE_READY:
			begin
				o_Data_Valid <= 0;
				ColAddr <= i_Addr[COL_ADDR_WIDTH-1:0];
				BankAddr <= i_Addr[BANK_ADDR_WIDTH+COL_ADDR_WIDTH-1:COL_ADDR_WIDTH];
				o_Dqm <= 2'b00;
				
				if (NeedRefresh)
				begin
					Refresh_Counter <= tREF;
					NeedRefresh <= 0;
					auto_refresh();
					wait_next_state(STATE_READY, tRC);
				end
				else if (i_Req_Valid)
				begin
					active(i_Addr[BANK_ADDR_WIDTH+COL_ADDR_WIDTH-1:COL_ADDR_WIDTH],i_Addr[ROW_ADDR_WIDTH+BANK_ADDR_WIDTH+COL_ADDR_WIDTH-1:BANK_ADDR_WIDTH+COL_ADDR_WIDTH]);
					if (i_Read_Write_n)
					begin
						wait_next_state(STATE_READ1, tRCD);
					end
					else
					begin
						wait_next_state(STATE_WRITE1, tRCD);
					end
				end
				else
				begin
					nop();
				end
			end
			STATE_READ1:
			begin
				// read with auto-precharge
				read(BankAddr,ColAddr|1024);
				Gen_Count <= 3;
				wait_next_state(STATE_READ2, tCL);
			end
			STATE_READ2:
			begin
				// read with auto-precharge
				nop();
				o_Data[15:0] <= b_Dq;
				o_Data_Valid <= 0;
				State <= STATE_READ3;
			end
			STATE_READ3:
			begin
				// read with auto-precharge
				nop();
				o_Data[31:16] <= b_Dq;
				o_Data_Valid <= 1;
				Gen_Count <= Gen_Count-4'd1;
				if (Gen_Count == 0)
				begin
					o_Last <= 1;
					wait_next_state(STATE_READY, 1);	// give time for cache to respond
				end
				else
				begin
					State <= STATE_READ2;
					o_Last <= 0;
				end
			end
			STATE_WRITE1:
			begin
				// write with auto-precharge
				write(BankAddr,ColAddr|1024, i_Data[15:0]);
				Gen_Count <= 3;
				State <= STATE_WRITE2;
				o_Data_Read <= 1;
			end
			STATE_WRITE2:
			begin
				
				o_Data_Read <= 0;
				o_Last <= 0;
				write_data(i_Data[31:16]);
				Gen_Count <= Gen_Count-4'd1;
				if (Gen_Count == 0)
				begin
					wait_next_state(STATE_READY, tCL);
				end
				else
				begin
					State <= STATE_WRITE3;
				end
			end
			STATE_WRITE3:
			begin
				// write with auto-precharge
				write_data(i_Data[15:0]);
				State <= STATE_WRITE2;
				o_Data_Read <= 1;
				if (Gen_Count == 0)
					o_Last <= 1;
			end
			
			STATE_WAIT:
			begin
				nop();
				o_Last <= 0;
				o_Data_Valid <= 0;
				Wait_Counter <= Wait_Counter-15'd1;
				if (Wait_Counter == 0)
					State <= NextState;
			end
		endcase
	end
end


endmodule
