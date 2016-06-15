`timescale 1ns / 1ps
//-------------------------------------------------------------
// 7-segment hexadecimal decoder
// October 1, 2015
// Alex Von Hoene
// 
// Given a 4-bit binary input
// Returns 7 binary signals, one for each segment of a
// 7-segment display, to display the corresponding hexadecimal number on the display.
//
// This is done a bit inefficiently - the decoder determines
// what number is encoded in the four bits, and then uses bitwise
// conditionals for each segment.
// Example:
//   The number is 4 if bit 2 is high and bits 3, 1, and 0 are low.
//   Segment 4 (E) is on if the number is 0, 2, 6, 8, 10 (A), 11 (b), 12 (C), 13 (D), 14 (E), or 15 (F)
// This is a bit inefficient, but very easy to read.
//
// Segments of the display are turned on if they are given binary 0 input.
//
// Here is a diagram of a typical 7-segment display, with segment labels made obvious
//
//    AAAA
//   F    B
//   F    B
//    GGGG
//   E    C
//   E    C
//    DDDD
//-------------------------------------------------------------
module bin2seg(B, S);
	input [3:0] B;  // binary input
	output [6:0] S; // one output for each of 7 segments

	// one wire for each possible number the input can represent
	wire m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m11, m12, m13, m14, m15;

	// What is the input number?
	assign m0  = ~B[3] & ~B[2] & ~B[1] & ~B[0]; // is the input 0?
	assign m1  = ~B[3] & ~B[2] & ~B[1] &  B[0]; // is the input 1?
	assign m2  = ~B[3] & ~B[2] &  B[1] & ~B[0]; // is the input 2?.
	assign m3  = ~B[3] & ~B[2] &  B[1] &  B[0]; // is the input 3?
	assign m4  = ~B[3] &  B[2] & ~B[1] & ~B[0]; // etc.
	assign m5  = ~B[3] &  B[2] & ~B[1] &  B[0]; 
	assign m6  = ~B[3] &  B[2] &  B[1] & ~B[0]; 
	assign m7  = ~B[3] &  B[2] &  B[1] &  B[0]; 
	assign m8  =  B[3] & ~B[2] & ~B[1] & ~B[0]; 
	assign m9  =  B[3] & ~B[2] & ~B[1] &  B[0]; 
	assign m10 =  B[3] & ~B[2] &  B[1] & ~B[0]; 
	assign m11 =  B[3] & ~B[2] &  B[1] &  B[0]; 
	assign m12 =  B[3] &  B[2] & ~B[1] & ~B[0]; 
	assign m13 =  B[3] &  B[2] & ~B[1] &  B[0]; 
	assign m14 =  B[3] &  B[2] &  B[1] & ~B[0]; 
	assign m15 =  B[3] &  B[2] &  B[1] &  B[0]; 

	// For each segment: should it be on (false) or off (true)?
	// example: segment A should be on if the input is 0, 2, 3, 5, 6, 7, 8, 9, 10 (A), 12 (C), 14 (E), or 15 (F)
	assign S[0] = ~(m0 |      m2 | m3 |      m5 | m6 | m7 | m8 | m9 | m10 |       m12 |       m14 | m15 ); // segment A
	assign S[1] = ~(m0 | m1 | m2 | m3 | m4 |           m7 | m8 | m9 | m10 |             m13             ); // segment B
	assign S[2] = ~(m0 | m1 | m3 |      m4 | m5 | m6 | m7 | m8 | m9 | m10 | m11 |       m13             ); // segment C
	assign S[3] = ~(m0 |      m2 | m3 |      m5 | m6 |      m8 |            m11 | m12 | m13 | m14       ); // segment D
	assign S[4] = ~(m0 |      m2 |                m6 |      m8 |      m10 | m11 | m12 | m13 | m14 | m15 ); // segment E
	assign S[5] = ~(m0 |                m4 | m5 | m6 |      m8 | m9 | m10 | m11 | m12 | m14 |       m15 ); // segment F
	assign S[6] = ~(          m2 | m3 | m4 | m5 | m6 |      m8 | m9 | m10 | m11 |       m13 | m14 | m15 ); // segment G

	// You can read down columns to see which segments are on for each digit, and
	// you can read scross rows to see which digits each segment is on for.
	// Again, not the most efficient way to write this,
	// but very easy to read, write, and debug.
endmodule
