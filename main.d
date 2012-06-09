module main;

import std.stdio;
import std.stream;
import std.format;

version(comp) import comp;
else import decomp;

int main(string[] argv)
{
	version(comp) {
		if (argv.length < 4) {
			stderr.writefln("Usage: %s romfile offset input", argv[0]);
			return 1;
		}
		auto inputFile = new std.stream.File(argv[3], FileMode.In);
		auto compdata = comp.comp(inputFile);
		auto file = new std.stream.File(argv[1], FileMode.Out);
		file.position = parseOffset(argv[2]);
		file.write(compdata);
		writefln("Compression ratio: %d/%d", compdata.length, inputFile.size);
		return 0;
	} else {
		if (argv.length < 4) {
			stderr.writefln("Usage: %s romfile offset output", argv[0]);
			return 1;
		}

		int compsize;
		auto output = decomp.decomp(new std.stream.File(argv[1], FileMode.In), parseOffset(argv[2]), compsize);

		if (argv[3] == "-")
			stdout.rawWrite(output);
		else
			(new std.stdio.File(argv[3], "wb")).rawWrite(output);

		writefln("Compression ratio: %d/%d", compsize, output.length);
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