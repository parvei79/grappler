-- Skjermbildet: sikte midt på skjermen (grønt når kroken når fram, rødt mot motstandere),
-- avstand, fart, skade-prosent, hjelpetekst, meldinger og musikk.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local HUD = {}

local spiller = Players.LocalPlayer
local Grappler

local skjerm = Instance.new("ScreenGui")
skjerm.Name = "GrapplerHUD"
skjerm.ResetOnSpawn = false
skjerm.IgnoreGuiInset = true

local function tekst(e)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.TextScaled = true
	for k, v in e do
		t[k] = v
	end
	return t
end

local function ramme(e)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in e do
		f[k] = v
	end
	return f
end

local function rund(f)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

-- siktet
local sikte = ramme({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1, Parent = skjerm })
local ring = Instance.new("UIStroke")
ring.Thickness = 2.5
ring.Color = Color3.new(1, 1, 1)
local ringRamme = ramme({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = sikte })
rund(ringRamme)
ring.Parent = ringRamme
local prikk = ramme({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = Color3.new(1, 1, 1), Parent = sikte })
rund(prikk)
local avstand = tekst({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 24), Size = UDim2.fromOffset(120, 20),
	Text = "", Parent = skjerm })

local fartTekst = tekst({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.fromOffset(240, 48),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = skjerm })
local skadeTekst = tekst({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -70), Size = UDim2.fromOffset(240, 40),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "0%", Parent = skjerm })
local hjelp = tekst({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(900, 26),
	Text = "HOLD VENSTRE MUS: skyt kroken  •  SLIPP: fly videre  •  WASD: sving  •  SPACE: trekk raskere  •  Fly inn i folk = FLYSPARK!",
	Parent = skjerm })
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	hjelp.Text = "Hold KROK for å skyte og henge  •  Slipp for å fly  •  Dra på høyre side for å se rundt"
end

local strom = ramme({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(640, 120),
	BackgroundTransparency = 1, Parent = skjerm })
local liste = Instance.new("UIListLayout")
liste.HorizontalAlignment = Enum.HorizontalAlignment.Center
liste.SortOrder = Enum.SortOrder.LayoutOrder
liste.Parent = strom
local nr = 0
function HUD.melding(t)
	nr += 1
	local m = tekst({ Size = UDim2.fromOffset(640, 26), Text = t, LayoutOrder = nr, Parent = strom })
	task.delay(5, function()
		if m.Parent then
			TweenService:Create(m, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			Debris:AddItem(m, 0.7)
		end
	end)
end

local GRONN = Color3.fromRGB(90, 255, 120)
local ROD = Color3.fromRGB(255, 70, 60)
local GRA = Color3.fromRGB(200, 200, 200)

local function oppdater()
	local sikt = Grappler.sikt()
	local s = Grappler.tilstand()
	local farge = GRA
	if sikt and sikt.treff and sikt.innenfor then
		farge = sikt.motstander and ROD or GRONN
	end
	ring.Color = farge
	prikk.BackgroundColor3 = farge
	sikte.Size = s.krok == "fest" and UDim2.fromOffset(24, 24) or UDim2.fromOffset(34, 34)
	if sikt and sikt.treff then
		avstand.Text = sikt.innenfor and string.format("%d", math.floor(sikt.avstand)) or "for langt"
		avstand.TextColor3 = farge
	else
		avstand.Text = ""
	end
	local figur = Grappler.figur()
	local rot = figur and figur:FindFirstChild("HumanoidRootPart")
	if rot then
		fartTekst.Text = string.format("%d studs/s", math.floor(rot.AssemblyLinearVelocity.Magnitude))
		local skade = figur:GetAttribute("Skade") or 0
		skadeTekst.Text = "SKADE " .. skade .. "%"
		local a = math.clamp(skade / 120, 0, 1)
		skadeTekst.TextColor3 = Color3.new(1, 1, 1):Lerp(ROD, a)
	end
end

function HUD.start(grappler, remotes)
	Grappler = grappler
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	skjerm.Parent = spiller:WaitForChild("PlayerGui")
	remotes.Hendelse.OnClientEvent:Connect(function(type_, a)
		if type_ == "melding" then
			HUD.melding(a)
		end
	end)
	task.delay(30, function()
		TweenService:Create(hjelp, TweenInfo.new(2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	RunService.RenderStepped:Connect(oppdater)

	-- musikk
	local musikk = Instance.new("Sound")
	musikk.Volume = 0.2
	musikk.Parent = workspace.CurrentCamera
	local n = 0
	local function neste()
		n = n % #Config.MUSIKK + 1
		musikk.SoundId = Config.MUSIKK[n]
		musikk.TimePosition = 0
		musikk:Play()
	end
	musikk.Ended:Connect(neste)
	neste()
end

return HUD
