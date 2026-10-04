-- Din egen krok: sikting (midt på skjermen), skyting, svinging med ekte momentum, slipp,
-- rykk mot andre (kroken treffer en spiller/dukke) og flyspark (du flyr inn i noen i full fart).
-- Du eier figuren din, så farten settes her hvert fysikksteg mens du henger eller flyr.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Krok = require(Shared:WaitForChild("Krok"))

local Grappler = {}

local spiller = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local kamera = workspace.CurrentCamera
local K, KAMP = Config.KROK, Config.KAMP

local s = Krok.ny()
local figur, hum, rot
local festeDel, festeLokal, maalModell = nil, nil, nil
local holder = false
local kontroller = nil
local sistSpark = {}
Grappler.hendelser = nil -- callback(liste) settes av Effekter/HUD
Grappler.sikte = { treff = false, innenfor = false, motstander = false, avstand = 0 }

function Grappler.tilstand()
	return s
end

function Grappler.figur()
	return figur
end

local function hendelse(...)
	if Grappler.hendelser then
		Grappler.hendelser({ { ... } })
	end
end

-- Munningen på krokpistolen (tauet starter her), ellers høyre hånd.
function Grappler.hand(f)
	f = f or figur
	if not f then
		return nil
	end
	local verktoy = f:FindFirstChildOfClass("Tool")
	local handle = verktoy and verktoy:FindFirstChild("Handle")
	local munning = handle and handle:FindFirstChild("Munning")
	if munning then
		return munning.WorldPosition, munning
	end
	local h = f:FindFirstChild("RightHand") or f:FindFirstChild("Right Arm") or f:FindFirstChild("HumanoidRootPart")
	return h and h.Position or nil, nil
end

local function hentKontroller()
	if kontroller then
		return kontroller
	end
	local ok, modul = pcall(function()
		return require(spiller:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and modul then
		kontroller = modul:GetControls()
	end
	return kontroller
end

-- Ønsket retning fra WASD i verdenskoordinater (i forhold til kameraet).
local function svingRetning()
	local c = hentKontroller()
	local mv = c and c:GetMoveVector() or Vector3.zero
	if mv.Magnitude < 0.05 then
		return nil
	end
	local cf = kamera.CFrame
	local frem = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	frem = frem.Magnitude > 0 and frem.Unit or Vector3.new(0, 0, -1)
	local hoyre = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	hoyre = hoyre.Magnitude > 0 and hoyre.Unit or Vector3.new(1, 0, 0)
	return (hoyre * mv.X - frem * mv.Z).Unit
end

-- ---------------------------------------------------------------- sikting

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local function erMotstander(inst)
	local m = inst
	while m and m ~= workspace do
		if m:IsA("Model") then
			if m ~= figur and Players:GetPlayerFromCharacter(m) then
				return m
			end
			if CollectionService:HasTag(m, "Dukke") then
				return m
			end
		end
		m = m.Parent
	end
	return nil
end

function Grappler.sikt()
	local ut = Grappler.sikte
	local hand = Grappler.hand()
	if not hand then
		ut.treff, ut.innenfor = false, false
		return nil
	end
	local unntak = { figur, workspace:FindFirstChild("KrokEffekter") }
	params.FilterDescendantsInstances = unntak
	local cf = kamera.CFrame
	local maks = K.REKKEVIDDE + (cf.Position - hand).Magnitude + 5
	local res = workspace:Raycast(cf.Position, cf.LookVector * maks, params)
	if res then
		ut.treff = true
		ut.punkt = res.Position
		ut.del = res.Instance
		ut.avstand = (res.Position - hand).Magnitude
		ut.innenfor = ut.avstand <= K.REKKEVIDDE
		ut.motstander = erMotstander(res.Instance)
	else
		ut.treff = false
		ut.innenfor = false
		ut.motstander = nil
		ut.punkt = cf.Position + cf.LookVector * maks
		ut.avstand = maks
	end
	return ut
end

-- ---------------------------------------------------------------- skyt og slipp

function Grappler.skyt()
	if not figur or not rot or hum.Health <= 0 or not Krok.kanSkyte(s) then
		return
	end
	local hand = Grappler.hand()
	local sikte = Grappler.sikt()
	if not hand or not sikte then
		return
	end
	local mal, treff
	if sikte.treff and sikte.innenfor then
		mal, treff = sikte.punkt, true
		festeDel = sikte.del
		festeLokal = sikte.del.CFrame:PointToObjectSpace(sikte.punkt)
		maalModell = sikte.motstander
	else
		mal = hand + (sikte.punkt - hand).Unit * K.REKKEVIDDE
		treff = false
		festeDel, festeLokal, maalModell = nil, nil, nil
	end
	if Krok.skyt(s, hand, mal, treff) then
		holder = true
		remotes.Krok:FireServer("skyt", mal, festeDel, festeLokal)
		hendelse("skudd", hand)
	end
end

function Grappler.slipp()
	holder = false
	local h = Krok.slipp(s)
	if h then
		hendelse(h)
	end
	remotes.Krok:FireServer("slipp")
	festeDel, festeLokal, maalModell = nil, nil, nil
end

-- ---------------------------------------------------------------- fysikksteg

local function steg(dt)
	if not figur or not rot or not rot.Parent or not hum or hum.Health <= 0 then
		return
	end
	dt = math.min(dt, 1 / 20)
	local hand = Grappler.hand() or rot.Position
	local anker = nil
	if s.krok == "fest" and festeDel and festeLokal then
		if festeDel.Parent then
			anker = festeDel.CFrame:PointToWorldSpace(festeLokal)
		else
			Grappler.slipp()
		end
	end
	local paaBakken = hum.FloorMaterial ~= Enum.Material.Air
	local res = Krok.steg(s, {
		sving = svingRetning(),
		trekk = UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA),
	}, dt, { pos = rot.Position, v = rot.AssemblyLinearVelocity, bakke = paaBakken, hand = hand, anker = anker })

	for _, h in res.hendelser do
		if h[1] == "fest" then
			if maalModell then
				-- kroken traff en motstander: rykk dem mot deg og slipp etter et øyeblikk
				remotes.Rykk:FireServer(festeDel)
				hendelse("rykk", s.anker)
				task.delay(0.28, function()
					if s.krok == "fest" then
						Grappler.slipp()
					end
				end)
			else
				hendelse("fest", s.anker, festeDel)
			end
		elseif Grappler.hendelser then
			Grappler.hendelser({ h })
		end
	end

	if res.v then
		rot.AssemblyLinearVelocity = res.v
		local tilstand = hum:GetState()
		if tilstand ~= Enum.HumanoidStateType.Freefall and tilstand ~= Enum.HumanoidStateType.Jumping then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		-- flyspark: fløy du inn i noen?
		local fart = res.v.Magnitude
		if fart >= KAMP.SPARK_MIN_FART then
			for _, annen in Players:GetPlayers() do
				local f = annen.Character
				if annen ~= spiller and f then
					local r = f:FindFirstChild("HumanoidRootPart")
					if r and (r.Position - rot.Position).Magnitude < KAMP.SPARK_AVSTAND then
						Grappler.spark(r, res.v)
					end
				end
			end
			for _, dukke in CollectionService:GetTagged("Dukke") do
				local r = dukke.PrimaryPart
				if r and (r.Position - rot.Position).Magnitude < KAMP.SPARK_AVSTAND then
					Grappler.spark(r, res.v)
				end
			end
		end
	end
end

function Grappler.spark(maalRot, fart)
	local naa = os.clock()
	if sistSpark[maalRot] and naa - sistSpark[maalRot] < 0.6 then
		return
	end
	sistSpark[maalRot] = naa
	remotes.Spark:FireServer(maalRot, fart)
	hendelse("spark", maalRot.Position)
	-- du spretter litt tilbake
	s.settFart = fart * -0.25 + Vector3.new(0, 25, 0)
end

-- ---------------------------------------------------------------- oppsett

local function nyFigur(f)
	figur = f
	hum = f:WaitForChild("Humanoid")
	rot = f:WaitForChild("HumanoidRootPart")
	s = Krok.ny()
	holder = false
end

function Grappler.start()
	UserInputService.InputBegan:Connect(function(input, behandlet)
		if behandlet then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			Grappler.skyt()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if holder then
				Grappler.slipp()
			end
		end
	end)
	-- mobil: egen KROK-knapp (hold for å henge, slipp for å fly)
	if UserInputService.TouchEnabled then
		ContextActionService:BindAction("KrokMobil", function(_, tilstand)
			if tilstand == Enum.UserInputState.Begin then
				Grappler.skyt()
			elseif tilstand == Enum.UserInputState.End then
				Grappler.slipp()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("KrokMobil", "KROK")
	end
	remotes.Knuff.OnClientEvent:Connect(function(hastighet, stun)
		Krok.knuff(s, hastighet, stun)
		festeDel, festeLokal, maalModell = nil, nil, nil
		holder = false
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		hendelse("truffet", hastighet)
	end)
	spiller.CharacterAdded:Connect(nyFigur)
	if spiller.Character then
		task.spawn(nyFigur, spiller.Character)
	end
	RunService.Stepped:Connect(function(_, dt)
		steg(dt)
	end)
end

return Grappler
