module compy.common;

import compy.hal;
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
	HALLZ2
}

ubyte[] decomp(Format format, ubyte[] input) @safe {
	size_t unused;
	return decomp(format, input, unused);
}
ubyte[] decomp(Format format, ubyte[] input, out size_t compressedSize) @safe {
	final switch (format) {
		case Format.HALLZ1: return HALLZ1.decomp(input, compressedSize);
		case Format.HALLZ2: return HALLZ2.decomp(input, compressedSize);
	}
}

ubyte[] comp(Format format, ubyte[] input) @safe {
	final switch (format) {
		case Format.HALLZ1: return HALLZ1.comp(input);
		case Format.HALLZ2: return HALLZ2.comp(input);
	}
}
