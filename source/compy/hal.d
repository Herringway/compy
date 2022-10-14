module compy.hal;

import compy.common;

import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.traits;
debug import std.stdio;

private static immutable (ubyte[] function(const(ubyte)[] input, const(ubyte)[] buffer, out ushort size) @safe pure nothrow)[] compFuncsV1 = [ &repeatByte, &repeatWord, &zeroFill, &bufferCopy, &bitReverseBufferCopy, &byteReverseBufferCopy ];
private static immutable (ubyte[] function(const(ubyte)[] input, const(ubyte)[] buffer, out ushort size) @safe pure nothrow)[] compFuncsV2 = [ &repeatByte, &repeatWord, &incByteFill, &bufferCopy, &bitReverseBufferCopy, &byteReverseBufferCopy ];

private enum BANKSIZE = 0x10000;
private enum Command : ubyte { uncompressed = 0, byteFill, shortFill, byteFillIncreasing, zeroFill = byteFillIncreasing, bufferCopy, bitReversedBufferCopy, byteReversedBufferCopy, extend}


///Older format used in pokemon games
struct HALLZ1 {
	static ubyte[] comp(const(ubyte)[] input) @safe {
		const(ubyte)[] buffer = input;
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
	static ubyte[] decomp(const(ubyte)[] input) @safe {
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
	static ubyte[] comp(const(ubyte)[] input) @safe {
		const(ubyte)[] buffer = input;
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
	static ubyte[] decomp(const(ubyte)[] input) @safe {
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
