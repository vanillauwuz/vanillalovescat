local StrToNumber = tonumber;
local Byte = string.byte;
local Char = string.char;
local Sub = string.sub;
local Subg = string.gsub;
local Rep = string.rep;
local Concat = table.concat;
local Insert = table.insert;
local LDExp = math.ldexp;
local GetFEnv = getfenv or function()
	return _ENV;
end;
local Setmetatable = setmetatable;
local PCall = pcall;
local Select = select;
local Unpack = unpack or table.unpack;
local ToNumber = tonumber;
local function VMCall(ByteString, vmenv, ...)
	local DIP = 1;
	local repeatNext;
	ByteString = Subg(Sub(ByteString, 5), "..", function(byte)
		if (Byte(byte, 2) == 79) then
			repeatNext = StrToNumber(Sub(byte, 1, 1));
			return "";
		else
			local a = Char(StrToNumber(byte, 16));
			if repeatNext then
				local b = Rep(a, repeatNext);
				repeatNext = nil;
				return b;
			else
				return a;
			end
		end
	end);
	local function gBit(Bit, Start, End)
		if End then
			local Res = (Bit / (2 ^ (Start - 1))) % (2 ^ (((End - 1) - (Start - 1)) + 1));
			return Res - (Res % 1);
		else
			local Plc = 2 ^ (Start - 1);
			return (((Bit % (Plc + Plc)) >= Plc) and 1) or 0;
		end
	end
	local function gBits8()
		local a = Byte(ByteString, DIP, DIP);
		DIP = DIP + 1;
		return a;
	end
	local function gBits16()
		local a, b = Byte(ByteString, DIP, DIP + 2);
		DIP = DIP + 2;
		return (b * 256) + a;
	end
	local function gBits32()
		local a, b, c, d = Byte(ByteString, DIP, DIP + 3);
		DIP = DIP + 4;
		return (d * 16777216) + (c * 65536) + (b * 256) + a;
	end
	local function gFloat()
		local Left = gBits32();
		local Right = gBits32();
		local IsNormal = 1;
		local Mantissa = (gBit(Right, 1, 20) * (2 ^ 32)) + Left;
		local Exponent = gBit(Right, 21, 31);
		local Sign = ((gBit(Right, 32) == 1) and -1) or 1;
		if (Exponent == 0) then
			if (Mantissa == 0) then
				return Sign * 0;
			else
				Exponent = 1;
				IsNormal = 0;
			end
		elseif (Exponent == 2047) then
			return ((Mantissa == 0) and (Sign * (1 / 0))) or (Sign * NaN);
		end
		return LDExp(Sign, Exponent - 1023) * (IsNormal + (Mantissa / (2 ^ 52)));
	end
	local function gString(Len)
		local Str;
		if not Len then
			Len = gBits32();
			if (Len == 0) then
				return "";
			end
		end
		Str = Sub(ByteString, DIP, (DIP + Len) - 1);
		DIP = DIP + Len;
		local FStr = {};
		for Idx = 1, #Str do
			FStr[Idx] = Char(Byte(Sub(Str, Idx, Idx)));
		end
		return Concat(FStr);
	end
	local gInt = gBits32;
	local function _R(...)
		return {...}, Select("#", ...);
	end
	local function Deserialize()
		local Instrs = {};
		local Functions = {};
		local Lines = {};
		local Chunk = {Instrs,Functions,nil,Lines};
		local ConstCount = gBits32();
		local Consts = {};
		for Idx = 1, ConstCount do
			local Type = gBits8();
			local Cons;
			if (Type == 1) then
				Cons = gBits8() ~= 0;
			elseif (Type == 2) then
				Cons = gFloat();
			elseif (Type == 3) then
				Cons = gString();
			end
			Consts[Idx] = Cons;
		end
		Chunk[3] = gBits8();
		for Idx = 1, gBits32() do
			local Descriptor = gBits8();
			if (gBit(Descriptor, 1, 1) == 0) then
				local Type = gBit(Descriptor, 2, 3);
				local Mask = gBit(Descriptor, 4, 6);
				local Inst = {gBits16(),gBits16(),nil,nil};
				if (Type == 0) then
					Inst[3] = gBits16();
					Inst[4] = gBits16();
				elseif (Type == 1) then
					Inst[3] = gBits32();
				elseif (Type == 2) then
					Inst[3] = gBits32() - (2 ^ 16);
				elseif (Type == 3) then
					Inst[3] = gBits32() - (2 ^ 16);
					Inst[4] = gBits16();
				end
				if (gBit(Mask, 1, 1) == 1) then
					Inst[2] = Consts[Inst[2]];
				end
				if (gBit(Mask, 2, 2) == 1) then
					Inst[3] = Consts[Inst[3]];
				end
				if (gBit(Mask, 3, 3) == 1) then
					Inst[4] = Consts[Inst[4]];
				end
				Instrs[Idx] = Inst;
			end
		end
		for Idx = 1, gBits32() do
			Functions[Idx - 1] = Deserialize();
		end
		return Chunk;
	end
	local function Wrap(Chunk, Upvalues, Env)
		local Instr = Chunk[1];
		local Proto = Chunk[2];
		local Params = Chunk[3];
		return function(...)
			local Instr = Instr;
			local Proto = Proto;
			local Params = Params;
			local _R = _R;
			local VIP = 1;
			local Top = -1;
			local Vararg = {};
			local Args = {...};
			local PCount = Select("#", ...) - 1;
			local Lupvals = {};
			local Stk = {};
			for Idx = 0, PCount do
				if (Idx >= Params) then
					Vararg[Idx - Params] = Args[Idx + 1];
				else
					Stk[Idx] = Args[Idx + 1];
				end
			end
			local Varargsz = (PCount - Params) + 1;
			local Inst;
			local Enum;
			while true do
				Inst = Instr[VIP];
				Enum = Inst[1];
				if (Enum <= 58) then
					if (Enum <= 28) then
						if (Enum <= 13) then
							if (Enum <= 6) then
								if (Enum <= 2) then
									if (Enum <= 0) then
										Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									elseif (Enum > 1) then
										local A = Inst[2];
										local T = Stk[A];
										for Idx = A + 1, Inst[3] do
											Insert(T, Stk[Idx]);
										end
									else
										local A = Inst[2];
										local Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
										Top = (Limit + A) - 1;
										local Edx = 0;
										for Idx = A, Top do
											Edx = Edx + 1;
											Stk[Idx] = Results[Edx];
										end
									end
								elseif (Enum <= 4) then
									if (Enum > 3) then
										Stk[Inst[2]] = Stk[Inst[3]] * Stk[Inst[4]];
									else
										Upvalues[Inst[3]] = Stk[Inst[2]];
									end
								elseif (Enum == 5) then
									if (Stk[Inst[2]] < Stk[Inst[4]]) then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									Stk[Inst[2]] = #Stk[Inst[3]];
								end
							elseif (Enum <= 9) then
								if (Enum <= 7) then
									Stk[Inst[2]] = Stk[Inst[3]] - Stk[Inst[4]];
								elseif (Enum == 8) then
									for Idx = Inst[2], Inst[3] do
										Stk[Idx] = nil;
									end
								else
									local A = Inst[2];
									do
										return Unpack(Stk, A, Top);
									end
								end
							elseif (Enum <= 11) then
								if (Enum == 10) then
									Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
								else
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								end
							elseif (Enum == 12) then
								Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
							else
								Stk[Inst[2]] = #Stk[Inst[3]];
							end
						elseif (Enum <= 20) then
							if (Enum <= 16) then
								if (Enum <= 14) then
									if not Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								elseif (Enum > 15) then
									local A = Inst[2];
									Top = (A + Varargsz) - 1;
									for Idx = A, Top do
										local VA = Vararg[Idx - A];
										Stk[Idx] = VA;
									end
								else
									local A = Inst[2];
									do
										return Stk[A](Unpack(Stk, A + 1, Top));
									end
								end
							elseif (Enum <= 18) then
								if (Enum > 17) then
									do
										return Stk[Inst[2]];
									end
								else
									local A = Inst[2];
									do
										return Stk[A](Unpack(Stk, A + 1, Top));
									end
								end
							elseif (Enum > 19) then
								if (Stk[Inst[2]] <= Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								Top = (A + Varargsz) - 1;
								for Idx = A, Top do
									local VA = Vararg[Idx - A];
									Stk[Idx] = VA;
								end
							end
						elseif (Enum <= 24) then
							if (Enum <= 22) then
								if (Enum > 21) then
									Stk[Inst[2]] = Stk[Inst[3]] * Inst[4];
								else
									do
										return;
									end
								end
							elseif (Enum > 23) then
								local A = Inst[2];
								local T = Stk[A];
								for Idx = A + 1, Top do
									Insert(T, Stk[Idx]);
								end
							else
								Stk[Inst[2]] = Stk[Inst[3]];
							end
						elseif (Enum <= 26) then
							if (Enum == 25) then
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								Stk[Inst[2]]();
							end
						elseif (Enum > 27) then
							if (Stk[Inst[2]] > Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]] * Inst[4];
						end
					elseif (Enum <= 43) then
						if (Enum <= 35) then
							if (Enum <= 31) then
								if (Enum <= 29) then
									local A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Top));
								elseif (Enum > 30) then
									local A = Inst[2];
									do
										return Unpack(Stk, A, A + Inst[3]);
									end
								else
									Stk[Inst[2]]();
								end
							elseif (Enum <= 33) then
								if (Enum == 32) then
									Upvalues[Inst[3]] = Stk[Inst[2]];
								else
									Stk[Inst[2]] = Env[Inst[3]];
								end
							elseif (Enum > 34) then
								Stk[Inst[2]] = Stk[Inst[3]];
							else
								local A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
							end
						elseif (Enum <= 39) then
							if (Enum <= 37) then
								if (Enum == 36) then
									local A = Inst[2];
									local Results, Limit = _R(Stk[A](Stk[A + 1]));
									Top = (Limit + A) - 1;
									local Edx = 0;
									for Idx = A, Top do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
								else
									local B = Inst[3];
									local K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
								end
							elseif (Enum == 38) then
								local A = Inst[2];
								local T = Stk[A];
								local B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							else
								Stk[Inst[2]] = {};
							end
						elseif (Enum <= 41) then
							if (Enum == 40) then
								do
									return;
								end
							else
								Stk[Inst[2]] = Env[Inst[3]];
							end
						elseif (Enum == 42) then
							if (Stk[Inst[2]] <= Stk[Inst[4]]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]] * Stk[Inst[4]];
						end
					elseif (Enum <= 50) then
						if (Enum <= 46) then
							if (Enum <= 44) then
								local A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Top));
							elseif (Enum > 45) then
								if (Stk[Inst[2]] == Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local NewProto = Proto[Inst[3]];
								local NewUvals;
								local Indexes = {};
								NewUvals = Setmetatable({}, {__index=function(_, Key)
									local Val = Indexes[Key];
									return Val[1][Val[2]];
								end,__newindex=function(_, Key, Value)
									local Val = Indexes[Key];
									Val[1][Val[2]] = Value;
								end});
								for Idx = 1, Inst[4] do
									VIP = VIP + 1;
									local Mvm = Instr[VIP];
									if (Mvm[1] == 23) then
										Indexes[Idx - 1] = {Stk,Mvm[3]};
									else
										Indexes[Idx - 1] = {Upvalues,Mvm[3]};
									end
									Lupvals[#Lupvals + 1] = Indexes;
								end
								Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
							end
						elseif (Enum <= 48) then
							if (Enum > 47) then
								if (Inst[2] < Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								local Results, Limit = _R(Stk[A]());
								Top = (Limit + A) - 1;
								local Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum == 49) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						else
							local A = Inst[2];
							Stk[A] = Stk[A]();
						end
					elseif (Enum <= 54) then
						if (Enum <= 52) then
							if (Enum > 51) then
								local A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
							else
								Stk[Inst[2]] = Inst[3] ~= 0;
							end
						elseif (Enum == 53) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						elseif Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 56) then
						if (Enum == 55) then
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						else
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum > 57) then
						local A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Top));
					else
						local A = Inst[2];
						Stk[A](Stk[A + 1]);
					end
				elseif (Enum <= 88) then
					if (Enum <= 73) then
						if (Enum <= 65) then
							if (Enum <= 61) then
								if (Enum <= 59) then
									local A = Inst[2];
									do
										return Stk[A](Unpack(Stk, A + 1, Inst[3]));
									end
								elseif (Enum == 60) then
									if (Stk[Inst[2]] < Inst[4]) then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									local A = Inst[2];
									local Results = {Stk[A]()};
									local Limit = Inst[4];
									local Edx = 0;
									for Idx = A, Limit do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
								end
							elseif (Enum <= 63) then
								if (Enum == 62) then
									Stk[Inst[2]] = Stk[Inst[3]] - Inst[4];
								else
									local A = Inst[2];
									local B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
								end
							elseif (Enum == 64) then
								do
									return Stk[Inst[2]];
								end
							else
								Stk[Inst[2]][Stk[Inst[3]]] = Stk[Inst[4]];
							end
						elseif (Enum <= 69) then
							if (Enum <= 67) then
								if (Enum > 66) then
									local A = Inst[2];
									Stk[A](Stk[A + 1]);
								else
									local A = Inst[2];
									local Results = {Stk[A]()};
									local Limit = Inst[4];
									local Edx = 0;
									for Idx = A, Limit do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
								end
							elseif (Enum == 68) then
								if (Stk[Inst[2]] > Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								Stk[A] = Stk[A]();
							end
						elseif (Enum <= 71) then
							if (Enum == 70) then
								Stk[Inst[2]] = Inst[3];
							else
								Stk[Inst[2]][Inst[3]] = Inst[4];
							end
						elseif (Enum > 72) then
							if (Stk[Inst[2]] ~= Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						end
					elseif (Enum <= 80) then
						if (Enum <= 76) then
							if (Enum <= 74) then
								Stk[Inst[2]] = -Stk[Inst[3]];
							elseif (Enum == 75) then
								local A = Inst[2];
								local Cls = {};
								for Idx = 1, #Lupvals do
									local List = Lupvals[Idx];
									for Idz = 0, #List do
										local Upv = List[Idz];
										local NStk = Upv[1];
										local DIP = Upv[2];
										if ((NStk == Stk) and (DIP >= A)) then
											Cls[DIP] = NStk[DIP];
											Upv[1] = Cls;
										end
									end
								end
							else
								local A = Inst[2];
								local T = Stk[A];
								local B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							end
						elseif (Enum <= 78) then
							if (Enum > 77) then
								if not Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum > 79) then
							VIP = Inst[3];
						else
							Stk[Inst[2]] = -Stk[Inst[3]];
						end
					elseif (Enum <= 84) then
						if (Enum <= 82) then
							if (Enum > 81) then
								if (Stk[Inst[2]] == Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = {};
							end
						elseif (Enum == 83) then
							local A = Inst[2];
							local Results, Limit = _R(Stk[A]());
							Top = (Limit + A) - 1;
							local Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum <= 86) then
						if (Enum == 85) then
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						end
					elseif (Enum > 87) then
						Stk[Inst[2]] = Stk[Inst[3]] + Stk[Inst[4]];
					else
						Stk[Inst[2]] = Stk[Inst[3]] + Stk[Inst[4]];
					end
				elseif (Enum <= 103) then
					if (Enum <= 95) then
						if (Enum <= 91) then
							if (Enum <= 89) then
								local A = Inst[2];
								local B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
							elseif (Enum == 90) then
								if (Stk[Inst[2]] < Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = Inst[3];
							end
						elseif (Enum <= 93) then
							if (Enum == 92) then
								Stk[Inst[2]] = Stk[Inst[3]] - Inst[4];
							else
								Stk[Inst[2]] = Inst[3] ~= 0;
							end
						elseif (Enum == 94) then
							local A = Inst[2];
							local Results = {Stk[A](Unpack(Stk, A + 1, Top))};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							local A = Inst[2];
							local C = Inst[4];
							local CB = A + 2;
							local Result = {Stk[A](Stk[A + 1], Stk[CB])};
							for Idx = 1, C do
								Stk[CB + Idx] = Result[Idx];
							end
							local R = Result[1];
							if R then
								Stk[CB] = R;
								VIP = Inst[3];
							else
								VIP = VIP + 1;
							end
						end
					elseif (Enum <= 99) then
						if (Enum <= 97) then
							if (Enum == 96) then
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local B = Inst[3];
								local K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
							end
						elseif (Enum == 98) then
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						else
							local A = Inst[2];
							local C = Inst[4];
							local CB = A + 2;
							local Result = {Stk[A](Stk[A + 1], Stk[CB])};
							for Idx = 1, C do
								Stk[CB + Idx] = Result[Idx];
							end
							local R = Result[1];
							if R then
								Stk[CB] = R;
								VIP = Inst[3];
							else
								VIP = VIP + 1;
							end
						end
					elseif (Enum <= 101) then
						if (Enum == 100) then
							Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
						else
							local NewProto = Proto[Inst[3]];
							local NewUvals;
							local Indexes = {};
							NewUvals = Setmetatable({}, {__index=function(_, Key)
								local Val = Indexes[Key];
								return Val[1][Val[2]];
							end,__newindex=function(_, Key, Value)
								local Val = Indexes[Key];
								Val[1][Val[2]] = Value;
							end});
							for Idx = 1, Inst[4] do
								VIP = VIP + 1;
								local Mvm = Instr[VIP];
								if (Mvm[1] == 23) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						end
					elseif (Enum > 102) then
						local A = Inst[2];
						local T = Stk[A];
						for Idx = A + 1, Top do
							Insert(T, Stk[Idx]);
						end
					else
						local A = Inst[2];
						do
							return Unpack(Stk, A, Top);
						end
					end
				elseif (Enum <= 110) then
					if (Enum <= 106) then
						if (Enum <= 104) then
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						elseif (Enum > 105) then
							for Idx = Inst[2], Inst[3] do
								Stk[Idx] = nil;
							end
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 108) then
						if (Enum == 107) then
							local A = Inst[2];
							local Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
							Top = (Limit + A) - 1;
							local Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							Stk[Inst[2]][Stk[Inst[3]]] = Stk[Inst[4]];
						end
					elseif (Enum > 109) then
						local A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Top));
					else
						local A = Inst[2];
						local Cls = {};
						for Idx = 1, #Lupvals do
							local List = Lupvals[Idx];
							for Idz = 0, #List do
								local Upv = List[Idz];
								local NStk = Upv[1];
								local DIP = Upv[2];
								if ((NStk == Stk) and (DIP >= A)) then
									Cls[DIP] = NStk[DIP];
									Upv[1] = Cls;
								end
							end
						end
					end
				elseif (Enum <= 114) then
					if (Enum <= 112) then
						if (Enum == 111) then
							local A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
						else
							VIP = Inst[3];
						end
					elseif (Enum == 113) then
						if (Stk[Inst[2]] ~= Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Inst[2] < Stk[Inst[4]]) then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 116) then
					if (Enum == 115) then
						local A = Inst[2];
						local Results, Limit = _R(Stk[A](Stk[A + 1]));
						Top = (Limit + A) - 1;
						local Edx = 0;
						for Idx = A, Top do
							Edx = Edx + 1;
							Stk[Idx] = Results[Edx];
						end
					else
						local A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Inst[3]));
					end
				elseif (Enum > 117) then
					Stk[Inst[2]] = Stk[Inst[3]] - Stk[Inst[4]];
				else
					local A = Inst[2];
					local Results = {Stk[A](Unpack(Stk, A + 1, Top))};
					local Edx = 0;
					for Idx = A, Inst[4] do
						Edx = Edx + 1;
						Stk[Idx] = Results[Edx];
					end
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!923O0003083O00636C6F6E6572656603043O0067616D65030A3O004765745365727669636503103O0055736572496E7075745365727669636503073O00506C6179657273030B3O004C6F63616C506C6179657203113O005265706C69636174656453746F72616765030C3O0057616974466F724368696C6403063O00686974626F7803063O007369676E616C030D3O00706C617965725265717565737403073O006D6F64756C657303073O006E6574776F726B03073O0072657175697265031C3O00612O706C794A6F6C7456656C6F63697479546F436861726163746572031A3O006163746976654162696C697479457865637574696F6E4461746103163O0061637469766174654162696C69747952657175657374030D3O006162696C6974794C2O6F6B757003083O004175746F4661726D0100030C3O004175746F4661726D426F2O73030A3O004175746F5069636B757003103O0044616D616765496E64696361746F727303083O004B692O6C6175726103103O004B692O6C61757261432O6F6C646F776E026O00E03F03063O00506C6179657203073O00476F644D6F6465030C3O004E6F46612O6C44616D616765030F3O00496E66696E6974655374616D696E6103063O00466C69676874030B3O00466C6967687453702O6564026O005940030A3O006C6F6164737472696E6703073O00482O747047657403493O00682O7470733A2O2F6769746875622E636F6D2F64617769642D736372697074732F466C75656E742F72656C65617365732F6C61746573742F646F776E6C6F61642F6D61696E2E6C756103543O00682O7470733A2O2F7261772E67697468756275736572636F6E74656E742E636F6D2F64617769642D736372697074732F466C75656E742F6D61737465722F412O646F6E732F536176654D616E616765722E6C756103593O00682O7470733A2O2F7261772E67697468756275736572636F6E74656E742E636F6D2F64617769642D736372697074732F466C75656E742F6D61737465722F412O646F6E732F496E746572666163654D616E616765722E6C7561030C3O0043726561746557696E646F7703053O005469746C6503093O0056657374657269612003073O0056657273696F6E03083O005375625469746C65030A3O0062792076616E692O6C6103083O005461625769647468026O00644003043O0053697A6503053O005544696D32030A3O0066726F6D4F2O66736574025O00208240025O00C07C4003073O00416372796C69632O0103053O005468656D6503043O004461726B030B3O004D696E696D697A654B657903043O00456E756D03073O004B6579436F6465030B3O004C656674436F6E74726F6C03043O004D61696E03063O00412O6454616203043O0049636F6E03043O00686F6D6503043O007573657203083O0053652O74696E677303083O0073652O74696E677303073O004F7074696F6E7303093O00412O64546F2O676C6503093O004175746F5F4661726D03093O004175746F204661726D03073O0044656661756C7403083O0043612O6C6261636B030E3O004175746F5F4661726D5F426F2O7303183O004175746F20426F2O73205B6E6F742066696E69736865645D03093O004175746F5F5069636B03093O004175746F205069636B030A3O00412O6453656374696F6E03083O004B692O6C4175726103093O004B692O6C5F6175726103093O004B692O6C204175726103143O004E6F5F44616D6167655F496E64696361746F727303143O004E6F2044616D61676520496E64696361746F727303093O00412O64536C6964657203123O004B692O6C5F617572615F432O6F6C646F776E03123O004B692O6C204175726120432O6F6C646F776E030B3O004465736372697074696F6E034O002O033O004D696E028O002O033O004D6178026O00F03F03083O00526F756E64696E67030B3O00412O6444726F70646F776E030E3O004661726D655F506F736974696F6E030D3O004661726D20506F736974696F6E03063O0056616C75657303053O0042656C6F7703053O0041626F766503053O0046726F6E7403063O00426568696E6403053O004D756C7469026O001040030D3O004661726D5F44697374616E6365030D3O004661726D2044697374616E6365026O001440026O00244003083O00476F645F4D6F646503083O00476F64204D6F6465030D3O004E6F5F46612O6C44616D616765030E3O004E6F2046612O6C2044616D61676503103O00496E66696E6974655F5374616D696E6103103O00496E66696E697465205374616D696E612O033O00466C79030C3O00466C696768745F53702O6564030C3O00466C696768742053702O6564026O004940025O00C07240030A3O005365744C69627261727903133O0049676E6F72655468656D6553652O74696E677303103O0053657449676E6F7265496E646578657303093O00536574466F6C646572030F3O00466C75656E74536372697074487562031D3O00466C75656E745363726970744875622F73706563696669632D67616D6503153O004275696C64496E7465726661636553656374696F6E03123O004275696C64436F6E66696753656374696F6E03093O0053656C65637454616203063O004E6F7469667903083O00566573746572696103073O00436F6E74656E74031B3O00546865207363726970742068617320622O656E206C6F616465642E03083O004475726174696F6E026O00204003123O004C6F61644175746F6C6F6164436F6E666967030E3O00682O6F6B6D6574616D6574686F64030A3O002O5F6E616D6563612O6C03073O002O5F696E646578030F3O006765747261776D6574617461626C65030B3O00736574726561646F6E6C79030B3O006E65772O636C6F737572650343012O008O206C6F63616C206F6C642C2053652O74696E6773203D203O2E0A8O2072657475726E2066756E6374696F6E2873656C662C203O2E290A9O203O2069662053652O74696E67735B2244616D616765496E64696361746F7273225D20616E642073656C662E4E616D65202O3D202264616D616765496E64696361746F722220616E64206765746E616D6563612O6C6D6574686F642829202O3D2022436C6F6E6522207468656E0A9O207O2072657475726E20496E7374616E63652E6E6577282242696E6461626C654576656E7422292E4576656E743A5761697428290A9O203O20656E640A9O203O2072657475726E206F6C645B315D2873656C662C203O2E290A8O20656E640A4O2003043O007469636B027O004003043O006669726503043O007461736B03053O00737061776E026O00344000C0012O0012213O00013O001221000100023O00203F00010001000300125B000300044O0001000100034O006E5O0002001221000100013O001221000200023O00203F00020002000300125B000400054O0001000200044O006E00013O0002001221000200013O0020680003000100062O0034000200020002001221000300013O001221000400023O00203F00040004000300125B000600074O0001000400064O006E00033O000200066500043O000100012O00173O00024O0023000500044O004500050001000200203F00050005000800125B000700094O003800050007000200203F00060003000800125B0008000A4O003800060008000200203F00070003000800125B0009000B4O003800070009000200203F00080003000800125B000A000C4O00380008000A000200203F00090008000800125B000B000D4O00380009000B0002001221000A000E3O001221000B00023O00203F000B000B000300125B000D00074O0038000B000D0002002068000B000B000C002068000B000B000D2O0034000A0002000200203F000B0009000800125B000D000F4O0038000B000D000200203F000C0005000800125B000E00104O0038000C000E000200203F000D0009000800125B000F00114O0038000D000F0002001221000E000E3O00203F000F0003000800125B001100124O0001000F00114O006E000E3O00022O0027000F3O0007003047000F00130014003047000F00150014003047000F00160014003047000F00170014003047000F00180014003047000F0019001A2O002700103O00050030470010001C00140030470010001D00140030470010001E00140030470010001F001400304700100020002100102O000F001B0010001221001000223O001221001100023O00203F00110011002300125B001300244O0001001100134O006E00103O00022O0045001000010002001221001100223O001221001200023O00203F00120012002300125B001400254O0001001200144O006E00113O00022O0045001100010002001221001200223O001221001300023O00203F00130013002300125B001500264O0001001300154O006E00123O00022O004500120001000200203F0013001000272O002700153O000700125B001600293O00206800170010002A2O006100160016001700102O0015002800160030470015002B002C0030470015002D002E001221001600303O00206800160016003100125B001700323O00125B001800334O003800160018000200102O0015002F0016003047001500340035003047001500360037001221001600393O00206800160016003A00206800160016003B00102O0015003800162O00380013001500022O002700143O000300203F00150013003D2O002700173O000200304700170028003C0030470017003E003F2O003800150017000200102O0014003C001500203F00150013003D2O002700173O000200304700170028001B0030470017003E00402O003800150017000200102O0014001B001500203F00150013003D2O002700173O00020030470017002800410030470017003E00422O003800150017000200102O00140041001500206800150010004300206800160014003C00203F00160016004400125B001800454O002700193O0003003047001900280046003047001900470014000665001A0001000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014003C00203F00160016004400125B001800494O002700193O000300304700190028004A00304700190047001400020C001A00023O00102O00190048001A2O007400160019000100206800160014003C00203F00160016004400125B0018004B4O002700193O000300304700190028004C003047001900470014000665001A0003000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014003C00203F00160016004D00125B0018004E4O007400160018000100206800160014003C00203F00160016004400125B0018004F4O002700193O0003003047001900280050003047001900470014000665001A0004000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014003C00203F00160016004400125B001800514O002700193O0003003047001900280052003047001900470014000665001A0005000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014003C00203F00160016005300125B001800544O002700193O000700304700190028005500304700190056005700304700190047001A0030470019005800590030470019005A005B0030470019005C005B000665001A0006000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014003C00203F00160016004D00125B001800414O007400160018000100206800160014003C00203F00160016005D00125B0018005E4O002700193O000400304700190028005F2O0027001A00043O00125B001B00613O00125B001C00623O00125B001D00633O00125B001E00644O0026001A0004000100102O00190060001A0030470019006500140030470019004700662O007400160019000100206800160014003C00203F00160016005300125B001800674O002700193O00060030470019002800680030470019005600570030470019004700690030470019005800690030470019005A006A0030470019005C00592O007400160019000100206800160014001B00203F00160016004400125B0018006B4O002700193O000300304700190028006C003047001900470014000665001A0007000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014001B00203F00160016004400125B0018006D4O002700193O000300304700190028006E003047001900470014000665001A0008000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014001B00203F00160016004400125B0018006F4O002700193O0003003047001900280070003047001900470014000665001A0009000100012O00173O000F3O00102O00190048001A2O007400160019000100206800160014001B00203F00160016004D00125B001800714O007400160018000100206800160014001B00203F00160016004400125B0018001F4O002700193O000300304700190028001F003047001900470014000665001A000A000100022O00173O000F4O00173O00023O00102O00190048001A2O007400160019000100206800160014001B00203F00160016005300125B001800724O002700193O00070030470019002800730030470019005600570030470019004700210030470019005800740030470019005A00750030470019005C0059000665001A000B000100012O00173O000F3O00102O00190048001A2O007400160019000100203F0016001100762O0023001800104O007400160018000100203F0016001200762O0023001800104O007400160018000100203F0016001100772O004300160002000100203F0016001100782O002700186O007400160018000100203F00160012007900125B0018007A4O007400160018000100203F00160011007900125B0018007B4O007400160018000100203F00160012007C0020680018001400412O007400160018000100203F00160011007D0020680018001400412O007400160018000100203F00160013007E00125B0018005B4O007400160018000100203F00160010007F2O002700183O00030030470018002800800030470018008100820030470018008300842O007400160018000100203F0016001100852O00430016000200010006650016000C000100012O00173O00153O0006650017000D000100022O00173O00054O00173O00163O0006650018000E000100012O00173O00023O0006650019000F000100012O00173O00194O0008001A001A3O001221001B00863O001221001C00023O00125B001D00873O000665001E0010000100032O00173O000F4O00173O00194O00173O001A4O0038001B001E00022O0023001A001B4O0008001B001B3O001221001C00863O001221001D00023O00125B001E00883O000665001F0011000100022O00173O000F4O00173O001B4O0038001C001F00022O0023001B001C3O001221001C00893O001221001D00024O0034001C00020002002068001D001C0087001221001E008A4O0023001F001C4O003300206O0074001E00200001001221001E008B3O000665001F0012000100022O00173O000F4O00173O001D4O0034001E0002000200102O001C0087001E001221001E008A4O0023001F001C4O0033002000014O0074001E002000012O004B001A6O0027001A5O001221001B00863O001221001C00023O00125B001D00873O001221001E00223O00125B001F008C4O0034001E000200022O0023001F001A4O00230020000F4O0001001E00204O006E001B3O000200102O001A005B001B001221001A008D4O0045001A0001000200205C001A001A008E2O0008001B001B3O002068001C000A008F000665001D0013000100042O00173O001C4O00173O001A4O00173O000F4O00173O001B3O00102O000A008F001D001221001D00903O002068001D001D0091000665001E0014000100032O00173O001B4O00173O001A4O00173O001C4O0043001D000200012O004B001A6O0027001A5O00125B001B00923O000665001C0015000100052O00173O00024O00173O001A4O00173O001B4O00173O00074O00173O00043O001221001D00903O002068001D001D0091000665001E0016000100032O00173O000F4O00173O00184O00173O00174O0043001D00020001001221001D00903O002068001D001D0091000665001E0017000100022O00173O000F4O00173O00174O0043001D00020001001221001D00903O002068001D001D0091000665001E0018000100032O00173O000F4O00173O00184O00173O00064O0043001D00020001001221001D00903O002068001D001D0091000665001E0019000100022O00173O000F4O00173O001C4O0043001D00020001001221001D00903O002068001D001D0091000665001E001A000100032O00173O000F4O00173O00044O00173O00024O0043001D000200012O00283O00013O001B3O00033O0003093O00436861726163746572030E3O00436861726163746572412O64656403043O0057616974000A4O00357O0020685O000100064E3O0008000100010004703O000800012O00357O0020685O000200203F5O00032O00343O000200022O00403O00024O00283O00017O00013O0003083O004175746F4661726D01034O003500015O00102O000100014O00283O00019O002O002O014O00283O00017O00013O00030A3O004175746F5069636B757001034O003500015O00102O000100014O00283O00017O00013O0003083O004B692O6C6175726101034O003500015O00102O000100014O00283O00017O00013O0003103O0044616D616765496E64696361746F727301034O003500015O00102O000100014O00283O00017O00013O0003103O004B692O6C61757261432O6F6C646F776E01034O003500015O00102O000100014O00283O00017O00023O0003063O00506C6179657203073O00476F644D6F646501044O003500015O00206800010001000100102O000100024O00283O00017O00023O0003063O00506C61796572030C3O004E6F46612O6C44616D61676501044O003500015O00206800010001000100102O000100024O00283O00017O00023O0003063O00506C61796572030F3O00496E66696E6974655374616D696E6101044O003500015O00206800010001000100102O000100024O00283O00017O000D3O0003063O00506C6179657203063O00466C6967687403073O0067657473656E76030D3O00506C617965725363726970747303043O007265706F030D3O00636F6E74726F6C53637269707403113O00706572666F726D5F666F7263654A756D7003053O007061697273030B3O00676574757076616C75657303063O00747970656F6603073O00566563746F7233030A3O00736574757076616C75652O033O006E657701204O003500015O00206800010001000100102O000100023O001221000100034O0035000200013O0020680002000200040020680002000200050020680002000200062O0034000100020002002068000100010007001221000200083O001221000300094O0023000400014O0024000300044O005E00023O00040004703O001D00010012210007000A4O0023000800064O00340007000200020026520007001D0001000B0004703O001D00010012210007000C4O0023000800014O0023000900053O001221000A000B3O002068000A000A000D2O002F000A00014O001D00073O00010004703O001F000100066300020010000100020004703O001000012O00283O00017O00023O0003063O00506C61796572030B3O00466C6967687453702O656401044O003500015O00206800010001000100102O000100024O00283O00017O00103O00030E3O004661726D655F506F736974696F6E03053O0056616C756503053O0042656C6F7703063O00434672616D652O033O006E6577028O00030D3O004661726D5F44697374616E636503063O00416E676C657303043O006D6174682O033O00726164025O0080564003053O0041626F7665025O008056C003053O0046726F6E74026O00084003063O00426568696E64005C4O00357O0020685O00010020685O00020026523O001A000100030004703O001A00010012213O00043O0020685O000500125B000100064O003500025O0020680002000200070020680002000200022O004A000200023O00125B000300064O00383O00030002001221000100043O002068000100010008001221000200093O00206800020002000A00125B0003000B4O003400020002000200125B000300063O00125B000400064O00380001000400022O002B5O00012O00403O00023O0004703O005B00012O00357O0020685O00010020685O00020026523O00330001000C0004703O003300010012213O00043O0020685O000500125B000100064O003500025O00206800020002000700206800020002000200125B000300064O00383O00030002001221000100043O002068000100010008001221000200093O00206800020002000A00125B0003000D4O003400020002000200125B000300063O00125B000400064O00380001000400022O002B5O00012O00403O00023O0004703O005B00012O00357O0020685O00010020685O00020026523O004D0001000E0004703O004D00010012213O00043O0020685O000500125B000100063O00125B000200064O003500035O0020680003000300070020680003000300022O004A000300034O00383O00030002001221000100043O002068000100010008001221000200093O00206800020002000A00125B000300064O003400020002000200125B0003000F3O00125B000400064O00380001000400022O002B5O00012O00403O00023O0004703O005B00012O00357O0020685O00010020685O00020026523O005B000100100004703O005B00010012213O00043O0020685O000500125B000100063O00125B000200064O003500035O0020680003000300070020680003000300022O003B3O00034O00668O00283O00017O00023O0003073O005069766F74546F03083O004765745069766F74010D4O003500015O00064E00010004000100010004703O000400012O00283O00014O003500015O00203F00010001000100203F00033O00022O00340003000200022O0035000400014O00450004000100022O002B0003000300042O00740001000300012O00283O00017O00173O0003043O006D61746803043O006875676503043O006E65787403093O00776F726B7370616365030C3O00706C616365466F6C6465727303183O00656E746974794D616E6966657374436F2O6C656374696F6E030B3O004765744368696C6472656E2O033O0049734103043O005061727403063O006865616C746803053O0056616C7565028O00030A3O00656E746974795479706503073O006D6F6E73746572030E3O0046696E6446697273744368696C642O033O0070657403153O0044697374616E636546726F6D43686172616374657203083O00506F736974696F6E026O00F03F026O00344003053O007461626C6503063O00696E73657274027O0040003F4O00273O00023O001221000100013O0020680001000100022O0008000200024O00263O000200012O002700015O001221000200033O001221000300043O00206800030003000500206800030003000600203F0003000300072O00190003000200040004703O0039000100203F00070006000800125B000900094O00380007000900020006600007003900013O0004703O0039000100206800070006000A00206800070007000B000E72000C0039000100070004703O0039000100206800070006000D00206800070007000B002652000700390001000E0004703O0039000100203F00070006000F00125B000900104O003800070009000200064E00070039000100010004703O003900012O003500075O00203F0007000700110020680009000600122O003800070009000200206800083O00130006050007002E000100080004703O002E00012O0027000700024O003500085O00203F000800080011002068000A000600122O00380008000A00022O0023000900064O00260007000200012O00233O00074O003500075O00203F0007000700110020680009000600122O003800070009000200263C00070039000100140004703O00390001001221000700153O0020680007000700162O0023000800014O0023000900064O00740007000900010006630002000D000100020004703O000D000100206800023O00172O0023000300014O0055000200034O00283O00017O00043O0003053O00706169727303043O007479706503053O007461626C6503073O006D6F6E73746572011A3O001221000100014O002300026O00190001000200030004703O00150001001221000600024O0023000700054O003400060002000200265200060011000100030004703O001100012O003500066O0023000700054O00340006000200020006600006001500013O0004703O001500012O0033000600014O0040000600023O0004703O0015000100265200050015000100040004703O001500012O0033000600014O0040000600023O00066300010004000100020004703O000400012O003300016O0040000100024O00283O00017O00083O0003063O00506C6179657203073O00476F644D6F646503113O006765746E616D6563612O6C6D6574686F64030A3O004669726553657276657203063O0069706169727303043O007479706503053O007461626C6503073O006D6F6E7374657201274O002700026O001000036O001800023O00012O003500035O0020680003000300010020680003000300020006600003002100013O0004703O00210001001221000300034O004500030001000200265200030021000100040004703O00210001001221000300054O0023000400024O00190003000200050004703O001F0001001221000800064O0023000900074O00340008000200020026520008001C000100070004703O001C00012O0035000800014O0023000900074O00340008000200020006600008001C00013O0004703O001C00012O00283O00013O0004703O001F00010026520007001F000100080004703O001F00012O00283O00013O00066300030010000100020004703O001000012O0035000300024O002300046O001000056O001100036O006600036O00283O00017O00073O0003063O00506C61796572030F3O00496E66696E6974655374616D696E6103083O00746F737472696E6703073O007374616D696E6103053O0056616C756503043O006D61746803043O006875676502154O003500025O0020680002000200010020680002000200020006600002000F00013O0004703O000F0001001221000200034O002300036O00340002000200020026520002000F000100040004703O000F00010026520001000F000100050004703O000F0001001221000200063O0020680002000200072O0040000200024O0035000200014O002300036O0023000400014O003B000200044O006600026O00283O00017O000A3O0003063O00506C61796572030C3O004E6F46612O6C44616D61676503113O006765746E616D6563612O6C6D6574686F64030A3O0046697265536572766572027O004003093O0067652O74696E67557003043O0074797065026O00104003063O006E756D626572028O00011C4O002700026O001000036O001800023O00012O003500035O0020680003000300010020680003000300020006600003001600013O0004703O00160001001221000300034O004500030001000200265200030016000100040004703O0016000100206800030002000500265200030016000100060004703O00160001001221000300073O0020680004000200082O003400030002000200265200030016000100090004703O0016000100125B0003000A4O0040000300024O0035000300014O002300046O001000056O001100036O006600036O00283O00017O000B3O00030B3O00636865636B63612O6C657203083O007361666543612O6C027O004003183O0070726F706F676174696F6E52657175657374546F53656C66026O00084003103O006E6F6E53657269616C697A654461746103083O006973536E6974636803043O007469636B03083O004B692O6C61757261026O00F03F026O33D33F002F4O002700016O001000026O001800013O0001001221000200014O00450002000100020006600002000C00013O0004703O000C0001001221000200024O003500036O001000046O001100026O006600025O0020680002000100030026520002002A000100040004703O002A00010020680002000100050026520002002A000100060004703O002A0001001221000200073O00064E0002002A000100010004703O002A0001001221000200084O00450002000100022O0035000300014O00760002000200032O0035000300023O0020680003000300090006600003002000013O0004703O0020000100125B0003000A3O00064E00030021000100010004703O0021000100125B0003000B3O00062A00020025000100030004703O002500012O0020000100034O00283O00014O0008000200024O0020000200033O001221000200084O00450002000100022O0020000200014O003500026O001000036O001100026O006600026O00283O00017O00093O0003043O007469636B026O00F83F03093O0064656275677761726E03043O00702O6F7003083O007361666543612O6C03063O00756E7061636B03043O007461736B03043O0077616974026O00F03F001A4O00357O0006603O001400013O0004703O001400010012213O00014O00453O000100022O0035000100014O00765O0001000E720002001400013O0004703O001400010012213O00033O00125B000100044O00433O000200010012213O00054O0035000100023O001221000200064O003500036O0024000200034O001D5O00012O00088O00207O0012213O00073O0020685O000800125B000100094O00433O000200010004705O00012O00283O00017O00143O00030E3O0046696E6446697273744368696C6403063O006F776E65727303083O00746F737472696E6703063O00557365724964030B3O004765744368696C6472656E028O0003043O007469636B026O00E03F03153O0044697374616E636546726F6D43686172616374657203083O00506F736974696F6E030C3O00496E766F6B6553657276657203113O007069636B55704974656D52657175657374030C3O00426F6479506F736974696F6E03083O00496E7374616E63652O033O006E657703083O004D6178466F72636503073O00566563746F723303043O006D61746803043O0068756765030B3O005072696D6172795061727401503O00203F00013O000100125B000300024O00380001000300020006600001001400013O0004703O0014000100206800013O000200203F000100010001001221000300034O003500045O0020680004000400042O0024000300044O006E00013O000200064E00010019000100010004703O0019000100206800013O000200203F0001000100052O00340001000200022O0006000100013O00267100010019000100060004703O0019000100203F00013O000100125B000300024O003800010003000200064E0001004F000100010004703O004F00012O0035000100014O000A000100013O0006600001002400013O0004703O00240001001221000100074O00450001000100022O0035000200014O000A000200024O0076000100010002000E720008004F000100010004703O004F00012O003500015O00203F00010001000900206800033O000A2O00380001000300022O0035000200023O00060500010035000100020004703O003500012O0035000100013O001221000200074O00450002000100022O004100013O00022O0035000100033O00203F00010001000B00125B0003000C4O002300046O00740001000400010004703O004F000100203F00013O000100125B0003000D4O003800010003000200064E0001004F000100010004703O004F00010012210002000E3O00206800020002000F00125B0003000D4O002300046O00380002000400022O0023000100023O001221000200113O00206800020002000F001221000300123O002068000300030013001221000400123O002068000400040013001221000500123O0020680005000500132O003800020005000200102O0001001000022O0035000200044O004500020001000200206800020002001400206800020002000A00102O0001000A00022O00283O00017O00033O0003043O007461736B03043O007761697403053O007063612O6C000D3O0012213O00013O0020685O00022O00453O000100020006603O000C00013O0004703O000C00010012213O00033O00066500013O000100032O00318O00313O00014O00313O00024O00433O000200010004705O00012O00283O00013O00013O00063O0003083O004175746F4661726D03043O007461736B03043O007761697403063O006865616C746803053O0056616C7565029O00154O00357O0020685O00010006603O001400013O0004703O001400012O00353O00014O00423O00010001001221000200023O0020680002000200032O001A0002000100012O0035000200024O002300036O004300020002000100206800023O000400206800020002000500261C00020014000100060004703O001400012O003500025O00206800020002000100064E00020006000100010004703O000600012O00283O00017O00033O0003043O007461736B03043O007761697403053O007063612O6C000C3O0012213O00013O0020685O00022O00453O000100020006603O000B00013O0004703O000B00010012213O00033O00066500013O000100022O00318O00313O00014O00433O000200010004705O00012O00283O00013O00013O00143O00030C3O004175746F4661726D426F2O7303043O006E65787403093O00776F726B7370616365030C3O00706C616365466F6C6465727303183O00656E746974794D616E6966657374436F2O6C656374696F6E030B3O004765744368696C6472656E2O033O0049734103043O005061727403063O006865616C746803053O0056616C7565028O00030A3O00656E746974795479706503073O006D6F6E73746572030E3O0046696E6446697273744368696C642O033O0070657403043O00626F2O732O0103043O007461736B03043O007761697403083O004175746F4661726D00374O00357O0020685O00010006603O003600013O0004703O003600010012213O00023O001221000100033O00206800010001000400206800010001000500203F0001000100062O00190001000200020004703O0034000100203F00050004000700125B000700084O00380005000700020006600005003400013O0004703O0034000100206800050004000900206800050005000A000E72000B0034000100050004703O0034000100206800050004000C00206800050005000A002652000500340001000D0004703O0034000100203F00050004000E00125B0007000F4O003800050007000200064E00050034000100010004703O0034000100203F00050004000E00125B000700104O00380005000700020006600005003400013O0004703O0034000100206800050004001000206800050005000A00265200050034000100110004703O00340001001221000500123O0020680005000500132O001A0005000100012O0035000500014O0023000600044O004300050002000100206800050004000900206800050005000A00261C000500340001000B0004703O003400012O003500055O00206800050005001400064E00050026000100010004703O002600010006633O000B000100020004703O000B00012O00283O00017O00033O0003043O007461736B03043O007761697403053O007063612O6C000D3O0012213O00013O0020685O00022O00453O000100020006603O000C00013O0004703O000C00010012213O00033O00066500013O000100032O00318O00313O00014O00313O00024O00433O000200010004705O00012O00283O00013O00013O000E3O0003083O004B692O6C61757261030A3O004669726553657276657203203O007265706C6963617465506C61796572416E696D6174696F6E53657175656E6365030F3O0073776F7264416E696D6174696F6E7303073O00737472696B6532030B3O00612O7461636B53702O6564026O00F0BF03053O007061697273031A3O00706C61796572526571756573745F64616D616765456E7469747903083O00506F736974696F6E03093O0065717569706D656E7403043O007461736B03043O007761697403103O004B692O6C61757261432O6F6C646F776E00214O00357O0020685O00010006603O002000013O0004703O002000012O00353O00014O00423O000100012O0035000200023O00203F00020002000200125B000400033O00125B000500043O00125B000600054O002700073O00010030470007000600072O0074000200070001001221000200084O0023000300014O00190002000200040004703O001900012O0035000700023O00203F00070007000200125B000900094O0023000A00063O002068000B0006000A00125B000C000B4O00740007000C000100066300020012000100020004703O001200010012210002000C3O00206800020002000D2O003500035O00206800030003000E2O00430002000200012O00283O00017O00043O0003043O007461736B03043O0077616974026O00E03F03053O007063612O6C000D3O0012213O00013O0020685O000200125B000100034O00343O000200020006603O000C00013O0004703O000C00010012213O00043O00066500013O000100022O00318O00313O00014O00433O000200010004705O00012O00283O00013O00013O00063O00030A3O004175746F5069636B757003043O006E65787403093O00776F726B7370616365030C3O00706C616365466F6C6465727303053O006974656D73030B3O004765744368696C6472656E00114O00357O0020685O00010006603O001000013O0004703O001000010012213O00023O001221000100033O00206800010001000400206800010001000500203F0001000100062O00190001000200020004703O000E00012O0035000500014O0023000600044O00430005000200010006633O000B000100020004703O000B00012O00283O00017O00033O0003043O007461736B03043O007761697403053O007063612O6C000E3O001221000100013O0020680001000100022O00450001000100020006600001000D00013O0004703O000D0001001221000100033O00066500023O000100042O00318O00313O00014O00178O00313O00024O00430001000200010004705O00012O00283O00013O00013O00293O0003063O00506C6179657203063O00466C69676874030B3O005072696D617279506172740003063O00434672616D652O033O006E657703013O007003083O004765744D6F757365030B3O00466C6967687453702O656403093O00776F726B7370616365030D3O0043752O72656E7443616D65726103073O00566563746F723303043O007A65726F03043O00456E756D03073O004B6579436F646503013O0057030A3O006C2O6F6B566563746F7203013O005303013O0041030B3O007269676874566563746F7203013O004403053O00537061636503083O007570566563746F72030B3O004C656674436F6E74726F6C03043O006E65787403043O0067616D6503103O0055736572496E7075745365727669636503093O0049734B6579446F776E03043O007461736B03043O007761697403063O006C2O6F6B4174025O0088C34003083O006973536E697463682O033O004E614E03083O0056656C6F63697479030E3O0066696E6446697273744368696C6403083O0067726F756E646572030A3O00686974626F784779726F030E3O00686974626F7856656C6F6369747903083O00506F736974696F6E03083O004D6178466F72636500994O00357O0020685O00010020685O00020006603O009600013O0004703O009600012O00353O00014O00453O000100020006603O009600013O0004703O009600012O00353O00014O00453O000100020020685O00030006603O009600013O0004703O009600012O00353O00014O00453O000100020020685O00032O0035000100023O0026520001001A000100040004703O001A0001001221000100053O00206800010001000600206800023O00050020680002000200072O00340001000200022O0020000100024O0035000100033O00203F0001000100082O00340001000200022O003500025O0020680002000200010020680002000200090012210003000A3O00206800030003000B0020680003000300050012210004000C3O00206800040004000D2O002700053O00060012210006000E3O00206800060006000F0020680006000600100020680007000300112O002B0007000700022O00410005000600070012210006000E3O00206800060006000F0020680006000600120020680007000300112O004A000700074O002B0007000700022O00410005000600070012210006000E3O00206800060006000F0020680006000600130020680007000300142O004A000700074O002B0007000700022O00410005000600070012210006000E3O00206800060006000F0020680006000600150020680007000300142O002B0007000700022O00410005000600070012210006000E3O00206800060006000F0020680006000600160020680007000300172O002B0007000700022O00410005000600070012210006000E3O00206800060006000F0020680006000600180020680007000300172O004A000700074O002B0007000700022O0041000500060007001221000600194O0023000700054O0008000800083O0004703O00590001001221000B001A3O002068000B000B001B00203F000B000B001C2O0023000D00094O0038000B000D0002000660000B005900013O0004703O005900012O005800040004000A00066300060051000100020004703O005100010012210006001D3O00206800060006001E2O00450006000100022O002B0004000400062O0035000600023O001221000700053O0020680007000700062O0023000800044O00340007000200022O002B0006000600072O0020000600023O001221000600053O00206800060006001F2O0035000700023O00206800070007000700206800080003000700206800090003001100201B0009000900202O00580008000800092O0038000600080002001221000700213O0006600007007900013O0004703O00790001001221000700053O002068000700070006001221000800223O001221000900223O001221000A00224O00380007000A00022O0023000600073O0012210007000C3O00206800070007000D00104O0023000700104O0005000600203F00073O002400125B000900254O003800070009000200203F00083O002400125B000A00264O00380008000A000200203F00093O002400125B000B00274O00380009000B00020006600007008A00013O0004703O008A0001002068000A0006000700102O00070028000A0006600008008D00013O0004703O008D000100102O0008000500060006600009009800013O0004703O00980001001221000A000C3O002068000A000A000D00102O00090023000A001221000A000C3O002068000A000A000D00102O00090029000A0004703O009800012O00088O00203O00024O00283O00017O00", GetFEnv(), ...);
