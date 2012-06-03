import std.stdio;
import std.stream;
import std.conv;

import comp;
import decomp;

unittest {
	int passes = 0;
	int tests = 0;
	bool test(lazy bool expr, string label, bool expectException = false) {
		char[] output = "[DECOMP] ".dup;
		bool success = false;
		tests++;
		try {
			if (expr) {
				output ~= "PASSED";
				success = true;
			} else
				output ~= "FAILED";
		} catch (Throwable e) {
			output ~= (expectException ? "PASSED" : "FAILED: [" ~ e.msg ~ " on line " ~ text(e.line) ~ " of module " ~ e.file ~ "]");
			success = expectException;
		}
		writeln(output ~ " " ~ label);
		if (success)
			passes++;
		return success;
	}
	void testeqar(T, V)(T[] input, V[] output, string msg) {
		if (!test(input == output, msg))
			writeln(input);
	}
	void decomptest(ubyte[] input, ubyte[] output, string msg) {
		int finalSize;
		ubyte[] data = decomp.decomp(input, finalSize);
		if (!test(data == output, "Decomp: " ~ msg))
			writeln(data);
		if (!test(finalSize == input.length, "Decomp: " ~ msg ~ " size"))
			writeln(data);
	}
	void comptest(ubyte[] input, string msg, int idealsize = -1) {
		auto data = comp.comp(input);
		if (!test(decomp.decomp(data) == input, "Comp: " ~ msg))
			writeln(data);
		if (idealsize >= 0)
			if (!test(data.length == idealsize, "Comp: " ~ msg ~ " ideal size"))
				writeln(data);
	}

	testeqar((0).increaseval(1), [0], "Increaseval: First value unaltered");
	testeqar((0).increaseval(3), [0, 1, 2], "Increaseval: algorithm");
	testeqar((255).increaseval(3), [255, 0, 1], "Increaseval: Wrapping values");
	testeqar((0).increaseval(0), [], "Increaseval: Void");

	testeqar([cast(ubyte)1].reversebits, [cast(ubyte)128], "Bit reversal: algorithm");
	testeqar((cast(ubyte[])[1, 2, 4, 5]).reversebits, cast(ubyte[])[128, 64, 32, 160], "Bit reversal: array");
	testeqar("HELLO".reversebits, cast(string)[18, 162, 50, 50, 242], "Bit reversal: string");
	testeqar([].reversebits, [], "Bit reversal: void");
	testeqar([cast(uint)0x80000000].reversebits, [1], "Bit reversal: int");

	testeqar(decomp.decomp([0x63, 0x00, 0xFF]), decomp.decomp(new MemoryStream(cast(ubyte[])[0x63, 0x00, 0xFF])), "Decomp: Stream == array");

	test(decomp.decomp([0x80, 0xFF, 0x00, 0xFF]) == [], "Decomp: Uninitialized buffer", true);

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

	comptest([1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], "Byte-fill Compression");
	comptest([1,2,1,2,1,2,1,2,1,2,1,2,1,2], "Word-fill Compression");
	comptest([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15], "Increasing Byte-fill Compression");
	comptest([1,3,3,3,3,3,7,1,3,3,3,3,3,7,1,3,3,3,3,3,7], "Buffer Compression", 13);
	comptest([1,3,3,3,3,3,7,7,3,3,3,3,3,1,7,3,3,3,3,3,1], "Reverse Buffer Compression", 13);
	comptest([1,3,3,3,3,3,7,128,192,192,192,192,192,224,128,192,192,192,192,192,224], "Bit-reversed Buffer Compression", 13);
	comptest(testArray, "Extended byte-fill", 4);

	writefln("Tests completed: %d/%d", passes, tests);
}