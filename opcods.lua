local bit = require 'bit'

local sizeOP = 6;
local sizeA = 8;
local sizeB = 9;
local sizeC = 9;


local BITRK = bit.lshift(1, (sizeB - 1))

--test whether value is a constant
local function ISK(x)
          return (bit.band(x, BITRK) ~= 0)
end

--gets the index of the constant
local function INDEXK(r)
       return bit.band(r, bit.bnot(BITRK))
end

local function iBase(raw)
	local m = {};
	m.opccode = bit.band(raw,    0x3F);
	m.name = "UnknownOp";
	m.description = "";
	m.tostring = function (self)
						return "Name: " .. self.name .. ", Description: " .. self.description;								
					end
	return m;
end

local function iABC(raw)
	local base = iBase(raw);	
	base.A = bit.rshift(bit.band(raw,    0x3FC0), 6);
	base.C = bit.rshift(bit.band(raw,  0x7FC000), 14);
	base.B = bit.rshift(bit.band(raw,0xFF800000), 23);
	base.tostring = function (self, cl)
		      		 if (base.preety) then
					return base:preety(cl) ..
					       "# [" .. tostring(self.A) .. 
					       ",".. tostring(self.B) .. 
					       "," .. tostring(self.C) .. 
					       "]"
		      		 else
					return "Name: " .. self.name .. 
					       "[" .. tostring(self.A) .. 
					       ",".. tostring(self.B) .. 
					       "," .. tostring(self.C) .. 
					       "] , Description: " .. 
					       self.description;													
				 end
			end
	return base;
end

local function iABx(raw)      	
	local base = iBase(raw);
	base.A = bit.rshift(bit.band(raw,    0x3FC0), 6);
	base.Bx = bit.rshift(bit.band(raw,0xFFFFC000), 14);
	base.tostring = function (self, cl)
		      		 if (base.preety) then
				    return base:preety(cl)
		      		 else
					return "Name: " .. 
						self.name .. 
						"[" .. tostring(self.A) .. 
						",".. tostring(self.Bx) .. 
						"] , Description: " .. self.description;								
		      		 end
			end
	return base;
end

local function iAsBx(raw)
	local base = iBase(raw);
	base.A = bit.rshift(bit.band(raw,    0x3FC0), 6);
	base.sBx = bit.rshift(bit.band(raw,0xFFFFC000), 14);
	base.tostring = function (self)
						return "Name: " .. self.name .. "[" .. tostring(self.A) .. ",".. tostring(self.sBx) .. "] , Description: " .. self.description;								
					end
	return base;
end

local function iAx(raw)
	local base = iBase(raw);
	base.Ax = bit.rshift(bit.band(raw,0xFFFFFFC0), 6);
	base.tostring = function (self)
						return "Name: " .. self.name .. "[" .. tostring(self.Ax) .. "] , Description: " .. self.description;								
					end
	return base;
end

local function _MOVE(ins)
      local op = iABC(ins)
      op.name = "OP_MOVE";
      op.description = "R(A) := R(B)";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
      		  	   local nameB = "__locals_" .. tostring(self.B);
			   if (cl.f.locvars[self.B+1]) then nameB =  cl.f.locvars[self.B+1].varname; end
      		  	   return (nameA .. " = " .. nameB);
      		  end
      return op
end

local function _LOADK(ins)
      local op = iABx(ins)
      op.name = "OP_LOADK";
      op.description = "R(A) := Kst(Bx)";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
      		  	   return (nameA .. " = " .. tostring(cl.f.k[self.Bx + 1]));
      		  end
      
      return op
end
local function _LOADKX(ins)
      local op = iABx(ins)
  	  op.name = "OP_LOADKX";
	  op.description = "R(A) := Kst(extra arg)";
      return op
end 
local function _LOADBOOL(ins)
      local op = iABC(ins)
      op.name = "OP_LOADBOOL";
      op.description = "R(A) := (Bool)B; if (C) pc++";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
			   local B = (self.B ~= 0);
			   local pc = "";
			   if (self.C ~= 0) then pc = " pc++"; end
      		  	   return (nameA .. " = " .. tostring(B) .. pc);
      		  end
      return op
end
local function _LOADNIL(ins)
      local op = iABC(ins)
  	  op.name = "OP_LOADNIL";
	  op.description = "R(A), R(A+1), ..., R(A+B) := nil";
      return op
end
local function _GETUPVAL(ins)
      local op = iABC(ins)
  	  op.name = "OP_GETUPVAL";
	  op.description = "R(A) := UpValue[B]";
      return op
end

local function _GETTABUP(ins)
      local op = iABC(ins);
      op.name = "OP_GETTABUP";
      op.description = "R(A) := UpValue[B][RK(C)]";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
			   local nameC;
			   if (ISK(self.C)) then 
			      nameC = tostring(cl.f.k[INDEXK(self.C) + 1]);
			   else
			      if (cl.f.locvars[self.C+1]) then 
			      	 nameC =  cl.f.locvars[self.C+1].varname; 
		 	      else
				 nameC = "__locals_" .. tostring(self.C);
			      end				
			   end
      		  	   return (nameA .. " = Upvalue[" .. tostring(self.B) .. "][" .. nameC .. "]");
      		  end
      return op
end

local function _GETTABLE(ins)
      local op = iABC(ins)
  	  op.name = "OP_GETTABLE";
	  op.description = "R(A) := R(B)[RK(C)]";
      return op
end

local function _SETTABUP(ins)
      local op = iABC(ins)
      op.name = "OP_SETTABUP";
      op.description = "UpValue[A][RK(B)] := RK(C)";
      op.preety = function (self, cl)
      		  	   local nameA = "UpValue[" .. tostring(self.A) .. "][";
			   local nameB;
			   if (ISK(self.B)) then 
			      nameB = tostring(cl.f.k[INDEXK(self.B) + 1]);
			   else
			      if (cl.f.locvars[self.B+1]) then 
			      	 nameB =  cl.f.locvars[self.B+1].varname; 
		 	      else
				 nameB = "__locals_" .. tostring(self.B);
			      end				
			   end
			   local nameC;
			   if (ISK(self.C)) then 
			      nameC = tostring(cl.f.k[INDEXK(self.C) + 1]);
			   else
			      if (cl.f.locvars[self.C+1]) then 
			      	 nameC =  cl.f.locvars[self.C+1].varname; 
		 	      else
				 nameC = "__locals_" .. tostring(self.C);
			      end				
			   end
      		  	   return (nameA .. nameB .. "] = "  .. nameC);
      		  end

      return op
end
local function _SETUPVAL(ins)
      local op = iABC(ins)
  	  op.name = "OP_SETUPVAL";
	  op.description = "UpValue[B] := R(A)";
      return op
end

local function _SETTABLE(ins)
      local op = iABC(ins)
      op.name = "OP_SETTABLE";
      op.description = "R(A)[RK(B)] := RK(C)";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
			   local nameB;
			   if (ISK(self.B)) then 
			      nameB = tostring(cl.f.k[INDEXK(self.B) + 1]);
			   else
			      if (cl.f.locvars[self.B+1]) then 
			      	 nameB =  cl.f.locvars[self.B+1].varname; 
		 	      else
				 nameB = "__locals_" .. tostring(self.B);
			      end				
			   end
			   local nameC;
			   if (ISK(self.C)) then 
			      nameC = tostring(cl.f.k[INDEXK(self.C) + 1]);
			   else
			      if (cl.f.locvars[self.C+1]) then 
			      	 nameC =  cl.f.locvars[self.C+1].varname; 
		 	      else
				 nameC = "__locals_" .. tostring(self.C);
			      end				
			   end
      		  	   return (nameA .. "[" .. nameB .. "] = " .. nameC);
      		  end
      return op
end

local function _NEWTABLE(ins)
      local op = iABC(ins)
      op.name = "OP_NEWTABLE";
      op.description = "R(A) := {} (size = B,C)";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
      		  	   return (nameA .. " = {} #array=" .. tostring(self.B) .. ", hash=" .. tostring(self.C));
      		  end
      return op
end

local function _SELF(ins)
      local op = iABC(ins)
  	  op.name = "OP_SELF";
	  op.description = "R(A+1) := R(B); R(A) := R(B)[RK(C)]";
      return op
end

local function _ADD(ins)
    local op = iABC(ins)
  	op.name = "OP_ADD";
	op.description = "R(A) := RK(B) + RK(C)";
    return op
end

local function _SUB(ins)
      local op = iABC(ins)
  	  op.name = "OP_SUB";
	  op.description = "R(A) := RK(B) - RK(C)";
      return op
end

local function _MUL(ins)
      local op = iABC(ins)
  	  op.name = "OP_MUL";
	  op.description = "R(A) := RK(B) * RK(C)";
      return op
end

local function _DIV(ins)
      local op = iABC(ins)
  	  op.name = "OP_DIV";
	  op.description = "R(A) := RK(B) / RK(C)";
      return op
end

local function _MOD(ins)
      local op = iABC(ins)
  	  op.name = "OP_MOD";
	  op.description = "R(A) := RK(B) % RK(C)";
      return op
end

local function _POW(ins)
      local op = iABC(ins)
  	  op.name = "OP_POW";
	  op.description = "R(A) := RK(B) ^ RK(C)";
      return op
end

local function _UNM(ins)
      local op = iABC(ins)
  	  op.name = "OP_UNM";
	  op.description = "R(A) := -R(B)";
      return op
end

local function _NOT(ins)
      local op = iABC(ins)
  	  op.name = "OP_NOT";
	  op.description = "R(A) := not R(B)";
      return op
end

local function _LEN(ins)
      local op = iABC(ins)
  	  op.name = "OP_LEN";
	  op.description = "R(A) := length of R(B)";
      return op
end


local function _CONCAT(ins)
      local op = iABC(ins)
      op.name = "OP_CONCAT";
      op.description = "R(A) := R(B).. ... ..R(C)";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
			   local str = ""
			   for i=self.B, self.C+1 do
			       local t = "__locals_" .. tostring(i);
			       if (cl.f.locvars[i+1]) then t =  cl.f.locvars[i+1].varname; end
			       str = str .. " .. " .. t
			   end
			   return nameA .. " = " .. str:sub(5);
			   end
      return op
end

local function _JMP(ins)
      local op = iAsBx(ins)
  	  op.name = "OP_JMP";
	  op.description = "pc+=sBx; if (A) close all upvalues >= R(A) + 1";
      return op
end

local function _EQ(ins)
      local op = iABC(ins)
  	  op.name = "OP_EQ";
	  op.description = "if ((RK(B) == RK(C)) ~= A) then pc++";
      return op
end

local function _LT(ins)
      local op = iABC(ins)
  	  op.name = "OP_LT";
	  op.description = "if ((RK(B) <  RK(C)) ~= A) then pc++";
      return op
end

local function _LE(ins)
      local op = iABC(ins)
  	  op.name = "OP_LE";
	  op.description = "if ((RK(B) <= RK(C)) ~= A) then pc++";
      return op
end

local function _TEST(ins)
      local op = iABC(ins)
  	  op.name = "OP_TEST";
	  op.description = "if not (R(A) <=> C) then pc++";
      return op
end

local function _TESTSET(ins)
      local op = iABC(ins)
  	  op.name = "OP_TESTSET";
	  op.description = "if (R(B) <=> C) then R(A) := R(B) else pc++";
      return op
end

local function _CALL(ins)
      local op = iABC(ins)
      op.name = "OP_CALL";
      op.description = "R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1))";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
			   return "Call [" .. self.A .. "," .. self.B .. "," .. self.C .. "] ".. nameA;
--[[
      		  	   local nameB = "__tmp" .. tostring(self.B - cl.f.sizelocvars - 1);
			   if (cl.f.locvars[self.B+1]) then nameB =  cl.f.locvars[self.B+1].varname; end
      		  	   return (nameA .. " = " .. nameB);
]]--
      		  end
	  
      return op
end

local function _TAILCALL(ins)
      local op = iABC(ins)
  	  op.name = "OP_TAILCALL";
	  op.description = "return R(A)(R(A+1), ... ,R(A+B-1))";
      return op
end

local function _RETURN(ins)
      local op = iABC(ins)
  	  op.name = "OP_RETURN";
	  op.description = "return R(A), ... ,R(A+B-2) (see note)";
      return op
end

local function _FORLOOP(ins)
      local op = iAsBx(ins)
  	  op.name = "OP_FORLOOP";
	  op.description = "R(A)+=R(A+2); if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) }";
      return op
end

local function _FORPREP(ins)
      local op = iAsBx(ins)
  	  op.name = "OP_FORPREP";
	  op.description = "R(A)-=R(A+2); pc+=sBx";
      return op
end

local function _TFORCALL(ins)
      local op = iABC(ins)
  	  op.name = "OP_TFORCALL";
	  op.description = "R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));";
      return op
end

local function _TFORLOOP(ins)
      local op = iAsBx(ins)
  	  op.name = "OP_TFORLOOP";
	  op.description = "if R(A+1) ~= nil then { R(A)=R(A+1); pc += sBx }";
      return op
end


local function _SETLIST(ins)
      local op = iABC(ins)
  	  op.name = "OP_SETLIST";
	  op.description = "R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B";
      return op
end


local function _CLOSURE(ins)
      local op = iABx(ins)
      op.name = "OP_CLOSURE";
      op.description = "R(A) := closure(KPROTO[Bx])";
      op.preety = function (self, cl)
      		  	   local nameA = "__locals_" .. tostring(self.A);
			   if (cl.f.locvars[self.A+1]) then nameA =  cl.f.locvars[self.A+1].varname; end
      		  	   return (nameA .. " = Functions[" ..  tostring(self.Bx) .. "]");
      		  end

      return op
end


local function _VARARG(ins)
      local op = iABC(ins)
  	  op.name = "OP_VARARG";
	  op.description = "R(A), R(A+1), ..., R(A+B-2) = vararg";
      return op
end

local function _EXTRAARG(ins)
      local op = iAx(ins)
   	  op.name = "OP_EXTRAARG";
	  op.description = "extra (larger) argument for previous opcode";
      return op
end


--[[

]]--

local names = 
{
	"OP_MOVE",
	"OP_LOADK",
	"OP_LOADKX",
	"OP_LOADBOOL",
	"OP_LOADNIL",
	"OP_GETUPVAL",
	"OP_GETTABUP",
	"OP_GETTABLE",
	"OP_SETTABUP",
	"OP_SETUPVAL",
	"OP_SETTABLE",
	"OP_NEWTABLE",
	"OP_SELF",
	"OP_ADD",
	"OP_SUB",
	"OP_MUL",
	"OP_DIV",
	"OP_MOD",
	"OP_POW",
	"OP_UNM",
	"OP_NOT",
	"OP_LEN",
	"OP_CONCAT",
	"OP_JMP",
	"OP_EQ",
	"OP_LT",
	"OP_LE",
	"OP_TEST",
	"OP_TESTSET",
	"OP_CALL",
	"OP_TAILCALL",
	"OP_RETURN",
	"OP_FORLOOP",
	"OP_FORPREP",
	"OP_TFORCALL",
	"OP_TFORLOOP",
	"OP_SETLIST",
	"OP_CLOSURE",
	"OP_VARARG",
	"OP_EXTRAARG"
}

local operations = 
{
	OP_MOVE = _MOVE,
	OP_LOADK = _LOADK,
	OP_LOADKX = _LOADKX,
	OP_LOADBOOL = _LOADBOOL,
	OP_LOADNIL = _LOADNIL,
	OP_GETUPVAL = _GETUPVAL,
	OP_GETTABUP = _GETTABUP,
	OP_GETTABLE = _GETTABLE,
	OP_SETTABUP = _SETTABUP,
	OP_SETUPVAL = _SETUPVAL,

	OP_SETTABLE = _SETTABLE,
	OP_NEWTABLE = _NEWTABLE,
	OP_SELF = _SELF,
	OP_ADD = _ADD,
	OP_SUB = _SUB,
	OP_MUL = _MUL,
	OP_DIV = _DIV,
	OP_MOD = _MOD,
	OP_POW = _POW,
	OP_UNM = _UNM,
	OP_NOT = _NOT,
	OP_LEN = _LEN,
	OP_CONCAT = _CONCAT,
	OP_JMP = _JMP,

	OP_EQ = _EQ,
	OP_LT = _LT,
	OP_LE = _LE,
	OP_TEST = _TEST,
	OP_TESTSET = _TESTSET,
	OP_CALL = _CALL,
	OP_TAILCALL = _TAILCALL,
	OP_RETURN = _RETURN,
	OP_FORLOOP = _FORLOOP,
	OP_FORPREP = _FORPREP,
	OP_TFORCALL = _TFORCALL,
	OP_TFORLOOP = _TFORLOOP,
	OP_SETLIST = _SETLIST,
	OP_CLOSURE = _CLOSURE,
	OP_VARARG = _VARARG,
	OP_EXTRAARG = _EXTRAARG,
}

local function _general_op (t, k)
      return iBase 	  
end

setmetatable (operations, {__index = _general_op})

local function fetch(ins)
--      print ("fetch:" .. string.format("%08X", ins) .. "\n");

	  local op = bit.band(ins, 0x3F);
      local name = names[op + 1] or ""
--      print ("op: " .. tostring(op) .. ", name: " .. name)
      return operations[name](ins)
end




return fetch
