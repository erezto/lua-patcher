local struct = require'struct';
local ops = require'opcods'
local bit = require 'bit'
local JSON = require'json'
local lua_assert = function (x) assert (x ~= 0) end;

local basic_types = 
{
	LUA_TNONE 			= -1,
	LUA_TNIL 			= 0,
	LUA_TBOOLEAN        = 1,
	LUA_TLIGHTUSERDATA  = 2,
	LUA_TNUMBER         = 3,
	LUA_TSTRING         = 4,
	LUA_TTABLE          = 5,
	LUA_TFUNCTION       = 6,
	LUA_TUSERDATA       = 7,
	LUA_TTHREAD         = 8,
	LUA_NUMTAGS         = 9,
}

local LoadFunction;

local function dump(str)
	local t = ''
	for i=1, #str do
	    	 b = string.format("%02X", str:byte(i))
		t = t .. b .. ",";
	end
	return t
end

local header_magic = "\x1bLua";
local header_tail = "\x19\x93\r\n\x1a\n";

local header = {};

local function error(S, msg)
	print ('Err: ' .. msg)
end

local function LoadIns(S)
	return struct.unpack(S.header.endianess .. "I4", S.reader:read(4))
end

local function LoadSizet(S)
	return struct.unpack(S.header.endianess .. "I4", S.reader:read(4))
end

local function LoadInt(s)
	return struct.unpack(s.header.endianess .. "i4", s.reader:read(4))
end

local function LoadByte(s)
	return struct.unpack(s.header.endianess .. "B", s.reader:read(1))
end

local function LoadChar(s)
	return struct.unpack(s.header.endianess .. "b", s.reader:read(1))
end

local function LoadBool(s)
	return (struct.unpack(s.header.endianess .. "b", s.reader:read(1)) == 0)
end

local function LoadNumber(s)
--      print ("LoadNumber: size=" .. tostring(s.header.luan_size) .. ", from:" .. tostring(s.reader:seek()) .. ":")
      local n = s.reader:read(s.header.luan_size)
--      print (dump(n))
      return struct.unpack(s.header.endianess .. "d", n)
end

local function LoadBlock(S, size)
--      print ("LoadBlock: size=" .. tostring(size) .. ", from=" .. tostring(S.reader:seek()))
      local b = S.reader:read(size)
      if (#b ~= size) then error(S,"truncated") end
--      print (dump(b))
      return b;
end

local function LoadMem(S,n,size)     return LoadBlock(S,(n)*(size)) end
--#define LoadVar(S,x)            LoadMem(S,&x,1,sizeof(x))
local function LoadVector(S,n,size)  return LoadMem(S,n,size) end


local function LoadCode(S, f)
 local n=LoadInt(S);
 f.sizecode=n;
-- print (S,n,S.header.inst_size)
 f.code = LoadVector(S,n,S.header.inst_size);
-- print ("LoadCod, from:"  .. tostring(S.reader:seek()) .. ", size: " .. tostring(f.sizecode))
-- print ("LoadCode:\n" .. dump(f.code) .. "\n")
end



local function LoadString(S)
	local size = LoadSizet(S);
	size = tonumber(size);
	if (size==0) then
		return '';
	else 
		local buff = LoadBlock(S, size) 
		return buff:sub(1, #buff);
	end
end

local function luaM_newvector(l, n)
	local ret = {};
      --Note: bad implementation
	  for i=1, n do	
		ret[i] = {}
	  end
      return ret
end

local function luaF_newproto(L)
      return {}
end

local function LoadConstants(S, f)
 local i,n;
 n = LoadSizet(S);
-- print ("LoadConstants, n=" .. tostring(n));
 f.k=luaM_newvector(S.L,n);
 f.sizek=n;
 for i=1, n do  f.k[i] = nil end
 for i=1, n do
    local t=LoadChar(S);
--	print ("i=", i, "t=", t)
    if (t == basic_types.LUA_TNIL) then
		f.k[i] = nil;
    elseif (t == basic_types.LUA_TBOOLEAN) then
		local v = LoadBool(S);
		f.k[i] = (v == 1);
    elseif (t == basic_types.LUA_TNUMBER) then
		f.k[i] = LoadNumber(S);
    elseif (t == basic_types.LUA_TSTRING) then
		f.k[i] = LoadString(S);
--		print ("LoadConstants, loaded string:" .. f.k[i]);
    else
--    default: 
      lua_assert(0);
     end
 end
 n=LoadInt(S);
 f.p=luaM_newvector(S.L,n);
 f.sizep=n;
 for i=1, n do f.p[i]=nil; end
 for i=1, n do
  f.p[i]=luaF_newproto(S.L);
  f.p[i] = LoadFunction(S);
 end
end

local function LoadUpvalues(S, f)
	local i,n;
	n=LoadInt(S);
	f.upvalues=luaM_newvector(S.L,n);
	f.sizeupvalues=n;
	for i=1, n do f.upvalues[i].name=nil; end
	for i=1, n do
		f.upvalues[i].instack=LoadByte(S);
		f.upvalues[i].idx=LoadByte(S);
	end
end

local function LoadDebug(S, f)
 local i,n;
 f.source=LoadString(S);
 n=LoadInt(S);
 f.lineinfo=luaM_newvector(S.L,n);
 f.sizelineinfo=n;
 f.lineinfo = LoadVector(S,n,S.header.int_size);
 n=LoadInt(S);
 f.locvars=luaM_newvector(S.L,n);
 f.sizelocvars=n;
 for i=1, n do f.locvars[i].varname=nil; end
 for i=1, n do
  f.locvars[i].varname=LoadString(S);
  f.locvars[i].startpc=LoadInt(S);
  f.locvars[i].endpc=LoadInt(S);
 end
 n=LoadInt(S);
 for i=1, n do f.upvalues[i].name=LoadString(S); end
end

LoadFunction = function(S)
	local cl = {}
	local f = {}
	f.linedefined=LoadInt(S);
	f.lastlinedefined=LoadInt(S);
	f.numparams=LoadByte(S);
	f.is_vararg=LoadByte(S);
	f.maxstacksize=LoadByte(S);
	LoadCode(S,f);
	LoadConstants(S,f);
	LoadUpvalues(S,f);
	LoadDebug(S,f);
	cl.f = f;
	return cl;
end


local function parseInstruction(ins)
--      print ("parseInstruction:" .. string.format("%08X", ins))
	return ops(ins)
end

local function parseCode(S, c)
	local instructions = {}
	for i=0, (((#c)/4) - 1) do
		local ins = struct.unpack(S.header.endianess .. 'I4', c:sub((4*i) +1, (4*i) + 5));
--		print ("op: " .. tostring(bit.band(ins, 0x3F)))
--		print (string.format("%X", ins))
		local op = parseInstruction(ins)
--		print (op:tostring())
		table.insert(instructions, op);
	end
	return instructions;
end

local function LoadHeader(reader)
	local header = {}
	header.magic = reader:read(#header_magic);
	header.version = reader:read(1);
	header.format 	  = reader:read(1);
	if (reader:read(1) == "\x00") then header.endianess = ">" else header.endianess =  "<" end
	header.int_size   = struct.unpack("B", reader:read(1));
	header.sizet_size = struct.unpack("B", reader:read(1));
	header.inst_size  = struct.unpack("B", reader:read(1));
	header.luan_size  = struct.unpack("B", reader:read(1));
	header.is_luan    = reader:read(1);
	header.tail		  = reader:read(#header_tail);
	return header
end

local function dumpTo(S, writer, cl, pref)
	writer:write(pref, "Source: " .. cl.f.source .. "\n");
	writer:write(pref, "numparams: " .. tostring(cl.f.numparams) ..
			 ", is_vararg:" .. tostring(cl.f.is_vararg) ..
			 ", maxstacksize:" .. tostring(cl.f.maxstacksize) .. "\n");

	writer:write(pref, "Local vars(" .. tostring(cl.f.sizelocvars) .. "):\n");
	for i=1,cl.f.sizelocvars do
		writer:write(pref, " #" .. tostring(i-1) .. ": " .. cl.f.locvars[i].varname .. "\n");
	end	
	
	writer:write(pref, "Constants(" .. tostring(cl.f.sizek) .. "):\n");
	for i=1,cl.f.sizek do
		writer:write(pref, " #" .. tostring(i-1) .. " (" .. type(cl.f.k[i]) .. "): \n");
		writer:write(pref, " " .. JSON.encode(cl.f.k[i]) .. '\n');
	end
	
	local instructions = parseCode(S, cl.f.code);
	writer:write(pref, "Code (" .. tostring(#instructions) .. "):\n");
	for i=1, #instructions do
		writer:write(pref, " " .. instructions[i]:tostring(cl) .. '\n');
	end
	writer:write(pref, "Functions (" .. tostring(cl.f.sizep) .. "):\n");
	for i=1,cl.f.sizep do
		writer:write(pref, " #" .. tostring(i-1) .. ":\n");
		dumpTo(S, writer, cl.f.p[i], pref .. "[" .. tostring(i-1) .. "] ");
	end

end


local input = io.open(arg[1], "rb");


local header = LoadHeader(input)
local S = {reader = input, header = header, L = {}}

local main = LoadFunction(S)
--print ("instruction size:", header.inst_size)
--print (string.format("%X", main.f.linedefined), string.format("%X", main.f.lastlinedefined));
--print (dump(main.f.code))
--parseCode(S, main.f.code);

--print (JSON.encode(main))
input:close();

local dumbWriter = 
{
	write = function(self, pref, str)
				io.write (pref .. str)
			end
};

dumpTo(S, dumbWriter, main, "__function[0]")

