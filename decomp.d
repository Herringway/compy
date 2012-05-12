module pkhack.eb.decomp;

import std.stream;
import std.stdio;

private const int BANKSIZE = 0x10000;
enum command : int { UNCOMPRESSED = 0, BYTEFILL, SHORTFILL, BYTEFILLINCREASING, BUFFERCOPY, BITREVERSEDBUFFERCOPY, BYTEREVERSEDBUFFERCOPY, EXTENDCOMMAND}

ubyte[] decomp(std.stream.File inputFile, int offset) {
	int throwAway;
	return decomp(inputFile, offset, throwAway);
}
ubyte[] decomp(std.stream.File inputFile, int offset, out int compressedSize) {
	debug writefln("Seeking to 0x%X", offset);
	debug writeln("----------------");
	inputFile.position = offset;
	ubyte[] buffer = new ubyte[BANKSIZE];
	ubyte[] uncompbuff;
	ubyte commandbyte,commandbyte2, tmp, tmp2;
	command commandID;
	ushort commandLength, bufferpos;
	int decompSize = 0;
	while(inputFile.position - offset < BANKSIZE) { //compressed data cannot exceed 64KB
		inputFile.read(commandbyte);
		commandID = cast(command)(commandbyte >> 5);
		commandLength = (commandbyte & 0x1F) + 1;
		debug writefln("Position: %X", inputFile.position-1);
		if (commandID == command.EXTENDCOMMAND) { //Extended range
			inputFile.read(commandbyte2);
			commandID = cast(command)((commandbyte & 0x1C) >> 2);
			commandLength = ((commandbyte & 3) << 8) + commandbyte2 + 1;
			debug writeln("Extended command");
		}
		debug writeln("Command: ", commandID);
		debug writeln("Length: ", commandLength);
		if ((commandID >= 4) && (commandID < 7)) { //Read buffer position
			inputFile.read(tmp);
			inputFile.read(tmp2);
			bufferpos = (tmp << 8) + tmp2;
			debug writefln("Buffer range: [%d..%d]", bufferpos, bufferpos+commandLength);
			assert(bufferpos < BANKSIZE, "Buffer size exceeds bank size!");
		}
		if (commandID == command.UNCOMPRESSED) { //Following data is uncompressed
			uncompbuff = new ubyte[commandLength];
			inputFile.read(uncompbuff);
			buffer[decompSize..decompSize+commandLength] = uncompbuff;
		} else if (commandID == command.BYTEFILL) { //Fill range with following byte
			inputFile.read(tmp);
			buffer[decompSize..decompSize+commandLength] = tmp;
		} else if (commandID == command.SHORTFILL) { //Fill range with following short
			inputFile.read(tmp);
			inputFile.read(tmp2);
			commandLength *= 2;
			buffer[decompSize..decompSize+commandLength] = [tmp,tmp2].stripe(commandLength);
		} else if (commandID == command.BYTEFILLINCREASING) { //Fill range with increasing byte, beginning with following value
			inputFile.read(tmp);
			buffer[decompSize..decompSize+commandLength] = tmp.increaseval(commandLength);
		} else if (commandID == command.BUFFERCOPY) { //Copy from buffer
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength].dup;
		} else if (commandID == command.BITREVERSEDBUFFERCOPY) { //Copy from buffer, but with reversed bits
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength].reversebits;
		} else if (commandID == command.BYTEREVERSEDBUFFERCOPY) { //Copy from buffer, but with reversed bytes
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos-commandLength+1..bufferpos+1].dup.reverse;
		} else
			break; //End of decompressed data
		decompSize += commandLength;
		debug writeln("----------------");
	}
	debug writeln("----------------");
	compressedSize = cast(int)inputFile.position - offset - 1;
	buffer.length = decompSize;
	debug writeln("Final data: ", buffer);
	return buffer;
}
T[] reversebits(T)(T[] input) {
	ubyte[] output;
	ubyte tmp;
	output.length = (cast(ubyte[])input).length;
	int i = 0;
	foreach (val; cast(ubyte[])input.dup) {
		tmp = ((val >> 1) & 0x55) | ((val << 1) & 0xAA);
		tmp = ((tmp >> 2) & 0x33) | ((tmp << 2) & 0xCC);
		tmp = ((tmp >> 4) & 0x0F) | ((tmp << 4) & 0xF0);
		output[i++] = tmp;
	}
	return cast(T[])output;
}
ubyte[] increaseval(ubyte input, int length) {
	ubyte[] output = new ubyte[length];
	foreach(ref val; output)
		val = input++;
	return output;
}
T[] stripe(T)(T[] input, int length) {
	T[] output = new T[length];
	assert(input != [], "Cannot stripe with empty array");
	foreach (i, ref outval; output)
		outval = input[i%input.length];
	return output;
}
unittest {
	void test(lazy bool expr, string label, bool expectException = false) {
		write("[DECOMP] " ~ label ~ ":");
		try {
			if (!expr)
				writeln("FAILED");
			else
				writeln("PASSED");
		} catch (Exception e) {
			if (!expectException)
				writeln("FAILED: " ~ e.msg);
			else
				writeln("PASSED");
		} catch (core.exception.AssertError e) {
			if (!expectException)
				writeln("FAILED: " ~ e.msg);
			else
				writeln("PASSED");
		}
	}
	import std.exception;
	test([0,1,2].stripe(10) == [0, 1, 2, 0, 1, 2, 0, 1, 2, 0], "Striping: Int");
	test(["hi","sup"].stripe(4) == ["hi", "sup", "hi", "sup"], "Striping: String");
	ubyte[] testv;
	test(testv.stripe(2) == [], "Striping: Null input exception", true);

	test((0).increaseval(1) == [0], "Increaseval: First value unaltered");
	test((0).increaseval(3) == [0, 1, 2], "Increaseval: algorithm");
	test((255).increaseval(3) == [255, 0, 1], "Increaseval: Wrapping values");
	test((0).increaseval(0) == [], "Increaseval: Void");

	test([1].reversebits == [128], "Bit reversal: algorithm");
	test([1, 2, 4, 5].reversebits == [128, 64, 32, 160], "Bit reversal: array");
	test("HELLO".reversebits == [18, 162, 50, 50, 242], "Bit reversal: string");
	test([].reversebits == [], "Bit reversal: void");
}