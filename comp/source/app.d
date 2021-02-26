import std.algorithm;
import std.array;
import std.format;
import std.stdio;
import compy;

int main(string[] argv)
{
	if (argv.length < 4) {
		stderr.writefln("Usage: %s romfile offset datafile", argv[0]);
		return 1;
	}
	auto inputFile = File(argv[1], "r");
	auto compdata = HALLZ2.comp(inputFile.byChunk(4096).joiner().array);
	auto file = File(argv[3], "w+");
	file.seek(parseOffset(argv[2]));
	file.write(compdata);
	writefln("Compression ratio: %d/%d", compdata.length, inputFile.size);
	return 0;
}
