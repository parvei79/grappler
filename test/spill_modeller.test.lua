-- Hele GRAPPLER i Roblox-etterligningen: serveren bygger øyene, en robotspiller svinger seg mellom
-- øyene og rykker/sparker treningsdukkene gjennom den ekte klientkoden.
-- Med falske modeller. Kjør: python3 tools/test_luau.py test/spill_modeller.test.lua --mock
local Oyer = krev("shared/Oyer")

-- bakken: toppen av øyer/steiner (ingen bunn), ellers tomrom
local function topp(x, z)
	local best = -1000
	for _, oy in Oyer.LISTE do
		local t = Oyer.form(oy, x, z)
		if t and t > best then
			best = t
		end
	end
	for _, st in Oyer.STEINER do
		local t = Oyer.steinForm(st, x, z)
		if t and t > best then
			best = t
		end
	end
	return best
end
Mock.terrengHoyde = topp
Mock.fysiske = function()
	local liste = {}
	for _, p in game:GetService("Players"):GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(liste, r)
		end
	end
	local verden = workspace:FindFirstChild("Verden")
	if verden then
		for _, m in verden:GetChildren() do
			if m.Name == "Dukke" and m.PrimaryPart then
				table.insert(liste, m.PrimaryPart)
			end
		end
	end
	return liste
end
MODULER["mock/PlayerModule"] = function()
	return { GetControls = function()
		return { GetMoveVector = function()
			return Mock.flytt or Vector3.zero
		end }
	end }
end

do -- falske importerte modeller (som Import 3D lager dem), så modell-kodeveiene også kjøres
	local ModelInfo = krev("shared/ModelInfo")
	local mappe = Instance.new("Model")
	mappe.Name = "Scene"
	for navn, info in ModelInfo do
		local node = Instance.new("Model")
		node.Name = navn .. "_Node"
		node.Parent = mappe
		local del = Instance.new("MeshPart")
		del.Name = navn
		del.Size = info.str
		del.Anchored = true
		del.Parent = node
	end
	mappe.Parent = workspace
end

local lastet = false
task.spawn(function()
	krev("server/Main")
	lastet = true
end)
while not lastet and #Mock.feil == 0 and Mock.tid() < 60 do
	Mock.steg(1 / 60)
end
assert(lastet, "Main ble ikke ferdig")
print(string.format("Server klar: %d instanser, %d voksler", Mock.instanser(), Mock.voksler))

local spiller = Mock.leggTilSpiller("Pål", 1001)
Mock.blilokal(spiller, "mock/PlayerModule")
local klar = false
task.spawn(function()
	krev("client/Klient")
	klar = true
end)
for _ = 1, 30 do
	Mock.steg(1 / 60)
end
assert(klar, "klienten ble ikke ferdig")

Mock.spesialdeler = {}
for _, m in workspace.Verden:GetChildren() do
	if m.Name == "Dukke" then
		table.insert(Mock.spesialdeler, m.PrimaryPart)
	end
end
local Grappler = krev("client/Grappler")
local Kamera = krev("client/Kamera")
local figur = spiller.Character
local rot = figur.HumanoidRootPart
local hum = figur:FindFirstChildOfClass("Humanoid")
print("Startposisjon: " .. tostring(rot.Position) .. "  verktøy: " .. tostring(figur:FindFirstChildOfClass("Tool")))

local dt = 1 / 60
local skudd, fester, landinger, rykk, spark, besokt = 0, 0, 0, 0, 0, {}
local maal, holdTid = nil, 0
Grappler.hendelser = (function(gammel)
	return function(liste)
		for _, h in liste do
			if h[1] == "fest" then
				fester += 1
			elseif h[1] == "landing" then
				landinger += 1
			elseif h[1] == "rykk" then
				rykk += 1
			elseif h[1] == "spark" then
				spark += 1
			end
		end
		gammel(liste)
	end
end)(Grappler.hendelser)

local rng = Random.new(5)
local tid0 = os.clock()
while Mock.tid() < 120 and #Mock.feil == 0 do
	local pos = rot.Position
	local t = topp(pos.X, pos.Z)
	hum.FloorMaterial = (pos.Y - 3 <= t + 0.3) and Enum.Material.Grass or Enum.Material.Air
	local s = Grappler.tilstand()
	if s.krok == "inne" and hum.FloorMaterial ~= Enum.Material.Air then
		local over = Oyer.over(pos)
		if over then
			besokt[over.navn] = true
		end
		-- velg mål: av og til en dukke, ellers en annen øy innen rekkevidde
		local valg = nil
		DEBUG_SIKT = false
		if rng:NextNumber() < 0.25 then
			for _, m in workspace.Verden:GetChildren() do
				if m.Name == "Dukke" and m.PrimaryPart and (m.PrimaryPart.Position - pos).Magnitude < 150 then
					valg = m.PrimaryPart.Position
					DEBUG_SIKT = true
					break
				end
			end
		end
		if not valg then
			local kandidater = {}
			for _, oy in Oyer.LISTE do
				local p = Vector3.new(oy.x, oy.topp + 1, oy.z)
				local mot = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(oy.x, 0, oy.z))
				p += (mot.Magnitude > 0 and mot.Unit or Vector3.xAxis) * oy.r * 0.5
				if oy ~= over and (p - pos).Magnitude < 220 then
					table.insert(kandidater, p)
				end
			end
			valg = #kandidater > 0 and kandidater[rng:NextInteger(1, #kandidater)] or nil
		end
		if valg then
			-- sikt fra kameraet (det er kamerastrålen som bestemmer hvor kroken treffer)
			for _ = 1, 3 do
				Kamera.settRetning((valg - workspace.CurrentCamera.CFrame.Position).Unit)
				Mock.steg(dt)
			end
			local sk = Grappler.sikt()
			if DEBUG_SIKT and sk and false then
				print("  sikter: treff", sk.treff, "innenfor", sk.innenfor, "motstander", sk.motstander, "del", sk.del)
			end
			Grappler.skyt()
			skudd += 1
			maal, holdTid = valg, 0
		end
	elseif s.krok == "fest" or s.krok == "ute" then
		holdTid += dt
		if (s.anker and (s.anker - pos).Magnitude < 14) or holdTid > 4 then
			Grappler.slipp()
		end
	end
	Mock.steg(dt)
	if hum.Health <= 0 then
		print("  falt ned ved " .. tostring(pos) .. " — legger spilleren tilbake på Hjem")
		hum.Health = 100
		figur:PivotTo(CFrame.new(0, 70, 0))
		rot.AssemblyLinearVelocity = Vector3.zero
	end
end
local navn = {}
for n in besokt do
	table.insert(navn, n)
end
table.sort(navn)
print(string.format("Simulerte %.0f s på %.1f s: %d skudd, %d fester, %d landinger, %d rykk, %d spark",
	Mock.tid(), os.clock() - tid0, skudd, fester, landinger, rykk, spark))
print("Besøkte øyer: " .. table.concat(navn, ", "))
local teller = {}
for _, h in Mock.hendelser do
	local k = h.remote .. ":" .. tostring(h.args[1])
	teller[k] = (teller[k] or 0) + 1
end
for k, n in teller do
	print(string.format("  %-24s %d", k, n))
end
print(#Mock.feil == 0 and "INGEN FEIL" or ("FEIL: " .. #Mock.feil))
