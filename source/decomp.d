module decomp;

import std.stream;
import std.algorithm;
import std.exception;

private const int BANKSIZE = 0x10000;
enum command : ubyte { UNCOMPRESSED = 0, BYTEFILL, SHORTFILL, BYTEFILLINCREASING, BUFFERCOPY, BITREVERSEDBUFFERCOPY, BYTEREVERSEDBUFFERCOPY, EXTENDCOMMAND}

ubyte[] decomp(Stream input, ulong offset) {
	int throwAway;
	return decomp(input, offset, throwAway);
}
ubyte[] decomp(Stream input) {
	int throwAway;
	return decomp(input, 0, throwAway);
}
ubyte[] decomp(Stream input, out int compressedSize) {
	return decomp(input, 0, compressedSize);
}
ubyte[] decomp(ubyte[] input) {
	int throwAway;
	return decomp(new MemoryStream(input), 0, throwAway);
}
ubyte[] decomp(ubyte[] input, out int compressedSize) {
	return decomp(new MemoryStream(input), 0, compressedSize);
}
ubyte readByte(Stream file) {
	ubyte output = void;
	file.read(output);
	return output;
}
ubyte[] decomp(Stream input, ulong offset, out int compressedSize) {
	input.position = offset;
	ubyte[] buffer = new ubyte[BANKSIZE];
	ubyte commandbyte = void;
	command commandID = void;
	ushort commandLength = void, bufferpos = void;
	int decompSize = 0;
	while(decompSize < BANKSIZE) { //decompressed data cannot exceed 64KB
		input.read(commandbyte);
		commandID = cast(command)(commandbyte >> 5);
		if (commandID == command.EXTENDCOMMAND) { //Command with extended range
			commandID = cast(command)((commandbyte & 0x1C) >> 2);
			if (commandID == command.EXTENDCOMMAND) //End of data
				break;
			commandLength = ((commandbyte & 3) << 8) + input.readByte() + 1;
		} else
			commandLength = (commandbyte & 0x1F) + 1;

		if ((commandID >= command.BUFFERCOPY) && (commandID < command.EXTENDCOMMAND)) { //Read buffer position
			bufferpos = (input.readByte() << 8) + input.readByte();
			enforce(bufferpos < BANKSIZE, "Buffer position exceeds bank size!");
			enforce(bufferpos < decompSize, "Buffer contents at position unknown!");
		}
		if (commandID == command.UNCOMPRESSED) //Following data is uncompressed
			input.read(buffer[decompSize..decompSize+commandLength]); //copy uncompressed data directly into buffer
		else if (commandID == command.BYTEFILL) //Fill range with following byte
			buffer[decompSize..decompSize+commandLength] = input.readByte();
		else if (commandID == command.SHORTFILL) { //Fill range with following short
			commandLength *= 2;
			buffer[decompSize..decompSize+commandLength].fill([input.readByte(),input.readByte()]);
		} else if (commandID == command.BYTEFILLINCREASING) //Fill range with increasing byte, beginning with following value
			buffer[decompSize..decompSize+commandLength] = increaseval(input.readByte(),commandLength);
		else if (commandID == command.BUFFERCOPY) //Copy from buffer
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength];
		else if (commandID == command.BITREVERSEDBUFFERCOPY) //Copy from buffer, but with reversed bits
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength].dup.reversebits;
		else if (commandID == command.BYTEREVERSEDBUFFERCOPY) //Copy from buffer, but with reversed bytes
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos-commandLength+1..bufferpos+1].dup.reverse;
		decompSize += commandLength;
	}
	compressedSize = cast(int)input.position - cast(int)offset;
	buffer.length = decompSize;
	return buffer;
}
unittest {
	assert(decomp([0x63, 0x00, 0xFF]) == decomp(new MemoryStream(cast(ubyte[])[0x63, 0x00, 0xFF])), "Decomp: Stream == array");

	assertThrown(decomp([0x80, 0xFF, 0x00, 0xFF]) == [], "Decomp: Uninitialized buffer");

	void decomptest(ubyte[] input, ubyte[] output, string msg) {
		int finalSize;
		auto data = decomp(input, finalSize);
		assert(data == output, "Decomp: " ~ msg);
		assert(finalSize == input.length, "Decomp: " ~ msg ~ " size");
	}
	decomptest([0x03, 1, 3, 3, 7, 0xFF], [1, 3, 3, 7], "Uncompressed data");
	decomptest([0x21, 1, 0xFF], [1, 1], "Byte fill");
	decomptest([0x41, 1, 2, 0xFF], [1, 2, 1, 2], "Word fill");
	decomptest([0x63, 0, 0xFF], [0, 1, 2, 3], "Decomp: Increasing value");
	decomptest([0x61, 1, 0x80, 0, 0, 0xFF], [1, 2, 1], "Buffer copy");
	decomptest([0x61, 1, 0xA0, 0, 0, 0xFF], [1, 2, 128], "Bit-reversed Buffer copy");
	decomptest([0x61, 1, 0xC1, 0, 1, 0xFF], [1, 2, 2, 1], "Byte-reversed buffer copy");
	ubyte[] testArray = new ubyte[513];
	testArray[] = 1;
	decomptest([0xE6, 0, 1, 0xFF], testArray, "Extended byte fill");
}

ubyte[] increaseval(ubyte input, int length) {
	ubyte[] output = new ubyte[length];
	foreach(ref val; output)
		val = input++;
	return output;
}
unittest {
	assert((0).increaseval(1) == [0], "Increaseval: First value unaltered");
	assert((0).increaseval(3) == [0, 1, 2], "Increaseval: algorithm");
	assert((255).increaseval(3) == [255, 0, 1], "Increaseval: Wrapping values");
	assert((0).increaseval(0) == [], "Increaseval: Void");
}
T[] reversebits(T)(T[] input) { 
	foreach (ref val; cast(ubyte[])input) {
		val = ((val >> 1) & 0x55) | ((val << 1) & 0xAA);
		val = ((val >> 2) & 0x33) | ((val << 2) & 0xCC);
		val = ((val >> 4) & 0x0F) | ((val << 4) & 0xF0);
	}
	if (input[0].sizeof > 1)
		for (int i = 0; i < input.length; i++)
			(cast(ubyte[])input)[i*input[0].sizeof..(i+1)*input[0].sizeof].reverse;

	return input;
}
unittest {
	assert([cast(ubyte)1].reversebits == [cast(ubyte)128], "Bit reversal: algorithm");
	assert((cast(ubyte[])[1, 2, 4, 5]).reversebits == cast(ubyte[])[128, 64, 32, 160], "Bit reversal: array");
	assert("HELLO".reversebits == cast(string)[18, 162, 50, 50, 242], "Bit reversal: string");
	assert([].reversebits == [], "Bit reversal: nothing");
	assert([cast(uint)0x80000000].reversebits == [1], "Bit reversal: int");
}