module compy.nintendo;

import compy.common;

import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.traits;

enum BANKSIZE = 0x10000;
private static immutable (ubyte[] function(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow)[] compFuncsV1 = [ &repeatByte, &repeatWord, &incByteFill, &bufferCopyBigEndian ];
private static immutable (ubyte[] function(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow)[] compFuncsV2 = [ &repeatByte, &repeatWord, &incByteFill, &bufferCopy ];

private enum NintendoCommand1 : ubyte { uncompressed = 0, byteFill, shortFill, byteFillIncreasing, bufferCopy, unused1, unused2, extend }

/// Format used in early SNES games by Nintendo. Also known as LC_LZ1.
struct NintendoLZ1 {
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
		NintendoCommand1 commandID = void;
		ushort commandLength = void;
		int decompSize = 0;
		decompLoop: while(decompSize < BANKSIZE) { //decompressed data cannot exceed 64KB
			commandbyte = input.readByte();
			compressedSize++;
			commandID = cast(NintendoCommand1)(commandbyte >> 5);
			if (commandID == NintendoCommand1.extend) { //Extend length of command
				commandID = cast(NintendoCommand1)((commandbyte & 0x1C) >> 2);
				if (commandID != NintendoCommand1.extend) { //Double extend does not have a length
					commandLength = ((commandbyte & 3) << 8) + input.readByte() + 1;
					compressedSize++;
				}
			} else {
				commandLength = (commandbyte & 0x1F) + 1;
			}
			debug(verbosecomp) writeln(commandID, ", ", commandLength);
			final switch(commandID) {
				case NintendoCommand1.uncompressed: //Following data is uncompressed
					buffer[decompSize..decompSize+commandLength] = array(input.takeExactly(commandLength));
					input.popFrontN(commandLength);
					compressedSize += commandLength;
					break; //copy uncompressed data directly into buffer
				case NintendoCommand1.byteFill: //Fill range with following byte
					buffer[decompSize..decompSize+commandLength] = input.readByte();
					compressedSize++;
					break;
				case NintendoCommand1.shortFill: //Fill range with following short
					commandLength *= 2;
					(cast(ushort[])buffer[decompSize..decompSize+commandLength])[] = cast(ushort)(input.readByte() + (input.readByte() << 8));
					compressedSize += 2;
					break;
				case NintendoCommand1.byteFillIncreasing: //Fill range with increasing byte, beginning with following value
					buffer[decompSize..decompSize+commandLength] = increaseval(input.readByte(), commandLength);
					compressedSize++;
					break;
				case NintendoCommand1.bufferCopy: //Copy from buffer
					const ushort bufferpos = input.readByte() + (input.readByte() << 8);
					compressedSize += 2;
					enforce(bufferpos < BANKSIZE, "Buffer position exceeds bank size!");
					enforce(bufferpos < decompSize, "Buffer contents at position unknown!");
					buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength];
					break;
				case NintendoCommand1.unused1:
					throw new Exception("Invalid compressed data - reserved command 1");
				case NintendoCommand1.unused2:
					throw new Exception("Invalid compressed data - reserved command 2");
				case NintendoCommand1.extend: break decompLoop;
			}
			decompSize += commandLength;
		}
		buffer.length = decompSize;
		return buffer;
	}
}
/// Format used in early SNES games by Nintendo. Identical to NintendoLZ1, except 'bufferCopy' is big endian. Also known as LC_LZ2.
struct NintendoLZ2 {
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
		NintendoCommand1 commandID = void;
		ushort commandLength = void;
		int decompSize = 0;
		decompLoop: while(decompSize < BANKSIZE) { //decompressed data cannot exceed 64KB
			commandbyte = input.readByte();
			compressedSize++;
			commandID = cast(NintendoCommand1)(commandbyte >> 5);
			if (commandID == NintendoCommand1.extend) { //Extend length of command
				commandID = cast(NintendoCommand1)((commandbyte & 0x1C) >> 2);
				if (commandID != NintendoCommand1.extend) { //Double extend does not have a length
					commandLength = ((commandbyte & 3) << 8) + input.readByte() + 1;
					compressedSize++;
				}
			} else {
				commandLength = (commandbyte & 0x1F) + 1;
			}
			debug(verbosecomp) writeln(commandID, ", ", commandLength);
			final switch(commandID) {
				case NintendoCommand1.uncompressed: //Following data is uncompressed
					buffer[decompSize..decompSize+commandLength] = array(input.takeExactly(commandLength));
					input.popFrontN(commandLength);
					compressedSize += commandLength;
					break; //copy uncompressed data directly into buffer
				case NintendoCommand1.byteFill: //Fill range with following byte
					buffer[decompSize..decompSize+commandLength] = input.readByte();
					compressedSize++;
					break;
				case NintendoCommand1.shortFill: //Fill range with following short
					commandLength *= 2;
					(cast(ushort[])buffer[decompSize..decompSize+commandLength])[] = cast(ushort)(input.readByte() + (input.readByte() << 8));
					compressedSize += 2;
					break;
				case NintendoCommand1.byteFillIncreasing: //Fill range with increasing byte, beginning with following value
					buffer[decompSize..decompSize+commandLength] = increaseval(input.readByte(), commandLength);
					compressedSize++;
					break;
				case NintendoCommand1.bufferCopy: //Copy from buffer
					const ushort bufferpos = (input.readByte() << 8) + input.readByte();
					compressedSize += 2;
					enforce(bufferpos < BANKSIZE, "Buffer position exceeds bank size!");
					enforce(bufferpos < decompSize, "Buffer contents at position unknown!");
					buffer[decompSize..decompSize+commandLength] = buffer[bufferpos..bufferpos+commandLength];
					break;
				case NintendoCommand1.unused1:
					throw new Exception("Invalid compressed data - reserved command 1");
				case NintendoCommand1.unused2:
					throw new Exception("Invalid compressed data - reserved command 2");
				case NintendoCommand1.extend: break decompLoop;
			}
			decompSize += commandLength;
		}
		buffer.length = decompSize;
		return buffer;
	}
}
