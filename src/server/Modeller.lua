-- Henter 3D-modellene fra Blender (importert i Studio som «KartModeller»).
-- Mangler de, returnerer hent() nil og resten av koden bygger reserver av klosser,
-- så spillet virker også før modellene er importert.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ModelInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelInfo"))

local Modeller = {}
local mappe = nil
local MAPPENAVN = "GrapplerModeller"

-- En importert modellmappe kjennes igjen på innholdet, ikke bare navnet
-- (Import 3D kan kalle den «Scene» hvis glTF-scenen ikke har fått navn).
local function erModellmappe(m)
	if not m:IsA("Model") and not m:IsA("Folder") then
		return false
	end
	for _, navn in { "KrokPistol", "Krok", "Furu", "Krystall" } do
		local del = m:FindFirstChild(navn, true)
		if del and del:IsA("BasePart") then
			return true
		end
	end
	return false
end

function Modeller.init()
	mappe = ServerStorage:FindFirstChild(MAPPENAVN) or workspace:FindFirstChild(MAPPENAVN)
	if not mappe then
		for _, beholder in { ServerStorage, workspace } do
			for _, m in beholder:GetChildren() do
				if erModellmappe(m) then
					mappe = m
					break
				end
			end
			if mappe then
				break
			end
		end
	end
	if mappe then
		mappe.Name = MAPPENAVN
		if mappe.Parent == workspace then
			mappe.Parent = ServerStorage
		end
		print("[GRAPPLER] Fant 3D-modellene fra Blender.")
	else
		warn("[GRAPPLER] Fant ikke «" .. MAPPENAVN .. "». Bruker reserve-modeller av klosser. "
			.. "Importer assets/GrapplerModeller.glb med Import i Studio for de ekte modellene.")
	end
end

function Modeller.info(navn)
	return ModelInfo[navn]
end

function Modeller.finnes(navn)
	if not mappe or not ModelInfo[navn] then
		return false
	end
	local kilde = mappe:FindFirstChild(navn, true)
	return kilde ~= nil
end

-- Returnerer en ny MeshPart med riktig størrelse (ModelInfo * skala), eller nil.
-- Skalerer jevnt, så det spiller ingen rolle hvilken enhet importen brukte.
function Modeller.hent(navn, skala)
	if not mappe then
		return nil
	end
	local info = ModelInfo[navn]
	local kilde = mappe:FindFirstChild(navn, true)
	if kilde and not kilde:IsA("BasePart") then
		kilde = kilde:FindFirstChildWhichIsA("BasePart", true)
	end
	if not kilde or not info then
		return nil
	end
	local del = kilde:Clone()
	for _, barn in del:GetChildren() do
		if barn:IsA("JointInstance") or barn:IsA("Constraint") or barn:IsA("Attachment") then
			barn:Destroy()
		end
	end
	local mal = info.str * (skala or 1)
	del.Size = del.Size * (mal.Magnitude / del.Size.Magnitude)
	del.Name = navn
	del.Anchored = false
	del.CanCollide = false
	del.CanTouch = false
	del.Massless = true
	return del
end

-- Plasser en modell med origo i `cf`. Forankret, uten kollisjon. Returnerer delen eller nil.
function Modeller.plasser(navn, cf, skala, forelder)
	local del = Modeller.hent(navn, skala)
	if not del then
		return nil
	end
	local info = ModelInfo[navn]
	del.Anchored = true
	del.CanQuery = false
	del.CFrame = cf * CFrame.new(info.midt * (skala or 1))
	del.Parent = forelder
	return del
end

-- Kopier noen modeller til ReplicatedStorage.KlientModeller, så klientene kan lage egne effekter
-- (for eksempel kroken som flyr). Mangler modellene, blir mappen tom og klienten bruker klosser.
function Modeller.delMedKlient(navnListe)
	local ut = Instance.new("Folder")
	ut.Name = "KlientModeller"
	for _, navn in navnListe do
		local del = Modeller.hent(navn, 1)
		if del then
			del.Parent = ut
		end
	end
	ut.Parent = game:GetService("ReplicatedStorage")
end

-- Punkt fra ModelInfo (relativt til origo), skalert. Nil hvis modellen/punktet mangler.
function Modeller.punkt(navn, punkt, skala)
	local info = ModelInfo[navn]
	local p = info and info[punkt]
	return p and p * (skala or 1) or nil
end

return Modeller
