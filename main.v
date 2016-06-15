`timescale 1ns / 1ps
//---------------------------------------------------------------------------------
// Stack-based calculator for FPGA, controlled by serial connection (SPI).
// November 18, 2015
// Alex Von Hoene
//
// This is a simple, stack-based calculator. Any usb-based microcontroller (we used a cheap STM board)
// can be used to interact with and use the calculator from a computer. A serial (SPI) bus communicates
// commands, arguments, and responses to and from the FPGA. Four 7-segment displays on the FPGA board show
// the last received command and the last message send back from the FPGA.
//
// Commands are 1 byte, and are always followed by a second byte. If the commands requires sending a number to
// the FPGA (for example, "push"), that number is in the second byte. An additional 8 clocks are sent by the STM
// after the second byte, during which the FPGA sends its response.
//
// = How the display is draw to; and why are there two clocks? =
// The FPGA board we are using has four 7-segment displays, and a bus that can only write 7 segments at once.
// There are also 4 additional bits, which enable or disable each display. To write unique contents to eac
// display, you need to turn all but one display off, write the contents of the one remaining display, wait a
// few dozen milliseconds, then turn that display off and move to the next one. If you switch quickly enough,
// each display will seem to be steadily and brightly showing its own content. The "clk" input is used to provide
// the timely signal for switching between displays. The serial clock from the STM board is only used when commands
// are being sent.
//---------------------------------------------------------------------------------
module main(cs, sck, mosi, miso, clk, seg, an);
	input clk;          // clock, used to switch which display is being drawn to
	output [6:0]seg;    // outputs to a single 7-segment display
	output reg [3:0]an; // which of the four 7-segment displays is being drawn to right now.

	input cs, sck, mosi, clk; // inputs of SPI bus - ChipSelect, SerialClock, MasterOutSlaveIn
	output miso;              // output of SPI bus - MasterInSlaveOut
	
	reg [4:0] bitcnt;       // Input bit count. Determines when a complete message has been received.
	reg [7:0] in_byte;      // Most recent input byte from STM board.
	reg [7:0] out_byte;     // Message to write to STM board (output) The bits in here get messed with.
	reg [7:0] byte_A;       // Byte A (first of 2, aka the "command")  received from the STM board
	reg [7:0] byte_B;       // Byte B (second of 2) received from the STM board.
	reg [7:0] ret_message;  // Message to send the STM board. Always has complete, unaltered message.
	reg [7:0] stack [0:63]; // stack memory
	reg [6:0] SP;           // Stack  pointer
	
	assign miso = out_byte[7]; // Serial Out - the highest bit of out_byte is what gets output to the STM.

	wire   cmd_clock;                                  // This clock determines when to process commands.
	assign cmd_clock = sck & ( bitcnt[3] | bitcnt[4]); // Process commands after the command byte is received,
	                                                   // while receiving the second byte.
	
	// When the input clock rises, receive the next bit of input.
	always @(posedge sck) 
		if (!cs) begin
			// rotate input byte to make room for newest bit
			in_byte <= {in_byte[6:0], mosi};
		// keep track of how many bits have been received
		if (bitcnt == 5'b11000)
			bitcnt <= 1;
		else 
			bitcnt <= bitcnt + 1;         // Increment bit counter    
	end
	
	// After a bit has been received, check if we have a complete command (byte_A).
	// If we do have a complete command, store it.
	always @(negedge sck)
		if (bitcnt == 5'b01000)
			byte_A <= in_byte[7:0];            // Extract byte A
		
	// After a but has been received, check if we have a complete arguemnt (byte_B).
	// If we do, store it.
	always @(negedge sck)
		if (bitcnt == 5'b10000)
			byte_B <= in_byte[7:0];            // Extract byte B
		
	// Processing commands - this block is run while immediately after each 16 bits have been clocked in
	always @(negedge cmd_clock)
		begin
		case (byte_A)
			8'h04: // "stack ready" - to make the FPGA respond once it is configured / booted
				case ( bitcnt )
					5'h09: ret_message <= 8'h01;
				endcase
			8'h08: // "stack empty" - return 1 is stack is empty, 2 if not
				case ( bitcnt )
					5'h09: 
						if (SP == 0)
							ret_message <= 1; 
						else
							ret_message <= 2;    
				endcase
			8'h09: // "stack full" - return 1 if stack is full, 2 if not
				case ( bitcnt )
					5'h09: 
						if (SP == 7'h60)
							ret_message <= 1; 
						else
							ret_message <= 2;    
				endcase
			8'h0a: // "stack push" - push argument (byte_B) to top of stack. No response.
				case ( bitcnt )
					5'h12: SP <= SP - 1;    
					5'h13: stack[ SP ] <= byte_B; 
				endcase
			8'h0B: // - "stack pop" - remove item from top of stack and return it
				case ( bitcnt )
					5'h09: ret_message <=  stack[ SP ] ; 
					5'h0A: SP <= SP + 1;  
				endcase
				
			8'h0C: // "peek" - return item at top of stack, but don't remove it
				case ( bitcnt )
					5'h09: ret_message = stack[ SP ] ;
				endcase
			8'h10: // "and" - remove top 2 items from stack, push their bitwise AND (to the top)
				case ( bitcnt )
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] & stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
						end
				endcase
			8'h11: // "or" - remove top 2 items from stack, push their bitwise OR
				case (bitcnt)
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] | stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
						end
				endcase
			8'h12: // "not" - replace item on top of stack with its bitwise NOT
				case (bitcnt)
					5'h09: begin
						stack[SP] = ~stack[SP];
						ret_message = stack[SP];
						end
				endcase
			8'h13: // "xor" - remove top 2 items from stack, push their bitwise XOR
				case (bitcnt)
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] ^ stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
					end
				endcase
			8'h20: // "add" - remove top 2 items from stack, push their sum
				case (bitcnt)
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] + stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
					end
				endcase
			8'h21: // "subtract" - pop a from stack, pop b from stack, then push b - a
				case (bitcnt)
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] - stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
					end
				endcase
			8'h22: // "increment" - replace item on top of stack with that item +1
				case (bitcnt)
					5'h09: begin
						stack[SP] = stack[SP] + 1;
						ret_message = stack[SP];
					end
				endcase
			8'h23: // "multiply" - pop a from stack, then pop b, then push b * a.
				case (bitcnt)
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] * stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
					end
				endcase
			8'h24: // "modulo" - pop a from stack, then pop b, then push b % a.
				case (bitcnt)
					5'h09: begin
						stack[SP + 1] = stack[SP + 1] % stack[SP];
						SP = SP + 1;
						ret_message = stack[SP];
					end
				endcase
		endcase 
	end
	
	// Transmit message to the STM board (on the down-side of each clock signal)
	always @(negedge sck)
	begin
		if (bitcnt == 5'b10000) // if 2 bytes have been received (command + argument), send new response
			out_byte <= ret_message;
		else
			out_byte <= {out_byte[6:0], out_byte[7]};  
	end
	


	// Draw the Command and Response on the 7-segment displays
	reg [27:0] q;           // BIG register, incremented by clock. Used for power-of-2 reduction of clock speed.
	wire switchDisplay;     // connected to clock, signals when to switch to next display
	reg [1:0] whichDisplay; // binary of which display to draw to right now
	reg [3:0] binary;       // binary value of current display

	bin2seg display(binary, seg); // convert binary values into signals for all 7 segments
	assign switchDisplay = q[12]; // When to switch to next display: whenever bit 12 of q goes from 0 to 1.
	
	// Keep track of clock
	always @(posedge clk)
	begin
		q = q + 1;
	end
	
	// switch to next display, draw its contents
	always @(posedge switchDisplay)
	begin
		whichDisplay = whichDisplay + 1;
		case (whichDisplay)
			2'b00: binary = byte_A[7:4];
			2'b01: binary = byte_A[3:0];
			2'b10: binary = ret_message[7:4];
			2'b11: binary = ret_message[3:0];
		endcase
		case (whichDisplay)
			2'b00: an <= 4'b0111;
			2'b01: an <= 4'b1011; 
			2'b10: an <= 4'b1101;
			2'b11: an <= 4'b1110;
		endcase
	end
endmodule
