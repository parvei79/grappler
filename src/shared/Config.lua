-- Alle tall som styrer hvordan GRAPPLER føles. Juster her, ikke rundt i koden.
local Config = {}

-- ---------------------------------------------------------------- kroken
Config.KROK = {
	REKKEVIDDE = 240,        -- hvor langt kroken når (studs)
	KROKFART = 950,          -- hvor fort kroken flyr ut (studs/s)
	INNTREKK = 62,           -- hvor fort tauet kortes inn mens du henger (studs/s)
	MAKS_INNTREKK = 95,      -- høyeste fart tauet kan dra deg innover med (studs/s)
	MIN_LENGDE = 7,          -- korteste tau
	TREKK = 70,              -- jevnt drag mot festet (studs/s²)
	TREKK_EKSTRA = 170,      -- ekstra drag mens du holder SPACE
	SVING_KRAFT = 48,        -- hvor mye WASD pumper svingen (studs/s²)
	MAKS_FART = 190,
	SLIPP_BOOST = 1.08,      -- litt ekstra fart når du slipper
	SLIPP_OPP = 8,           -- og et lite løft
	LUFTSTYRING = 34,        -- styring i lufta etter slipp (studs/s²)
	LUFTMOTSTAND = 0.12,     -- andel fart som forsvinner per sekund i lufta
	STARTHOPP = 26,          -- løft når kroken drar deg fra bakken
	VENTETID = 0.18,         -- minste tid mellom to skudd
}

-- ---------------------------------------------------------------- slåssing
Config.KAMP = {
	RYKK_KRAFT = 58,         -- fart motstanderen rykkes mot deg med
	RYKK_OPP = 26,
	RYKK_SKADE = 10,
	SPARK_MIN_FART = 62,     -- så fort må du fly for å gi flyspark
	SPARK_AVSTAND = 6.5,
	SPARK_SKADE = 9,
	SKADE_DELER = 90,        -- knuff * (1 + skade / SKADE_DELER)
	STUN = 0.6,              -- sekunder uten krok etter å ha blitt truffet
	SIST_TRUFFET = 8,        -- sekunder: den som traff sist får æren når du faller
}

Config.FALL_GRENSE = -70       -- under denne Y er du falt ned i skyene
Config.RESPAWN_TID = 2.5

-- ---------------------------------------------------------------- lyd (gratis lyder fra Roblox sitt bibliotek)
local function id(n)
	return "rbxassetid://" .. n
end
Config.LYD = {
	skudd = id(9120629100),       -- Web Shoot Short Juicy Launch 1
	fest = id(9119072660),        -- Shield Clang As Hit Metal
	festStein = id(9116677587),   -- Metal Impact Railroad Hammer
	vinsj = id(9116908667),       -- Metal Winch Gears 1 (løkke)
	slipp = id(9126229255),       -- Whoosh By Fast
	vind = id(9125742262),        -- Plasma Trails Constant Airy Whooshing Windy (løkke)
	tausvisj = id(9125419776),    -- Cable Swish
	rykk = id(9113510797),        -- Body Hit Slap 3
	spark = id(9119061631),       -- Sharp Punch 8
	bom = id(9120704978),         -- Whooshes Fast Wipes (kroken bommer)
	fall = "rbxasset://sounds/oof.ogg",
	landing = "rbxasset://sounds/action_jump_land.mp3",
	vindsus = id(9114057104),     -- Desert Wind Whistley Light Gusts 1 (bakgrunn)
}
Config.MUSIKK = {
	id(1839885740), -- Flying So High (APM)
	id(1842755603), -- High Flying (APM)
	id(9047876673), -- Happy Adventure (APM)
}

return Config
