module compy.hal;

import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.traits;
debug import std.stdio;

private static immutable (ubyte[] function(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow)[] compFuncsV1 = [ &repeatByte, &repeatWord, &zeroFill, &bufferCopy, &bitReverseBufferCopy, &byteReverseBufferCopy ];
private static immutable (ubyte[] function(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow)[] compFuncsV2 = [ &repeatByte, &repeatWord, &incByteFill, &bufferCopy, &bitReverseBufferCopy, &byteReverseBufferCopy ];

private enum BANKSIZE = 0x10000;
private enum Command : ubyte { uncompressed = 0, byteFill, shortFill, byteFillIncreasing, zeroFill = byteFillIncreasing, bufferCopy, bitReversedBufferCopy, byteReversedBufferCopy, extend}


///Older format used in pokemon games
struct HALLZ1 {
	static ubyte[] comp(ubyte[] input) @safe {
		ubyte[] buffer = input;
		ubyte[] output, tmpBuffer, tmpBuffer2, uncompBuffer;
		ushort size, tmpSize, uncompSize;
		short bufferPos = -1;
		byte method;
		float ratio;
		float tmpRatio;
		while (input.length > 0) {
			ratio = 1.0;
			method = -1;
			tmpBuffer = [];
			foreach (k, compFunc; compFuncsV1) {
				tmpBuffer2 = compFunc(input, buffer[0..bufferPos+1], tmpSize);
				tmpRatio = cast(float)tmpSize / cast(float)tmpBuffer2.length;
				debug(verbosecomp) writefln("Method %d: %f", k, tmpRatio);
				if (tmpRatio > ratio) {
					debug(verbosecomp) writeln("Candidate found: ", k);
					method = cast(byte)k;
					tmpBuffer = tmpBuffer2;
					ratio = tmpRatio;
					size = tmpSize;
				}
			}
			if (tmpBuffer.length == 0) {
				uncompBuffer ~= input[0];
				bufferPos++;
				size = 1;
			} else {
				debug(verbosecomp) writeln("Selecting method ", method);
				bufferPos += tmpBuffer.length;
				while (uncompBuffer.length > 0) {
					output ~= uncompdata(uncompBuffer, uncompSize);
					uncompBuffer = uncompBuffer[uncompSize..$];
				}
				output ~= tmpBuffer;
			}
			input = input[size..$];
		}
		while (uncompBuffer.length > 0) {
			output ~= uncompdata(uncompBuffer, uncompSize);
			uncompBuffer = uncompBuffer[uncompSize..$];
		}
		debug(verbosecomp) writefln("Compressed size: %d/%d (%0.2f)", output.length + 1, buffer.length, (cast(double)output.length + 1.0) / cast(double)buffer.length * 100.0);
		return output ~ 0xFF;
	}
	static ubyte[] decomp(ubyte[] input) @safe {
		size_t throwAway;
		return decomp(input, throwAway);
	}
	static ubyte[] decomp(T)(T input, out size_t compressedSize) if (isInputRange!T) {
		ubyte[] buffer = new ubyte[](BANKSIZE);
		ubyte commandbyte;
		Command commandID;
		ushort commandLength;
		ushort bufferpos;
		int decompSize = 0;
		decompLoop: while(decompSize < BANKSIZE) { //decompressed data cannot exceed 64KB
			commandbyte = input.readByte();
			compressedSize++;
			commandID = cast(Command)(commandbyte >> 5);
			if (commandID == Command.extend) { //Extend length of command
				commandID = cast(Command)((commandbyte & 0x1C) >> 2);
				if (commandID != Command.extend) { //Double extend does not have a length
					commandLength = ((commandbyte & 3) << 8) + input.readByte() + 1;
					compressedSize++;
				}
			} else {
				commandLength = (commandbyte & 0x1F) + 1;
			}
			debug(verbosecomp) writeln(commandID, ", ", commandLength);
			if ((commandID >= Command.bufferCopy) && (commandID < Command.extend)) { //Read buffer position
				const next = input.readByte();
				bufferpos = next >= 0x80 ? 	cast(ushort)(decompSize - (next & 0x7F) - 1) : ((next << 8) + input.readByte());
				debug(verbosecomp) writeln("\t", next, ", ", bufferpos);
				compressedSize += next > 0x80 ? 1 : 2;
			}
			with(Command) final switch(commandID) {
				case uncompressed: //Following data is uncompressed
					copy(input.takeExactly(commandLength), buffer[decompSize..decompSize+commandLength]);
					input.popFrontN(commandLength);
					compressedSize += commandLength;
					break; //copy uncompressed data directly into buffer
				case byteFill: //Fill range with following byte
					buffer[decompSize..decompSize+commandLength] = input.readByte();
					compressedSize++;
					break;
				case shortFill: //Fill range with following short
					(cast(ushort[])buffer[decompSize..decompSize+commandLength*2])[] = cast(ushort)(input.readByte() + (input.readByte() << 8));
					compressedSize += 2;
					break;
				case zeroFill: //Fill range with zeroes
					buffer[decompSize..decompSize+commandLength] = 0;
					break;
				case bufferCopy: //Copy from buffer
					copy(buffer[bufferpos..bufferpos+commandLength], buffer[decompSize..decompSize+commandLength]);
					break;
				case bitReversedBufferCopy: //Copy from buffer, but with reversed bits
					copy(buffer[bufferpos..bufferpos+commandLength].map!reversebits, buffer[decompSize..decompSize+commandLength]);
					break;
				case byteReversedBufferCopy: //Copy from buffer, but with reversed bytes
					copy(buffer[bufferpos-commandLength+1..bufferpos+1].retro, buffer[decompSize..decompSize+commandLength]);
					break;
				case extend: break decompLoop;
			}
			debug(verbosecomp) writefln!"[%(%02X %)]"(buffer[decompSize..decompSize+commandLength]);
			decompSize += commandLength;
		}
		buffer.length = decompSize;
		return buffer;
	}
}
///Newer format used in later games (Earthbound, Kirby's Super Star)
struct HALLZ2 {
	static ubyte[] comp(ubyte[] input) @safe {
		ubyte[] buffer = input;
		ubyte[] output, tmpBuffer, tmpBuffer2, uncompBuffer;
		ushort size, tmpSize, uncompSize;
		short bufferPos = -1;
		byte method;
		float ratio;
		float tmpRatio;
		while (input.length > 0) {
			ratio = 1.0;
			method = -1;
			tmpBuffer = [];
			foreach (k, compFunc; compFuncsV2) {
				tmpBuffer2 = compFunc(input, buffer[0..bufferPos+1], tmpSize);
				tmpRatio = cast(float)tmpSize / cast(float)tmpBuffer2.length;
				debug(verbosecomp) writefln("Method %d: %f", k, tmpRatio);
				if (tmpRatio > ratio) {
					debug(verbosecomp) writeln("Candidate found: ", k);
					method = cast(byte)k;
					tmpBuffer = tmpBuffer2;
					ratio = tmpRatio;
					size = tmpSize;
				}
			}
			if (tmpBuffer.length == 0) {
				uncompBuffer ~= input[0];
				bufferPos++;
				size = 1;
			} else {
				debug(verbosecomp) writeln("Selecting method ", method);
				bufferPos += tmpBuffer.length;
				while (uncompBuffer.length > 0) {
					output ~= uncompdata(uncompBuffer, uncompSize);
					uncompBuffer = uncompBuffer[uncompSize..$];
				}
				output ~= tmpBuffer;
			}
			input = input[size..$];
		}
		while (uncompBuffer.length > 0) {
			output ~= uncompdata(uncompBuffer, uncompSize);
			uncompBuffer = uncompBuffer[uncompSize..$];
		}
		debug(verbosecomp) writefln("Compressed size: %d/%d (%0.2f)", output.length + 1, buffer.length, (cast(double)output.length + 1.0) / cast(double)buffer.length * 100.0);
		return output ~ 0xFF;
	}
	static ubyte[] decomp(ubyte[] input) @safe {
		size_t throwAway;
		return decomp(input, throwAway);
	}
	static ubyte[] decomp(T)(T input, out size_t compressedSize) if (isInputRange!T) {
		ubyte[] buffer = new ubyte[](BANKSIZE);
		ubyte commandbyte = void;
		Command commandID = void;
		ushort commandLength = void, bufferpos = void;
		int decompSize = 0;
		decompLoop: while(decompSize < BANKSIZE) { //decompressed data cannot exceed 64KB
			commandbyte = input.readByte();
			compressedSize++;
			commandID = cast(Command)(commandbyte >> 5);
			if (commandID == Command.extend) { //Extend length of command
				commandID = cast(Command)((commandbyte & 0x1C) >> 2);
				if (commandID != Command.extend) { //Double extend does not have a length
					commandLength = ((commandbyte & 3) << 8) + input.readByte() + 1;
					compressedSize++;
				}
			} else {
				commandLength = (commandbyte & 0x1F) + 1;
			}
			if ((commandID >= Command.bufferCopy) && (commandID < Command.extend)) { //Read buffer position
				bufferpos = (input.readByte() << 8) + input.readByte();
				compressedSize += 2;
				enforce(bufferpos < BANKSIZE, "Buffer position exceeds bank size!");
				enforce(bufferpos < decompSize, "Buffer contents at position unknown!");
			}
			debug(verbosecomp) writeln(commandID, ", ", commandLength, ", ", bufferpos);
			with(Command) final switch(commandID) {
				case uncompressed: //Following data is uncompressed
					buffer[decompSize..decompSize+commandLength] = array(input.takeExactly(commandLength));
					input.popFrontN(commandLength);
					compressedSize += commandLength;
					break; //copy uncompressed data directly into buffer
				case byteFill: //Fill range with following byte
					buffer[decompSize..decompSize+commandLength] = input.readByte();
					compressedSize++;
					break;
				case shortFill: //Fill range with following short
					commandLength *= 2;
					(cast(ushort[])buffer[decompSize..decompSize+commandLength])[] = cast(ushort)(input.readByte() + (input.readByte() << 8));
					compressedSize += 2;
					break;
				case byteFillIncreasing: //Fill range with increasing byte, beginning with following value
					buffer[decompSize..decompSize+commandLength] = increaseval(input.readByte(), commandLength);
					compressedSize++;
					break;
				case bufferCopy: //Copy from buffer
					buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength];
					break;
				case bitReversedBufferCopy: //Copy from buffer, but with reversed bits
					copy(buffer[bufferpos..bufferpos+commandLength].map!reversebits, buffer[decompSize..decompSize+commandLength]);
					break;
				case byteReversedBufferCopy: //Copy from buffer, but with reversed bytes
					copy(buffer[bufferpos-commandLength+1..bufferpos+1].retro, buffer[decompSize..decompSize+commandLength]);
					break;
				case extend: break decompLoop;
			}
			decompSize += commandLength;
		}
		buffer.length = decompSize;
		return buffer;
	}
}
@safe unittest {
	void comptest(ubyte[] input, string msg, int idealsize = -1) @safe {
		auto data = HALLZ2.comp(input);
		assert(HALLZ2.decomp(data) == input, "Comp: " ~ msg);
		//if (idealsize >= 0)
		//	assert(data.length == idealsize, "Comp: " ~ msg ~ " ideal size");
	}

	comptest([1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], "Byte-fill Compression");
	comptest([1,2,1,2,1,2,1,2,1,2,1,2,1,2], "Word-fill Compression");
	comptest([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15], "Increasing Byte-fill Compression");
	comptest([1,3,3,3,3,3,7,1,3,3,3,3,3,7,1,3,3,3,3,3,7], "Buffer Compression", 13);
	comptest([1,3,3,3,3,3,7,7,3,3,3,3,3,1,7,3,3,3,3,3,1], "Reverse Buffer Compression", 13);
	comptest([1,3,3,3,3,3,7,128,192,192,192,192,192,224,128,192,192,192,192,192,224], "Bit-reversed Buffer Compression", 13);
	ubyte[] testArray = new ubyte[513];
	testArray[] = 1;
	comptest(testArray, "Extended byte-fill", 4);
}

private ubyte[] uncompdata(ubyte[] input, out ushort size) @safe {
	size = cast(ushort)min(input.length,1024);
	return buildCommand(0, size, input[0..size]);
}
@safe pure nothrow private ubyte[] repeatByte(ubyte[] input, ubyte[] buffer, out ushort size) {
	ubyte match = input[0];
	foreach (val; input) {
		if ((val != match) || (size == 1024))
			break;
		size++;
	}
	return buildCommand(1, size, match);
}
@safe pure nothrow private ubyte[] repeatWord(ubyte[] input, ubyte[] buffer, out ushort size) {
	if (input.length < 2)
		return [];
	ubyte[] match = input[0..2];
	foreach (k, val; input) {
		if ((val != match[k%2]) || (size == 1024))
			break;
		if (k%2 == 1)
			size++;
	}
	size *= 2;
	return buildCommand(2,size/2, match);
}
@safe pure nothrow private ubyte[] incByteFill(ubyte[] input, ubyte[] buffer, out ushort size) {
	ubyte initialVal, tmpVal;
	initialVal = tmpVal = input[0];
	size = 1;
	foreach (k, val; input[1..$]) {
		if (++tmpVal != val)
			break;
		size++;
	}
	return buildCommand(3,size,initialVal);
}
@safe pure nothrow private ubyte[] zeroFill(ubyte[] input, ubyte[] buffer, out ushort size) {
	size = 0;
	foreach (k, val; input[1..$]) {
		if (val != 0) {
			break;
		}
		size++;
	}
	return buildCommand(3, size, []);
}
@safe pure nothrow private ubyte[] bufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	if (input.empty || buffer.empty)
		return [];
	size = cast(ushort)min(input.length, 1024);
	long tmp = -1;
	while ((tmp == -1) && (size > 0)) {
		tmp = countUntil(buffer, input[0..size--]);
	}
	return buildCommand(4, size, cast(ushort)tmp);
}
@safe pure nothrow private ubyte[] bitReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	return buildCommand(5, 0, []);
}
@safe pure nothrow private ubyte[] byteReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	return buildCommand(6, 0, []);
}
@safe pure nothrow private ubyte[] buildCommand(ubyte ID, ushort length, ubyte payLoad) {
	return buildCommand(ID,length,[payLoad]);
}
@safe pure nothrow private ubyte[] buildCommand(ubyte ID, ushort length, ushort payLoad) {
	return buildCommand(ID,length,[payLoad&0xFF, payLoad>>8]);
}
@safe pure nothrow private ubyte[] buildCommand(ubyte ID, ushort length, ubyte[] payLoad) {
	ubyte[] output;
	if (length == 0) {
		return [];
	} else if (length <= 32) {
		output = new ubyte[payLoad.length+1];
		output[0] = cast(ubyte)((ID<<5) + ((length-1)&0x1F));
	} else {
		output = new ubyte[payLoad.length+2];
		output[0] =  cast(ubyte)(0xE0 + (ID<<2) + ((length-1)>>8));
		output[1] = (length-1)&0xFF;
	}
	output[$-payLoad.length..$] = payLoad;
	return output;
}

ubyte readByte(T)(ref T file) {
	auto v = file.front;
	file.popFront();
	return v;
}
@safe unittest {
	assertThrown(HALLZ2.decomp([0x80, 0xFF, 0x00, 0xFF]) == [], "Decomp: Uninitialized buffer");

	void decomptest(ubyte[] input, ubyte[] output, string msg) {
		import std.conv : text;
		size_t finalSize;
		auto data = HALLZ2.decomp(input, finalSize);
		assert(data == output, text("Decomp: ", msg, " ", data, " != ", output));
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

const(ubyte)[] increaseval(ubyte input, in int length) pure nothrow @safe {
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
ubyte reversebits(ubyte input) @safe pure nothrow @nogc {
	ubyte val = input;
	val = ((val >> 1) & 0x55) | ((val << 1) & 0xAA);
	val = ((val >> 2) & 0x33) | ((val << 2) & 0xCC);
	val = ((val >> 4) & 0x0F) | ((val << 4) & 0xF0);
	return val;
}
ushort reversebits(ushort input) @safe pure nothrow @nogc {
	ushort val = input;
	val = ((val & 0x5555) << 1) | ((val & 0xAAAA) >> 1);
	val = ((val & 0x3333) << 2) | ((val & 0xCCCC) >> 2);
	val = ((val & 0x0F0F) << 4) | ((val & 0xF0F0) >> 4);
	val = ((val & 0x00FF) << 8) | ((val & 0xFF00) >> 8);
	return val;
}
uint reversebits(uint input) @safe pure nothrow @nogc {
	uint val = input;
	val = ((val & 0x55555555) << 1) | ((val & 0xAAAAAAAA) >> 1);
	val = ((val & 0x33333333) << 2) | ((val & 0xCCCCCCCC) >> 2);
	val = ((val & 0x0F0F0F0F) << 4) | ((val & 0xF0F0F0F0) >> 4);
	val = ((val & 0x00FF00FF) << 8) | ((val & 0xFF00FF00) >> 8);
	val = ((val & 0x0000FFFF) << 16) | ((val & 0xFFFF0000) >> 16);
	return val;
}
pure nothrow @nogc @safe unittest {
	assert(cast(ubyte)1.reversebits == cast(ubyte)128, "Bit reversal: algorithm");
	assert(cast(uint)0x80000000.reversebits == 1, "Bit reversal: int");
}
