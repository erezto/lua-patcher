
function reverseEndianess(arr, offset) {
	for (i=0, k=(arr.length+offset -1); i<k; i++, k--) {
		arr[i] += arr[k];
		arr[k] = arr[i] - arr[k];
		arr[i] -= arr[k];
	}
}

function _readInstruction(arr, offset, header) {
	var inst;
	switch (header.inst_size) {
		case 4:			
			inst = arr.subarray(offset, offset+4);
			break;
		default:
			console.log("Unsupported instruction size " + header.inst_size);
	}
//	console.log('_readInstruction: offset=' + offset + ", inst=" + inst[3] + " " + inst [0]);
	return inst;
}

function _writeInstruction(arr, offset, val, header) {
		console.log('writng data ' + val + ' to offset ' + offset);
		for (var i=0; i<header.inst_size; i++) {
			arr[offset +i ] = val[i];
		}	
}

function ParseBytecode(arr) {
	var header = {};
	header.magic =String.fromCharCode(arr[0]) + String.fromCharCode(arr[1])  + String.fromCharCode(arr[2]) + String.fromCharCode(arr[3]) ;
	header.version = arr[4];
	console.log('version: ' + arr[4]);
	switch(header.version) {
		case 0x52:
			return new Lua52(arr);
			break;
		case 0x53:
			return new Lua53(arr);
			break;
		default:
			console.log('Unknown version ' + parseInt(header.version , 16));
			return null;
	}
}

function Lua53(arr) {	
	this.arr = arr;
	var header = {};
	header.magic =String.fromCharCode(arr[0]) + String.fromCharCode(arr[1])  + String.fromCharCode(arr[2]) + String.fromCharCode(arr[3]) ;
	header.version = arr[4];
	header.format = arr[5];
	//data should be //"\x19\x93\r\n\x1a\n"
	header.data = String.fromCharCode(arr[6]) + String.fromCharCode(arr[7])  + String.fromCharCode(arr[8]) + String.fromCharCode(arr[9]) +  String.fromCharCode(arr[10]) + String.fromCharCode(arr[11]) ;
	header.int_size =  arr[12];
	header.sizet_size =  arr[13];
	header.inst_size =  arr[14];
	header.integet_size =  arr[15];
	header.luan_size =  arr[16];
	var  t = arr.subarray(17, 17+header.integet_size);
	header.endianess (t[0])? 1:0;
	t = arr.subarray(17+header.integet_size, 17+header.integet_size+header.luan_size);
	header.cl = arr[17+header.integet_size+header.luan_size];
	this.header = header;
	var reader = new Reader(arr, 17+header.integet_size+header.luan_size+1);
	this.main = new LuaFunction53(reader, header);
}


function LuaFunction53(reader, header) {
	//console.log('LuaFunction53, reader.offset=' + reader.offset);
	var t;
	var parser = new BinaryParser;
	this.arr = reader.arr;
	this.base = reader.offset;
	this.header = header;
	t = reader.Read(1, 1)[0];
	if (t == 0xFF) {
		//sizet is expected to be 32b
		t = this.arr.subarray(reader.offset, reader.offset+header.sizet_size);
		reader.offset += header.sizet_size;
		t = parser.fromInt(t);
	}
	if (t == 0x0) {
		this,source = "";
	}
	else {
		this,source = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+t));
		reader.offset += t;		
	}
	
	this.first_line = reader.Read(4, 1)[0];
	this.last_line =  reader.Read(4, 1)[0];
	this.num_params =  reader.Read(1, 1)[0];
	this.is_vararg = reader.Read(1, 1)[0];
	this.stack_size =  reader.Read(1, 1)[0];
	this.code_length =  reader.Read(4, 1)[0];
	this.code_base = reader.offset;
	reader.offset += this.code_length*header.inst_size;
	this.constants_length =  reader.Read(4, 1)[0];
	
	this.constants = [];
	for (var i=0; i<this.constants_length; i++){
		this.constants[i] = {};
		t = reader.Read(1, 1)[0];
		switch (t) {
			case 0:	//LUA_TNIL
				this.constants[i].type = 'nil';
				break;
			case 1:	//LUA_TBOOLEAN
				this.constants[i].type = 'bool';
				this.constants[i].value = reader.Read(1, 1)[0];
				break;
			case 3:	//LUA_TNUMFLT
				this.constants[i].type = 'number';
				this.constants[i].value = parser.toDouble(String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+8)));
				reader.offset += 8;
				break;
			case (3+0x10):	//LUA_TNUMINT
				this.constants[i].type = 'number';
				this.constants[i].value = parser.toInt(String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+8)));
				reader.offset += 8;
				break;				
			case 4:	//LUA_TSHRSTR
			case (4+0x10):	//LUA_TLNGSTR
				this.constants[i].type = 'string';
				var str_len = reader.Read(4, 1)[0];
				this.constants[i].value = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+str_len));
				reader.offset += str_len;
				break;
			default:
				//Can't parse this
				console.error('Failed parsing constant, offset ' + reader.offset);
				return {};			
		}		
	}


	
//Upvalues
	t= reader.Read(4, 1)[0];
	this.upvalues = [];
	for (var i=0; i<t; i++) {
		this.upvalues[i] = {};
		this.upvalues[i].name = null;
		this.upvalues[i].instack = reader.Read(1, 1)[0];
		this.upvalues[i].idx = reader.Read(1, 1)[0];		
	}
	
//Protos
	this.closures = [];
	t = reader.Read(4, 1)[0];
	for (var i=0; i<t; i++) {
		this.closures[i] = new LuaFunction53(reader, header);
	}
	
//Debug	
	
	t = reader.Read(4, 1)[0];
	this.lineinfo = reader.Read(4, t);
	t = reader.Read(4, 1)[0];
	this.localvars = [];
	for (var i=0; i<t; i++) {
		this.localvars[i] = {};
		var str_len = reader.Read(4, 1)[0];
		this.localvars[i].varname = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+t));
		reader.offset += str_len;
		this.localvars[i].startpc = reader.Read(4, 1)[0];
		this.localvars[i].endpc = reader.Read(4, 1)[0];
	}
	t = reader.Read(4, 1)[0];
	for (var i=0; i<t; i++) {		
		var str_len = reader.Read(4, 1)[0];
		this.upvalues[i].name = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+t));
		reader.offset += str_len;
	 }
	
	
}


LuaFunction53.prototype.GetRawInstrution = function (i) {
		if (i>= this.code_length) return;
		return _readInstruction(this.arr , (this.base + 15 + (this.header.inst_size * i)), this.header);
};

LuaFunction53.prototype.SetInstrution = function (i, val) {
		if (i>= this.code_length) return;
		//_writeInstruction(arr, (offset + 15 + (header.inst_size * i)), val, header);		
		var t = this.base + 15 + (this.header.inst_size * i);
		//console.log('writng data ' + val + ' to offset ' + t + ',i = ' + i);
		for (var k=0; k<this.header.inst_size; k++) {
			this.arr [t +k] = val[k];
		}	
};


function Lua52(arr) {	
	this.arr = arr;
	var header = {};
	header.magic =String.fromCharCode(arr[0]) + String.fromCharCode(arr[1])  + String.fromCharCode(arr[2]) + String.fromCharCode(arr[3]) ;
	header.version = arr[4];
	header.format = arr[5];
	header.endianess =  arr[6];
	header.int_size =  arr[7];
	header.sizet_size =  arr[8];
	header.inst_size =  arr[9];
	header.luan_size =  arr[10];
	header.is_luan =  arr[11];
	header.tail =  arr.subarray(12, 18);				
	this.header = header;
	var reader = new Reader(arr, 18);
	this.main = new LuaFunction52(reader, header);
}

function LuaFunction52(reader, header) {
	//console.log('LuaFunction52, reader.offset=' + reader.offset);
	var parser = new BinaryParser;
	this.arr = reader.arr;
	this.base = reader.offset;
	this.header = header;
	this.first_line = reader.Read(4, 1)[0];
	this.last_line =  reader.Read(4, 1)[0];
	this.num_params =  reader.Read(1, 1)[0];
	this.is_vararg = reader.Read(1, 1)[0];
	this.stack_size =  reader.Read(1, 1)[0];
	this.code_length =  reader.Read(4, 1)[0];
	this.code_base = reader.offset;
	reader.offset += this.code_length*header.inst_size;
	this.constants_length =  reader.Read(4, 1)[0];
	
	this.constants = [];
	for (var i=0; i<this.constants_length; i++){
		this.constants[i] = {};
		var t = reader.Read(1, 1)[0];
		switch (t) {
			case 0:	//LUA_TNIL
				this.constants[i].type = 'nil';
				break;
			case 1:	//LUA_TBOOLEAN
				this.constants[i].type = 'bool';
				this.constants[i].value = reader.Read(1, 1)[0];
				break;
			case 3:	//LUA_TNUMBER
				this.constants[i].type = 'number';
				this.constants[i].value = parser.toDouble(String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+8)));
				reader.offset += 8;
				break;
			case 4:	//LUA_TSTRING
				this.constants[i].type = 'string';
				var str_len = reader.Read(4, 1)[0];
				this.constants[i].value = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+str_len));
				reader.offset += str_len;
				break;
			default:
				//Can't parse this
				console.error('Failed parsing constant, offset ' + reader.offset);
				return {};			
		}		
	}
	this.closures = [];
	var t = reader.Read(4, 1)[0];
	for (var i=0; i<t; i++) {
		this.closures[i] = new LuaFunction52(reader, header);
	}
	t= reader.Read(4, 1)[0];
	this.upvalues = [];
	for (var i=0; i<t; i++) {
		this.upvalues[i] = {};
		this.upvalues[i].name = null;
		this.upvalues[i].instack = reader.Read(1, 1)[0];
		this.upvalues[i].idx = reader.Read(1, 1)[0];		
	}
	
	 t =  reader.Read(4, 1)[0];
	this.source=String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+t));
	reader.offset += t;
	
	t = reader.Read(4, 1)[0];
	this.lineinfo = reader.Read(4, t);
	t = reader.Read(4, 1)[0];
	this.localvars = [];
	for (var i=0; i<t; i++) {
		this.localvars[i] = {};
		var str_len = reader.Read(4, 1)[0];
		this.localvars[i].varname = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+t));
		reader.offset += str_len;
		this.localvars[i].startpc = reader.Read(4, 1)[0];
		this.localvars[i].endpc = reader.Read(4, 1)[0];
	}
	t = reader.Read(4, 1)[0];
	for (var i=0; i<t; i++) {		
		var str_len = reader.Read(4, 1)[0];
		this.upvalues[i].name = String.fromCharCode.apply(null, this.arr.subarray(reader.offset, reader.offset+t));
		reader.offset += str_len;
	 }
	
	
}

LuaFunction52.prototype.GetRawInstrution = function (i) {
		if (i>= this.code_length) return;
		return _readInstruction(this.arr , (this.base + 15 + (this.header.inst_size * i)), this.header);
};

LuaFunction52.prototype.SetInstrution = function (i, val) {
		if (i>= this.code_length) return;
		//_writeInstruction(arr, (offset + 15 + (header.inst_size * i)), val, header);		
		var t = this.base + 15 + (this.header.inst_size * i);
		//console.log('writng data ' + val + ' to offset ' + t + ',i = ' + i);
		for (var k=0; k<this.header.inst_size; k++) {
			this.arr [t +k] = val[k];
		}	
};

function GetInstructionParser(bytes) {
	var  op = bytes[0] & 0x3F;
	switch (op) {
		case 0:	//OP_MOVE
			return ParseABInstruction(bytes);
		case 1:	//OP_LOADK
			return ParseABxInstruction(bytes);
		case 2:	//OP_LOADKX
			return ParseAInstruction(bytes);
		case 3:	//OP_LOADBOOL
			return ParseABCInstruction(bytes);
		case 4:	//OP_LOADNIL
			return ParseABInstruction(bytes);
		case 5:	//OP_GETUPVAL
			return ParseABInstruction(bytes);
		case 6:	//OP_GETTABUP
			return ParseABCInstruction(bytes);
		case 7:	//OP_GETTABLE
			return ParseABCInstruction(bytes);
		case 8:	//OP_SETTABUP
			return ParseABCInstruction(bytes);
		case 9:	//OP_SETUPVAL
			return ParseABInstruction(bytes);
		case 10:	//OP_SETTABLE
			return ParseABCInstruction(bytes);
		case 11:	//OP_NEWTABLE
			return ParseABCInstruction(bytes);
		case 12:	//OP_SELF
			return ParseABCInstruction(bytes);
		case 13:	//OP_ADD
			return ParseABCInstruction(bytes);
		case 14:	//OP_SUB
			return ParseABCInstruction(bytes);
		case 15:	//OP_MUL
			return ParseABCInstruction(bytes);
		case 16:	//OP_DIV
			return ParseABCInstruction(bytes);
		case 17:	//OP_MOD
			return ParseABCInstruction(bytes);
		case 18:	//OP_POW
			return ParseABCInstruction(bytes);
		case 19:	//OP_UNM
			return ParseABInstruction(bytes);
		case 20:	//OP_NOT
			return ParseABInstruction(bytes);
		case 21:	//OP_LEN
			return ParseABInstruction(bytes);
		case 22:	//OP_CONCAT
			return ParseABCInstruction(bytes);
		case 23:	//OP_JMP
			return ParseAsBxInstruction(bytes);
		case 24:	//OP_EQ
			return ParseABCInstruction(bytes);
		case 25:	//OP_LT
			return ParseABCInstruction(bytes);
		case 26:	//OP_LE
			return ParseABCInstruction(bytes);
		case 27:	//OP_TEST
			return ParseACInstruction(bytes);
		case 28:	//OP_TESTSET
			return ParseABCInstruction(bytes);
		case 29:	//OP_CALL
			return ParseABCInstruction(bytes);
		case 30:	//OP_TAILCALL
			return ParseABCInstruction(bytes);
		case 31:	//OP_RETURN
			return ParseABInstruction(bytes);
		case 32:	//OP_FORLOOP
			return ParseAsBxInstruction(bytes);
		case 33:	//OP_FORPREP
			return ParseAsBxInstruction(bytes);
		case 34:	//OP_TFORCALL
			return ParseACInstruction(bytes);
		case 35:	//OP_TFORLOOP
			return ParseAsBxInstruction(bytes);
		case 36:	//OP_SETLIST
			var t = ParseABCInstruction(bytes);
			if (t.c == 0) t = ParseAxInstruction(bytes);
			return t;
		case 37:	//OP_CLOSURE
			return ParseABxInstruction(bytes);
		case 38:	//OP_VARARG
			return ParseABInstruction(bytes);
		case 38:	//OP_EXTRAARG
			return ParseAxInstruction(bytes);			
		}
		return ParseUnknownInstruction(bytes);
}

function OpToString(op) {
	switch (op) {
		case 0:
			return 'OP_MOVE';
		case 1:
			return 'OP_LOADK';
		case 2:
			return 'OP_LOADKX';
		case 3:
			return "OP_LOADBOOL";
		case 4:
			return "OP_LOADNIL";
		case 5:
			return "OP_GETUPVAL";
		case 6:
			return "OP_GETTABUP";
		case 7:
			return "OP_GETTABLE";
		case 8:
			return "OP_SETTABUP";
		case 9:
			return "OP_SETUPVAL";
		case 10:
			return "OP_SETTABLE";
		case 11:
			return "OP_NEWTABLE";
		case 12:
			return "OP_SELF";
		case 13:
			return "OP_ADD";
		case 14:
			return "OP_SUB";
		case 15:
			return "OP_MUL";
		case 16:
			return "OP_DIV";
		case 17:
			return "OP_MOD";
		case 18:
			return "OP_POW";
		case 19:
			return "OP_UNM";
		case 20:
			return "OP_NOT";
		case 21:
			return "OP_LEN";
		case 22:
			return "OP_CONCAT";
		case 23:
			return "OP_JMP";
		case 24:
			return "OP_EQ";
		case 25:
			return "OP_LT";
		case 26:
			return "OP_LE";
		case 27:
			return "OP_TEST";
		case 28:
			return "OP_TESTSET";
		case 29:
			return "OP_CALL";
		case 30:
			return "OP_TAILCALL";
		case 31:
			return "OP_RETURN";
		case 32:
			return "OP_FORLOOP";
		case 33:
			return "OP_FORPREP";
		case 34:
			return "OP_TFORCALL";
		case 35:
			return "OP_TFORLOOP";
		case 36:
			return "OP_SETLIST";
		case 37:
			return "OP_CLOSURE";
		case 38:
			return "OP_VARARG";
		case 38:
			return "OP_EXTRAARG";			
		}
		return 'OP_UNKNOWN';
}