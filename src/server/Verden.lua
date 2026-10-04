-- Alt rundt øyene: lys og himmel, skyhav under øyene, pynt etter tema, hengebroer, luftskipet,
-- vindmølla, treningsdukker og startpunktene. Terrenget lages i Oyterreng.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Oyer = require(Shared:WaitForChild("Oyer"))
local Config = require(Shared:WaitForChild("Config"))

local Verden = {}

local Modeller
local mappe
Verden.dukkeListe = {} -- { modell, rot, hjem (CFrame) }

local function del(e, forelder)
	local p = Instance.new(e.Klasse or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in e do
		if k ~= "Klasse" then
			p[k] = v
		end
	end
	p.Parent = forelder or mappe
	return p
end

local function toppHoyde(oy, x, z)
	local t = Oyer.form(oy, x, z)
	return t
end

-- ---------------------------------------------------------------- lys og himmel

function Verden.lys()
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(96, 104, 124)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 168, 190)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	local function effekt(klasse, e)
		local x = Instance.new(klasse)
		for k, v in e do
			x[k] = v
		end
		x.Parent = Lighting
	end
	effekt("Atmosphere", { Density = 0.22, Offset = 0.05, Color = Color3.fromRGB(200, 226, 255),
		Decay = Color3.fromRGB(120, 150, 200), Glare = 0.4, Haze = 0.8 })
	effekt("Sky", { SunAngularSize = 14 })
	effekt("BloomEffect", { Intensity = 0.5, Size = 24, Threshold = 1.3 })
	effekt("SunRaysEffect", { Intensity = 0.06, Spread = 0.8 })
	effekt("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.06 })
	local skyer = Instance.new("Clouds")
	skyer.Cover = 0.45
	skyer.Density = 0.4
	skyer.Parent = workspace.Terrain
end

-- Skyhavet under øyene: klumper av hvite kuler. Kroken går gjennom dem.
local function sky(senter, storrelse, rng)
	for _ = 1, rng:NextInteger(4, 8) do
		local d = storrelse * rng:NextNumber(0.4, 1)
		del({ Name = "Sky", Shape = Enum.PartType.Ball, Size = Vector3.one * d, CanCollide = false, CanQuery = false,
			CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 255, 255),
			Transparency = 0.08,
			CFrame = CFrame.new(senter + Vector3.new(rng:NextNumber(-1, 1) * storrelse, rng:NextNumber(-0.25, 0.25) * storrelse,
				rng:NextNumber(-1, 1) * storrelse)) })
	end
end

function Verden.skyhav()
	local rng = Random.new(77)
	for _ = 1, 70 do
		local senter = Vector3.new(rng:NextNumber(-650, 650), rng:NextNumber(-45, -20), rng:NextNumber(-700, 600))
		sky(senter, rng:NextNumber(30, 60), rng)
	end
	for _ = 1, 14 do
		local senter = Vector3.new(rng:NextNumber(-600, 600), rng:NextNumber(150, 260), rng:NextNumber(-650, 550))
		sky(senter, rng:NextNumber(18, 34), rng)
	end
end

-- ---------------------------------------------------------------- pynt

-- Hvilke modeller hver øy får: { navn, antall, skala-område, kollisjon }
local PYNT = {
	hjem = { { "Hus", 4, 1, 1, true }, { "Lykt", 6, 1, 1, false } },
	sopp = { { "Sopp", 6, 0.9, 1.4, true }, { "SoppLiten", 12, 0.8, 1.3, false } },
	krystall = { { "KrystallStor", 2, 0.9, 1.2, true }, { "Krystall", 12, 0.8, 1.4, true } },
	ruin = { { "Soyle", 8, 0.9, 1.2, true }, { "Ruinbue", 2, 1, 1.2, true }, { "Steinhode", 2, 1, 1.3, true } },
	sno = { { "Furu", 12, 0.8, 1.3, true }, { "Snomann", 2, 1, 1.2, false } },
	orken = { { "Kaktus", 9, 0.8, 1.4, true } },
	jungel = { { "Bambus", 8, 0.9, 1.3, true }, { "Bregne", 14, 0.8, 1.5, false } },
	lava = { { "Vulkanstein", 9, 0.8, 1.6, true } },
	taarn = { { "Lykt", 4, 1, 1, false } },
}

local function settNed(navn, cf, skala, kollisjon)
	local p = Modeller.plasser(navn, cf, skala, mappe)
	if p then
		p.CanCollide = kollisjon
		p.CanQuery = true -- kroken kan feste seg i det meste
	end
	return p
end

local function reserveTre(pos, rng)
	local h = rng:NextNumber(10, 16)
	del({ Name = "Stamme", Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
		Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 78, 50) })
	del({ Name = "Krone", Shape = Enum.PartType.Ball, Size = Vector3.one * h * 0.7, CFrame = CFrame.new(pos + Vector3.new(0, h, 0)),
		Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 150, 60) })
end

local function fritt(liste, pos, avstand)
	for _, p in liste do
		if (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < avstand then
			return false
		end
	end
	return true
end

function Verden.pynt()
	local rng = Random.new(2026)
	local brukt = {}
	-- broendene skal være fri for pynt
	for _, bro in Oyer.BROER do
		local a, b = Oyer.broPunkter(bro)
		table.insert(brukt, a)
		table.insert(brukt, b)
	end
	for _, oy in Oyer.LISTE do
		-- startplassen på Hjem er fri
		if oy.tema == "hjem" then
			table.insert(brukt, Vector3.new(oy.x, 0, oy.z))
		end
		for _, valg in PYNT[oy.tema] or {} do
			local navn, antall, s0, s1, kollisjon = valg[1], valg[2], valg[3], valg[4], valg[5]
			for n = 1, antall do
				for _ = 1, 12 do
					local vinkel = rng:NextNumber(0, math.pi * 2)
					local radius = oy.r * (oy.tema == "hjem" and rng:NextNumber(0.35, 0.78) or rng:NextNumber(0.12, 0.78))
					if navn == "Hus" then
						vinkel = n / antall * math.pi * 2 + 0.4
						radius = oy.r * 0.55
					end
					local x, z = oy.x + math.cos(vinkel) * radius, oy.z + math.sin(vinkel) * radius
					local t = toppHoyde(oy, x, z)
					local pos = t and Vector3.new(x, t - 0.3, z)
					if pos and fritt(brukt, pos, navn == "Hus" and 18 or 8) then
						table.insert(brukt, pos)
						-- hus vender mot midten av øya
						local cf = navn == "Hus" and CFrame.lookAt(pos, Vector3.new(oy.x, pos.Y, oy.z))
							or CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
						local p = settNed(navn, cf, rng:NextNumber(s0, s1), kollisjon)
						if not p and (navn == "Furu" or navn == "Bambus" or navn == "Sopp") then
							reserveTre(pos, rng)
						end
						if p and navn == "Lykt" then
							local pkt = Modeller.punkt("Lykt", "lys", 1)
							if pkt then
								local lys = Instance.new("PointLight")
								lys.Range = 18
								lys.Brightness = 1.5
								lys.Color = Color3.fromRGB(255, 220, 150)
								lys.Parent = p
							end
						end
						break
					end
				end
			end
		end
	end
	-- spesielle ting
	local hjem = Oyer.LISTE[Oyer.HJEM]
	do -- vindmølla på Hjem
		local x, z = hjem.x - hjem.r * 0.6, hjem.z + hjem.r * 0.35
		local t = toppHoyde(hjem, x, z)
		if t then
			local cf = CFrame.lookAt(Vector3.new(x, t - 0.3, z), Vector3.new(hjem.x, t, hjem.z))
			if settNed("Vindmolle", cf, 1, true) then
				local nav = Modeller.punkt("Vindmolle", "nav", 1)
				local vinger = nav and Modeller.plasser("VindmolleVinger", cf * CFrame.new(nav), 1, mappe)
				if vinger then
					vinger.CanCollide = false
					CollectionService:AddTag(vinger, "Vinge")
				end
			end
		end
	end
	for _, oy in Oyer.LISTE do
		if oy.tema == "orken" then
			local t = toppHoyde(oy, oy.x, oy.z)
			settNed("Pyramide", CFrame.new(oy.x, t - 0.5, oy.z) * CFrame.Angles(0, 0.3, 0), 1, true)
		elseif oy.tema == "taarn" then
			local t = toppHoyde(oy, oy.x, oy.z)
			if not settNed("Taarn", CFrame.new(oy.x, t - 0.5, oy.z), 1, true) then
				del({ Name = "Taarn", Size = Vector3.new(12, 70, 12), CFrame = CFrame.new(oy.x, t + 35, oy.z),
					Material = Enum.Material.Brick, Color = Color3.fromRGB(170, 120, 90) })
			end
		elseif oy.tema == "lava" then
			-- glødende lavapøler, ild og røyk
			for n = 1, 4 do
				local v = n * 1.7
				local x, z = oy.x + math.cos(v) * oy.r * 0.4, oy.z + math.sin(v) * oy.r * 0.4
				local t = toppHoyde(oy, x, z)
				if t then
					local pol = del({ Name = "Lavapol", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9),
						CFrame = CFrame.new(x, t + 0.1, z) * CFrame.Angles(0, 0, math.rad(90)), CanCollide = false,
						Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 100, 30) })
					local lys = Instance.new("PointLight")
					lys.Range = 22
					lys.Brightness = 2.5
					lys.Color = Color3.fromRGB(255, 120, 40)
					lys.Parent = pol
					local ild = Instance.new("Fire")
					ild.Size = 5
					ild.Heat = 10
					ild.Parent = pol
				end
			end
		end
	end
	-- svevesteiner (modell) som ekstra krokfester høyt oppe
	local rng2 = Random.new(9)
	for _ = 1, 10 do
		local pos = Vector3.new(rng2:NextNumber(-300, 330), rng2:NextNumber(130, 230), rng2:NextNumber(-380, 260))
		if not Oyer.over(pos) then
			settNed("Svevestein", CFrame.new(pos) * CFrame.Angles(0, rng2:NextNumber(0, 6), 0), rng2:NextNumber(1, 1.6), true)
		end
	end
end

-- ---------------------------------------------------------------- hengebroer

local function bro(a, b)
	local lengde = (b - a).Magnitude
	local frem = (b - a).Unit
	local hoyre = frem:Cross(Vector3.new(0, 1, 0)).Unit
	local heng = lengde * 0.07
	local antall = math.floor(lengde / 2.4)
	local forrige = { }
	local BREDDE = 7
	for i = 0, antall do
		local t = i / antall
		local p = a:Lerp(b, t) - Vector3.new(0, heng * 4 * t * (1 - t), 0)
		local q = a:Lerp(b, math.min(1, t + 1 / antall)) - Vector3.new(0, heng * 4 * math.min(1, t + 1 / antall) * (1 - math.min(1, t + 1 / antall)), 0)
		local retning = (q - p).Magnitude > 0.01 and (q - p).Unit or frem
		if i < antall then
			del({ Name = "Broplanke", Size = Vector3.new(BREDDE, 0.45, 2.0),
				CFrame = CFrame.lookAt(p, p + retning) * CFrame.new(0, -0.2, -1.1),
				Material = Enum.Material.WoodPlanks, Color = i % 2 == 0 and Color3.fromRGB(150, 104, 62) or Color3.fromRGB(128, 88, 52) })
		end
		-- tau på sidene
		for _, side in { -1, 1 } do
			local topp = p + hoyre * side * (BREDDE / 2 + 0.2) + Vector3.new(0, 3, 0)
			if forrige[side] then
				local m = (forrige[side] + topp) / 2
				del({ Name = "Brotau", Size = Vector3.new(0.25, 0.25, (topp - forrige[side]).Magnitude), CFrame = CFrame.lookAt(m, topp),
					CanCollide = false, Material = Enum.Material.Fabric, Color = Color3.fromRGB(70, 52, 36) })
			end
			if i % 4 == 0 then
				del({ Name = "Brostolpe", Size = Vector3.new(0.3, 3, 0.3), CFrame = CFrame.new(topp - Vector3.new(0, 1.5, 0)),
					CanCollide = false, Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 64, 40) })
			end
			forrige[side] = topp
		end
	end
	for _, ende in { a, b } do
		for _, side in { -1, 1 } do
			del({ Name = "Brofeste", Size = Vector3.new(1, 5, 1), CFrame = CFrame.new(ende + hoyre * side * (BREDDE / 2 + 0.2) + Vector3.new(0, 1.5, 0)),
				Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 64, 40) })
		end
	end
end

function Verden.broer()
	for _, b in Oyer.BROER do
		local a, c = Oyer.broPunkter(b)
		bro(a + Vector3.new(0, 0.3, 0), c + Vector3.new(0, 0.3, 0))
	end
end

-- ---------------------------------------------------------------- luftskipet

function Verden.luftskip()
	local L = Oyer.LUFTSKIP
	local skip = Modeller.plasser("Luftskip", CFrame.new(L.x, L.hoyde, L.z), 1, mappe)
	if not skip then
		skip = del({ Name = "Luftskip", Size = Vector3.new(20, 18, 60), Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(220, 70, 60), CFrame = CFrame.new(L.x, L.hoyde, L.z) })
	end
	skip.CanCollide = true
	skip.CanQuery = true
	local midt = (Modeller.info("Luftskip") and Modeller.info("Luftskip").midt) or Vector3.zero
	local vinkel = 0
	RunService.Heartbeat:Connect(function(dt)
		vinkel += dt * L.fart
		local pos = Vector3.new(L.x + math.cos(vinkel) * L.radius, L.hoyde + math.sin(vinkel * 3) * 6, L.z + math.sin(vinkel) * L.radius)
		local frem = Vector3.new(-math.sin(vinkel), 0, math.cos(vinkel))
		skip.CFrame = CFrame.lookAt(pos, pos + frem) * CFrame.new(midt)
	end)
end

-- ---------------------------------------------------------------- treningsdukker

local function lagDukke(cf)
	local modell = Instance.new("Model")
	modell.Name = "Dukke"
	local rot = Instance.new("Part")
	rot.Name = "Rot"
	rot.Size = Vector3.new(2.6, 6, 2)
	rot.Transparency = 1
	rot.CFrame = cf * CFrame.new(0, 3, 0)
	rot.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.6, 0.2)
	rot.Parent = modell
	local mesh = Modeller.hent("Dukke", 1)
	if mesh then
		mesh.CFrame = cf * CFrame.new(Modeller.info("Dukke").midt)
		mesh.CanQuery = true
	else
		mesh = Instance.new("Part")
		mesh.Name = "Kropp"
		mesh.Size = Vector3.new(2.4, 5.8, 1.8)
		mesh.Color = Color3.fromRGB(220, 190, 110)
		mesh.Material = Enum.Material.Fabric
		mesh.CFrame = rot.CFrame
		mesh.Massless = true
		mesh.CanCollide = false
	end
	mesh.Parent = modell
	local w = Instance.new("WeldConstraint")
	w.Part0 = rot
	w.Part1 = mesh
	w.Parent = mesh
	modell.PrimaryPart = rot
	modell:SetAttribute("Skade", 0)
	modell.Parent = mappe
	CollectionService:AddTag(modell, "Dukke")
	pcall(function()
		rot:SetNetworkOwner(nil)
	end)
	return modell, rot
end

function Verden.dukker()
	local hjem = Oyer.LISTE[Oyer.HJEM]
	for n = 1, 4 do
		local x, z = hjem.x + (n - 2.5) * 9, hjem.z - hjem.r * 0.3
		local t = toppHoyde(hjem, x, z) or hjem.topp
		local cf = CFrame.lookAt(Vector3.new(x, t, z), Vector3.new(x, t, z + 10))
		local modell, rot = lagDukke(cf)
		table.insert(Verden.dukkeListe, { modell = modell, rot = rot, hjem = cf })
	end
	-- dukker som faller ned kommer tilbake
	task.spawn(function()
		while true do
			task.wait(1)
			for _, d in Verden.dukkeListe do
				if d.rot.Position.Y < Config.FALL_GRENSE or (d.rot.Position - d.hjem.Position).Magnitude > 400 then
					d.rot.AssemblyLinearVelocity = Vector3.zero
					d.rot.AssemblyAngularVelocity = Vector3.zero
					d.modell:PivotTo(d.hjem * CFrame.new(0, 3, 0))
					d.modell:SetAttribute("Skade", 0)
				end
			end
		end
	end)
end

-- ---------------------------------------------------------------- startpunkter

-- Lages FØRST (før terrenget), så spillerne har noe å stå på mens øyene bygges.
function Verden.startpunkter()
	mappe = mappe or Instance.new("Folder")
	mappe.Name = "Verden"
	mappe.Parent = workspace
	local hjem = Oyer.LISTE[Oyer.HJEM]
	for n = 0, 5 do
		local v = n / 6 * math.pi * 2
		local x, z = hjem.x + math.cos(v) * 10, hjem.z + math.sin(v) * 10
		local t = toppHoyde(hjem, x, z) or hjem.topp
		del({ Klasse = "SpawnLocation", Name = "Start", Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(x, t + 0.2, z),
			Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 220, 255), Transparency = 0.3, Duration = 0,
			Neutral = true })
	end
end

function Verden.bygg(modeller)
	Modeller = modeller
	if not mappe then
		Verden.startpunkter()
	end
	Verden.lys()
	Verden.skyhav()
	Verden.broer()
	Verden.pynt()
	Verden.luftskip()
	Verden.dukker()
end

return Verden
