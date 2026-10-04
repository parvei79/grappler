-- Lyd og effekter: «thwip» når kroken skytes, klank når den biter seg fast, vinsj mens tauet
-- trekkes inn, vind som øker med farten, sus når du slipper, slag og spark, gnister og støv,
-- kamerarist, og vindmølla som snurrer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Effekter = {}

local spiller = Players.LocalPlayer
local Grappler, Kamera
local L = Config.LYD
local mappe

local function lyd(id, pos, volum, tonehoyde, rekkevidde)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = mappe
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volum or 0.7
	s.PlaybackSpeed = tonehoyde or 1
	s.RollOffMaxDistance = rekkevidde or 250
	s.RollOffMinDistance = 10
	s.Parent = p
	s:Play()
	Debris:AddItem(p, 6)
end
Effekter.lyd = lyd

local function lyd2D(id, volum, tonehoyde)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volum or 0.6
	s.PlaybackSpeed = tonehoyde or 1
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 6)
end

local function burst(pos, farge, antall, fart, storrelse)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = mappe
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Speed = NumberRange.new(fart * 0.5, fart)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Drag = 4
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(storrelse, 0)
	e.Color = ColorSequence.new(farge)
	e.Parent = p
	e:Emit(antall)
	Debris:AddItem(p, 1.5)
end

local function smell(pos, tekst, farge)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos + Vector3.new(0, 3, 0)
	p.Parent = mappe
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 2.4)
	gui.AlwaysOnTop = true
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = tekst
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = farge
	t.TextStrokeTransparency = 0
	t.Rotation = math.random(-12, 12)
	t.Parent = gui
	Debris:AddItem(p, 0.9)
end

-- hendelser fra din egen krok
function Effekter.egen(liste)
	local figur = Grappler.figur()
	local rot = figur and figur:FindFirstChild("HumanoidRootPart")
	for _, h in liste do
		local navn = h[1]
		if navn == "skudd" then
			lyd2D(L.skudd, 0.7, 0.95 + math.random() * 0.15)
		elseif navn == "fest" then
			local pos, del = h[2], h[3]
			local stein = del and (del:IsA("Terrain") or del.Material == Enum.Material.Rock)
			lyd(stein and L.festStein or L.fest, pos, 0.8, 0.9 + math.random() * 0.2)
			burst(pos, Color3.fromRGB(255, 220, 140), 10, 22, 0.5)
			burst(pos, Color3.fromRGB(170, 160, 150), 8, 10, 1.2)
			Kamera.rist(0.15)
		elseif navn == "rykk" then
			lyd2D(L.tausvisj, 0.7, 1.1)
		elseif navn == "slipp" then
			lyd2D(L.slipp, 0.45, 0.9 + math.random() * 0.2)
		elseif navn == "bom" then
			lyd2D(L.bom, 0.35, 1.3)
		elseif navn == "landing" and rot and h[2] > 0.3 then
			lyd(L.landing, rot.Position, 0.5 + h[2] * 0.5, 0.9)
			burst(rot.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 190, 170), 12, 14, 1.4)
			Kamera.rist(h[2] * 0.4)
		elseif navn == "spark" then
			Kamera.rist(0.5)
		elseif navn == "truffet" then
			Kamera.rist(0.8)
		end
	end
end

-- hendelser fra serveren (alle ser dem)
local function serverHendelse(type_, a, b)
	if type_ == "rykk" then
		lyd(L.rykk, a, 1, 0.9 + math.random() * 0.2)
		burst(a, Color3.fromRGB(255, 240, 200), 14, 25, 0.6)
		smell(a, "RYKK!", Color3.fromRGB(255, 214, 10))
	elseif type_ == "spark" then
		lyd(L.spark, a, 1.1, 0.9 + math.random() * 0.2)
		burst(a, Color3.fromRGB(255, 200, 120), 22, 35, 0.8)
		smell(a, "FLYSPARK!", Color3.fromRGB(255, 90, 60))
	elseif type_ == "krok" and a ~= spiller then
		local figur = a and a.Character
		local rot = figur and figur:FindFirstChild("HumanoidRootPart")
		if b == "skyt" and rot then
			lyd(L.skudd, rot.Position, 0.6, 1)
		end
	end
end

function Effekter.start(grappler, kamera, remotes)
	Grappler, Kamera = grappler, kamera
	mappe = workspace:WaitForChild("KrokEffekter")
	remotes.Hendelse.OnClientEvent:Connect(serverHendelse)

	-- løkker: vinsj mens du henger, vind etter fart
	local vinsj = Instance.new("Sound")
	vinsj.SoundId = L.vinsj
	vinsj.Looped = true
	vinsj.Volume = 0
	vinsj.Parent = workspace.CurrentCamera
	vinsj:Play()
	local vind = Instance.new("Sound")
	vind.SoundId = L.vind
	vind.Looped = true
	vind.Volume = 0
	vind.Parent = workspace.CurrentCamera
	vind:Play()
	local bakgrunn = Instance.new("Sound")
	bakgrunn.SoundId = L.vindsus
	bakgrunn.Looped = true
	bakgrunn.Volume = 0.25
	bakgrunn.Parent = workspace.CurrentCamera
	bakgrunn:Play()

	local vinger = {}
	local function registrer(v)
		vinger[v] = v.CFrame
	end
	for _, v in CollectionService:GetTagged("Vinge") do
		registrer(v)
	end
	CollectionService:GetInstanceAddedSignal("Vinge"):Connect(registrer)

	RunService.RenderStepped:Connect(function(dt)
		local s = Grappler.tilstand()
		local figur = Grappler.figur()
		local rot = figur and figur:FindFirstChild("HumanoidRootPart")
		local fart = rot and rot.AssemblyLinearVelocity.Magnitude or 0
		local hekta = s.krok == "fest" and s.bevegelse == "hekta"
		vinsj.Volume += ((hekta and 0.35 or 0) - vinsj.Volume) * math.min(1, dt * 10)
		vinsj.PlaybackSpeed = 1 + math.clamp(fart / 200, 0, 0.6)
		local vindMal = math.clamp((fart - 30) / 150, 0, 1) * 0.8
		vind.Volume += (vindMal - vind.Volume) * math.min(1, dt * 4)
		vind.PlaybackSpeed = 0.8 + math.clamp(fart / 200, 0, 0.7)
		local t = os.clock()
		for v, base in vinger do
			if v.Parent then
				v.CFrame = base * CFrame.Angles(0, 0, t * 0.8)
			end
		end
	end)
end

return Effekter
