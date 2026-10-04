-- De flytende øyene: plassering, størrelse, tema og form (topp og bunn for hver kolonne).
-- Ren matematikk, delt mellom server (bygging av terreng og pynt) og klient (kart). Testbar med luau.
local Oyer = {}

-- tema: bestemmer materialer og pynt. topp = høyden på toppflaten, r = radius, dybde = hvor langt
-- «stalaktitt-kjeglen» under øya går ned, kuppel = hvor mye midten hvelver seg.
Oyer.LISTE = {
	{ navn = "Hjem", tema = "hjem", x = 0, z = 0, topp = 60, r = 72, dybde = 70, kuppel = 4, stoy = 2.5, fro = 1 },
	{ navn = "Soppskogen", tema = "sopp", x = 195, z = 45, topp = 78, r = 44, dybde = 55, kuppel = 6, stoy = 3, fro = 2 },
	{ navn = "Krystallgrotta", tema = "krystall", x = 130, z = -195, topp = 112, r = 46, dybde = 65, kuppel = 3, stoy = 4, fro = 3 },
	{ navn = "Ruinene", tema = "ruin", x = -185, z = -85, topp = 86, r = 56, dybde = 60, kuppel = 2, stoy = 2, fro = 4 },
	{ navn = "Snøtoppen", tema = "sno", x = -60, z = -285, topp = 150, r = 50, dybde = 80, kuppel = 14, stoy = 4, fro = 5 },
	{ navn = "Ørkenøya", tema = "orken", x = -235, z = 145, topp = 52, r = 50, dybde = 45, kuppel = 5, stoy = 3, fro = 6 },
	{ navn = "Jungelen", tema = "jungel", x = 40, z = 235, topp = 72, r = 52, dybde = 65, kuppel = 5, stoy = 3, fro = 7 },
	{ navn = "Lavaøya", tema = "lava", x = 305, z = -140, topp = 96, r = 40, dybde = 50, kuppel = 8, stoy = 4, fro = 8 },
	{ navn = "Tårnøya", tema = "taarn", x = 150, z = -370, topp = 122, r = 30, dybde = 55, kuppel = 1, stoy = 1.5, fro = 9 },
}
Oyer.HJEM = 1

-- Små svevesteiner å svinge seg i (terreng), mellom øyene.
Oyer.STEINER = {
	{ x = 95, z = 30, y = 95, r = 9 }, { x = 70, z = -110, y = 120, r = 8 }, { x = -95, z = -40, y = 105, r = 9 },
	{ x = -120, z = -190, y = 140, r = 8 }, { x = 30, z = -260, y = 170, r = 7 }, { x = 230, z = -60, y = 125, r = 8 },
	{ x = 260, z = 120, y = 110, r = 8 }, { x = 120, z = 160, y = 105, r = 9 }, { x = -110, z = 110, y = 90, r = 9 },
	{ x = -120, z = 240, y = 110, r = 7 }, { x = 220, z = -270, y = 150, r = 8 }, { x = -260, z = 20, y = 115, r = 8 },
	{ x = 0, z = 120, y = 125, r = 7 }, { x = 360, z = 0, y = 140, r = 7 },
}

-- Hengebroer mellom øyer (navnene i LISTE).
Oyer.BROER = {
	{ "Hjem", "Soppskogen" }, { "Hjem", "Ruinene" }, { "Hjem", "Jungelen" }, { "Krystallgrotta", "Lavaøya" },
	{ "Ruinene", "Ørkenøya" },
}

-- Luftskipet sirkler rundt over øyene.
Oyer.LUFTSKIP = { x = 0, z = -40, radius = 290, hoyde = 195, fart = 0.035 }

local etterNavn = {}
for i, oy in Oyer.LISTE do
	etterNavn[oy.navn] = oy
	oy.indeks = i
end
function Oyer.finn(navn)
	return etterNavn[navn]
end

-- Formen på øya i kolonnen (x, z). Returnerer topp, bunn og «kantandel» (0 midt, 1 ytterst), eller nil.
function Oyer.form(oy, x, z)
	local dx, dz = x - oy.x, z - oy.z
	local d = math.sqrt(dx * dx + dz * dz)
	local f = oy.fro * 17.3
	local kant = oy.r * (1 + 0.16 * math.noise(dx / 34 + f, dz / 34, f * 0.5))
	if d >= kant then
		return nil
	end
	local t = d / kant
	local topp = oy.topp + oy.kuppel * (1 - t * t) + math.noise(x / 26, z / 26, f + 1.3) * oy.stoy
	if t > 0.82 then
		topp -= ((t - 0.82) / 0.18) ^ 2 * 5 -- rund av kanten
	end
	local bunn = oy.topp - oy.dybde * (1 - t ^ 1.5) ^ 0.75
	bunn += math.noise(x / 11, z / 11, f + 4.2) * 7 * (1 - t) + math.noise(x / 40, z / 40, f + 9.1) * 6
	bunn = math.min(bunn, topp - 4)
	return topp, bunn, t
end

-- Form for en liten svevestein.
function Oyer.steinForm(s, x, z)
	local dx, dz = x - s.x, z - s.z
	local d = math.sqrt(dx * dx + dz * dz)
	local kant = s.r * (1 + 0.2 * math.noise(dx / 6, dz / 6, s.x * 0.01))
	if d >= kant then
		return nil
	end
	local t = d / kant
	local topp = s.y + 1.5 * (1 - t * t)
	local bunn = s.y - s.r * 1.3 * (1 - t ^ 1.4) ^ 0.8
	return topp, math.min(bunn, topp - 3), t
end

-- Endepunktene for en bro: på kanten av hver øy, i høyde med toppen.
function Oyer.broPunkter(bro)
	local a, b = etterNavn[bro[1]], etterNavn[bro[2]]
	local retning = Vector3.new(b.x - a.x, 0, b.z - a.z).Unit
	local pa = Vector3.new(a.x, 0, a.z) + retning * (a.r * 0.82)
	local pb = Vector3.new(b.x, 0, b.z) - retning * (b.r * 0.82)
	local ta = Oyer.form(a, pa.X, pa.Z) or a.topp
	local tb = Oyer.form(b, pb.X, pb.Z) or b.topp
	return Vector3.new(pa.X, ta, pa.Z), Vector3.new(pb.X, tb, pb.Z)
end

-- Hvilken øy står du over? (for meldinger og kart)
function Oyer.over(pos)
	for _, oy in Oyer.LISTE do
		local dx, dz = pos.X - oy.x, pos.Z - oy.z
		if dx * dx + dz * dz < (oy.r * 1.1) ^ 2 then
			return oy
		end
	end
	return nil
end

return Oyer
