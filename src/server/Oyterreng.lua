-- Bygger de flytende øyene og svevesteinene i Roblox-terreng (voksler), med materialer etter tema.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Oyer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Oyer"))

local Oyterreng = {}

-- topp / side / bunn-materiale per tema (lava får flekker av glødende lava på toppen)
local TEMA = {
	hjem = { topp = "Grass", side = "Rock", bunn = "Rock" },
	sopp = { topp = "Salt", side = "Rock", bunn = "Slate" },
	krystall = { topp = "Glacier", side = "Slate", bunn = "Slate" },
	ruin = { topp = "Limestone", side = "Cobblestone", bunn = "Rock" },
	sno = { topp = "Snow", side = "Rock", bunn = "Rock" },
	orken = { topp = "Sand", side = "Sandstone", bunn = "Sandstone" },
	jungel = { topp = "LeafyGrass", side = "Ground", bunn = "Rock" },
	lava = { topp = "Basalt", side = "Basalt", bunn = "Basalt", flekk = "CrackedLava" },
	taarn = { topp = "Pavement", side = "Rock", bunn = "Rock" },
	stein = { topp = "Grass", side = "Rock", bunn = "Rock" },
}
Oyterreng.TEMA = TEMA

local FARGER = {
	Grass = Color3.fromRGB(104, 178, 74),
	LeafyGrass = Color3.fromRGB(58, 140, 60),
	Salt = Color3.fromRGB(214, 168, 236),
	Glacier = Color3.fromRGB(168, 150, 255),
	Slate = Color3.fromRGB(86, 72, 116),
	Limestone = Color3.fromRGB(222, 212, 184),
	Cobblestone = Color3.fromRGB(150, 140, 126),
	Snow = Color3.fromRGB(246, 250, 255),
	Sand = Color3.fromRGB(238, 208, 140),
	Sandstone = Color3.fromRGB(206, 150, 98),
	Ground = Color3.fromRGB(122, 92, 64),
	Basalt = Color3.fromRGB(58, 52, 54),
	CrackedLava = Color3.fromRGB(255, 104, 32),
	Pavement = Color3.fromRGB(160, 162, 170),
	Rock = Color3.fromRGB(128, 118, 110),
}

-- Lag voksel-tabellene for én øy (form = funksjon (x, z) -> topp, bunn) og skriv dem.
local function skriv(T, form, x0, x1, z0, z1, tema, fro)
	local mats = TEMA[tema]
	local ix0, ix1 = math.floor(x0 / 4), math.ceil(x1 / 4)
	local iz0, iz1 = math.floor(z0 / 4), math.ceil(z1 / 4)
	local sx, sz = ix1 - ix0, iz1 - iz0
	-- kolonner først, så vi vet høydespennet
	local topper, bunner = {}, {}
	local ymin, ymax = math.huge, -math.huge
	for i = 1, sx do
		topper[i], bunner[i] = {}, {}
		local x = (ix0 + i - 0.5) * 4
		for k = 1, sz do
			local z = (iz0 + k - 0.5) * 4
			local t, b = form(x, z)
			topper[i][k], bunner[i][k] = t, b
			if t then
				ymin, ymax = math.min(ymin, b), math.max(ymax, t)
			end
		end
	end
	if ymin == math.huge then
		return 0
	end
	local iy0, iy1 = math.floor(ymin / 4) - 1, math.ceil(ymax / 4) + 1
	local sy = iy1 - iy0
	local luft = Enum.Material.Air
	local mTopp, mSide, mBunn = Enum.Material[mats.topp], Enum.Material[mats.side], Enum.Material[mats.bunn]
	local mFlekk = mats.flekk and Enum.Material[mats.flekk]
	local M, O = table.create(sx), table.create(sx)
	for i = 1, sx do
		local mx, ox = table.create(sy), table.create(sy)
		local x = (ix0 + i - 0.5) * 4
		for j = 1, sy do
			local y0 = (iy0 + j - 1) * 4
			local my, oy = table.create(sz), table.create(sz)
			for k = 1, sz do
				local t, b = topper[i][k], bunner[i][k]
				local o = 0
				if t then
					o = math.clamp(math.min(t - y0, y0 + 4 - b) / 4, 0, 1)
				end
				if o > 0.02 then
					local m = mSide
					if t - y0 < 4.5 then
						m = mTopp
						if mFlekk and math.noise(x / 14, ((iz0 + k - 0.5) * 4) / 14, fro) > 0.32 then
							m = mFlekk
						end
					elseif y0 - b < 8 then
						m = mBunn
					end
					my[k], oy[k] = m, o
				else
					my[k], oy[k] = luft, 0
				end
			end
			mx[j], ox[j] = my, oy
		end
		M[i], O[i] = mx, ox
	end
	T:WriteVoxels(Region3.new(Vector3.new(ix0 * 4, iy0 * 4, iz0 * 4), Vector3.new(ix1 * 4, iy1 * 4, iz1 * 4)), 4, M, O)
	return sx * sy * sz
end

function Oyterreng.bygg()
	local T = workspace.Terrain
	local start = os.clock()
	T:Clear()
	for navn, farge in FARGER do
		pcall(function()
			T:SetMaterialColor(Enum.Material[navn], farge)
		end)
	end
	pcall(function()
		T.Decoration = true
	end)
	local voksler = 0
	for _, oy in Oyer.LISTE do
		local r = oy.r * 1.25
		voksler += skriv(T, function(x, z)
			return Oyer.form(oy, x, z)
		end, oy.x - r, oy.x + r, oy.z - r, oy.z + r, oy.tema, oy.fro)
		task.wait()
	end
	for n, s in Oyer.STEINER do
		local r = s.r * 1.35
		voksler += skriv(T, function(x, z)
			return Oyer.steinForm(s, x, z)
		end, s.x - r, s.x + r, s.z - r, s.z + r, "stein", n)
	end
	print(string.format("[GRAPPLER] Øyene bygget på %.1f s (%d voksler)", os.clock() - start, voksler))
end

return Oyterreng
