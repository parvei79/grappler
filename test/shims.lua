-- Enkle erstatninger for Roblox-typer, så rene moduler (bane, fysikk-matte, AI) kan testes med
-- `luau` på Macen. Bare det koden vår bruker er med. Brukes av tools/test_luau.py.

-- ---------------------------------------------------------------- Vector3
local Vmt = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vmt)
end
local function erV(v)
	return getmetatable(v) == Vmt
end
local metoder = {}
function metoder.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function metoder.Cross(a, b)
	return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function metoder.Lerp(a, b, t)
	return vec(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function metoder.Abs(a)
	return vec(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function metoder.Max(a, b)
	return vec(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function metoder.Min(a, b)
	return vec(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function metoder.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function metoder.Angle(a, b)
	local d = metoder.Dot(a, b) / (math.sqrt(metoder.Dot(a, a)) * math.sqrt(metoder.Dot(b, b)))
	return math.acos(math.clamp(d, -1, 1))
end
Vmt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	local f = metoder[k]
	if f then
		return f
	end
	error("Vector3 har ikke feltet " .. tostring(k), 2)
end
Vmt.__newindex = function()
	error("Vector3 kan ikke endres", 2)
end
Vmt.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vmt.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vmt.__mul = function(a, b)
	if type(a) == "number" then
		return vec(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vmt.__div = function(a, b)
	if type(b) == "number" then
		return vec(a.X / b, a.Y / b, a.Z / b)
	end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vmt.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
Vmt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vmt.__tostring = function(a)
	return string.format("%.3f, %.3f, %.3f", a.X, a.Y, a.Z)
end

Vector3 = {
	new = function(x, y, z)
		return vec(x or 0, y or 0, z or 0)
	end,
}
Vector3.zero = vec(0, 0, 0)
Vector3.one = vec(1, 1, 1)
Vector3.xAxis = vec(1, 0, 0)
Vector3.yAxis = vec(0, 1, 0)
Vector3.zAxis = vec(0, 0, 1)

-- ---------------------------------------------------------------- CFrame
-- Rotasjonen lagres som kolonnene høyre (X), opp (Y) og bak (Z). LookVector = -Z.
local Cmt = {}
local function cf(p, rx, ry, rz)
	return setmetatable({ p = p, rx = rx, ry = ry, rz = rz }, Cmt)
end
local function rot(c, v)
	return c.rx * v.X + c.ry * v.Y + c.rz * v.Z
end
local function rotT(c, v)
	return vec(c.rx:Dot(v), c.ry:Dot(v), c.rz:Dot(v))
end
local cmetoder = {}
function cmetoder.Inverse(c)
	-- transponert rotasjon
	local rx = vec(c.rx.X, c.ry.X, c.rz.X)
	local ry = vec(c.rx.Y, c.ry.Y, c.rz.Y)
	local rz = vec(c.rx.Z, c.ry.Z, c.rz.Z)
	local inv = cf(Vector3.zero, rx, ry, rz)
	return cf(-rot(inv, c.p), rx, ry, rz)
end
function cmetoder.ToWorldSpace(a, b)
	return a * b
end
function cmetoder.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function cmetoder.PointToWorldSpace(a, v)
	return a.p + rot(a, v)
end
function cmetoder.PointToObjectSpace(a, v)
	return rotT(a, v - a.p)
end
function cmetoder.VectorToWorldSpace(a, v)
	return rot(a, v)
end
function cmetoder.VectorToObjectSpace(a, v)
	return rotT(a, v)
end
function cmetoder.GetComponents(a)
	return a.p.X, a.p.Y, a.p.Z, a.rx.X, a.ry.X, a.rz.X, a.rx.Y, a.ry.Y, a.rz.Y, a.rx.Z, a.ry.Z, a.rz.Z
end
function cmetoder.Lerp(a, b, t)
	-- grov, men god nok for tester: lineær + ortonormalisering
	local look = (a.LookVector:Lerp(b.LookVector, t)).Unit
	local up = a.UpVector:Lerp(b.UpVector, t)
	return CFrame.lookAt(a.p:Lerp(b.p, t), a.p:Lerp(b.p, t) + look, up)
end
Cmt.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "LookVector" then
		return -c.rz
	elseif k == "RightVector" or k == "XVector" then
		return c.rx
	elseif k == "UpVector" or k == "YVector" then
		return c.ry
	elseif k == "ZVector" then
		return c.rz
	elseif k == "Rotation" then
		return cf(Vector3.zero, c.rx, c.ry, c.rz)
	end
	local f = cmetoder[k]
	if f then
		return f
	end
	error("CFrame har ikke feltet " .. tostring(k), 2)
end
Cmt.__mul = function(a, b)
	if getmetatable(b) == Cmt then
		return cf(a.p + rot(a, b.p), rot(a, b.rx), rot(a, b.ry), rot(a, b.rz))
	end
	return a.p + rot(a, b)
end
Cmt.__add = function(a, v)
	return cf(a.p + v, a.rx, a.ry, a.rz)
end
Cmt.__sub = function(a, v)
	return cf(a.p - v, a.rx, a.ry, a.rz)
end
Cmt.__tostring = function(a)
	return "CFrame(" .. tostring(a.p) .. ")"
end

local function fraAkser(p, x, y, z)
	return cf(p, x, y, z)
end
CFrame = {}
function CFrame.new(a, b, c, ...)
	local ekstra = { ... }
	if a == nil then
		return fraAkser(Vector3.zero, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
	elseif erV(a) and b == nil then
		return fraAkser(a, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
	elseif erV(a) and erV(b) then
		return CFrame.lookAt(a, b)
	elseif #ekstra == 9 then
		local r = ekstra
		return fraAkser(vec(a, b, c), vec(r[1], r[4], r[7]), vec(r[2], r[5], r[8]), vec(r[3], r[6], r[9]))
	end
	return fraAkser(vec(a, b, c), Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
function CFrame.lookAt(p, mal, opp)
	opp = opp or Vector3.yAxis
	local look = (mal - p).Unit
	local hoyre = look:Cross(opp)
	if hoyre.Magnitude < 1e-6 then
		hoyre = look:Cross(Vector3.zAxis)
	end
	hoyre = hoyre.Unit
	local opp2 = hoyre:Cross(look)
	return fraAkser(p, hoyre, opp2, -look)
end
function CFrame.fromMatrix(p, x, y, z)
	z = z or x:Cross(y).Unit
	return fraAkser(p, x, y, z)
end
local function Rx(a)
	local c, s = math.cos(a), math.sin(a)
	return fraAkser(Vector3.zero, vec(1, 0, 0), vec(0, c, s), vec(0, -s, c))
end
local function Ry(a)
	local c, s = math.cos(a), math.sin(a)
	return fraAkser(Vector3.zero, vec(c, 0, -s), vec(0, 1, 0), vec(s, 0, c))
end
local function Rz(a)
	local c, s = math.cos(a), math.sin(a)
	return fraAkser(Vector3.zero, vec(c, s, 0), vec(-s, c, 0), vec(0, 0, 1))
end
function CFrame.Angles(x, y, z)
	return Rx(x or 0) * Ry(y or 0) * Rz(z or 0)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromAxisAngle(akse, vinkel)
	local u = akse.Unit
	local c, s = math.cos(vinkel), math.sin(vinkel)
	local function r(v)
		return v * c + u:Cross(v) * s + u * (u:Dot(v) * (1 - c))
	end
	return fraAkser(Vector3.zero, r(Vector3.xAxis), r(Vector3.yAxis), r(Vector3.zAxis))
end
CFrame.identity = CFrame.new()

-- ---------------------------------------------------------------- Random, Color3, Enum, typeof
Random = {}
function Random.new(fro)
	local tilstand = (fro or 1) % 2147483647
	if tilstand <= 0 then
		tilstand = tilstand + 2147483646
	end
	local r = {}
	local function neste()
		tilstand = (tilstand * 16807) % 2147483647
		return tilstand / 2147483647
	end
	function r:NextNumber(a, b)
		a, b = a or 0, b or 1
		return a + (b - a) * neste()
	end
	function r:NextInteger(a, b)
		return math.floor(a + (b - a + 1) * neste())
	end
	return r
end

Color3 = {}
local Col = {}
Col.__index = {
	Lerp = function(a, b, t)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end,
	ToHex = function(c)
		return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end,
}
function Color3.fromHex(h)
	h = string.gsub(h, "#", "")
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Col)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then
		return Color3.new(v, t, p)
	elseif m == 1 then
		return Color3.new(q, v, p)
	elseif m == 2 then
		return Color3.new(p, v, t)
	elseif m == 3 then
		return Color3.new(p, q, v)
	elseif m == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end

-- Enum-verdier er unike tabeller (som i Roblox), så == fungerer og .Name/.Value finnes.
local EnumMt = {}
EnumMt.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
local enumTeller = 0
Enum = setmetatable({}, {
	__index = function(selv, gruppe)
		local g = setmetatable({}, {
			__index = function(t, navn)
				enumTeller += 1
				local verdi = setmetatable({ Name = navn, Value = enumTeller, EnumType = gruppe }, EnumMt)
				rawset(t, navn, verdi)
				return verdi
			end,
		})
		rawset(selv, gruppe, g)
		return g
	end,
})

local ekteTypeof = typeof
function typeof(v)
	local mt = getmetatable(v)
	if mt == Vmt then
		return "Vector3"
	elseif mt == Cmt then
		return "CFrame"
	elseif mt == Col then
		return "Color3"
	elseif mt == EnumMt then
		return "EnumItem"
	end
	return ekteTypeof and ekteTypeof(v) or type(v)
end
