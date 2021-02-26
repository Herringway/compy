import std.algorithm;
import std.array;
import std.format;
import std.getopt;
import std.stdio;
import compy;

int main(string[] argv)
{
	auto file = stdout;
	Format compressionFormat = Format.HALLZ2;
	auto help = getopt(argv,
		"output|o", "write to a file", (string x, string path) { file = File(path, "wb"); },
		"format|f", "compression format (HALLZ1, HALLZ2)", &compressionFormat
	);
	if (help.helpWanted || (argv.length < 3 )) {
		defaultGetoptPrinter(format!"Usage: %s romfile offset"(argv[0]), help.options);
		return 1;
	}
	size_t compsize;
	auto source = File(argv[1], "r");
	source.seek(parseOffset(argv[2]));
	auto output = decomp(compressionFormat, source.byChunk(4096).joiner.array, compsize);

	file.rawWrite(output);

	writefln("Compression ratio: %d/%d", compsize, output.length);
	return 0;
}
