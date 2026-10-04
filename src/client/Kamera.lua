-- Skulderkamera: musa styrer blikket (låst i midten, siktet er midt på skjermen), figuren snur seg
-- etter kameraet, synsfeltet vider seg ut i høy fart, og kameraet rister når du blir truffet.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kamera = {}

local spiller = Players.LocalPlayer
local kamera = workspace.CurrentCamera
local yaw, pitch = 0, -0.12
local rist = 0
local FOLSOMHET = 0.0032
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local glattPos = nil

function Kamera.rist(styrke)
	rist = math.max(rist, styrke)
end

function Kamera.retning()
	return yaw, pitch
end

-- Pek kameraet i en retning (brukes av testene og kan brukes til å sikte automatisk).
function Kamera.settRetning(retning)
	yaw = math.atan2(-retning.X, -retning.Z)
	pitch = math.asin(math.clamp(retning.Y, -1, 1))
end

local function steg(dt)
	local figur = spiller.Character
	local rot = figur and figur:FindFirstChild("HumanoidRootPart")
	local hum = figur and figur:FindFirstChildOfClass("Humanoid")
	kamera.CameraType = Enum.CameraType.Scriptable
	if not rot or not hum then
		return
	end
	if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
	local rotasjon = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local fokus = rot.Position + Vector3.new(0, 2.2, 0)
	local onsket = fokus + rotasjon * Vector3.new(2.6, 0.8, 12.5)
	-- ikke gjennom vegger og øyer
	params.FilterDescendantsInstances = { figur, workspace:FindFirstChild("KrokEffekter") }
	local res = workspace:Raycast(fokus, onsket - fokus, params)
	local pos = res and (res.Position + (fokus - res.Position).Unit * 0.8) or onsket
	glattPos = glattPos and glattPos:Lerp(pos, 1 - math.exp(-dt * 25)) or pos
	if (glattPos - pos).Magnitude > 20 then
		glattPos = pos
	end
	local p = glattPos
	if rist > 0.01 then
		p += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * rist * 1.8
		rist = math.max(0, rist - dt * 3)
	end
	kamera.CFrame = CFrame.new(p) * rotasjon
	-- synsfelt etter fart
	local fart = rot.AssemblyLinearVelocity.Magnitude
	local fov = 70 + math.clamp((fart - 35) / 140, 0, 1) * 20
	kamera.FieldOfView += (fov - kamera.FieldOfView) * math.min(1, dt * 6)
	-- figuren ser dit kameraet ser
	hum.AutoRotate = false
	local m = rot.CFrame
	local mal = CFrame.new(m.Position) * CFrame.Angles(0, yaw, 0)
	rot.CFrame = m:Lerp(mal, math.min(1, dt * 18))
end

function Kamera.start()
	UserInputService.InputChanged:Connect(function(input, behandlet)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * FOLSOMHET
			pitch = math.clamp(pitch - input.Delta.Y * FOLSOMHET, -1.35, 1.25)
		elseif input.UserInputType == Enum.UserInputType.Touch and not behandlet then
			-- mobil: dra på høyre halvdel av skjermen for å se rundt
			if input.Position.X > kamera.ViewportSize.X * 0.4 then
				yaw -= input.Delta.X * FOLSOMHET * 1.6
				pitch = math.clamp(pitch - input.Delta.Y * FOLSOMHET * 1.6, -1.35, 1.25)
			end
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			Kamera.spak = input.Position
		end
	end)
	RunService:BindToRenderStep("GrapplerKamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if Kamera.spak and Kamera.spak.Magnitude > 0.15 then
			yaw -= Kamera.spak.X * dt * 3
			pitch = math.clamp(pitch + Kamera.spak.Y * dt * 2.2, -1.35, 1.25)
		end
		steg(dt)
	end)
end

return Kamera
