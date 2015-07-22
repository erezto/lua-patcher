function Reader(arr, offset) {
	this.arr = arr;
	this.offset = offset;
}

Reader.prototype.Read = function (size, count) {
	var res;
	var from = this.offset; var to = from + (count*size);
	switch(size) {
		case 1:
			res = new Uint8Array(this.arr.subarray(from, to));
			this.offset = to;
			break;
		case 4:
			res = new Uint32Array(this.arr.subarray(from, to));
			this.offset = to;
			break;
		default:
			console.error('Canot read size ' + size);
	}
	return res;
}

function ConstantToString(cons){
	if (cons.type == 'nil') return 'nil';
	return cons.value + ' //' + cons.type;
}
function GetOp(bytes) {
	return bytes[0] & 0x3F;
}

function ParseUnknownInstruction(bytes) {
	var  parsed = {};
	parsed.OP=bytes[0] & 0x3F;
	parsed.ToString = function() {return "";};
	return parsed;
}

function ParseABCInstruction(bytes) {
	var  parsed = {}
	parsed.OP=bytes[0] & 0x3F;
	parsed.A = ((bytes[0] & 0xC0)>>6) + ((bytes[1] & 0x3F)<<2);
	parsed.C = ((bytes[1] & 0xC0)>>6) + ((bytes[2] & 0x7F)<<2);
	parsed.B=((bytes[2] & 0x80)>>7) + (bytes[3] <<1);
	parsed.ToString = function() {return "A:" + parsed.A + ", B:" + parsed.B + ", C:" + parsed.C;};
	return parsed;
}

function ParseABInstruction(bytes) {
	var  parsed = {};
	parsed.OP=bytes[0] & 0x3F;
	parsed.A = ((bytes[0] & 0xC0)>>6) + ((bytes[1] & 0x3F)<<2);
	parsed.B = ((bytes[2] & 0x80)>>7) + (bytes[3] <<1);
	parsed.ToString = function() {return "A:" + parsed.A + ", B:" + parsed.B;};
	return parsed;
}

function ParseACInstruction(bytes) {
	var  parsed = {}
	parsed.OP=bytes[0] & 0x3F;
	parsed.A = ((bytes[0] & 0xC0)>>6) + ((bytes[1] & 0x3F)<<2);
	parsed.C = ((bytes[1] & 0xC0)>>6) + ((bytes[2] & 0x7F)<<2);
	parsed.ToString = function() {return "A:" + parsed.A + ", C:" + parsed.C;};
	return parsed;
}


function ParseABxInstruction(bytes) {
	var  parsed = {};
	parsed.OP=bytes[0] & 0x3F;
	parsed.A = ((bytes[0] & 0xC0)>>6) + ((bytes[1] & 0x3F)<<2);
	parsed.Bx = ((bytes[1] & 0xC0)>>6) + (bytes[2]<<2) + (bytes[3] <<10);
	parsed.ToString = function() {return "A:" + parsed.A + ", Bx:" + parsed.Bx;};
	return parsed;
}

function ParseAsBxInstruction(bytes) {
	var  parsed = {};
	parsed.OP=bytes[0] & 0x3F;
	parsed.A = ((bytes[0] & 0xC0)>>6) + ((bytes[1] & 0x3F)<<2);
	parsed.sBx = ((bytes[1] & 0xC0)>>6) + (bytes[2]<<2) + (bytes[3] <<10);
	parsed.sBx -= 0x1FFFF;
	parsed.ToString = function() {return "A:" + parsed.A + ", sBx:" + parsed.sBx;};
	return parsed;
}


function ParseAxInstruction(bytes) {
	var  parsed = {};
	parsed.OP=bytes[0] & 0x3F;
	parsed.Ax = ((bytes[0] & 0xC0)>>6) + (bytes[1] <<2) + (bytes[2] <<10) + (bytes[3] <<18);
	parsed.ToString = function() {return "Ax:" + parsed.Ax;};
	return parsed;
}


function ParseAInstruction(bytes) {
	var  parsed = {};
	parsed.OP=bytes[0] & 0x3F;
	parsed.A=(bytes[0] & 0xC0)>>6 + (bytes[1] & 0x3F)<<2;
	parsed.ToString = function() {return "A:" + parsed.A;};
	return parsed;
}

function ParseInstruction(ins) {
	//TODO: fix endianess
	var bytes = true? 
		[ins[0], ins[1], ins[2], ins[3]]:
		[inst[3], ins[2], ins[1], ins[0]];
	var parsed = GetInstructionParser(bytes);
	parsed.name = OpToString(parsed.OP) + " - " + parsed.ToString();
	//console.log('OpCode: ' + OpToString(parsed.OP));
	return parsed;
}
