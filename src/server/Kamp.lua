-- Server: krokpistolen til alle, videresending av kroker (så alle ser alle tau), rykk og flyspark
-- mot andre spillere og treningsdukker, skade-prosent, og hva som skjer når noen faller ned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Kamp = {}

local Modeller, Fjern
local sistTruffet = {} -- [figur] = { av = navn, tid }
local sistSkudd = {}   -- [spiller] = tid
local sistSpark = {}   -- [spiller..mål] = tid
local K, KK = Config.KAMP, Config.KROK

local function naa()
	return workspace:GetServerTimeNow()
end

-- ---------------------------------------------------------------- krokpistolen

local function lagPistol()
	local verktoy = Instance.new("Tool")
	verktoy.Name = "Krokpistol"
	verktoy.CanBeDropped = false
	verktoy.RequiresHandle = true
	local handle = Modeller.hent("KrokPistol", 1)
	local munning
	if handle then
		handle.Name = "Handle"
		local info = Modeller.info("KrokPistol")
		verktoy.Grip = CFrame.new(info.grep)
		munning = info.munning - info.midt
	else
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.6, 0.8, 3)
		handle.Color = Color3.fromRGB(230, 57, 70)
		handle.CanCollide = false
		handle.Massless = true
		verktoy.Grip = CFrame.new(0, -0.2, 0.8)
		munning = Vector3.new(0, 0.1, -1.6)
	end
	local a = Instance.new("Attachment")
	a.Name = "Munning"
	a.Position = munning
	a.Parent = handle
	handle.Parent = verktoy
	return verktoy
end

local function skadeMerke(figur)
	local hode = figur:WaitForChild("Head", 5)
	if not hode then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SkadeMerke"
	gui.Size = UDim2.fromOffset(80, 30)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 150
	gui.Adornee = hode
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.Text = "0%"
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = gui
	local function oppdater()
		local s = figur:GetAttribute("Skade") or 0
		local a = math.clamp(s / 120, 0, 1)
		t.Text = s .. "%"
		t.TextColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 40), math.min(a * 2, 1))
			:Lerp(Color3.fromRGB(255, 50, 40), math.max(a * 2 - 1, 0))
	end
	figur:GetAttributeChangedSignal("Skade"):Connect(oppdater)
	oppdater()
	gui.Parent = hode
end

local function figurInn(spiller, figur)
	figur:SetAttribute("Skade", 0)
	local hum = figur:WaitForChild("Humanoid")
	task.defer(function()
		local verktoy = lagPistol()
		verktoy.Parent = spiller:WaitForChild("Backpack")
		hum:EquipTool(verktoy)
	end)
	skadeMerke(figur)
end

-- ---------------------------------------------------------------- treff

-- Mål kan være en spillerfigur eller en treningsdukke. Returnerer modell, rotdel, eier (Player|nil).
local function maalFra(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	local m = inst
	while m and m ~= workspace do
		if m:IsA("Model") then
			local spiller = Players:GetPlayerFromCharacter(m)
			if spiller then
				return m, m:FindFirstChild("HumanoidRootPart"), spiller
			end
			if CollectionService:HasTag(m, "Dukke") then
				return m, m.PrimaryPart, nil
			end
		end
		m = m.Parent
	end
	return nil
end

local function knuff(modell, rot, eier, hastighet, skade, angriper)
	local s = (modell:GetAttribute("Skade") or 0) + skade
	modell:SetAttribute("Skade", s)
	local faktor = 1 + s / K.SKADE_DELER
	hastighet *= faktor
	if eier then
		Fjern.Knuff:FireClient(eier, hastighet, K.STUN)
	else
		rot.AssemblyLinearVelocity = hastighet
		rot.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	end
	if angriper then
		sistTruffet[modell] = { av = angriper.DisplayName, tid = naa() }
	end
end

local function rykk(spiller, mal)
	local figur = spiller.Character
	local minRot = figur and figur:FindFirstChild("HumanoidRootPart")
	local modell, rot, eier = maalFra(mal)
	if not minRot or not modell or not rot or modell == figur then
		return
	end
	local avstand = (rot.Position - minRot.Position).Magnitude
	if avstand > KK.REKKEVIDDE + 25 then
		return
	end
	local mot = (minRot.Position - rot.Position)
	local retning = Vector3.new(mot.X, 0, mot.Z).Unit
	local fart = K.RYKK_KRAFT + math.min(avstand * 0.25, 40)
	knuff(modell, rot, eier, retning * fart + Vector3.new(0, K.RYKK_OPP, 0), K.RYKK_SKADE, spiller)
	Fjern.Hendelse:FireAllClients("rykk", rot.Position, spiller)
end

local function spark(spiller, mal, minFart)
	local figur = spiller.Character
	local minRot = figur and figur:FindFirstChild("HumanoidRootPart")
	local modell, rot, eier = maalFra(mal)
	if not minRot or not modell or not rot or modell == figur or typeof(minFart) ~= "Vector3" then
		return
	end
	local nokkel = spiller.UserId .. tostring(modell)
	if sistSpark[nokkel] and naa() - sistSpark[nokkel] < 0.5 then
		return
	end
	if (rot.Position - minRot.Position).Magnitude > K.SPARK_AVSTAND + 8 then
		return
	end
	local fart = math.min(minFart.Magnitude, KK.MAKS_FART)
	if fart < K.SPARK_MIN_FART * 0.8 then
		return
	end
	sistSpark[nokkel] = naa()
	local retning = minFart.Unit
	knuff(modell, rot, eier, retning * (fart * 0.75) + Vector3.new(0, 30, 0), K.SPARK_SKADE + math.floor(fart / 12), spiller)
	Fjern.Hendelse:FireAllClients("spark", rot.Position, spiller)
end

-- ---------------------------------------------------------------- fall

local function sjekkFall()
	for _, spiller in Players:GetPlayers() do
		local figur = spiller.Character
		local hum = figur and figur:FindFirstChildOfClass("Humanoid")
		local rot = figur and figur:FindFirstChild("HumanoidRootPart")
		if hum and rot and hum.Health > 0 and rot.Position.Y < Config.FALL_GRENSE then
			local sist = sistTruffet[figur]
			if sist and naa() - sist.tid < K.SIST_TRUFFET then
				Fjern.Hendelse:FireAllClients("melding", string.format("%s ble rykket ned i skyene av %s! ☁️", spiller.DisplayName, sist.av))
			else
				Fjern.Hendelse:FireAllClients("melding", string.format("%s glemte å skyte kroken. ☁️", spiller.DisplayName))
			end
			sistTruffet[figur] = nil
			hum.Health = 0
		end
	end
end

function Kamp.init(modeller, remotes)
	Modeller, Fjern = modeller, remotes
	Players.RespawnTime = Config.RESPAWN_TID

	-- kroken: videresend til alle andre, så de ser tauet
	Fjern.Krok.OnServerEvent:Connect(function(spiller, type_, mal, del, lokal)
		if type_ == "skyt" then
			if typeof(mal) ~= "Vector3" then
				return
			end
			local t = naa()
			if sistSkudd[spiller] and t - sistSkudd[spiller] < KK.VENTETID * 0.7 then
				return
			end
			sistSkudd[spiller] = t
			local figur = spiller.Character
			local rot = figur and figur:FindFirstChild("HumanoidRootPart")
			if not rot or (mal - rot.Position).Magnitude > KK.REKKEVIDDE + 30 then
				return
			end
			if del ~= nil and typeof(del) ~= "Instance" then
				del = nil
			end
			if typeof(lokal) ~= "Vector3" then
				lokal = nil
			end
			for _, annen in Players:GetPlayers() do
				if annen ~= spiller then
					Fjern.Hendelse:FireClient(annen, "krok", spiller, "skyt", mal, del, lokal)
				end
			end
		elseif type_ == "slipp" then
			for _, annen in Players:GetPlayers() do
				if annen ~= spiller then
					Fjern.Hendelse:FireClient(annen, "krok", spiller, "slipp")
				end
			end
		end
	end)
	Fjern.Rykk.OnServerEvent:Connect(rykk)
	Fjern.Spark.OnServerEvent:Connect(spark)

	local function spillerInn(spiller)
		spiller.CharacterAdded:Connect(function(figur)
			figurInn(spiller, figur)
		end)
		if spiller.Character then
			task.spawn(figurInn, spiller, spiller.Character)
		end
	end
	Players.PlayerAdded:Connect(spillerInn)
	for _, s in Players:GetPlayers() do
		task.spawn(spillerInn, s)
	end
	Players.PlayerRemoving:Connect(function(spiller)
		sistSkudd[spiller] = nil
	end)

	local akk = 0
	RunService.Heartbeat:Connect(function(dt)
		akk += dt
		if akk >= 0.2 then
			akk = 0
			sjekkFall()
		end
	end)
end

return Kamp
