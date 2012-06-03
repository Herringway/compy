module decomp;

import std.stream;
import std.stdio;
import std.algorithm;

private const int BANKSIZE = 0x10000;
enum command : int { UNCOMPRESSED = 0, BYTEFILL, SHORTFILL, BYTEFILLINCREASING, BUFFERCOPY, BITREVERSEDBUFFERCOPY, BYTEREVERSEDBUFFERCOPY, EXTENDCOMMAND}

ubyte[] decomp(Stream input, int offset) {
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
ubyte[] decomp(Stream input, int offset, out int compressedSize) {
	debug writefln("Seeking to 0x%X", offset);
	debug writeln("----------------");
	input.position = offset;
	ubyte[] buffer = new ubyte[BANKSIZE];
	ubyte[] uncompbuff;
	ubyte commandbyte,commandbyte2, tmp, tmp2;
	command commandID;
	ushort commandLength, bufferpos;
	int decompSize = 0;
	while(input.position - offset < BANKSIZE) { //compressed data cannot exceed 64KB
		input.read(commandbyte);
		commandID = cast(command)(commandbyte >> 5);
		commandLength = (commandbyte & 0x1F) + 1;
		debug writefln("Position: %X", input.position-1);
		if (commandID == command.EXTENDCOMMAND) { //Extended range
			commandID = cast(command)((commandbyte & 0x1C) >> 2);
			if (commandID == command.EXTENDCOMMAND) //End of data
				break;
			input.read(commandbyte2);
			commandLength = ((commandbyte & 3) << 8) + commandbyte2 + 1;
			debug writeln("Extended command");
		}
		debug writeln("Command: ", commandID);
		debug writeln("Length: ", commandLength);
		if ((commandID >= command.BUFFERCOPY) && (commandID < command.EXTENDCOMMAND)) { //Read buffer position
			input.read(tmp);
			input.read(tmp2);
			bufferpos = (tmp << 8) + tmp2;
			debug writefln("Buffer range: [%d..%d]", bufferpos, bufferpos+commandLength);
			assert(bufferpos < BANKSIZE, "Buffer position exceeds bank size!");
			assert(bufferpos < decompSize, "Buffer contents at position unknown!");
		}
		if (commandID == command.UNCOMPRESSED) { //Following data is uncompressed
			uncompbuff = new ubyte[commandLength];
			input.read(uncompbuff);
			buffer[decompSize..decompSize+commandLength] = uncompbuff;
		} else if (commandID == command.BYTEFILL) { //Fill range with following byte
			input.read(tmp);
			buffer[decompSize..decompSize+commandLength] = tmp;
		} else if (commandID == command.SHORTFILL) { //Fill range with following short
			input.read(tmp);
			input.read(tmp2);
			commandLength *= 2;
			buffer[decompSize..decompSize+commandLength].fill([tmp,tmp2]);
		} else if (commandID == command.BYTEFILLINCREASING) { //Fill range with increasing byte, beginning with following value
			input.read(tmp);
			buffer[decompSize..decompSize+commandLength] = tmp.increaseval(commandLength);
		} else if (commandID == command.BUFFERCOPY) //Copy from buffer
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength];
		else if (commandID == command.BITREVERSEDBUFFERCOPY) //Copy from buffer, but with reversed bits
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength].dup.reversebits;
		else if (commandID == command.BYTEREVERSEDBUFFERCOPY) //Copy from buffer, but with reversed bytes
			buffer[decompSize..decompSize+commandLength] = buffer[bufferpos-commandLength+1..bufferpos+1].dup.reverse;
		decompSize += commandLength;
		debug writeln("----------------");
	}
	debug writeln("----------------");
	compressedSize = cast(int)input.position - offset;
	buffer.length = decompSize;
	debug writeln("Final data: ", buffer);
	return buffer;
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
@safe ubyte[] increaseval(ubyte input, int length) {
	ubyte[] output = new ubyte[length];
	foreach(ref val; output)
		val = input++;
	return output;
}