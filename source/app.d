import std.stdio;
import std.stream;
import std.format;

int main(string[] argv)
{
	if (argv.length < 4) {
		stderr.writefln("Usage: %s romfile offset datafile", argv[0]);
		return 1;
	}
	version(comp) {
		import comp;
		auto inputFile = new std.stream.File(argv[1], FileMode.In);
		auto compdata = comp.comp(inputFile);
		auto file = new std.stream.File(argv[3], FileMode.Out);
		file.position = parseOffset(argv[2]);
		file.write(compdata);
		writefln("Compression ratio: %d/%d", compdata.length, inputFile.size);
	} else {
		import decomp;
		int compsize;
		auto output = decomp.decomp(new std.stream.File(argv[1], FileMode.In), parseOffset(argv[2]), compsize);

		if (argv[3] == "-")
			stdout.rawWrite(output);
		else
			(new std.stdio.File(argv[3], "wb")).rawWrite(output);

		writefln("Compression ratio: %d/%d", compsize, output.length);
	}
	return 0;
}
ulong parseOffset(string arg) {
	ulong offset;
	if (arg[1] == 'x')
		formattedRead(arg, "0x%x", &offset);
	else
		formattedRead(arg, "%s", &offset);
	return offset;
}