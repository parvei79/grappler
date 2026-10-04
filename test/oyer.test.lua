-- Øyene sett ovenfra (topphøyde og tema) og fra siden, som DATA for tools/vis_oyer.py.
-- Sjekker også avstander: hver øy skal kunne nås fra minst én annen med kroken.
local Oyer = krev("shared/Oyer")
local Config = krev("shared/Config")
local STEG = 4
for _, oy in Oyer.LISTE do
	local n, min, maks, bunn = 0, math.huge, -math.huge, math.huge
	for x = oy.x - oy.r * 1.3, oy.x + oy.r * 1.3, STEG do
		for z = oy.z - oy.r * 1.3, oy.z + oy.r * 1.3, STEG do
			local t, b = Oyer.form(oy, x, z)
			if t then
				n += 1
				min, maks, bunn = math.min(min, t), math.max(maks, t), math.min(bunn, b)
				print(string.format('DATA:{"k":"c","x":%.0f,"z":%.0f,"t":%.1f,"b":%.1f,"tema":"%s"}', x, z, t, b, oy.tema))
			end
		end
	end
	print(string.format("%-15s areal %5d m², topp %.0f–%.0f, bunn %.0f", oy.navn, n * STEG * STEG, min, maks, bunn))
end
for _, s in Oyer.STEINER do
	for x = s.x - s.r * 1.3, s.x + s.r * 1.3, STEG do
		for z = s.z - s.r * 1.3, s.z + s.r * 1.3, STEG do
			local t, b = Oyer.steinForm(s, x, z)
			if t then
				print(string.format('DATA:{"k":"c","x":%.0f,"z":%.0f,"t":%.1f,"b":%.1f,"tema":"stein"}', x, z, t, b))
			end
		end
	end
end
for _, bro in Oyer.BROER do
	local a, b = Oyer.broPunkter(bro)
	print(string.format("Bro %s–%s: %.0f studs", bro[1], bro[2], (b - a).Magnitude))
	print(string.format('DATA:{"k":"bro","ax":%.0f,"az":%.0f,"ay":%.0f,"bx":%.0f,"bz":%.0f,"by":%.0f}', a.X, a.Z, a.Y, b.X, b.Z, b.Y))
end
-- nærmeste nabo (kant til kant) for hver øy, med steiner som mellomstopp
local R = Config.KROK.REKKEVIDDE
for _, oy in Oyer.LISTE do
	local best, navn = math.huge, ""
	for _, annen in Oyer.LISTE do
		if annen ~= oy then
			local d = math.sqrt((oy.x - annen.x) ^ 2 + (oy.z - annen.z) ^ 2 + (oy.topp - annen.topp) ^ 2) - oy.r - annen.r
			if d < best then
				best, navn = d, annen.navn
			end
		end
	end
	print(string.format("  %-15s nærmeste øy %-15s %4.0f studs kant-til-kant %s", oy.navn, navn, best, best < R * 0.8 and "" or "  <-- LANGT"))
end
