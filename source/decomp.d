module decomp;

import std.range;
import std.algorithm;
import std.exception;
import std.traits;

private enum BANKSIZE = 0x10000;
private enum command : ubyte { UNCOMPRESSED = 0, BYTEFILL, SHORTFILL, BYTEFILLINCREASING, BUFFERCOPY, BITREVERSEDBUFFERCOPY, BYTEREVERSEDBUFFERCOPY, EXTENDCOMMAND}

ubyte[] decomp(ubyte[] input) {
	int throwAway;
	return decomp(input, throwAway);
}
ubyte readByte(T)(ref T file) {
	auto v = file.front;
	file.popFront();
	return v;
}
ubyte[] decomp(T)(T input, out int compressedSize) if (isInputRange!T) {
	ubyte[] buffer = new ubyte[](BANKSIZE);
	ubyte commandbyte = void;
	command commandID = void;
	ushort commandLength = void, bufferpos = void;
	int decompSize = 0;
	while(decompSize < BANKSIZE) { //decompressed data cannot exceed 64KB
		commandbyte = input.readByte();
		compressedSize++;
		commandID = cast(command)(commandbyte >> 5);
		if (commandID == command.EXTENDCOMMAND) { //Extend length of command
			commandID = cast(command)((commandbyte & 0x1C) >> 2);
			if (commandID == command.EXTENDCOMMAND) //Double extend marks end of data
				break;
			commandLength = ((commandbyte & 3) << 8) + input.readByte() + 1;
			compressedSize++;
		} else
			commandLength = (commandbyte & 0x1F) + 1;
		if ((commandID >= command.BUFFERCOPY) && (commandID < command.EXTENDCOMMAND)) { //Read buffer position
			bufferpos = (input.readByte() << 8) + input.readByte();
			compressedSize += 2;
			enforce(bufferpos < BANKSIZE, "Buffer position exceeds bank size!");
			enforce(bufferpos < decompSize, "Buffer contents at position unknown!");
		}
		with(command) final switch(commandID) {
			case UNCOMPRESSED: //Following data is uncompressed
				buffer[decompSize..decompSize+commandLength] = array(input.takeExactly(commandLength)); input.popFrontN(commandLength); compressedSize += commandLength; break; //copy uncompressed data directly into buffer
			case BYTEFILL: //Fill range with following byte
				buffer[decompSize..decompSize+commandLength] = input.readByte(); compressedSize++; break;
			case SHORTFILL: //Fill range with following short
				commandLength *= 2;
				buffer[decompSize..decompSize+commandLength].fill([input.readByte(),input.readByte()]); compressedSize += 2; break;
			case BYTEFILLINCREASING: //Fill range with increasing byte, beginning with following value
				buffer[decompSize..decompSize+commandLength] = increaseval(input.readByte(), commandLength); compressedSize++; break;
			case BUFFERCOPY: //Copy from buffer
				buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength]; break;
			case BITREVERSEDBUFFERCOPY: //Copy from buffer, but with reversed bits
				buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength].dup.reversebits; break;
			case BYTEREVERSEDBUFFERCOPY: //Copy from buffer, but with reversed bytes
				buffer[decompSize..decompSize+commandLength] = buffer[bufferpos-commandLength+1..bufferpos+1].dup; buffer[decompSize..decompSize+commandLength].reverse(); break;
			case EXTENDCOMMAND: break;
		}
		decompSize += commandLength;
	}
	buffer.length = decompSize;
	return buffer;
}
unittest {
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

ubyte[] increaseval(ubyte input, in int length) pure nothrow @safe {
	ubyte[] output = new ubyte[](length);
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
T[] reversebits(T)(T[] input) if (!isMutable!T) {
	Unqual!T[] output = input.dup;
	output.reversebits();
	return output;
}
T[] reversebits(T)(T[] input) if (isMutable!T) {
	union ByteAddressable {
		static if (is(T == void)) {
			ubyte val;
			ubyte byteVal;
		} else {
			T val;
			static if (T.sizeof == 1) {
				ubyte byteVal;
			} else static if (T.sizeof == 2) {
				ushort shortVal;
			} else static if (T.sizeof == 4) {
				uint intVal;
			}
		}
		ubyte[val.sizeof] rawBytes;
	}
	foreach (ref val; () @trusted { return cast(ByteAddressable[])input; }()) {
		static if (T.sizeof == 1) {
			val.byteVal = ((val.byteVal >> 1) & 0x55) | ((val.byteVal << 1) & 0xAA);
			val.byteVal = ((val.byteVal >> 2) & 0x33) | ((val.byteVal << 2) & 0xCC);
			val.byteVal = ((val.byteVal >> 4) & 0x0F) | ((val.byteVal << 4) & 0xF0);
		} else static if (T.sizeof == 2) {
			val.shortVal = ((val.shortVal & 0x5555) << 1) | ((val.shortVal & 0xAAAA) >> 1);
			val.shortVal = ((val.shortVal & 0x3333) << 2) | ((val.shortVal & 0xCCCC) >> 2);
			val.shortVal = ((val.shortVal & 0x0F0F) << 4) | ((val.shortVal & 0xF0F0) >> 4);
			val.shortVal = ((val.shortVal & 0x00FF) << 8) | ((val.shortVal & 0xFF00) >> 8);
		} else static if (T.sizeof == 4) {
			val.intVal = ((val.intVal & 0x55555555) << 1) | ((val.intVal & 0xAAAAAAAA) >> 1);
			val.intVal = ((val.intVal & 0x33333333) << 2) | ((val.intVal & 0xCCCCCCCC) >> 2);
			val.intVal = ((val.intVal & 0x0F0F0F0F) << 4) | ((val.intVal & 0xF0F0F0F0) >> 4);
			val.intVal = ((val.intVal & 0x00FF00FF) << 8) | ((val.intVal & 0xFF00FF00) >> 8);
			val.intVal = ((val.intVal & 0x0000FFFF) << 16) | ((val.intVal & 0xFFFF0000) >> 16);
		} else {
			static assert(0, "Unsupported");
		}
	}
	return input;
}
pure nothrow @safe unittest {
	assert([cast(ubyte)1].reversebits == [cast(ubyte)128], "Bit reversal: algorithm");
	assert((cast(ubyte[])[1, 2, 4, 5]).reversebits == cast(ubyte[])[128, 64, 32, 160], "Bit reversal: array");
	assert("HELLO".reversebits == "\x12\xA2\x32\x32\xF2", "Bit reversal: string");
	assert([].reversebits == [], "Bit reversal: nothing");
	assert([cast(uint)0x80000000].reversebits == [1], "Bit reversal: int");
}