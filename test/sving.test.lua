-- Simulerer en spiller som svinger seg mellom øyene med den ekte krokfysikken (Krok.lua).
-- Bakken er toppen av øyene/steinene. Roboten går til kanten, skyter mot neste mål (øy eller
-- stein underveis), holder til den er nær festet og slipper. Sjekker at alle øyene kan nås.
local Oyer = krev("shared/Oyer")
local Krok = krev("shared/Krok")
local Config = krev("shared/Config")

local G = 196.2
local HOFTE = 3 -- rotdelen står så høyt over bakken
local R = Config.KROK.REKKEVIDDE

local function bakke(x, z, y)
	local best = nil
	for _, oy in Oyer.LISTE do
		local t = Oyer.form(oy, x, z)
		if t and y >= t - 2 and (not best or t > best) then
			best = t
		end
	end
	for _, s in Oyer.STEINER do
		local t = Oyer.steinForm(s, x, z)
		if t and y >= t - 2 and (not best or t > best) then
			best = t
		end
	end
	return best
end

-- mål: punkter vi kan feste kroken i (toppen av øyer og steiner, litt inn fra kanten)
local function festepunkt(mal, fra)
	local retning = Vector3.new(fra.X - mal.x, 0, fra.Z - mal.z)
	retning = retning.Magnitude > 0 and retning.Unit or Vector3.new(1, 0, 0)
	local r = mal.r * 0.55
	local x, z = mal.x + retning.X * r, mal.z + retning.Z * r
	local t = mal.topp and Oyer.form(mal, x, z) or Oyer.steinForm(mal, x, z)
	return Vector3.new(x, (t or mal.topp or mal.y) + 0.5, z)
end

local function reise(fra, til)
	-- start på toppen av «fra», midt på
	local y0 = bakke(fra.x, fra.z, 1000)
	local pos = Vector3.new(fra.x, y0 + HOFTE, fra.z)
	local v = Vector3.zero
	local s = Krok.ny()
	local dt = 1 / 60
	local tid, skudd, maksFart = 0, 0, 0
	local mal = nil
	while tid < 40 do
		local tak = bakke(pos.X, pos.Z, pos.Y - HOFTE + 0.5)
		local paaBakken = tak ~= nil and pos.Y - HOFTE <= tak + 0.15
		-- har vi kommet fram?
		local ovenfor = Oyer.over(pos)
		if paaBakken and ovenfor == til then
			return true, tid, skudd, maksFart
		end
		-- velg neste mål: øya hvis innenfor rekkevidde, ellers steinen som kommer oss nærmest
		if s.krok == "inne" and paaBakken then
			local direkte = festepunkt(til, pos)
			if (direkte - pos).Magnitude < R * 0.95 then
				mal = direkte
			else
				local best, bestD = nil, math.huge
				for _, st in Oyer.STEINER do
					local p = festepunkt(st, pos)
					local d = (p - pos).Magnitude
					local igjen = (Vector3.new(til.x, til.topp, til.z) - p).Magnitude
					if d < R * 0.95 and d > 25 and igjen < bestD then
						best, bestD = p, igjen
					end
				end
				mal = best
			end
			if mal and Krok.skyt(s, pos + Vector3.new(1, 1, 0), mal, true) then
				skudd += 1
			end
		end
		-- slipp når vi er nær festet
		-- slipp når farten peker mot målet (som en spiller ville gjort), eller helt inne ved festet
		local mot = Vector3.new(til.x - pos.X, til.topp + 15 - pos.Y, til.z - pos.Z)
		local erMalet = mal and (Vector3.new(mal.X, 0, mal.Z) - Vector3.new(til.x, 0, til.z)).Magnitude < til.r
		local siktetRett = v.Magnitude > 30 and v.Unit:Dot(mot.Unit) > 0.75 and not erMalet and pos.Y > til.topp - 5 and v.Y > -25
		if s.krok == "fest" and ((s.anker - pos).Magnitude < 12 or (siktetRett and (s.anker - pos).Magnitude < 60)) then
			Krok.slipp(s)
			if DEBUG then
				print(string.format("    slipp ved %s fart %s (%.0f)", tostring(pos), tostring(v), v.Magnitude))
			end
		end
		local res = Krok.steg(s, { sving = mal and (Vector3.new(mal.X - pos.X, 0, mal.Z - pos.Z)).Unit or nil, trekk = false },
			dt, { pos = pos, v = v, bakke = paaBakken, hand = pos + Vector3.new(1, 1, 0) })
		if res.v then
			v = res.v
		elseif paaBakken then
			-- Humanoid: gå mot kanten i retning målet
			local mot = Vector3.new(til.x - pos.X, 0, til.z - pos.Z)
			v = mot.Magnitude > 1 and mot.Unit * 16 or Vector3.zero
		end
		v -= Vector3.new(0, G * dt, 0)
		pos += v * dt
		local t2 = bakke(pos.X, pos.Z, pos.Y - HOFTE + 2)
		if t2 and pos.Y - HOFTE < t2 then
			pos = Vector3.new(pos.X, t2 + HOFTE, pos.Z)
			if v.Y < 0 then
				v = Vector3.new(v.X, 0, v.Z)
			end
		end
		maksFart = math.max(maksFart, v.Magnitude)
		if pos.Y < Config.FALL_GRENSE then
			if DEBUG then
				print("    falt ved " .. tostring(pos) .. "  mål " .. tostring(mal))
			end
			return false, tid, skudd, maksFart
		end
		tid += dt
	end
	return false, tid, skudd, maksFart
end

DEBUG = false
-- direkte hopp mellom alle par av øyer som ligger innen rekkevidde, og hvilke øyer som kan nås fra Hjem
local kanter = {}
local antallPar, antallOk = 0, 0
for _, a in Oyer.LISTE do
	kanter[a] = {}
	for _, b in Oyer.LISTE do
		if a ~= b then
			local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2 + (a.topp - b.topp) ^ 2) - a.r * 0.8 - b.r * 0.55
			if d < R * 0.95 then
				antallPar += 1
				local ok, tid, skudd, maks = reise(a, b)
				if ok then
					antallOk += 1
					table.insert(kanter[a], b)
				end
				print(string.format("  %-15s → %-15s %s %4.1f s  %d skudd  maks %3.0f", a.navn, b.navn, ok and "OK  " or "FALL", tid, skudd, maks))
			end
		end
	end
end
local naadd = { [Oyer.LISTE[Oyer.HJEM]] = true }
local ko = { Oyer.LISTE[Oyer.HJEM] }
while #ko > 0 do
	local a = table.remove(ko, 1)
	for _, b in kanter[a] do
		if not naadd[b] then
			naadd[b] = true
			table.insert(ko, b)
		end
	end
end
local antall = 0
for _ in naadd do
	antall += 1
end
print(string.format("Direkte hopp: %d av %d lyktes. Øyer som kan nås fra Hjem: %d av %d", antallOk, antallPar, antall, #Oyer.LISTE))
