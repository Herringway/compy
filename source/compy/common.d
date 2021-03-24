module compy.common;

import compy.hal;
import compy.nintendo;

import std.algorithm;
import std.format;

ulong parseOffset(string arg) {
	ulong offset;
	if ((arg.length > 1) && (arg[1] == 'x')) {
		formattedRead(arg, "0x%x", &offset);
	} else {
		formattedRead(arg, "%s", &offset);
	}
	return offset;
}

enum Format {
	HALLZ1,
	HALLZ2,
	NintendoLZ1,
	NintendoLZ2
}

ubyte[] decomp(Format format, ubyte[] input) @safe {
	size_t unused;
	return decomp(format, input, unused);
}
ubyte[] decomp(Format format, ubyte[] input, out size_t compressedSize) @safe {
	final switch (format) {
		case Format.HALLZ1: return HALLZ1.decomp(input, compressedSize);
		case Format.HALLZ2: return HALLZ2.decomp(input, compressedSize);
		case Format.NintendoLZ1: return NintendoLZ1.decomp(input, compressedSize);
		case Format.NintendoLZ2: return NintendoLZ2.decomp(input, compressedSize);
	}
}

ubyte[] comp(Format format, ubyte[] input) @safe {
	final switch (format) {
		case Format.HALLZ1: return HALLZ1.comp(input);
		case Format.HALLZ2: return HALLZ2.comp(input);
		case Format.NintendoLZ1: return NintendoLZ1.comp(input);
		case Format.NintendoLZ2: return NintendoLZ2.comp(input);
	}
}

package:

ubyte readByte(T)(ref T file) {
	import std.range : front, popFront;
	auto v = file.front;
	file.popFront();
	return v;
}

ubyte[] uncompdata(ubyte[] input, out ushort size) @safe {
	size = cast(ushort)min(input.length,1024);
	return buildCommand(0, size, input[0..size]);
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
ubyte[] repeatByte(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
	ubyte match = input[0];
	foreach (val; input) {
		if ((val != match) || (size == 1024))
			break;
		size++;
	}
	return buildCommand(1, size, match);
}
ubyte[] repeatWord(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
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
ubyte[] incByteFill(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
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
ubyte[] zeroFill(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
	size = 0;
	foreach (k, val; input[1..$]) {
		if (val != 0) {
			break;
		}
		size++;
	}
	return buildCommand(3, size, []);
}
ubyte[] bufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
	import std.range : empty;
	if (input.empty || buffer.empty)
		return [];
	size = cast(ushort)min(input.length, 1024);
	long tmp = -1;
	while ((tmp == -1) && (size > 0)) {
		tmp = countUntil(buffer, input[0..size--]);
	}
	return buildCommand(4, size, cast(ushort)tmp);
}
ubyte[] bufferCopyBigEndian(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
	import std.range : empty;
	if (input.empty || buffer.empty)
		return [];
	size = cast(ushort)min(input.length, 1024);
	long tmp = -1;
	while ((tmp == -1) && (size > 0)) {
		tmp = countUntil(buffer, input[0..size--]);
	}
	return buildCommandBE(4, size, cast(ushort)tmp);
}
ubyte[] bitReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
	return buildCommand(5, 0, []);
}
ubyte[] byteReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) @safe pure nothrow {
	return buildCommand(6, 0, []);
}
ubyte[] buildCommand(ubyte ID, ushort length, ubyte payLoad) @safe pure nothrow {
	return buildCommand(ID,length,[payLoad]);
}
ubyte[] buildCommand(ubyte ID, ushort length, ushort payLoad) @safe pure nothrow {
	return buildCommand(ID,length,[payLoad&0xFF, payLoad>>8]);
}
ubyte[] buildCommandBE(ubyte ID, ushort length, ushort payLoad) @safe pure nothrow {
	return buildCommand(ID,length,[payLoad>>8, payLoad&0xFF]);
}
ubyte[] buildCommand(ubyte ID, ushort length, ubyte[] payLoad) @safe pure nothrow {
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