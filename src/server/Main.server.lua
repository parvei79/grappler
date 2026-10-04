-- GRAPPLER — serveren starter her.
-- Bygger de flytende øyene, gir alle en krokpistol, og passer på rykk, flyspark og fall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modeller = require(script.Parent.Modeller)
local Oyterreng = require(script.Parent.Oyterreng)
local Verden = require(script.Parent.Verden)
local Kamp = require(script.Parent.Kamp)

-- remotes først, så klientene finner dem med en gang
local remotes = {}
local remoteMappe = Instance.new("Folder")
remoteMappe.Name = "Remotes"
for _, navn in { "Krok", "Rykk", "Spark", "Knuff", "Hendelse" } do
	local r = Instance.new("RemoteEvent")
	r.Name = navn
	r.Parent = remoteMappe
	remotes[navn] = r
end
remoteMappe.Parent = ReplicatedStorage

-- startpunktene før terrenget, så ingen faller mens øyene bygges
Verden.startpunkter()
Modeller.init()
Modeller.delMedKlient({ "Krok" })
Kamp.init(Modeller, remotes)
Oyterreng.bygg()
Verden.bygg(Modeller)
print("[GRAPPLER] Øyene svever. Sving i vei!")
