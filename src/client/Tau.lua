-- Tau og krok for ALLE spillere: et svart tau (Beam) fra krokpistolens munning til kroken,
-- kroken som spinner ut, biter seg fast og trekkes inn igjen. Din egen krok følger
-- Grappler-tilstanden; andres krok følger hendelser fra serveren.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelInfo = require(Shared:WaitForChild("ModelInfo"))

local Tau = {}

local spiller = Players.LocalPlayer
local Grappler
local mappe = Instance.new("Folder")
mappe.Name = "KrokEffekter"
mappe.Parent = workspace

local visninger = {} -- [Player] = { krok, beam, a1, tilstand, ... }
local andre = {}     -- [Player] = tilstand for andres kroker
local K = Config.KROK

local function lagKrok()
	local mal = ReplicatedStorage:FindFirstChild("KlientModeller") and ReplicatedStorage.KlientModeller:FindFirstChild("Krok")
	local krok
	local ring = Vector3.new(0, 0, 1.2)
	if mal then
		krok = mal:Clone()
		local info = ModelInfo.Krok
		if info and info.ring then
			ring = info.ring - info.midt
		end
	else
		krok = Instance.new("Part")
		krok.Size = Vector3.new(0.9, 0.9, 2.4)
		krok.Color = Color3.fromRGB(150, 155, 165)
		krok.Material = Enum.Material.Metal
	end
	krok.Name = "Krok"
	krok.Anchored = true
	krok.CanCollide = false
	krok.CanQuery = false
	krok.CanTouch = false
	krok.Transparency = 1
	krok.Parent = mappe
	local a = Instance.new("Attachment")
	a.Name = "Ring"
	a.Position = ring
	a.Parent = krok
	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Color3.fromRGB(12, 12, 14))
	beam.Width0 = 0.22
	beam.Width1 = 0.18
	beam.FaceCamera = true
	beam.Segments = 16
	beam.LightInfluence = 0.2
	beam.Transparency = NumberSequence.new(0)
	beam.Attachment1 = a
	beam.Enabled = false
	beam.Parent = krok
	return { krok = krok, beam = beam, a1 = a, spinn = 0, bitt = 0 }
end

local function visning(p)
	local v = visninger[p]
	if not v or not v.krok.Parent then
		v = lagKrok()
		visninger[p] = v
	end
	return v
end

local function munning(figur)
	local verktoy = figur and figur:FindFirstChildOfClass("Tool")
	local handle = verktoy and verktoy:FindFirstChild("Handle")
	local m = handle and handle:FindFirstChild("Munning")
	if m then
		return m.WorldPosition, m
	end
	local h = figur and (figur:FindFirstChild("RightHand") or figur:FindFirstChild("HumanoidRootPart"))
	return h and h.Position or nil, nil
end

-- Tegn én krok: tilstand = "inne" | "ute" | "fest" | "tilbake", pos = krokens posisjon.
local function tegn(v, tilstand, pos, handPos, munningAtt, dt)
	if tilstand == "inne" or not pos or not handPos then
		v.krok.Transparency = 1
		v.beam.Enabled = false
		return
	end
	v.krok.Transparency = 0
	v.beam.Enabled = munningAtt ~= nil
	if munningAtt and v.beam.Attachment0 ~= munningAtt then
		v.beam.Attachment0 = munningAtt
	end
	local retning = pos - handPos
	retning = retning.Magnitude > 0.01 and retning.Unit or Vector3.new(0, 0, -1)
	if tilstand == "ute" then
		v.spinn += dt * 28
		v.bitt = 0
	elseif tilstand == "fest" then
		v.bitt = math.min(1, v.bitt + dt * 8)
	end
	local cf = CFrame.lookAt(pos - retning * 0.6, pos + retning) * CFrame.Angles(0, 0, v.spinn)
	-- når den biter seg fast: et lite dytt innover
	if tilstand == "fest" and v.bitt < 1 then
		cf = cf * CFrame.new(0, 0, -math.sin(v.bitt * math.pi) * 0.5)
	end
	v.krok.CFrame = cf
	-- tauet: slakt og bølgete på vei ut og inn, stramt når det sitter
	local t = os.clock()
	if tilstand == "fest" then
		v.beam.CurveSize0 = 0
		v.beam.CurveSize1 = 0
	else
		local b = tilstand == "ute" and 2.2 or 1.4
		v.beam.CurveSize0 = math.sin(t * 34) * b
		v.beam.CurveSize1 = -math.cos(t * 29) * b
	end
end

-- ---------------------------------------------------------------- andres kroker

local function andreHendelse(p, type_, mal, del, lokal)
	if p == spiller then
		return
	end
	if type_ == "skyt" then
		local hand = munning(p.Character) or mal
		andre[p] = { tilstand = "ute", fra = hand, mal = mal, del = del, lokal = lokal, tid = 0,
			varighet = math.max((mal - hand).Magnitude / K.KROKFART, 0.03) }
	elseif type_ == "slipp" then
		local a = andre[p]
		if a and a.tilstand ~= "inne" then
			a.tilstand = "tilbake"
			a.tid = 0
			a.fra = a.pos or a.mal
		end
	end
end

local function oppdaterAndre(dt)
	for p, a in andre do
		if not p.Parent then
			andre[p] = nil
			local v = visninger[p]
			if v then
				v.krok:Destroy()
				visninger[p] = nil
			end
			continue
		end
		local hand, att = munning(p.Character)
		a.tid += dt
		if a.tilstand == "ute" then
			local andel = math.clamp(a.tid / a.varighet, 0, 1)
			a.pos = (hand or a.fra):Lerp(a.mal, andel)
			if andel >= 1 then
				a.tilstand = "fest"
			end
		elseif a.tilstand == "fest" then
			if a.del and a.lokal and a.del.Parent then
				a.pos = a.del.CFrame:PointToWorldSpace(a.lokal)
			else
				a.pos = a.mal
			end
		elseif a.tilstand == "tilbake" then
			local andel = math.clamp(a.tid / 0.16, 0, 1)
			a.pos = a.fra:Lerp(hand or a.fra, andel)
			if andel >= 1 then
				a.tilstand = "inne"
			end
		end
		tegn(visning(p), a.tilstand, a.pos, hand, att, dt)
	end
end

function Tau.start(grappler, remotes)
	Grappler = grappler
	remotes.Hendelse.OnClientEvent:Connect(function(type_, p, ...)
		if type_ == "krok" then
			andreHendelse(p, ...)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local s = Grappler.tilstand()
		local figur = Grappler.figur()
		local hand, att = munning(figur)
		tegn(visning(spiller), s.krok, s.krokPos, hand, att, dt)
		oppdaterAndre(dt)
	end)
end

return Tau
