module comp;

import std.algorithm;
import std.array;
import std.stream;
debug import std.stdio;

@safe pure nothrow immutable ubyte[] function(ubyte[] input, ubyte[] buffer, out ushort size)[] compFuncs = [ &repeatByte, &repeatWord, &incByteFill, &bufferCopy, &bitReverseBufferCopy, &byteReverseBufferCopy ];

ubyte[] comp(std.stream.File input) {
	assert(input.size < 0x10000, "Cannot compress a file that large!");
	ubyte[] buf = new ubyte[cast(ushort)input.size];
	input.read(buf);
	return comp(buf);
}
ubyte[] comp(ubyte[] input) {
	ubyte[] buffer = input;
	ubyte[] output, tmpBuffer, tmpBuffer2, uncompBuffer;
	ushort size, tmpSize, uncompSize;
	short bufferPos = -1;
	byte method;
	float ratio;
	float tmpRatio;
	while (input.length > 0) {
		ratio = 1.0;
		method = -1;
		tmpBuffer = [];
		foreach (k, compFunc; compFuncs) {
			tmpBuffer2 = compFunc(input, buffer[0..bufferPos+1], tmpSize);
			tmpRatio = cast(float)tmpSize / cast(float)tmpBuffer2.length;
			//debug writefln("Method %d: %f", k, tmpRatio);
			if (tmpRatio > ratio) {
				//debug writeln("Candidate found: ", k);
				method = cast(byte)k;
				tmpBuffer = tmpBuffer2;
				ratio = tmpRatio;
				size = tmpSize;
			}
		}
		if (tmpBuffer.length == 0) {
			uncompBuffer ~= input[0];
			bufferPos++;
			size = 1;
		} else {
			//debug writeln("Selecting method ", method);
			bufferPos += tmpBuffer.length;
			while (uncompBuffer.length > 0) {
				output ~= uncompdata(uncompBuffer, uncompSize);
				uncompBuffer = uncompBuffer[uncompSize..$];
			}
			output ~= tmpBuffer;
		}
		input = input[size..$];
	}
	while (uncompBuffer.length > 0) {
		output ~= uncompdata(uncompBuffer, uncompSize);
		uncompBuffer = uncompBuffer[uncompSize..$];
	}
	//debug writefln("Compressed size: %d/%d (%0.2f)", output.length + 1, buffer.length, (cast(double)output.length + 1.0) / cast(double)buffer.length * 100.0);
	return output ~ 0xFF;
}
unittest {
	void comptest(ubyte[] input, string msg, int idealsize = -1) {
		import decomp;
		auto data = comp(input);
		assert(decomp.decomp(data) == input, "Comp: " ~ msg);
		//if (idealsize >= 0)
		//	assert(data.length == idealsize, "Comp: " ~ msg ~ " ideal size");
	}

	comptest([1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], "Byte-fill Compression");
	comptest([1,2,1,2,1,2,1,2,1,2,1,2,1,2], "Word-fill Compression");
	comptest([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15], "Increasing Byte-fill Compression");
	comptest([1,3,3,3,3,3,7,1,3,3,3,3,3,7,1,3,3,3,3,3,7], "Buffer Compression", 13);
	comptest([1,3,3,3,3,3,7,7,3,3,3,3,3,1,7,3,3,3,3,3,1], "Reverse Buffer Compression", 13);
	comptest([1,3,3,3,3,3,7,128,192,192,192,192,192,224,128,192,192,192,192,192,224], "Bit-reversed Buffer Compression", 13);
	ubyte[] testArray = new ubyte[513];
	testArray[] = 1;
	comptest(testArray, "Extended byte-fill", 4);
}

private ubyte[] uncompdata(ubyte[] input, out ushort size) {
	size = cast(ushort)min(input.length,1024);
	return buildCommand(0, size, input[0..size]);
}
@safe pure nothrow private ubyte[] repeatByte(ubyte[] input, ubyte[] buffer, out ushort size) {
	ubyte match = input[0];
	foreach (val; input) {
		if ((val != match) || (size == 1024))
			break;
		size++;
	}
	return buildCommand(1, size, match);
}
@safe pure nothrow private ubyte[] repeatWord(ubyte[] input, ubyte[] buffer, out ushort size) {
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
@safe pure nothrow private ubyte[] incByteFill(ubyte[] input, ubyte[] buffer, out ushort size) {
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
@safe pure nothrow private ubyte[] bufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	if (input.empty || buffer.empty)
		return [];
	size = cast(ushort)min(input.length, 1024);
	long tmp = -1;
	while ((tmp == -1) && (size > 0)) {
		tmp = countUntil(buffer, input[0..size--]);
	}
	return buildCommand(4, size, cast(ushort)tmp);
}
@safe pure nothrow private ubyte[] bitReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	return buildCommand(5, 0, []);
}
@safe pure nothrow private ubyte[] byteReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	return buildCommand(6, 0, []);
}
@safe pure nothrow private ubyte[] buildCommand(ubyte ID, ushort length, ubyte payLoad) {
	return buildCommand(ID,length,[payLoad]);
}
@safe pure nothrow private ubyte[] buildCommand(ubyte ID, ushort length, ushort payLoad) {
	return buildCommand(ID,length,[payLoad&0xFF, payLoad>>8]);
}
@safe pure nothrow private ubyte[] buildCommand(ubyte ID, ushort length, ubyte[] payLoad) {
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