-- Fysikken for gripekroken: kroken flyr ut, fester seg, tauet kortes inn mens du svinger som en
-- pendel, og når du slipper, flyr du videre med farten du har. Ren matematikk: miljøet (posisjon,
-- fart, bakkekontakt, hvor festet er nå) kommer inn som argumenter, så modulen kan testes med luau
-- og brukes likt av alle klienter.
--
-- To tilstander:
--   krok      = "inne" | "ute" (på vei ut) | "fest" | "tilbake" (trekkes inn igjen)
--   bevegelse = "bakke" (Humanoid styrer selv) | "hekta" (pendel i tauet) | "flyr" (fart bevares i lufta)
local Config = require(script.Parent.Config)

local Krok = {}

local K = Config.KROK
local OPP = Vector3.new(0, 1, 0)

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function Krok.ny()
	return {
		krok = "inne",
		bevegelse = "bakke",
		anker = nil,
		lengde = 0,
		krokPos = nil,
		krokFra = nil,
		krokMal = nil,
		krokTid = 0,
		krokVarighet = 0,
		krokTreff = false,
		returTid = 0,
		stun = 0,
		sistSkudd = -10,
		tid = 0,
		flyTid = 0,
		slippBoost = false,
		settFart = nil,
	}
end

function Krok.kanSkyte(s)
	return s.stun <= 0 and s.krok == "inne" and s.tid - s.sistSkudd >= K.VENTETID
end

-- Skyt kroken fra `fra` mot `mal`. `treff` = om strålen faktisk traff noe (ellers bommer kroken).
function Krok.skyt(s, fra, mal, treff)
	if not Krok.kanSkyte(s) then
		return false
	end
	s.krok = "ute"
	s.krokFra = fra
	s.krokMal = mal
	s.krokPos = fra
	s.krokTid = 0
	s.krokVarighet = math.max((mal - fra).Magnitude / K.KROKFART, 0.03)
	s.krokTreff = treff
	s.sistSkudd = s.tid
	return true
end

-- Slipp tauet (eller avbryt et kast).
function Krok.slipp(s)
	local hendelse = nil
	if s.krok == "fest" then
		hendelse = "slipp"
		if s.bevegelse == "hekta" then
			s.bevegelse = "flyr"
			s.flyTid = 0
			s.slippBoost = true
		end
	end
	if s.krok == "ute" or s.krok == "fest" then
		s.krok = "tilbake"
		s.returTid = 0
		s.krokFra = s.krokPos or s.krokFra
	end
	return hendelse
end

-- Truffet av noen: kastes med `hastighet`, mister kroken, og kan ikke skyte på en stund.
function Krok.knuff(s, hastighet, stun)
	Krok.slipp(s)
	s.slippBoost = false
	s.bevegelse = "flyr"
	s.flyTid = 0
	s.settFart = hastighet
	s.stun = math.max(s.stun, stun or Config.KAMP.STUN)
end

--[[ Ett steg.
	inn   = { sving = Vector3 (ønsket retning fra WASD, kan være null), trekk = bool (SPACE) }
	miljo = { pos = Vector3, v = Vector3, bakke = bool, hand = Vector3, anker = Vector3|nil (festet nå, hvis det beveger seg) }
	Returnerer { v = ny fart eller nil (Humanoid styrer), hendelser = {...}, krokPos = Vector3|nil }
]]
function Krok.steg(s, inn, dt, miljo)
	local hendelser = {}
	s.tid += dt
	s.stun = math.max(0, s.stun - dt)
	local pos = miljo.pos
	local hand = miljo.hand or pos

	-- kroken selv
	if s.krok == "ute" then
		s.krokTid += dt
		local andel = math.clamp(s.krokTid / s.krokVarighet, 0, 1)
		s.krokPos = hand:Lerp(s.krokMal, andel)
		if andel >= 1 then
			if s.krokTreff then
				s.krok = "fest"
				s.anker = s.krokMal
				s.lengde = (pos - s.anker).Magnitude
				s.bevegelse = "hekta"
				table.insert(hendelser, { "fest" })
				if miljo.bakke then
					s.settFart = Vector3.new(miljo.v.X, math.max(miljo.v.Y, 0) + K.STARTHOPP, miljo.v.Z)
				end
			else
				s.krok = "tilbake"
				s.returTid = 0
				s.krokFra = s.krokMal
				table.insert(hendelser, { "bom" })
			end
		end
	elseif s.krok == "fest" then
		if miljo.anker then
			s.anker = miljo.anker
		end
		s.krokPos = s.anker
	elseif s.krok == "tilbake" then
		s.returTid += dt
		local varighet = 0.16
		local andel = math.clamp(s.returTid / varighet, 0, 1)
		s.krokPos = (s.krokFra or hand):Lerp(hand, andel)
		if andel >= 1 then
			s.krok = "inne"
			s.krokPos = nil
		end
	end

	-- bevegelsen
	local v = miljo.v
	if s.settFart then
		v = s.settFart
		s.settFart = nil
	end
	if s.bevegelse == "hekta" then
		if s.krok ~= "fest" then
			s.bevegelse = "flyr"
			s.flyTid = 0
		else
			local r = pos - s.anker
			local avstand = r.Magnitude
			if avstand > 1e-3 then
				local n = r / avstand
				s.lengde = math.max(K.MIN_LENGDE, math.min(s.lengde, avstand) - K.INNTREKK * dt)
				-- dra mot festet
				local trekk = K.TREKK + (inn.trekk and K.TREKK_EKSTRA or 0)
				v -= n * (trekk * dt)
				-- pump svingen med WASD (bare på tvers av tauet)
				local sving = inn.sving
				if sving and sving.Magnitude > 0.01 then
					local tvers = sving - n * sving:Dot(n)
					v += tvers * (K.SVING_KRAFT * dt)
				end
				-- tauet er stramt: ingen fart utover, og trekk inn igjen hvis vi er for langt ute
				local ut = v:Dot(n) -- positiv = utover
				if avstand > s.lengde then
					local innover = math.min((avstand - s.lengde) * 10, K.MAKS_INNTREKK)
					if ut > -innover then
						v -= n * (ut + innover)
						ut = -innover
					end
				end
				-- ikke raskere innover enn taket (resten av farten er sving på tvers)
				local tak = K.MAKS_INNTREKK * (inn.trekk and 1.5 or 1.15)
				if ut < -tak then
					v -= n * (ut + tak)
				end
				-- kort tau: demp farten på tvers litt, så du ikke spinner rundt festet som en snurrebass
				if s.lengde < 22 then
					local tvers = v - n * v:Dot(n)
					v -= tvers * (1 - math.exp(-1.6 * dt))
				end
				-- helt inne ved festet: heng der
				if avstand <= K.MIN_LENGDE + 1.5 then
					v *= math.exp(-5 * dt)
				end
			end
			if v.Magnitude > K.MAKS_FART then
				v = v.Unit * K.MAKS_FART
			end
			return { v = v, hendelser = hendelser, krokPos = s.krokPos }
		end
	end
	if s.bevegelse == "flyr" then
		s.flyTid += dt
		if s.slippBoost then
			v = v * K.SLIPP_BOOST + OPP * K.SLIPP_OPP
			s.slippBoost = false
		end
		local sving = inn.sving
		if sving and sving.Magnitude > 0.01 then
			v += flat(sving).Unit * (K.LUFTSTYRING * dt)
		end
		v *= (1 - K.LUFTMOTSTAND * dt)
		if v.Magnitude > K.MAKS_FART then
			v = v.Unit * K.MAKS_FART
		end
		if miljo.bakke and v.Y <= 2 and s.flyTid > 0.12 then
			s.bevegelse = "bakke"
			table.insert(hendelser, { "landing", math.clamp(-miljo.v.Y / 120, 0, 1) })
			return { v = nil, hendelser = hendelser, krokPos = s.krokPos }
		end
		return { v = v, hendelser = hendelser, krokPos = s.krokPos }
	end
	return { v = nil, hendelser = hendelser, krokPos = s.krokPos }
end

return Krok
