-- ScanByCharacterAndOwnerToF9.lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function getCharacterRoot(plr)
	local char = plr and plr.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function isOwnedByPlayer(model, plr)
	if not model or not plr then return false end
	local lowerName = string.lower(plr.Name)
	local userIdStr = tostring(plr.UserId)

	-- 1. Cek atribut umum kepemilikan
	for _, attrName in ipairs({ "Owner", "Player", "OwnerName", "PlayerName", "Driver" }) do
		local val = model:GetAttribute(attrName)
		if val ~= nil then
			local s = string.lower(tostring(val))
			if s == lowerName or string.find(s, lowerName, 1, true) then
				return true
			end
		end
	end
	local uidAttr = model:GetAttribute("UserId") or model:GetAttribute("OwnerId") or model:GetAttribute("PlayerId")
	if uidAttr ~= nil and tostring(uidAttr) == userIdStr then
		return true
	end

	-- 2. Cek ValueBase (StringValue / ObjectValue / IntValue / NumberValue) di dalam model
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("StringValue") and (obj.Name == "Owner" or obj.Name == "Player" or obj.Name == "Driver") then
			local s = string.lower(obj.Value)
			if s == lowerName or string.find(s, lowerName, 1, true) then
				return true
			end
		elseif obj:IsA("ObjectValue") and (obj.Name == "Owner" or obj.Name == "Player" or obj.Name == "Driver") then
			if obj.Value == plr or (plr.Character and obj.Value == plr.Character) then
				return true
			end
		elseif (obj:IsA("IntValue") or obj:IsA("NumberValue")) and (obj.Name == "UserId" or obj.Name == "OwnerId") then
			if tostring(obj.Value) == userIdStr then
				return true
			end
		elseif obj:IsA("VehicleSeat") or obj:IsA("Seat") then
			if plr.Character and obj.Occupant and obj.Occupant:IsDescendantOf(plr.Character) then
				return true
			end
		end
	end

	-- 3. Cek format nama umum "<Player>'s Car" atau memuat nama player
	if model.Name == plr.Name .. "'s Car" or string.find(string.lower(model.Name), lowerName, 1, true) then
		return true
	end

	return false
end

local function findMyVehicleFromCharacter(plr)
	local vehicles = workspace:FindFirstChild("Vehicles")
	if not vehicles then
		warn("[CharDMX] workspace.Vehicles tidak ada.")
		return nil
	end

	local root = getCharacterRoot(plr)
	if not root then
		warn("[CharDMX] Character / HumanoidRootPart belum siap.")
	end

	-- Cari kendaraan yang cocok pemiliknya
	for _, veh in ipairs(vehicles:GetChildren()) do
		if veh:IsA("Model") and isOwnedByPlayer(veh, plr) then
			return veh
		end
	end

	-- Fallback: kalau tidak ada penanda nama/owner, ambil model terdekat dengan karakter kita
	if root then
		local closestVeh = nil
		local bestDist = math.huge
		for _, veh in ipairs(vehicles:GetChildren()) do
			if veh:IsA("Model") then
				local pivotPos = veh:GetPivot().Position
				local dist = (pivotPos - root.Position).Magnitude
				if dist < bestDist and dist <= 60 then
					bestDist = dist
					closestVeh = veh
				end
			end
		end
		if closestVeh then
			return closestVeh
		end
	end

	return nil
end

local function runCharDmxScan()
	local char = player.Character or player.CharacterAdded:Wait()
	local root = getCharacterRoot(player)
	local myVeh = findMyVehicleFromCharacter(player)

	print("==========================================")
	print("[CharDMX] Player :", player.Name)
	print("[CharDMX] Char   :", char and char.Name or "None")
	print("[CharDMX] Pos    :", root and tostring(Vector3.new(math.round(root.Position.X), math.round(root.Position.Y), math.round(root.Position.Z))) or "NoRoot")

	if not myVeh then
		warn("[CharDMX] Kendaraan milik sendiri tidak ditemukan.")
		print("==========================================")
		return
	end

	print("[CharDMX] Matched Vehicle:", myVeh:GetFullName())

	local dmxFolder = (myVeh:FindFirstChild("Folder") and myVeh.Folder:FindFirstChild("DmxLights"))
		or myVeh:FindFirstChild("DmxLights", true)

	if not dmxFolder then
		warn("[CharDMX] DmxLights tidak ditemukan di kendaraan:", myVeh.Name)
		print("==========================================")
		return
	end

	local items = dmxFolder:GetChildren()
	local summary = {}

	print("[CharDMX] DmxPath:", dmxFolder:GetFullName())
	print("[CharDMX] Total direct children:", #items)
	print("------------------------------------------")

	for i, item in ipairs(items) do
		print(string.format("  [%d] %s (%s)", i, item.Name, item.ClassName))
		summary[item.Name] = (summary[item.Name] or 0) + 1
	end

	print("------------------------------------------")
	print("[CharDMX] Ringkasan fixture kendaraan sendiri:")
	for name, total in pairs(summary) do
		print(string.format("  * %s : %d", name, total))
	end
	print("==========================================")
end

runCharDmxScan()
