-- En liten etterligning av Roblox-motoren, nok til å kjøre serverkoden i KAOS-KART med `luau`
-- på Macen: instanser med egenskaper/attributter/barn, signaler, task-planlegger med falsk klokke,
-- tjenester, terreng som sjekker voksel-tabellene, og stråler mot en enkel modell av bakken.
-- Fanger skrivefeil i metodenavn, feil i løkker og nil-feil før Pål trenger å trykke Play.
-- Krever test/shims.lua (Vector3, CFrame, Random, Color3, Enum) først.

Mock = {}
function warn(...)
	print("ADVARSEL:", ...)
end
function tick()
	return Mock.tid()
end
local tid = 0
local planlagt = {} -- { tid, co, args }
Mock.feil = {}

function Mock.tid()
	return tid
end

local function rapporter(co, err)
	local spor = debug.traceback(co, tostring(err))
	table.insert(Mock.feil, spor)
	print("FEIL I KORUTINE: " .. spor)
end

local function gjenoppta(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		rapporter(co, err)
	end
end

-- ---------------------------------------------------------------- task
task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	gjenoppta(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	table.insert(planlagt, { tid = tid, co = co, args = table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	table.insert(planlagt, { tid = tid + (t or 0), co = co, args = table.pack(...) })
	return co
end
function task.wait(t)
	local co = coroutine.running()
	table.insert(planlagt, { tid = tid + math.max(t or 0, 1 / 60), co = co, args = table.pack() })
	coroutine.yield()
	return t or 0
end
function task.cancel() end
wait = task.wait

-- ---------------------------------------------------------------- signaler
local Signal = {}
Signal.__index = Signal
local function lagSignal()
	return setmetatable({ lyttere = {} }, Signal)
end
function Signal:Connect(f)
	local c = { Connected = true, f = f }
	function c:Disconnect()
		self.Connected = false
	end
	table.insert(self.lyttere, c)
	return c
end
function Signal:Once(f)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		f(...)
	end)
	return c
end
function Signal:Fire(...)
	for _, c in table.clone(self.lyttere) do
		if c.Connected then
			task.spawn(c.f, ...)
		end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		gjenoppta(co, ...)
	end)
	return coroutine.yield()
end
Mock.lagSignal = lagSignal

-- ---------------------------------------------------------------- datatyper
local V2 = {}
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y
		end
	end
	error("Vector2 har ikke feltet " .. tostring(k), 2)
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
Vector2 = { new = v2 }
Vector2.zero = v2(0, 0)
NumberRange = { new = function(a, b)
	return { Min = a, Max = b or a }
end }
NumberSequenceKeypoint = { new = function(t, v)
	return { Time = t, Value = v }
end }
NumberSequence = { new = function(a, b)
	return { a = a, b = b }
end }
ColorSequenceKeypoint = { new = function(t, v)
	return { Time = t, Value = v }
end }
ColorSequence = { new = function(a, b)
	return { a = a, b = b }
end }
PhysicalProperties = { new = function(...)
	return { ... }
end }
TweenInfo = { new = function(...)
	return { ... }
end }
UDim = { new = function(a, b)
	return { Scale = a, Offset = b }
end }
UDim2 = {
	new = function(a, b, c, d)
		return { X = UDim.new(a, b), Y = UDim.new(c, d) }
	end,
	fromScale = function(a, b)
		return UDim2.new(a, 0, b, 0)
	end,
	fromOffset = function(a, b)
		return UDim2.new(0, a, 0, b)
	end,
}
Region3 = { new = function(a, b)
	return { min = a, max = b, Size = b - a, CFrame = CFrame.new((a + b) / 2) }
end }
RaycastParams = { new = function()
	return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, IgnoreWater = false }
end }
OverlapParams = RaycastParams

-- ---------------------------------------------------------------- instanser
local ARV = {
	Part = "BasePart", MeshPart = "BasePart", WedgePart = "BasePart", Seat = "BasePart", Terrain = "BasePart",
	PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
	Weld = "JointInstance", Motor6D = "JointInstance",
	AlignOrientation = "Constraint", LinearVelocity = "Constraint",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector",
	TextLabel = "GuiObject", Frame = "GuiObject", ImageLabel = "GuiObject",
	Folder = "Instance", Model = "PVInstance",
}

local STANDARD = {
	BasePart = {
		CFrame = CFrame.new(), Size = Vector3.new(4, 1, 2), Anchored = false, CanCollide = true, CanQuery = true,
		CanTouch = true, Transparency = 0, Massless = false, Color = Color3.new(0.6, 0.6, 0.6),
		AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero, Reflectance = 0,
		LocalTransparencyModifier = 0, CollisionGroup = "Default", TextureID = "", Shape = Enum.PartType.Block,
	},
	Sound = { Volume = 0.5, PlaybackSpeed = 1, IsPlaying = false, Looped = false, SoundId = "", TimePosition = 0 },
	Light = { Enabled = true, Brightness = 1, Range = 8 },
	ParticleEmitter = { Enabled = true, Rate = 5 },
	Humanoid = { Health = 100, MaxHealth = 100, JumpPower = 50, UseJumpPower = true },
	Attachment = { Position = Vector3.zero, CFrame = CFrame.new() },
	Motor6D = { C0 = CFrame.new(), C1 = CFrame.new(), Transform = CFrame.new() },
	AlignOrientation = { CFrame = CFrame.new(), Responsiveness = 10 },
	LinearVelocity = { VectorVelocity = Vector3.zero },
}

local metoder = {}
local Inst = {}
local tagger = {}

local function erInstans(v)
	return type(v) == "table" and getmetatable(v) == Inst
end
Mock.erInstans = erInstans

local function standard(klasse, k)
	local s = STANDARD[klasse]
	if s and s[k] ~= nil then
		return s[k]
	end
	local foreldre = ARV[klasse]
	if foreldre and STANDARD[foreldre] and STANDARD[foreldre][k] ~= nil then
		return STANDARD[foreldre][k]
	end
	return nil
end

local HENDELSER = {
	Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, AncestryChanged = true,
	Touched = true, Died = true, Running = true, OnServerEvent = true, OnClientEvent = true, CharacterAdded = true,
	CharacterRemoving = true, Heartbeat = true, Stepped = true, RenderStepped = true, PreSimulation = true,
	PlayerAdded = true, PlayerRemoving = true, Activated = true, Ended = true, Completed = true,
	InputBegan = true, InputEnded = true, InputChanged = true, DescendantRemoving = true,
}

local function ny(klasse, forelder)
	local selv = setmetatable({
		__klasse = klasse,
		__barn = {},
		__attr = {},
		__props = { Name = klasse },
		__signaler = {},
		__forelder = nil,
	}, Inst)
	if forelder then
		selv.Parent = forelder
	end
	return selv
end
Mock.ny = ny

Inst.__index = function(selv, k)
	local m = metoder[k]
	if m then
		return m
	end
	local props = rawget(selv, "__props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if k == "Parent" then
		return rawget(selv, "__forelder")
	elseif k == "ClassName" then
		return rawget(selv, "__klasse")
	elseif k == "Position" then
		local cf = props.CFrame
		if cf then
			return cf.Position
		end
		local s = standard(rawget(selv, "__klasse"), "CFrame")
		return s and s.Position or nil
	elseif k == "WorldPosition" then
		local p = rawget(selv, "__forelder")
		local pos = props.Position or Vector3.zero
		return p and p.CFrame and p.CFrame * pos or pos
	elseif k == "PrimaryPart" then
		return nil
	end
	if HENDELSER[k] then
		local sig = rawget(selv, "__signaler")
		sig[k] = sig[k] or lagSignal()
		return sig[k]
	end
	local s = standard(rawget(selv, "__klasse"), k)
	if s ~= nil then
		return s
	end
	for _, b in rawget(selv, "__barn") do
		if b.Name == k then
			return b
		end
	end
	return nil
end

Inst.__newindex = function(selv, k, v)
	if k == "Parent" then
		local gammel = rawget(selv, "__forelder")
		if gammel == v then
			return
		end
		if gammel then
			local liste = rawget(gammel, "__barn")
			for i, b in liste do
				if b == selv then
					table.remove(liste, i)
					break
				end
			end
			local sig = rawget(gammel, "__signaler").ChildRemoved
			if sig then
				sig:Fire(selv)
			end
		end
		rawset(selv, "__forelder", v)
		if v then
			assert(erInstans(v), "Parent må være en instans")
			table.insert(rawget(v, "__barn"), selv)
			local sig = rawget(v, "__signaler").ChildAdded
			if sig then
				sig:Fire(selv)
			end
		end
		return
	end
	local props = rawget(selv, "__props")
	if k == "Position" and (props.CFrame or standard(rawget(selv, "__klasse"), "CFrame")) and rawget(selv, "__klasse") ~= "Attachment" then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = cf.Rotation + v
		return
	end
	if k == "PrimaryPart" and v ~= nil then
		assert(erInstans(v), "PrimaryPart må være en del")
	end
	props[k] = v
end

Inst.__tostring = function(selv)
	return selv:GetFullName()
end

function metoder.GetFullName(selv)
	local navn = {}
	local d = selv
	while d do
		table.insert(navn, 1, d.Name)
		d = rawget(d, "__forelder")
	end
	return table.concat(navn, ".")
end
function metoder.IsA(selv, klasse)
	local k = rawget(selv, "__klasse")
	if k == klasse or klasse == "Instance" then
		return true
	end
	local f = ARV[k]
	while f do
		if f == klasse then
			return true
		end
		f = ARV[f]
	end
	return false
end
function metoder.SetAttribute(selv, k, v)
	assert(type(k) == "string", "SetAttribute: navnet må være tekst")
	local t = type(v)
	assert(v == nil or t == "string" or t == "number" or t == "boolean" or typeof(v) == "Vector3" or typeof(v) == "Color3"
		or typeof(v) == "CFrame", "SetAttribute: ugyldig verditype for " .. k .. ": " .. t)
	rawget(selv, "__attr")[k] = v
	local sig = rawget(selv, "__signaler")["attr_" .. k]
	if sig then
		sig:Fire()
	end
end
function metoder.GetAttribute(selv, k)
	return rawget(selv, "__attr")[k]
end
function metoder.GetAttributeChangedSignal(selv, k)
	local sig = rawget(selv, "__signaler")
	sig["attr_" .. k] = sig["attr_" .. k] or lagSignal()
	return sig["attr_" .. k]
end
function metoder.GetPropertyChangedSignal(selv, k)
	local sig = rawget(selv, "__signaler")
	sig["prop_" .. k] = sig["prop_" .. k] or lagSignal()
	return sig["prop_" .. k]
end
function metoder.GetChildren(selv)
	return table.clone(rawget(selv, "__barn"))
end
function metoder.GetDescendants(selv)
	local ut = {}
	local function g(d)
		for _, b in rawget(d, "__barn") do
			table.insert(ut, b)
			g(b)
		end
	end
	g(selv)
	return ut
end
function metoder.FindFirstChild(selv, navn, rekursiv)
	for _, b in rawget(selv, "__barn") do
		if b.Name == navn then
			return b
		end
	end
	if rekursiv then
		for _, b in rawget(selv, "__barn") do
			local f = b:FindFirstChild(navn, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function metoder.WaitForChild(selv, navn, tidsgrense)
	local f = selv:FindFirstChild(navn)
	if f then
		return f
	end
	if tidsgrense then
		return nil
	end
	error("WaitForChild: " .. selv:GetFullName() .. " mangler " .. navn)
end
function metoder.FindFirstChildOfClass(selv, klasse)
	for _, b in rawget(selv, "__barn") do
		if rawget(b, "__klasse") == klasse then
			return b
		end
	end
	return nil
end
function metoder.FindFirstChildWhichIsA(selv, klasse, rekursiv)
	for _, b in (rekursiv and selv:GetDescendants() or rawget(selv, "__barn")) do
		if b:IsA(klasse) then
			return b
		end
	end
	return nil
end
function metoder.FindFirstAncestorOfClass(selv, klasse)
	local d = rawget(selv, "__forelder")
	while d do
		if rawget(d, "__klasse") == klasse then
			return d
		end
		d = rawget(d, "__forelder")
	end
	return nil
end
function metoder.IsDescendantOf(selv, annen)
	local d = rawget(selv, "__forelder")
	while d do
		if d == annen then
			return true
		end
		d = rawget(d, "__forelder")
	end
	return false
end
function metoder.Destroy(selv)
	for _, b in table.clone(rawget(selv, "__barn")) do
		b:Destroy()
	end
	selv.Parent = nil
	rawset(selv, "__odelagt", true)
end
function metoder.ClearAllChildren(selv)
	for _, b in table.clone(rawget(selv, "__barn")) do
		b:Destroy()
	end
end
function metoder.Clone(selv)
	local k = ny(rawget(selv, "__klasse"))
	for n, v in rawget(selv, "__props") do
		rawget(k, "__props")[n] = v
	end
	for n, v in rawget(selv, "__attr") do
		rawget(k, "__attr")[n] = v
	end
	for _, b in rawget(selv, "__barn") do
		b:Clone().Parent = k
	end
	return k
end
function metoder.GetPivot(selv)
	if selv:IsA("BasePart") then
		return selv.CFrame
	end
	local pp = rawget(selv, "__props").PrimaryPart
	if pp then
		return pp.CFrame
	end
	local d = selv:FindFirstChildWhichIsA("BasePart", true)
	return d and d.CFrame or CFrame.new()
end
function metoder.PivotTo(selv, cf)
	local gammel = selv:GetPivot()
	local delta = cf * gammel:Inverse()
	if selv:IsA("BasePart") then
		selv.CFrame = cf
		return
	end
	for _, d in selv:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
function metoder.SetNetworkOwner(selv, eier)
	assert(selv:IsA("BasePart"), "SetNetworkOwner på noe som ikke er en del")
	assert(selv:IsDescendantOf(workspace), "SetNetworkOwner: delen er ikke i workspace")
	assert(not selv.Anchored, "SetNetworkOwner: delen er forankret")
	rawset(selv, "__eier", eier)
end
function metoder.Sit(selv, hum)
	assert(hum and rawget(hum, "__klasse") == "Humanoid", "Sit trenger en Humanoid")
	rawset(selv, "__sitter", hum)
	hum.Sit = true
end
function metoder.Play(selv)
	if rawget(selv, "__klasse") == "Sound" then
		assert(type(selv.SoundId) == "string" and selv.SoundId ~= "", "Sound:Play uten SoundId")
	end
	selv.IsPlaying = true
end
function metoder.Stop(selv)
	selv.IsPlaying = false
end
function metoder.Emit(selv, n)
	assert(type(n) == "number", "Emit trenger et tall")
end
function metoder.AdjustSpeed() end
function metoder.LoadAnimation(selv, anim)
	assert(anim and rawget(anim, "__klasse") == "Animation", "LoadAnimation trenger en Animation")
	return { Play = function() end, Stop = function() end, AdjustSpeed = function() end, Looped = false, Priority = nil }
end
function metoder.FireAllClients(selv, ...)
	Mock.logg(selv.Name, "alle", ...)
	if Mock.lokalSpiller then
		selv.OnClientEvent:Fire(...)
	end
end
function metoder.FireClient(selv, spiller, ...)
	assert(spiller and rawget(spiller, "__klasse") == "Player", "FireClient trenger en Player")
	Mock.logg(selv.Name, spiller.Name, ...)
	if spiller == Mock.lokalSpiller then
		selv.OnClientEvent:Fire(...)
	end
end
function metoder.FireServer(selv, ...)
	Mock.logg(selv.Name, "server", ...)
	if Mock.lokalSpiller then
		selv.OnServerEvent:Fire(Mock.lokalSpiller, ...)
	end
end
-- klienttjenester
function metoder.IsKeyDown()
	return false
end
Mock.handlinger = {}
function metoder.BindActionAtPriority(_, navn, f, _knapp, _prioritet, ...)
	assert(type(navn) == "string" and type(f) == "function", "BindActionAtPriority: feil argumenter")
	Mock.handlinger[navn] = f
end
function metoder.BindAction(_, navn, f)
	Mock.handlinger[navn] = f
end
function metoder.SetTitle() end
Mock.renderSteg = {}
function metoder.BindToRenderStep(_, navn, prioritet, f)
	assert(type(navn) == "string" and type(prioritet) == "number" and type(f) == "function", "BindToRenderStep: feil argumenter")
	Mock.renderSteg[navn] = f
end
function metoder.Create(_, inst, info, mal)
	assert(Mock.erInstans(inst), "TweenService:Create trenger en instans")
	assert(type(info) == "table" and type(mal) == "table", "TweenService:Create: feil argumenter")
	return { Play = function()
		for k, v in mal do
			inst[k] = v
		end
	end, Cancel = function() end, Completed = lagSignal() }
end
function metoder.JSONDecode(_, tekst)
	local i = 1
	local function mellomrom()
		i = string.find(tekst, "[^%s]", i) or #tekst + 1
	end
	local verdi
	local function streng()
		local slutt = i + 1
		local ut = {}
		while true do
			local c = string.sub(tekst, slutt, slutt)
			if c == '"' then
				break
			elseif c == "\\" then
				slutt += 1
				c = string.sub(tekst, slutt, slutt)
			end
			table.insert(ut, c)
			slutt += 1
		end
		i = slutt + 1
		return table.concat(ut)
	end
	function verdi()
		mellomrom()
		local c = string.sub(tekst, i, i)
		if c == "{" then
			i += 1
			local obj = {}
			mellomrom()
			if string.sub(tekst, i, i) == "}" then
				i += 1
				return obj
			end
			while true do
				mellomrom()
				local k = streng()
				mellomrom()
				i += 1 -- :
				obj[k] = verdi()
				mellomrom()
				local s2 = string.sub(tekst, i, i)
				i += 1
				if s2 == "}" then
					return obj
				end
			end
		elseif c == "[" then
			i += 1
			local arr = {}
			mellomrom()
			if string.sub(tekst, i, i) == "]" then
				i += 1
				return arr
			end
			while true do
				table.insert(arr, verdi())
				mellomrom()
				local s2 = string.sub(tekst, i, i)
				i += 1
				if s2 == "]" then
					return arr
				end
			end
		elseif c == '"' then
			return streng()
		elseif string.sub(tekst, i, i + 3) == "true" then
			i += 4
			return true
		elseif string.sub(tekst, i, i + 4) == "false" then
			i += 5
			return false
		elseif string.sub(tekst, i, i + 3) == "null" then
			i += 4
			return nil
		end
		local s0, s1 = string.find(tekst, "^-?[%d%.eE+-]+", i)
		local tall = tonumber(string.sub(tekst, s0, s1))
		i = s1 + 1
		return tall
	end
	return verdi()
end
function metoder.SetStateEnabled() end
function metoder.ChangeState(hum, tilstand)
	rawget(hum, "__props").__tilstand = tilstand
end
function metoder.GetState(hum)
	return rawget(hum, "__props").__tilstand or Enum.HumanoidStateType.Running
end
function metoder.EquipTool(hum, verktoy)
	assert(verktoy and rawget(verktoy, "__klasse") == "Tool", "EquipTool trenger et Tool")
	verktoy.Parent = hum.Parent
end
function metoder.HasTag(_, inst, tag)
	return (tagger[tag] or {})[inst] == true
end
function metoder.UnequipTools() end
function metoder.GetPlayerFromCharacter(_, figur)
	for _, s in Mock.spillere do
		if s.Character == figur then
			return s
		end
	end
	return nil
end
function metoder.GetPlayerByUserId(_, id)
	for _, s in Mock.spillere do
		if s.UserId == id then
			return s
		end
	end
	return nil
end
function metoder.GetPlayers()
	return table.clone(Mock.spillere)
end
function metoder.SetCoreGuiEnabled() end

Mock.hendelser = {}
function Mock.logg(remote, til, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		local a = args[i]
		if type(a) == "table" and not erInstans(a) and typeof(a) ~= "Vector3" and typeof(a) ~= "CFrame" and typeof(a) ~= "Color3" then
			error(remote .. ": ugyldig argument #" .. i .. " til remote (tabell med metatabell?)")
		end
	end
	table.insert(Mock.hendelser, { remote = remote, til = til, args = args })
end

Instance = {
	new = function(klasse, forelder)
		return ny(klasse, forelder)
	end,
}

-- ---------------------------------------------------------------- tjenester og verden
local spill = ny("DataModel")
spill.Name = "game"
local tjenester = {}
local function tjeneste(navn)
	if not tjenester[navn] then
		local t = ny(navn, spill)
		t.Name = navn
		tjenester[navn] = t
	end
	return tjenester[navn]
end
function metoder.GetService(_, navn)
	return tjeneste(navn)
end
game = spill
workspace = tjeneste("Workspace")
local terreng = ny("Terrain", workspace)
terreng.Name = "Terrain"
Mock.voksler = 0
Mock.terrengKall = 0
function metoder.Clear() end
function metoder.SetMaterialColor(_, m, c)
	assert(typeof(m) == "EnumItem" and typeof(c) == "Color3", "SetMaterialColor: feil argumenter")
end
function metoder.FillBlock(_, cf, str, mat)
	assert(typeof(cf) == "CFrame" and typeof(str) == "Vector3" and typeof(mat) == "EnumItem", "FillBlock: feil argumenter")
	Mock.terrengKall += 1
end
function metoder.WriteVoxels(_, region, opploesning, mats, occ)
	assert(opploesning == 4, "WriteVoxels: oppløsning må være 4")
	local str = region.Size / 4
	local function heltall(v)
		return math.abs(v - math.floor(v + 0.5)) < 1e-6
	end
	assert(heltall(region.min.X / 4) and heltall(region.min.Y / 4) and heltall(region.min.Z / 4), "WriteVoxels: regionen er ikke på 4-rutenettet")
	assert(#mats == str.X and #occ == str.X, string.format("WriteVoxels: feil X-størrelse %d vs %d", #mats, str.X))
	for ix = 1, str.X do
		assert(#mats[ix] == str.Y and #occ[ix] == str.Y, "WriteVoxels: feil Y-størrelse")
		for iy = 1, str.Y do
			assert(#mats[ix][iy] == str.Z and #occ[ix][iy] == str.Z, "WriteVoxels: feil Z-størrelse")
			for iz = 1, str.Z do
				local o = occ[ix][iy][iz]
				assert(type(o) == "number" and o >= 0 and o <= 1, "WriteVoxels: ugyldig fyllgrad")
				assert(typeof(mats[ix][iy][iz]) == "EnumItem", "WriteVoxels: ugyldig materiale")
			end
		end
	end
	Mock.voksler += str.X * str.Y * str.Z
	Mock.terrengKall += 1
end
function metoder.GetServerTimeNow()
	return tid
end
function metoder.AddItem(_, inst, levetid)
	task.delay(levetid or 10, function()
		inst:Destroy()
	end)
end
function metoder.RegisterCollisionGroup() end
function metoder.CollisionGroupSetCollidable(_, a, b, c)
	assert(type(a) == "string" and type(b) == "string" and type(c) == "boolean", "CollisionGroupSetCollidable: feil argumenter")
end
function metoder.AddTag(_, inst, tag)
	tagger[tag] = tagger[tag] or {}
	tagger[tag][inst] = true
end
function metoder.GetTagged(_, tag)
	local ut = {}
	for inst in tagger[tag] or {} do
		table.insert(ut, inst)
	end
	return ut
end
function metoder.GetInstanceAddedSignal()
	return lagSignal()
end
function metoder.GetInstanceRemovedSignal()
	return lagSignal()
end
function metoder.JSONEncode(_, v)
	local function enc(x)
		local t = type(x)
		if t == "table" then
			if #x > 0 or next(x) == nil then
				local deler = {}
				for _, y in x do
					table.insert(deler, enc(y))
				end
				return "[" .. table.concat(deler, ",") .. "]"
			end
			local deler = {}
			for k, y in x do
				table.insert(deler, string.format("%q:%s", tostring(k), enc(y)))
			end
			return "{" .. table.concat(deler, ",") .. "}"
		elseif t == "string" then
			return string.format("%q", x)
		end
		return tostring(x)
	end
	return enc(v)
end
function metoder.ToHex(c)
	return string.format("%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255)
end

-- figurer for spillere og boter
local function lagFigur(navn)
	local m = ny("Model")
	m.Name = navn
	local hrp = ny("Part", m)
	hrp.Name = "HumanoidRootPart"
	for _, d in { "Head", "UpperTorso", "LowerTorso", "LeftHand", "RightHand" } do
		local p = ny("Part", m)
		p.Name = d
	end
	local hum = ny("Humanoid", m)
	ny("Animator", hum)
	ny("LocalScript", m).Name = "Animate"
	rawget(m, "__props").PrimaryPart = hrp
	return m
end
function metoder.CreateHumanoidModelFromDescription(_, desc, rig)
	assert(desc and rawget(desc, "__klasse") == "HumanoidDescription", "CreateHumanoidModelFromDescription trenger en HumanoidDescription")
	assert(rig == Enum.HumanoidRigType.R15, "forventet R15")
	return lagFigur("Bot")
end

-- kamera
local kamera = ny("Camera", workspace)
kamera.Name = "Camera"
kamera.CFrame = CFrame.new()
kamera.FieldOfView = 70
workspace.CurrentCamera = kamera
local uis = tjeneste("UserInputService")
uis.TouchEnabled = false
uis.KeyboardEnabled = true

-- spillere
Mock.spillere = {}
function Mock.leggTilSpiller(navn, id)
	local s = ny("Player", tjeneste("Players"))
	s.Name = navn
	s.DisplayName = navn
	s.UserId = id
	table.insert(Mock.spillere, s)
	tjeneste("Players").PlayerAdded:Fire(s)
	ny("Backpack", s).Name = "Backpack"
	local figur = lagFigur(navn)
	figur.Parent = workspace
	for _, d in workspace:GetDescendants() do
		if rawget(d, "__klasse") == "SpawnLocation" then
			figur:PivotTo(CFrame.new(d.Position + Vector3.new(0, 4, 0)))
			break
		end
	end
	s.Character = figur
	ny("PlayerGui", s).Name = "PlayerGui"
	ny("PlayerScripts", s).Name = "PlayerScripts"
	s.CharacterAdded:Fire(figur)
	return s
end

function Mock.blilokal(spiller, kontrollModul)
	Mock.lokalSpiller = spiller
	tjeneste("Players").LocalPlayer = spiller
	local pm = ny("ModuleScript", spiller.PlayerScripts)
	pm.Name = "PlayerModule"
	pm:SetAttribute("__sti", kontrollModul)
end

-- ---------------------------------------------------------------- stråler mot en enkel bakkemodell
-- Bakken: veidelene fra workspace.Bane (asfalt, rampe, boostfelt) sett som skrå plater, ellers
-- et grovt terreng fra Terreng.naturlig (settes av testen). Karter er kuler med radius 3.5.
Mock.terrengHoyde = function()
	return 10
end

local function iBoks(del, punkt)
	local lokal = del.CFrame:PointToObjectSpace(punkt)
	local h = del.Size / 2
	return math.abs(lokal.X) <= h.X + 0.01 and math.abs(lokal.Y) <= h.Y + 0.3 and math.abs(lokal.Z) <= h.Z + 0.01
end

local function inkludert(params, inst)
	local liste = params.FilterDescendantsInstances or {}
	local inne = false
	for _, f in liste do
		if inst == f or inst:IsDescendantOf(f) then
			inne = true
			break
		end
	end
	if params.FilterType == Enum.RaycastFilterType.Include then
		return inne
	end
	return not inne
end

function metoder.Raycast(_, fra, retning, params)
	params = params or RaycastParams.new()
	local lengde = retning.Magnitude
	if lengde < 1e-6 then
		return nil
	end
	local enhet = retning / lengde
	local best = nil
	local function kandidat(res)
		if res and res.Distance >= 0 and res.Distance <= lengde and (not best or res.Distance < best.Distance) then
			best = res
		end
	end
	-- karter som kuler
	local karter = workspace:FindFirstChild("Karter")
	if karter then
		for _, kart in karter:GetChildren() do
			local rot = kart:FindFirstChild("Rot")
			if rot and inkludert(params, rot) then
				local til = rot.Position - fra
				local t = math.clamp(til:Dot(enhet), 0, lengde)
				local naermest = fra + enhet * t
				if (naermest - rot.Position).Magnitude < 3.5 then
					kandidat({ Position = naermest, Normal = -enhet, Instance = rot, Material = Enum.Material.Plastic, Distance = t })
				end
			end
		end
	end
	local bane = workspace:FindFirstChild("Bane")
	local medBane = bane and inkludert(params, bane)
	local medTerreng = inkludert(params, terreng)
	-- spesialdeler (boost, rampe): marsjer bare når en er i nærheten
	do
		for _, del in Mock.spesialdeler or {} do
			if not inkludert(params, del) then
				continue
			end
			local flatAvstand = Vector3.new(del.Position.X - fra.X, 0, del.Position.Z - fra.Z).Magnitude
			if flatAvstand < del.Size.Magnitude / 2 + lengde then
				local t = 0
				while t <= lengde do
					local p = fra + enhet * t
					if iBoks(del, p) then
						kandidat({ Position = p, Normal = del.CFrame.UpVector, Instance = del, Material = Enum.Material.SmoothPlastic, Distance = t })
						break
					end
					t += 0.5
				end
			end
		end
	end
	local vertikal = math.abs(enhet.Y) > 0.95
	if vertikal then
		if medBane then
			local h = Mock.veiHoyde and Mock.veiHoyde(fra)
			if h then
				kandidat({ Position = Vector3.new(fra.X, h, fra.Z), Normal = Vector3.yAxis, Instance = Mock.veiDel or bane,
					Material = Enum.Material.Asphalt, Distance = (fra.Y - h) / -enhet.Y })
			end
		end
		if medTerreng then
			local h = Mock.terrengHoyde(fra.X, fra.Z)
			if not params.IgnoreWater and h < 0 then
				kandidat({ Position = Vector3.new(fra.X, 0, fra.Z), Normal = Vector3.yAxis, Instance = terreng,
					Material = Enum.Material.Water, Distance = (fra.Y - 0) / -enhet.Y })
			end
			kandidat({ Position = Vector3.new(fra.X, h, fra.Z), Normal = Vector3.yAxis, Instance = terreng,
				Material = h < 4 and Enum.Material.Sand or Enum.Material.Grass, Distance = (fra.Y - h) / -enhet.Y })
		end
		return best
	end
	-- skrå stråler: marsjer
	local steg = math.max(0.5, math.min(4, lengde / 40))
	local t = 0
	while t <= lengde do
		if best and t > best.Distance then
			break
		end
		local p = fra + enhet * t
		if medBane then
			local h = Mock.veiHoyde and Mock.veiHoyde(p)
			if h and p.Y <= h then
				kandidat({ Position = Vector3.new(p.X, h, p.Z), Normal = Vector3.yAxis, Instance = Mock.veiDel or bane,
					Material = Enum.Material.Asphalt, Distance = t })
				break
			end
		end
		if medTerreng then
			local h = Mock.terrengHoyde(p.X, p.Z)
			if p.Y <= h then
				kandidat({ Position = Vector3.new(p.X, h, p.Z), Normal = Vector3.yAxis, Instance = terreng,
					Material = Enum.Material.Grass, Distance = t })
				break
			end
		end
		t += steg
	end
	return best
end

-- ---------------------------------------------------------------- fysikk og klokke
-- Enkle «fysikk»: deler med AssemblyLinearVelocity flyttes, tyngdekraft for de uten LinearVelocity.
Mock.fysiske = function()
	return {}
end

function Mock.steg(dt)
	tid += dt
	local runService = tjeneste("RunService")
	runService.Stepped:Fire(tid, dt)
	for _, del in Mock.fysiske() do
		if del.Parent and not del.Anchored then
			local lv = del:FindFirstChildOfClass("LinearVelocity")
			local v = lv and lv.VectorVelocity or (del.AssemblyLinearVelocity - Vector3.new(0, 196.2 * dt, 0))
			del.AssemblyLinearVelocity = v
			local pos = del.Position + v * dt
			-- enkel bakkekollisjon (veien eller terrenget)
			local bunn = del.Size.Y / 2
			local bakke = (Mock.veiHoyde and Mock.veiHoyde(pos + Vector3.new(0, bunn + 1, 0))) or Mock.terrengHoyde(pos.X, pos.Z)
			if pos.Y - bunn < bakke then
				pos = Vector3.new(pos.X, bakke + bunn, pos.Z)
				if v.Y < 0 then
					v = Vector3.new(v.X * 0.98, del.Name == "Granat" and -v.Y * 0.4 or 0, v.Z * 0.98)
					del.AssemblyLinearVelocity = v
				end
			end
			local ao = del:FindFirstChildOfClass("AlignOrientation")
			local rot = ao and ao.CFrame.Rotation or del.CFrame.Rotation
			local gammel = del.CFrame
			del.CFrame = rot + pos
			-- sveisede deler følger med (grovt: like stor forflytning)
			local modell = del.Parent
			if modell and modell:IsA("Model") and modell.PrimaryPart == del then
				local delta = del.CFrame * gammel:Inverse()
				for _, d in modell:GetDescendants() do
					if d ~= del and d:IsA("BasePart") then
						d.CFrame = delta * d.CFrame
					end
				end
			end
		end
	end
	runService.Heartbeat:Fire(dt)
	if Mock.lokalSpiller then
		runService.RenderStepped:Fire(dt)
		for _, f in Mock.renderSteg do
			local ok, err = pcall(f, dt)
			if not ok then
				table.insert(Mock.feil, "RenderStep: " .. tostring(err))
				print("FEIL I RENDERSTEP: " .. tostring(err))
			end
		end
	end
	-- planlagte oppgaver
	local klare = {}
	local rest = {}
	for _, p in planlagt do
		if p.tid <= tid then
			table.insert(klare, p)
		else
			table.insert(rest, p)
		end
	end
	planlagt = rest
	for _, p in klare do
		if coroutine.status(p.co) == "suspended" then
			gjenoppta(p.co, table.unpack(p.args, 1, p.args.n))
		end
	end
end

function Mock.instanser()
	return #workspace:GetDescendants()
end
