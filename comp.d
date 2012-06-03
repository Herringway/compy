module comp;

import std.algorithm;
import std.array;
debug import std.stdio;

ubyte[] function(ubyte[] input, ubyte[] buffer, out ushort size)[] compFuncs = [ &repeatByte, &repeatWord, &incByteFill, &bufferCopy, &bitReverseBufferCopy, &byteReverseBufferCopy ];

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
			debug writefln("Method %d: %f", k, tmpRatio);
			if (tmpRatio > ratio) {
				debug writeln("Candidate found: ", k);
				method = cast(byte)k;
				tmpBuffer = tmpBuffer2;
				ratio = tmpRatio;
				size = tmpSize;
			}
		}
		if (tmpBuffer.length == 0) {
			debug writeln("adding to uncompressed buffer");
			uncompBuffer ~= input[0];
			bufferPos++;
			size = 1;
		} else {
			debug writeln("Using method ", method);
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
	debug writeln("Compressed size: ", output.length + 1);
	return output ~ 0xFF;
}

private ubyte[] uncompdata(ubyte[] input, out ushort size) {
	size = cast(ushort)min(input.length,1024);
	return buildCommand(0, size, input[0..size]);
}
private ubyte[] repeatByte(ubyte[] input, ubyte[] buffer, out ushort size) {
	ubyte match = input[0];
	foreach (val; input) {
		if ((val != match) || (size == 1024))
			break;
		size++;
	}
	return buildCommand(1, size, match);
}
private ubyte[] repeatWord(ubyte[] input, ubyte[] buffer, out ushort size) {
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
private ubyte[] incByteFill(ubyte[] input, ubyte[] buffer, out ushort size) {
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
private ubyte[] bufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	if (input.empty || buffer.empty)
		return [];
	size = cast(ushort)min(input.length, 1024);
	debug writeln(buffer);
	int tmp = -1;
	while ((tmp == -1) && (size > 0)) {
		tmp = countUntil(buffer, input[0..size--]);
	}
	return buildCommand(4, size, cast(ushort)tmp);
}
private ubyte[] bitReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	return [];
}
private ubyte[] byteReverseBufferCopy(ubyte[] input, ubyte[] buffer, out ushort size) {
	return [];
}
private ubyte[] buildCommand(ubyte ID, ushort length, ubyte payLoad) {
	return buildCommand(ID,length,[payLoad]);
}
private ubyte[] buildCommand(ubyte ID, ushort length, ushort payLoad) {
	return buildCommand(ID,length,[payLoad&0xFF, payLoad>>8]);
}
private ubyte[] buildCommand(ubyte ID, ushort length, ubyte[] payLoad) {
	ubyte[] output;
	if (length <= 32) {
		output = new ubyte[payLoad.length+1];
		output[0] = cast(ubyte)((ID<<5) + ((length-1)&0x1F));
	} else {
		debug writeln("Writing extended command");
		output = new ubyte[payLoad.length+2];
		output[0] =  cast(ubyte)(0xE0 + (ID<<2) + ((length-1)>>8));
		output[1] = (length-1)&0xFF;
	}
	output[$-payLoad.length..$] = payLoad;
	return output;
}