import std.stdio;
import std.stream;

import comp;
import decomp;

unittest {
	void test(lazy bool expr, string label, bool expectException = false) {
		write("[DECOMP] ");
		try
			write(expr ? "PASSED" : "FAILED");
		catch (Throwable e)
			write(expectException ? "PASSED" : "FAILED: " ~ e.msg);
		writeln(" " ~ label);
	}
	void dcomptest(ubyte[] input, ubyte[] output, string msg, bool printResult = false) {
		int finalSize;
		if (printResult)
			writeln(decomp.decomp(input, finalSize));
		test(decomp.decomp(input, finalSize) == output, "Decomp: " ~ msg);
		test(finalSize == input.length, "Decomp: " ~ msg ~ " size");
	}
	import std.exception;
	test([0,1,2].stripe(10) == [0, 1, 2, 0, 1, 2, 0, 1, 2, 0], "Striping: Int");
	test(["hi","sup"].stripe(4) == ["hi", "sup", "hi", "sup"], "Striping: String");
	ubyte[] testv;
	test(testv.stripe(2) == [], "Striping: Null input exception", true);

	test((0).increaseval(1) == [0], "Increaseval: First value unaltered");
	test((0).increaseval(3) == [0, 1, 2], "Increaseval: algorithm");
	test((255).increaseval(3) == [255, 0, 1], "Increaseval: Wrapping values");
	test((0).increaseval(0) == [], "Increaseval: Void");

	test([1].reversebits == [128], "Bit reversal: algorithm");
	test([1, 2, 4, 5].reversebits == [128, 64, 32, 160], "Bit reversal: array");
	test("HELLO".reversebits == [18, 162, 50, 50, 242], "Bit reversal: string");
	test([].reversebits == [], "Bit reversal: void");
	ubyte[] testArray = [0x63, 0x00, 0xFF];
	test(decomp.decomp(testArray) == decomp.decomp(new MemoryStream(testArray)), "Decomp: Stream == array");

	testArray = [0x80, 0xFF, 0x00, 0xFF];
	test(decomp.decomp(testArray) == [], "Decomp: Uninitialized buffer", true);

	dcomptest([0x03, 1, 3, 3, 7, 0xFF], [1, 3, 3, 7], "Uncompressed data");
	dcomptest([0x21, 1, 0xFF], [1, 1], "Byte fill");
	dcomptest([0x41, 1, 2, 0xFF], [1, 2, 1, 2], "Word fill");
	dcomptest([0x63, 0, 0xFF], [0, 1, 2, 3], "Decomp: Increasing value");
	dcomptest([0x61, 1, 0x80, 0, 0, 0xFF], [1, 2, 1], "Buffer copy");
	dcomptest([0x61, 1, 0xA0, 0, 0, 0xFF], [1, 2, 128], "Bit-reversed Buffer copy");
	dcomptest([0x61, 1, 0xC1, 0, 1, 0xFF], [1, 2, 2, 1], "Byte-reversed buffer copy");
	ubyte[] extended = new ubyte[513];
	extended[] = 1;
	dcomptest([0xE6, 0, 1, 0xFF], extended, "Extended byte fill");

	test(decomp.decomp(comp.comp([1,3,3,7])) == [1,3,3,7], "Compression");
}