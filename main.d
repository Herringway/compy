module main;

import std.stdio;
import std.stream;
import std.format;

import pkhack.eb.decomp;

int main(string[] argv)
{
	version(unittest) {
		return 0;
	} else {
		int compsize;
		ubyte[] output;
		if (argv.length < 4) {
			stderr.writefln("Usage: %s romfile offset output", argv[0]);
			return 1;
		}

		output = decomp(new std.stream.File(argv[1], FileMode.In), parseOffset(argv[2]), compsize);

		if (argv[3] == "-")
			stdout.rawWrite(output);
		else
			(new std.stdio.File(argv[3], "wb")).rawWrite(output);

		writefln("Compression ratio: %d/%d (%0.2f%%)", compsize, output.length, cast(float)compsize/cast(float)output.length * 100);
		return 0;
	}
}
int parseOffset(string arg) {
	int offset;
	if (arg[1] == 'x')
		formattedRead(arg, "0x%x", &offset);
	else
		formattedRead(arg, "%s", &offset);
	return offset;
}