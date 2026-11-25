-- DmxConsoleUI_CanvaLayout.lua (360x465)
-- Layout sesuai desain Canva: Multi-select Channel 1..12, page 1 / next page >, Pan / Tilt, number°, & Fader Geser

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local MAX_CHANNELS = 512
local DEFAULT_MAX_UNIVERSES = 2

-- ============================================================================
-- PATCH ENGINE
-- ============================================================================
local PatchEngine = {}
do
	local mod = ReplicatedStorage:FindFirstChild("PatchEngine")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" and type(res.PatchAll) == "function" then
			PatchEngine = res
		end
	end
end

if not PatchEngine.Profiles then
	local BarWashProfile = {
		Group = "BarWash", Span = 8, Dimmer = 0, Shutter = 1, Red = 2, Green = 3, Blue = 4, Effect = 5, Speed = 7,
	}
	local ClaraS14Profile = {
		Group = "MovingBeam", Span = 16, X = 0, Y = 1, Shutter = 6, Dimmer = 7, Effect = 11, Speed = 14,
	}
	PatchEngine.Profiles = {
		["ClaraS14"] = ClaraS14Profile,
		["Wallwasher_24X3W"] = BarWashProfile,
		["StrobeBar_192_Segment"] = BarWashProfile,
		["STROBE_1000W"] = { Group = "Strobe1000W", Span = 8, Dimmer = 0, Shutter = 1, Red = 2, Green = 3, Blue = 4, Effect = 5, Speed = 7 },
		["Parled"] = { Group = "Parled", Span = 6, Dimmer = 0, Red = 1, Green = 2, Blue = 3, White = 4, Shutter = 5 },
		["BlinderRing_2x50W"] = { Group = "Blinder", Span = 12, Dimmer = 0, Shutter = 1, Pod1Mode = 2, Pod2Mode = 3, AmberDim = 4, BacklightDim = 5, RingDim = 6, Red = 7, Green = 8, Blue = 9, Effect = 10, Speed = 11 },
		["Blinder"] = { Group = "Blinder", Span = 8, Dimmer = 0, LED1 = 0, LED2 = 1, LED3 = 2, LED4 = 3 },
		["Fogger"] = { Group = "Fogger", Span = 16, X = 0, Dimmer = 2, Shutter = 4, Red = 5, Green = 8, Blue = 9, Effect = 12 },
		["Flower"] = { Group = "Flower", Span = 18, Dimmer = 0, Red = 1, Green = 2, Blue = 3, Effect = 4, Speed = 5, Shutter = 16 },
		["Miniled"] = { Group = "MiniLed", Span = 1, Dimmer = 0 },
		["Pixelbeambar"] = { Group = "PixelBar", Span = 20, Y = 0, Speed = 2, Effect = 3, Dimmer = 5, Shutter = 6, Red = 8, Green = 9, Blue = 10 },
		["Retrohex"] = { Group = "RetroHex", Span = 11, Dimmer = 0, Shutter = 3, Effect = 4, Red = 6, Green = 7, Blue = 8 },
		["Windmill"] = { Group = "Windmill", Span = 8, Dimmer = 0, Shutter = 1, Speed = 2, Effect = 3, Red = 5, Green = 6, Blue = 7 },
	}
end

local NameAliases = {
	["ClaraS14"] = { "claras14", "clara_s14", "clara s14" },
	["STROBE_1000W"] = { "strobe_1000w", "strobe1000", "strobo_1000w", "strobe 1000w" },
	["Wallwasher_24X3W"] = { "wallwasher_24x3w", "wallwasher", "wall washer" },
	["StrobeBar_192_Segment"] = { "strobebar_192_segment", "strobebar", "strobe bar" },
	["BlinderRing_2x50W"] = { "blinderring_2x50w", "blinderring", "blinder ring" },
	["Pixelbeambar"] = { "pixelbeambar", "pixelbar", "pixel beam bar" },
}

local function matchesAnyKey(itemName, keys)
	local lowerName = string.lower(tostring(itemName or ""))
	for _, k in ipairs(keys) do
		local keyLower = string.lower(tostring(k or ""))
		if keyLower ~= "" and (lowerName == keyLower or string.find(lowerName, keyLower, 1, true)) then
			return true
		end
	end
	return false
end

local function toAbsChannel(address, offset0, maxChannels)
	if type(address) ~= "number" or type(offset0) ~= "number" then return nil end
	if offset0 < 0 or offset0 >= (maxChannels or MAX_CHANNELS) then return nil end
	local ch = math.floor(address + offset0)
	return (ch >= 1 and ch <= MAX_CHANNELS) and ch or nil
end

if type(PatchEngine.AutoAddress) ~= "function" then
	function PatchEngine.AutoAddress(fixtures, maxUniverses)
		local limitUniv = maxUniverses or DEFAULT_MAX_UNIVERSES
		local cursors = {}
		for u = 1, limitUniv do cursors[u] = 1 end
		local overflow = {}
		for _, fix in ipairs(fixtures or {}) do
			local univ = math.clamp(math.floor(fix.Universe or 1), 1, limitUniv)
			fix.Universe = univ
			local prof = PatchEngine.Profiles[fix.Type]
			local span = (prof and prof.Span) or 8
			fix.Span = span
			if cursors[univ] + span - 1 <= MAX_CHANNELS then
				fix.Address = cursors[univ]
				cursors[univ] = fix.Address + span
				fix.Overflow = false
			else
				fix.Overflow = true
				table.insert(overflow, fix)
			end
		end
		return fixtures, overflow
	end
end

if type(PatchEngine.PatchAll) ~= "function" then
	function PatchEngine.PatchAll(fixtures, universeFilter, autoAddress, maxUniverses)
		local overflow = {}
		if autoAddress then
			_, overflow = PatchEngine.AutoAddress(fixtures, maxUniverses or DEFAULT_MAX_UNIVERSES)
		end
		local patched = {}
		for _, fix in ipairs(fixtures or {}) do
			if not fix.Overflow and (not universeFilter or (fix.Universe or 1) == universeFilter) then
				local prof = PatchEngine.Profiles[fix.Type] or {}
				local span = prof.Span or 8
				local addr = fix.Address or 1
				table.insert(patched, {
					Address = addr,
					EndAddress = math.min(MAX_CHANNELS, addr + span - 1),
					Span = span,
					Universe = fix.Universe or 1,
					Type = fix.Type,
					Channels = {
						X = toAbsChannel(addr, prof.X, span),
						Y = toAbsChannel(addr, prof.Y, span),
						Shutter = toAbsChannel(addr, prof.Shutter, span),
						Dimmer = toAbsChannel(addr, prof.Dimmer or 0, span),
						Red = toAbsChannel(addr, prof.Red, span),
						Green = toAbsChannel(addr, prof.Green, span),
						Blue = toAbsChannel(addr, prof.Blue, span),
					},
				})
			end
		end
		return patched, overflow
	end
end

if type(PatchEngine.GetFixtureAtChannel) ~= "function" then
	function PatchEngine.GetFixtureAtChannel(patchedList, channel, universeFilter)
		local target = tonumber(channel)
		if not target then return nil end
		for _, item in ipairs(patchedList or {}) do
			if not universeFilter or item.Universe == universeFilter then
				if target >= (item.Address or 1) and target <= (item.EndAddress or item.Address or 1) then
					return item
				end
			end
		end
		return nil
	end
end

-- ============================================================================
-- TRANSPORT BUFFER 3-BYTE -> carModel.Data
-- ============================================================================
local function getOwnCarModel(plr)
	local vehicles = workspace:FindFirstChild("Vehicles")
	if not vehicles or not plr then return nil end
	local exact = vehicles:FindFirstChild(plr.Name .. "'s Car")
	if exact then return exact end
	local lp = string.lower(plr.Name)
	for _, c in ipairs(vehicles:GetChildren()) do
		if string.find(string.lower(c.Name), lp, 1, true) then
			return c
		end
	end
	return nil
end

local DmxTransport = {}
DmxTransport.__index = DmxTransport

function DmxTransport.new(plr)
	local self = setmetatable({}, DmxTransport)
	self.Player = plr
	self.DataRemote = nil
	self.LastValues = {}
	self:_bind()
	return self
end

function DmxTransport:_attach(carModel)
	if not carModel or carModel ~= getOwnCarModel(self.Player) then return end
	task.spawn(function()
		local remote = carModel:WaitForChild("Data", 30)
		if remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
			self.DataRemote = remote
		end
	end)
end

function DmxTransport:_bind()
	local vehicles = workspace:FindFirstChild("Vehicles")
	if not vehicles then return end
	for _, child in ipairs(vehicles:GetChildren()) do
		self:_attach(child)
	end
	vehicles.ChildAdded:Connect(function(child)
		self:_attach(child)
	end)
end

function DmxTransport:SendChannel(ch, dmxVal, force)
	local channel = math.clamp(math.floor(tonumber(ch) or 1), 1, MAX_CHANNELS)
	local val = math.clamp(math.floor(tonumber(dmxVal) or 0), 0, 255)
	if not force and self.LastValues[channel] == val then
		return true
	end
	self.LastValues[channel] = val
	if not self.DataRemote then
		return false
	end
	local buf = buffer.create(3)
	buffer.writeu16(buf, 0, channel)
	buffer.writeu8(buf, 2, val)
	self.DataRemote:FireServer(buf)
	return true
end

local transport = DmxTransport.new(player)

-- ============================================================================
-- UI SESUAI DESAIN CANVA (360x465)
-- ============================================================================
local parentTarget = player:WaitForChild("PlayerGui")
pcall(function()
	if gethui then parentTarget = gethui() end
end)
local oldGui = parentTarget:FindFirstChild("DmxConsoleCanvaGui")
if oldGui then oldGui:Destroy() end

local fixtureNames = {}
do
	local seen = {}
	for name, prof in pairs(PatchEngine.Profiles or {}) do
		if type(prof) == "table" and not seen[prof] then
			seen[prof] = true
			table.insert(fixtureNames, name)
		end
	end
	table.sort(fixtureNames, function(a, b)
		if a == "ClaraS14" then return true end
		if b == "ClaraS14" then return false end
		return a < b
	end)
end

local state = {
	activeTab = "patch", -- "patch", "Preferensi", "main", "Setting"
	page = 1,
	slotsPerPage = 12,
	universe = 1,
	fixtureIndex = 1,
	selectedChannels = { [1] = true, [2] = true }, -- multi-select channel (seperti 1 & 2 di screenshot)
	axisMode = "Pan", -- "Pan" (role X) atau "Tilt" (role Y)
	axisValue = 0, -- nilai 0..255 (ditampilkan sebagai derajat / nilai)
	rawByUniv = { [1] = {}, [2] = {} },
	patchedByUniv = { [1] = {}, [2] = {} },
	nextAddress = 1,
	autoOpenGate = true,
}

local function getSelectedFixtureName()
	return fixtureNames[state.fixtureIndex] or "ClaraS14"
end

local function getSelectedChannelList()
	local list = {}
	for ch, isSel in pairs(state.selectedChannels) do
		if isSel then
			table.insert(list, ch)
		end
	end
	table.sort(list)
	return list
end

local function applyAxisToSelectedChannels(dmxVal)
	local clamped = math.clamp(math.floor(dmxVal), 0, 255)
	state.axisValue = clamped

	local patched = state.patchedByUniv[state.universe] or {}
	local role = (state.axisMode == "Pan") and "X" or "Y"
	local targets = {}

	-- Jika ada fixture ter-patch di channel terpilih, arahkan ke channel role X/Y fixture tersebut;
	-- jika belum ter-patch, kirim langsung ke nomor channel yang dipilih.
	local seenCh = {}
	for ch in pairs(state.selectedChannels) do
		local fix = PatchEngine.GetFixtureAtChannel(patched, ch, state.universe)
		local roleCh = fix and fix.Channels and fix.Channels[role]
		local finalCh = roleCh or ch
		if not seenCh[finalCh] then
			seenCh[finalCh] = true
			table.insert(targets, finalCh)
		end

		if state.autoOpenGate and fix and fix.Channels then
			if fix.Channels.Dimmer then
				transport:SendChannel(fix.Channels.Dimmer, 255, true)
			end
			if fix.Channels.Shutter then
				transport:SendChannel(fix.Channels.Shutter, 255, true)
			end
		end
	end

	for _, targetCh in ipairs(targets) do
		transport:SendChannel(targetCh, clamped, true)
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxConsoleCanvaGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = parentTarget

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.fromOffset(360, 465)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -232.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(64, 65, 68)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 18)

-- Top Bar (— dan × + Drag)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 44)
topBar.BackgroundTransparency = 1
topBar.Active = true
topBar.Parent = mainFrame

do
	local dragging = false
	local dragInput = nil
	local dragStart = Vector2.zero
	local startPos = UDim2.new()

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = mainFrame.Position
			dragInput = input
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	topBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(34, 28)
minBtn.Position = UDim2.new(1, -86, 0, 8)
minBtn.BackgroundTransparency = 1
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(235, 236, 240)
minBtn.TextSize = 20
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(34, 28)
closeBtn.Position = UDim2.new(1, -44, 0, 8)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(235, 236, 240)
closeBtn.TextSize = 24
closeBtn.Font = Enum.Font.Gotham
closeBtn.Parent = topBar

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, -24, 0, 1)
topLine.Position = UDim2.fromOffset(12, 44)
topLine.BackgroundColor3 = Color3.fromRGB(165, 166, 170)
topLine.BorderSizePixel = 0
topLine.Parent = mainFrame

-- 4 Tab: patch | Preferensi | main | Setting
local tabNames = { "patch", "Preferensi", "main", "Setting" }
local tabButtons = {}
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, -24, 0, 28)
tabContainer.Position = UDim2.fromOffset(12, 54)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabContainer

-- Area Konten Utama
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -24, 1, -94)
contentFrame.Position = UDim2.fromOffset(12, 90)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Grid Channel 1..12 (2 baris x 6 kolom) di bagian atas (bisa multi-select)
local gridHolder = Instance.new("Frame")
gridHolder.Size = UDim2.new(1, 0, 0, 92)
gridHolder.Position = UDim2.fromOffset(0, 2)
gridHolder.BackgroundTransparency = 1
gridHolder.Parent = contentFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(50, 41)
gridLayout.CellPadding = UDim2.fromOffset(5.2, 6)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridHolder

local channelSlots = {}
for slotIdx = 1, 12 do
	local btn = Instance.new("TextButton")
	btn.Name = "Slot_" .. slotIdx
	btn.LayoutOrder = slotIdx
	btn.Text = tostring(slotIdx)
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = gridHolder
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(36, 36, 38)
	stroke.Thickness = 1.5

	btn.MouseButton1Click:Connect(function()
		local chNum = tonumber(btn.Text)
		if not chNum then return end
		state.selectedChannels[chNum] = not state.selectedChannels[chNum]
		refreshAll()
	end)

	channelSlots[slotIdx] = btn
end

-- Baris "page 1" dan "next page >"
local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.fromOffset(100, 20)
pageLabel.Position = UDim2.fromOffset(0, 102)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "page 1"
pageLabel.TextXAlignment = Enum.TextXAlignment.Left
pageLabel.TextColor3 = Color3.fromRGB(225, 226, 230)
pageLabel.TextSize = 13
pageLabel.Font = Enum.Font.Gotham
pageLabel.Parent = contentFrame

local nextPageBtn = Instance.new("TextButton")
nextPageBtn.Size = UDim2.fromOffset(100, 20)
nextPageBtn.Position = UDim2.new(1, -100, 0, 102)
nextPageBtn.BackgroundTransparency = 1
nextPageBtn.Text = "next page >"
nextPageBtn.TextXAlignment = Enum.TextXAlignment.Right
nextPageBtn.TextColor3 = Color3.fromRGB(225, 226, 230)
nextPageBtn.TextSize = 13
nextPageBtn.Font = Enum.Font.Gotham
nextPageBtn.Parent = contentFrame

-- Baris Pan | Tilt | number° + Fader Geser (muncul di bawah page 1 sesuai desain Canva)
local panBtn = Instance.new("TextButton")
panBtn.Size = UDim2.fromOffset(108, 28)
panBtn.Position = UDim2.fromOffset(0, 130)
panBtn.Text = "Pan"
panBtn.TextSize = 13
panBtn.Font = Enum.Font.GothamMedium
panBtn.BorderSizePixel = 0
panBtn.Parent = contentFrame
Instance.new("UICorner", panBtn).CornerRadius = UDim.new(0, 6)

local tiltBtn = Instance.new("TextButton")
tiltBtn.Size = UDim2.fromOffset(108, 28)
tiltBtn.Position = UDim2.fromOffset(116, 130)
tiltBtn.Text = "Tilt"
tiltBtn.TextSize = 13
tiltBtn.Font = Enum.Font.GothamMedium
tiltBtn.BorderSizePixel = 0
tiltBtn.Parent = contentFrame
Instance.new("UICorner", tiltBtn).CornerRadius = UDim.new(0, 6)

local numberDegLabel = Instance.new("TextLabel")
numberDegLabel.Size = UDim2.fromOffset(96, 26)
numberDegLabel.Position = UDim2.new(1, -96, 0, 131)
numberDegLabel.BackgroundColor3 = Color3.fromRGB(115, 116, 120)
numberDegLabel.Text = "number°"
numberDegLabel.TextColor3 = Color3.fromRGB(32, 32, 34)
numberDegLabel.TextSize = 12
numberDegLabel.Font = Enum.Font.GothamMedium
numberDegLabel.BorderSizePixel = 0
numberDegLabel.Parent = contentFrame
Instance.new("UICorner", numberDegLabel).CornerRadius = UDim.new(0, 4)

-- Fader Horizontal (Track + Thumb yang bisa digeser)
local faderTrack = Instance.new("Frame")
faderTrack.Name = "FaderTrack"
faderTrack.Size = UDim2.new(1, 0, 0, 6)
faderTrack.Position = UDim2.fromOffset(0, 178)
faderTrack.BackgroundColor3 = Color3.fromRGB(130, 131, 135)
faderTrack.BorderSizePixel = 0
faderTrack.Parent = contentFrame
Instance.new("UICorner", faderTrack).CornerRadius = UDim.new(1, 0)

local faderThumb = Instance.new("TextButton")
faderThumb.Name = "FaderThumb"
faderThumb.Size = UDim2.fromOffset(36, 20)
faderThumb.Position = UDim2.fromOffset(0, -7)
faderThumb.BackgroundColor3 = Color3.fromRGB(150, 151, 155)
faderThumb.Text = ""
faderThumb.BorderSizePixel = 0
faderThumb.Parent = faderTrack
Instance.new("UICorner", faderThumb).CornerRadius = UDim.new(0, 2)

local function setFaderByRatio(ratio)
	local r = math.clamp(ratio, 0, 1)
	local trackW = math.max(1, faderTrack.AbsoluteSize.X - faderThumb.AbsoluteSize.X)
	faderThumb.Position = UDim2.fromOffset(math.floor(r * trackW), -7)

	local dmxVal = math.floor(r * 255 + 0.5)
	local degVal = math.floor(r * 360 + 0.5)
	numberDegLabel.Text = tostring(degVal) .. "°"
	applyAxisToSelectedChannels(dmxVal)
end

do
	local sliding = false
	local slideInput = nil

	local function updateFromInput(posX)
		local left = faderTrack.AbsolutePosition.X
		local width = math.max(1, faderTrack.AbsoluteSize.X)
		setFaderByRatio((posX - left) / width)
	end

	local function beginSlide(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			slideInput = input
			updateFromInput(input.Position.X)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					sliding = false
				end
			end)
		end
	end

	faderTrack.InputBegan:Connect(beginSlide)
	faderThumb.InputBegan:Connect(beginSlide)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and input == slideInput then
			updateFromInput(input.Position.X)
		end
	end)
end

-- Sub-konten khusus tab "patch" di bagian bawah (add fixture +, cycle fixture, count, universe, auto calculate)
local patchExtras = Instance.new("Frame")
patchExtras.Size = UDim2.new(1, 0, 1, -206)
patchExtras.Position = UDim2.fromOffset(0, 206)
patchExtras.BackgroundTransparency = 1
patchExtras.Parent = contentFrame

local addFixtureBtn = Instance.new("TextButton")
addFixtureBtn.Size = UDim2.fromOffset(102, 26)
addFixtureBtn.Position = UDim2.new(1, -102, 0, 0)
addFixtureBtn.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
addFixtureBtn.Text = "add fixture +"
addFixtureBtn.TextColor3 = Color3.fromRGB(245, 248, 255)
addFixtureBtn.TextSize = 12
addFixtureBtn.Font = Enum.Font.GothamMedium
addFixtureBtn.BorderSizePixel = 0
addFixtureBtn.Parent = patchExtras
Instance.new("UICorner", addFixtureBtn).CornerRadius = UDim.new(0, 7)

local fixRow = Instance.new("Frame")
fixRow.Size = UDim2.new(1, 0, 0, 28)
fixRow.Position = UDim2.fromOffset(0, 30)
fixRow.BackgroundColor3 = Color3.fromRGB(78, 79, 82)
fixRow.BorderSizePixel = 0
fixRow.Parent = patchExtras
Instance.new("UICorner", fixRow).CornerRadius = UDim.new(1, 0)

local prevFixBtn = Instance.new("TextButton")
prevFixBtn.Size = UDim2.fromOffset(32, 28)
prevFixBtn.Position = UDim2.fromOffset(4, 0)
prevFixBtn.BackgroundTransparency = 1
prevFixBtn.Text = "◁"
prevFixBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
prevFixBtn.TextSize = 14
prevFixBtn.Font = Enum.Font.GothamBold
prevFixBtn.Parent = fixRow

local fixNameLbl = Instance.new("TextLabel")
fixNameLbl.Size = UDim2.new(1, -80, 1, 0)
fixNameLbl.Position = UDim2.fromOffset(40, 0)
fixNameLbl.BackgroundTransparency = 1
fixNameLbl.Text = getSelectedFixtureName()
fixNameLbl.TextColor3 = Color3.fromRGB(238, 240, 244)
fixNameLbl.TextSize = 12
fixNameLbl.Font = Enum.Font.GothamMedium
fixNameLbl.Parent = fixRow

local nextFixBtn = Instance.new("TextButton")
nextFixBtn.Size = UDim2.fromOffset(32, 28)
nextFixBtn.Position = UDim2.new(1, -36, 0, 0)
nextFixBtn.BackgroundTransparency = 1
nextFixBtn.Text = "▷"
nextFixBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
nextFixBtn.TextSize = 14
nextFixBtn.Font = Enum.Font.GothamBold
nextFixBtn.Parent = fixRow

local function makeExtraPill(yPos, isInput, textOrPh)
	local obj = Instance.new(isInput and "TextBox" or "TextButton")
	obj.Size = UDim2.new(1, 0, 0, 26)
	obj.Position = UDim2.fromOffset(0, yPos)
	obj.BackgroundColor3 = Color3.fromRGB(78, 79, 82)
	obj.TextColor3 = Color3.fromRGB(238, 240, 244)
	obj.TextSize = 12
	obj.Font = Enum.Font.GothamMedium
	obj.BorderSizePixel = 0
	obj.Parent = patchExtras
	if isInput then
		obj.Text = ""
		obj.PlaceholderText = textOrPh
		obj.PlaceholderColor3 = Color3.fromRGB(175, 177, 182)
		obj.ClearTextOnFocus = false
	else
		obj.Text = textOrPh
	end
	Instance.new("UICorner", obj).CornerRadius = UDim.new(1, 0)
	return obj
end

local countBox = makeExtraPill(62, true, "count fixture your add")
local univBtn = makeExtraPill(92, false, "Universe 1")
local autoCalcBtn = makeExtraPill(122, false, "Auto calculate")

local statusBadge = Instance.new("TextLabel")
statusBadge.Size = UDim2.fromOffset(92, 20)
statusBadge.Position = UDim2.new(1, -92, 1, -20)
statusBadge.BackgroundColor3 = Color3.fromRGB(168, 169, 173)
statusBadge.Text = "U1 • 1"
statusBadge.TextColor3 = Color3.fromRGB(28, 28, 30)
statusBadge.TextSize = 11
statusBadge.Font = Enum.Font.GothamBold
statusBadge.BorderSizePixel = 0
statusBadge.Parent = patchExtras
Instance.new("UICorner", statusBadge).CornerRadius = UDim.new(0, 5)

-- ============================================================================
-- REFRESH & EVENTS
-- ============================================================================
function refreshAll()
	fixNameLbl.Text = getSelectedFixtureName()
	univBtn.Text = "Universe " .. state.universe
	pageLabel.Text = "page " .. state.page

	panBtn.BackgroundColor3 = (state.axisMode == "Pan") and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
	panBtn.TextColor3 = (state.axisMode == "Pan") and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)

	tiltBtn.BackgroundColor3 = (state.axisMode == "Tilt") and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
	tiltBtn.TextColor3 = (state.axisMode == "Tilt") and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)

	local baseCh = (state.page - 1) * state.slotsPerPage
	for slotIdx = 1, 12 do
		local chNum = baseCh + slotIdx
		local btn = channelSlots[slotIdx]
		local isSelected = state.selectedChannels[chNum] == true
		btn.Text = tostring(chNum)
		btn.Visible = chNum <= MAX_CHANNELS
		btn.BackgroundColor3 = isSelected and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
		btn.TextColor3 = isSelected and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)
	end

	local selList = getSelectedChannelList()
	local selText = (#selList > 0) and table.concat(selList, ",") or "-"
	statusBadge.Text = "U" .. state.universe .. " • [" .. selText .. "]"
end

for _, tName in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(77, 26)
	btn.Text = tName
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = tabContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	tabButtons[tName] = btn

	btn.MouseButton1Click:Connect(function()
		state.activeTab = tName
		for name, b in pairs(tabButtons) do
			local active = (name == tName)
			b.BackgroundColor3 = active and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
			b.TextColor3 = active and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)
		end
		patchExtras.Visible = (tName == "patch")
	end)
end

for name, b in pairs(tabButtons) do
	local active = (name == state.activeTab)
	b.BackgroundColor3 = active and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
	b.TextColor3 = active and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)
end

panBtn.MouseButton1Click:Connect(function()
	state.axisMode = "Pan"
	refreshAll()
end)

tiltBtn.MouseButton1Click:Connect(function()
	state.axisMode = "Tilt"
	refreshAll()
end)

nextPageBtn.MouseButton1Click:Connect(function()
	local maxPages = math.ceil(MAX_CHANNELS / state.slotsPerPage)
	state.page = (state.page % maxPages) + 1
	refreshAll()
end)

prevFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = ((state.fixtureIndex - 2) % #fixtureNames) + 1
	refreshAll()
end)

nextFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = (state.fixtureIndex % #fixtureNames) + 1
	refreshAll()
end)

univBtn.MouseButton1Click:Connect(function()
	state.universe = (state.universe == 1) and 2 or 1
	refreshAll()
end)

autoCalcBtn.MouseButton1Click:Connect(function()
	local car = getOwnCarModel(player)
	local folder = car and car:FindFirstChild("Folder")
	local dmxFolder = (folder and folder:FindFirstChild("DmxLights")) or (car and car:FindFirstChild("DmxLights", true))
	local keys = NameAliases[getSelectedFixtureName()] or { string.lower(getSelectedFixtureName()) }
	local found = 0
	if dmxFolder then
		for _, desc in ipairs(dmxFolder:GetDescendants()) do
			if matchesAnyKey(desc.Name, keys) then
				found += 1
			end
		end
	end
	countBox.Text = tostring(found)
end)

addFixtureBtn.MouseButton1Click:Connect(function()
	local qty = math.max(1, math.floor(tonumber(countBox.Text) or 1))
	local fixName = getSelectedFixtureName()
	for _ = 1, qty do
		table.insert(state.rawByUniv[state.universe], {
			Type = fixName,
			Universe = state.universe,
		})
	end
	local patched = PatchEngine.PatchAll(state.rawByUniv[state.universe], state.universe, true, DEFAULT_MAX_UNIVERSES)
	state.patchedByUniv[state.universe] = patched
	refreshAll()
end)

minBtn.MouseButton1Click:Connect(function()
	local collapsed = mainFrame.Size.Y.Offset <= 52
	mainFrame.Size = collapsed and UDim2.fromOffset(360, 465) or UDim2.fromOffset(360, 48)
	tabContainer.Visible = collapsed
	contentFrame.Visible = collapsed
end)

closeBtn.MouseButton1Click:Connect(function()
	if screenGui then
		screenGui:Destroy()
	end
end)

refreshAll()
