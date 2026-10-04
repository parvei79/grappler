-- GRAPPLER — klienten starter her og kobler sammen kamera, krok, tau, effekter og HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kamera = require(script.Parent:WaitForChild("Kamera"))
local Grappler = require(script.Parent:WaitForChild("Grappler"))
local Tau = require(script.Parent:WaitForChild("Tau"))
local Effekter = require(script.Parent:WaitForChild("Effekter"))
local HUD = require(script.Parent:WaitForChild("HUD"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

Grappler.hendelser = function(liste)
	Effekter.egen(liste)
end

Kamera.start()
Grappler.start()
Tau.start(Grappler, remotes)
Effekter.start(Grappler, Kamera, remotes)
HUD.start(Grappler, remotes)
