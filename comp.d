module comp;

import std.algorithm;

ubyte[] comp(ubyte[] input) {
	ubyte[] output;
	int size;
	while (input.length > 0) {
		output ~= uncompdata(input, size);
		input = input[size..$];
	}
	return output ~ 0xFF;
}

private ubyte[] uncompdata(ubyte[] input, out int size) {
	ubyte[] output;
	if (input.length <= 32)
		output ~= (input.length-1)&0x1F;
	else if (input.length <= 1024) {
		output ~= 0xE0 + (((input.length-1)&0x3)>>8);
		output ~= ((input.length-1)&0xFF);
	}
	size = input.length;
	output ~= input[0..min($,1024)];

	return output;
}