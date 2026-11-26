-- DmxConsoleUI_Synced.lua (360x465)
-- Kotak channel di patch dan Preferensi sinkron 1:1 (kalau di patch muncul 1 kotak, di Preferensi juga 1 kotak)
-- Multi-select channel + Pan / Tilt + number° + fader geser + efek 16-ch beam -> buffer.create(3) ke UDP_DMXDATA

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local MAX_CHANNELS = 512
local DEFAULT_MAX_UNIVERSES = 2
local REMOTE_NAME = "UDP_DMXDATA"

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
	-- Confirmed 16-Ch Beam mapping (0-based offsets):
	-- CH 1 (0): PanCoarse | CH 2 (1): TiltCoarse | CH 3 (2): PanFine | CH 4 (3): TiltFine
	-- CH 7 (6): Strobe/Shutter | CH 8 (7): Dimmer | CH 9 (8): Color | CH 10 (9): Gobo
	-- CH 12 (11): Prism | CH 13 (12): Focus | CH 15 (14): GoboRotation / PrismRot
	-- CH 5, 6, 11, 14, 16: unused/reserved
	local ClaraS14Profile = {
		Group = "MovingBeam",
		Span = 16,
		X = 0,
		Y = 1,
		PanFine = 2,
		TiltFine = 3,
		Shutter = 6,
		Dimmer = 7,
		Color = 8,
		Gobo = 9,
		Prism = 11,
		Effect = 11,
		Focus = 12,
		Speed = 14,
		GoboRotation = 14,
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
						PanFine = toAbsChannel(addr, prof.PanFine, span),
						TiltFine = toAbsChannel(addr, prof.TiltFine, span),
						Shutter = toAbsChannel(addr, prof.Shutter, span),
						Dimmer = toAbsChannel(addr, prof.Dimmer or 0, span),
						Color = toAbsChannel(addr, prof.Color, span),
						Gobo = toAbsChannel(addr, prof.Gobo, span),
						Prism = toAbsChannel(addr, prof.Prism or prof.Effect, span),
						Focus = toAbsChannel(addr, prof.Focus, span),
						Speed = toAbsChannel(addr, prof.Speed or prof.GoboRotation, span),
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
-- TRANSPORT BUFFER 3-BYTE -> UDP_DMXDATA
-- ============================================================================
local function getOwnCarModel(plr)
	local vehicles = Workspace:FindFirstChild("Vehicles")
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

local function findUdpDmxRemote(plr)
	local carModel = getOwnCarModel(plr)
	if carModel then
		local r = carModel:FindFirstChild(REMOTE_NAME, true)
		if r and (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then
			return r
		end
	end
	local rRs = ReplicatedStorage:FindFirstChild(REMOTE_NAME, true)
	if rRs and (rRs:IsA("RemoteEvent") or rRs:IsA("UnreliableRemoteEvent")) then
		return rRs
	end
	local rWs = Workspace:FindFirstChild(REMOTE_NAME, true)
	if rWs and (rWs:IsA("RemoteEvent") or rWs:IsA("UnreliableRemoteEvent")) then
		return rWs
	end
	return nil
end

local DmxTransport = {}
DmxTransport.__index = DmxTransport

function DmxTransport.new(plr)
	local self = setmetatable({}, DmxTransport)
	self.Player = plr
	self.DataRemote = findUdpDmxRemote(plr)
	self.LastValues = {}
	self:_bind()
	return self
end

function DmxTransport:_refreshRemote()
	local found = findUdpDmxRemote(self.Player)
	if found then
		self.DataRemote = found
	end
	return self.DataRemote
end

function DmxTransport:_bind()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		vehicles.ChildAdded:Connect(function()
			task.wait(0.25)
			self:_refreshRemote()
		end)
	end
	task.spawn(function()
		while not self.DataRemote do
			self:_refreshRemote()
			task.wait(1)
		end
	end)
end

function DmxTransport:SendChannel(ch, dmxVal, force)
	local channel = math.clamp(math.floor(tonumber(ch) or 1), 1, MAX_CHANNELS)
	local val = math.clamp(math.floor(tonumber(dmxVal) or 0), 0, 255)
	if not force and self.LastValues[channel] == val then
		return true
	end
	self.LastValues[channel] = val
	local remote = self.DataRemote or self:_refreshRemote()
	if not remote then
		return false
	end
	local buf = buffer.create(3)
	buffer.writeu16(buf, 0, channel)
	buffer.writeu8(buf, 2, val)
	remote:FireServer(buf)
	return true
end

local transport = DmxTransport.new(player)

-- ============================================================================
-- UI (360x465) — KOTAK CHANNEL SINKRON 1:1 ANTARA PATCH & PREFERENSI
-- ============================================================================
local parentTarget = player:WaitForChild("PlayerGui")
pcall(function()
	if gethui then parentTarget = gethui() end
end)
local oldGui = parentTarget:FindFirstChild("DmxConsoleSyncedGui")
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
	addedCountByUniv = { [1] = 0, [2] = 0 }, -- jumlah kotak channel yang muncul di patch & Preferensi
	selectedChannels = {}, -- multi-select kotak/fixture
	axisMode = "Pan", -- "Pan" (X) atau "Tilt" (Y)
	rawByUniv = { [1] = {}, [2] = {} },
	patchedByUniv = { [1] = {}, [2] = {} },
	nextAddress = 1,
	autoOpenGate = true,
	-- Quick effect steps untuk 16-ch beam
	colorStep = 1,  -- 1..8 (CH 9)
	goboStep = 0,   -- 0..4 (CH 10)
	prismStep = 0,  -- 0=single, 1=flat, 2=ring1, 3=ring2 (CH 12)
	focusVal = 0,   -- 0..255 (CH 13)
	rotVal = 0,     -- 0..255 (CH 15)
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

local function resolveFixtureForBox(boxIdx)
	local patched = state.patchedByUniv[state.universe] or {}
	if patched[boxIdx] then
		return patched[boxIdx]
	end
	return PatchEngine.GetFixtureAtChannel(patched, boxIdx, state.universe)
end

local function openGateForFixture(fix)
	if not (state.autoOpenGate and fix and fix.Channels) then return end
	if fix.Channels.Dimmer then
		transport:SendChannel(fix.Channels.Dimmer, 255, true)
	end
	-- Nilai 0..3 berada di OffRanges strobe (lampu nyala normal tanpa kedip)
	if fix.Channels.Shutter then
		transport:SendChannel(fix.Channels.Shutter, 0, true)
	end
end

local function sendToSelectedRole(roleKey, dmxVal, fallbackCh)
	local clamped = math.clamp(math.floor(dmxVal), 0, 255)
	local targets = {}
	local seen = {}

	for boxIdx, isSel in pairs(state.selectedChannels) do
		if isSel then
			local fix = resolveFixtureForBox(boxIdx)
			local targetCh = (fix and fix.Channels and fix.Channels[roleKey])
			if not targetCh then
				if fix and fix.Address and fallbackCh then
					targetCh = toAbsChannel(fix.Address, fallbackCh - 1, fix.Span or 16)
				else
					targetCh = boxIdx
				end
			end
			if targetCh and not seen[targetCh] then
				seen[targetCh] = true
				table.insert(targets, targetCh)
			end
		end
	end

	for _, targetCh in ipairs(targets) do
		transport:SendChannel(targetCh, clamped, true)
	end
end

local function applyAxisToSelectedChannels(dmxVal)
	local role = (state.axisMode == "Pan") and "X" or "Y"
	local fallback = (state.axisMode == "Pan") and 1 or 2
	sendToSelectedRole(role, dmxVal, fallback)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxConsoleSyncedGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = parentTarget

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.fromOffset(360, 465)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -232.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(58, 58, 60)
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
minBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
minBtn.TextSize = 20
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(34, 28)
closeBtn.Position = UDim2.new(1, -44, 0, 8)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(220, 222, 226)
closeBtn.TextSize = 24
closeBtn.Font = Enum.Font.Gotham
closeBtn.Parent = topBar

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, -24, 0, 1)
topLine.Position = UDim2.fromOffset(12, 44)
topLine.BackgroundColor3 = Color3.fromRGB(150, 150, 154)
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

local bodyFrame = Instance.new("Frame")
bodyFrame.Size = UDim2.new(1, -24, 1, -94)
bodyFrame.Position = UDim2.fromOffset(12, 90)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = mainFrame

-- ============================================================================
-- KOMPONEN BERSAMA: GRID CHANNEL & PAGING (1:1 antara patch dan Preferensi)
-- ============================================================================
local sharedChannelHolder = Instance.new("Frame")
sharedChannelHolder.Size = UDim2.new(1, 0, 0, 124)
sharedChannelHolder.Position = UDim2.fromOffset(0, 2)
sharedChannelHolder.BackgroundTransparency = 1
sharedChannelHolder.Parent = bodyFrame

local channelFrame = Instance.new("ScrollingFrame")
channelFrame.Name = "ChannelContainer"
channelFrame.Size = UDim2.new(1, 0, 0, 96)
channelFrame.Position = UDim2.fromOffset(0, 0)
channelFrame.BackgroundTransparency = 1
channelFrame.ScrollBarThickness = 3
channelFrame.CanvasSize = UDim2.fromOffset(0, 0)
channelFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
channelFrame.Parent = sharedChannelHolder

local channelGrid = Instance.new("UIGridLayout")
channelGrid.CellSize = UDim2.fromOffset(49, 43)
channelGrid.CellPadding = UDim2.fromOffset(6.5, 8)
channelGrid.FillDirection = Enum.FillDirection.Horizontal
channelGrid.SortOrder = Enum.SortOrder.LayoutOrder
channelGrid.Parent = channelFrame

local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.fromOffset(90, 20)
pageLabel.Position = UDim2.fromOffset(0, 102)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "page 1"
pageLabel.TextXAlignment = Enum.TextXAlignment.Left
pageLabel.TextColor3 = Color3.fromRGB(190, 190, 195)
pageLabel.TextSize = 13
pageLabel.Font = Enum.Font.Gotham
pageLabel.Parent = sharedChannelHolder

local nextPageBtn = Instance.new("TextButton")
nextPageBtn.Size = UDim2.fromOffset(96, 20)
nextPageBtn.Position = UDim2.new(1, -96, 0, 102)
nextPageBtn.BackgroundTransparency = 1
nextPageBtn.Text = "next page >"
nextPageBtn.TextXAlignment = Enum.TextXAlignment.Right
nextPageBtn.TextColor3 = Color3.fromRGB(190, 190, 195)
nextPageBtn.TextSize = 13
nextPageBtn.Font = Enum.Font.Gotham
nextPageBtn.Parent = sharedChannelHolder

-- ============================================================================
-- TAB 1: PATCH
-- ============================================================================
local patchPage = Instance.new("Frame")
patchPage.Size = UDim2.new(1, 0, 1, -126)
patchPage.Position = UDim2.fromOffset(0, 126)
patchPage.BackgroundTransparency = 1
patchPage.Visible = true
patchPage.Parent = bodyFrame

local addFixtureBtn = Instance.new("TextButton")
addFixtureBtn.Size = UDim2.fromOffset(104, 28)
addFixtureBtn.Position = UDim2.new(1, -104, 0, 20)
addFixtureBtn.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
addFixtureBtn.Text = "add fixture +"
addFixtureBtn.TextColor3 = Color3.fromRGB(245, 248, 255)
addFixtureBtn.TextSize = 13
addFixtureBtn.Font = Enum.Font.GothamMedium
addFixtureBtn.BorderSizePixel = 0
addFixtureBtn.Parent = patchPage
Instance.new("UICorner", addFixtureBtn).CornerRadius = UDim.new(0, 8)

local fixtureRow = Instance.new("Frame")
fixtureRow.Size = UDim2.new(1, 0, 0, 32)
fixtureRow.Position = UDim2.fromOffset(0, 58)
fixtureRow.BackgroundColor3 = Color3.fromRGB(74, 74, 77)
fixtureRow.BorderSizePixel = 0
fixtureRow.Parent = patchPage
Instance.new("UICorner", fixtureRow).CornerRadius = UDim.new(1, 0)
local fixStroke = Instance.new("UIStroke", fixtureRow)
fixStroke.Color = Color3.fromRGB(34, 34, 36)
fixStroke.Thickness = 1.5

local prevFixBtn = Instance.new("TextButton")
prevFixBtn.Size = UDim2.fromOffset(36, 32)
prevFixBtn.Position = UDim2.fromOffset(6, 0)
prevFixBtn.BackgroundTransparency = 1
prevFixBtn.Text = "◁"
prevFixBtn.TextColor3 = Color3.fromRGB(28, 28, 30)
prevFixBtn.TextSize = 16
prevFixBtn.Font = Enum.Font.GothamBold
prevFixBtn.Parent = fixtureRow

local fixtureNameLabel = Instance.new("TextLabel")
fixtureNameLabel.Size = UDim2.new(1, -92, 1, 0)
fixtureNameLabel.Position = UDim2.fromOffset(46, 0)
fixtureNameLabel.BackgroundTransparency = 1
fixtureNameLabel.Text = getSelectedFixtureName()
fixtureNameLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
fixtureNameLabel.TextSize = 13
fixtureNameLabel.Font = Enum.Font.GothamMedium
fixtureNameLabel.Parent = fixtureRow

local nextFixBtn = Instance.new("TextButton")
nextFixBtn.Size = UDim2.fromOffset(36, 32)
nextFixBtn.Position = UDim2.new(1, -42, 0, 0)
nextFixBtn.BackgroundTransparency = 1
nextFixBtn.Text = "▷"
nextFixBtn.TextColor3 = Color3.fromRGB(28, 28, 30)
nextFixBtn.TextSize = 16
nextFixBtn.Font = Enum.Font.GothamBold
nextFixBtn.Parent = fixtureRow

local function createPill(parent, yPos, isInput, textOrPlaceholder)
	local box = Instance.new(isInput and "TextBox" or "TextButton")
	box.Size = UDim2.new(1, 0, 0, 30)
	box.Position = UDim2.fromOffset(0, yPos)
	box.BackgroundColor3 = Color3.fromRGB(74, 74, 77)
	box.TextColor3 = Color3.fromRGB(235, 235, 240)
	box.TextSize = 13
	box.Font = Enum.Font.GothamMedium
	box.BorderSizePixel = 0
	box.Parent = parent
	if isInput then
		box.Text = ""
		box.PlaceholderText = textOrPlaceholder
		box.PlaceholderColor3 = Color3.fromRGB(170, 170, 176)
		box.ClearTextOnFocus = false
	else
		box.Text = textOrPlaceholder
	end
	Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", box)
	stroke.Color = Color3.fromRGB(34, 34, 36)
	stroke.Thickness = 1.5
	return box
end

local countBox = createPill(patchPage, 96, true, "count fixture your add")
local universeBtn = createPill(patchPage, 132, false, "Universe 1")
local autoCalcBtn = createPill(patchPage, 168, false, "Auto calculate")

local addrBadge = Instance.new("TextLabel")
addrBadge.Size = UDim2.fromOffset(124, 24)
addrBadge.Position = UDim2.new(1, -124, 1, -24)
addrBadge.BackgroundColor3 = Color3.fromRGB(168, 168, 172)
addrBadge.Text = "U1 • 1"
addrBadge.TextColor3 = Color3.fromRGB(30, 30, 32)
addrBadge.TextSize = 12
addrBadge.Font = Enum.Font.GothamBold
addrBadge.BorderSizePixel = 0
addrBadge.Parent = patchPage
Instance.new("UICorner", addrBadge).CornerRadius = UDim.new(0, 6)

-- ============================================================================
-- TAB 2: PREFERENSI (Kotak channel sinkron + Pan / Tilt + number° + Fader + 16-Ch FX)
-- ============================================================================
local prefPage = Instance.new("Frame")
prefPage.Size = UDim2.new(1, 0, 1, -126)
prefPage.Position = UDim2.fromOffset(0, 126)
prefPage.BackgroundTransparency = 1
prefPage.Visible = false
prefPage.Parent = bodyFrame

local panBtn = Instance.new("TextButton")
panBtn.Size = UDim2.fromOffset(108, 26)
panBtn.Position = UDim2.fromOffset(0, 4)
panBtn.Text = "Pan"
panBtn.TextSize = 13
panBtn.Font = Enum.Font.GothamMedium
panBtn.BorderSizePixel = 0
panBtn.Parent = prefPage
Instance.new("UICorner", panBtn).CornerRadius = UDim.new(0, 6)

local tiltBtn = Instance.new("TextButton")
tiltBtn.Size = UDim2.fromOffset(108, 26)
tiltBtn.Position = UDim2.fromOffset(116, 4)
tiltBtn.Text = "Tilt"
tiltBtn.TextSize = 13
tiltBtn.Font = Enum.Font.GothamMedium
tiltBtn.BorderSizePixel = 0
tiltBtn.Parent = prefPage
Instance.new("UICorner", tiltBtn).CornerRadius = UDim.new(0, 6)

local numberDegLabel = Instance.new("TextLabel")
numberDegLabel.Size = UDim2.fromOffset(96, 26)
numberDegLabel.Position = UDim2.new(1, -96, 0, 4)
numberDegLabel.BackgroundColor3 = Color3.fromRGB(115, 116, 120)
numberDegLabel.Text = "0°"
numberDegLabel.TextColor3 = Color3.fromRGB(32, 32, 34)
numberDegLabel.TextSize = 12
numberDegLabel.Font = Enum.Font.GothamBold
numberDegLabel.BorderSizePixel = 0
numberDegLabel.Parent = prefPage
Instance.new("UICorner", numberDegLabel).CornerRadius = UDim.new(0, 4)

local faderTrack = Instance.new("Frame")
faderTrack.Size = UDim2.new(1, 0, 0, 6)
faderTrack.Position = UDim2.fromOffset(0, 42)
faderTrack.BackgroundColor3 = Color3.fromRGB(130, 131, 135)
faderTrack.BorderSizePixel = 0
faderTrack.Parent = prefPage
Instance.new("UICorner", faderTrack).CornerRadius = UDim.new(1, 0)

local faderThumb = Instance.new("TextButton")
faderThumb.Size = UDim2.fromOffset(36, 20)
faderThumb.Position = UDim2.fromOffset(0, -7)
faderThumb.BackgroundColor3 = Color3.fromRGB(150, 151, 155)
faderThumb.Text = ""
faderThumb.BorderSizePixel = 0
faderThumb.Parent = faderTrack
Instance.new("UICorner", faderThumb).CornerRadius = UDim.new(0, 2)

local function setFaderRatio(ratio)
	local r = math.clamp(ratio, 0, 1)
	local maxOffset = math.max(1, faderTrack.AbsoluteSize.X - faderThumb.AbsoluteSize.X)
	faderThumb.Position = UDim2.fromOffset(math.floor(r * maxOffset), -7)

	local maxSpanDeg = (state.axisMode == "Pan") and 540 or 270
	local degVal = math.floor(r * maxSpanDeg + 0.5)
	local dmxVal = math.floor(r * 255 + 0.5)
	numberDegLabel.Text = tostring(degVal) .. "°"
	applyAxisToSelectedChannels(dmxVal)
end

do
	local sliding = false
	local slideInput = nil

	local function updateFromX(posX)
		local left = faderTrack.AbsolutePosition.X
		local width = math.max(1, faderTrack.AbsoluteSize.X)
		setFaderRatio((posX - left) / width)
	end

	local function beginSlide(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			slideInput = input
			updateFromX(input.Position.X)
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
			updateFromX(input.Position.X)
		end
	end)
end

local function createMiniBtn(parent, xPos, yPos, width, text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(width, 26)
	btn.Position = UDim2.fromOffset(xPos, yPos)
	btn.BackgroundColor3 = Color3.fromRGB(74, 74, 77)
	btn.TextColor3 = Color3.fromRGB(235, 235, 240)
	btn.Text = text
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local colorBtn = createMiniBtn(prefPage, 0, 58, 108, "Color #1 (CH9)")
local goboBtn = createMiniBtn(prefPage, 114, 58, 108, "Gobo Off (CH10)")
local prismBtn = createMiniBtn(prefPage, 228, 58, 108, "Prism 1x (CH12)")

local focusBtn = createMiniBtn(prefPage, 0, 90, 165, "Focus: 0 (CH13)")
local rotBtn = createMiniBtn(prefPage, 171, 90, 165, "Rot/Spd: 0 (CH15)")

local autoGateBtn = createPill(prefPage, 124, false, "Auto Gate (Dim255+Strobe0): ON")
autoGateBtn.MouseButton1Click:Connect(function()
	state.autoOpenGate = not state.autoOpenGate
	autoGateBtn.Text = "Auto Gate (Dim255+Strobe0): " .. (state.autoOpenGate and "ON" or "OFF")
	if state.autoOpenGate then
		for boxIdx, isSel in pairs(state.selectedChannels) do
			if isSel then
				openGateForFixture(resolveFixtureForBox(boxIdx))
			end
		end
	end
end)

local prismModes = {
	{ label = "Single", val = 0 },
	{ label = "Flat", val = 25 },
	{ label = "Ring1", val = 80 },
	{ label = "Ring2", val = 180 },
}

colorBtn.MouseButton1Click:Connect(function()
	state.colorStep = (state.colorStep % 8) + 1
	local dmxVal = math.floor(((state.colorStep - 1) / 8) * 255)
	colorBtn.Text = "Color #" .. state.colorStep .. " (CH9)"
	sendToSelectedRole("Color", dmxVal, 9)
end)

goboBtn.MouseButton1Click:Connect(function()
	state.goboStep = (state.goboStep + 1) % 5
	local dmxVal = (state.goboStep == 0) and 0 or math.floor(((state.goboStep - 1) / 4) * 255)
	goboBtn.Text = (state.goboStep == 0) and "Gobo Off (CH10)" or ("Gobo #" .. state.goboStep .. " (CH10)")
	sendToSelectedRole("Gobo", dmxVal, 10)
end)

prismBtn.MouseButton1Click:Connect(function()
	state.prismStep = (state.prismStep % #prismModes) + 1
	local mode = prismModes[state.prismStep]
	prismBtn.Text = "Prism " .. mode.label .. " (CH12)"
	sendToSelectedRole("Prism", mode.val, 12)
end)

focusBtn.MouseButton1Click:Connect(function()
	state.focusVal = (state.focusVal + 64) % 256
	focusBtn.Text = "Focus: " .. state.focusVal .. " (CH13)"
	sendToSelectedRole("Focus", state.focusVal, 13)
end)

rotBtn.MouseButton1Click:Connect(function()
	state.rotVal = (state.rotVal + 64) % 256
	rotBtn.Text = "Rot/Spd: " .. state.rotVal .. " (CH15)"
	sendToSelectedRole("Speed", state.rotVal, 15)
end)

-- ============================================================================
-- TAB 3: MAIN & TAB 4: SETTING
-- ============================================================================
local mainPage = Instance.new("TextLabel")
mainPage.Size = UDim2.fromScale(1, 1)
mainPage.BackgroundTransparency = 1
mainPage.TextColor3 = Color3.fromRGB(220, 222, 228)
mainPage.TextSize = 13
mainPage.Font = Enum.Font.GothamMedium
mainPage.TextWrapped = true
mainPage.Visible = false
mainPage.Parent = bodyFrame

local settingPage = Instance.new("Frame")
settingPage.Size = UDim2.fromScale(1, 1)
settingPage.BackgroundTransparency = 1
settingPage.Visible = false
settingPage.Parent = bodyFrame

local clearAllBtn = createPill(settingPage, 8, false, "Reset / Clear Patch")

-- ============================================================================
-- REFRESH & EVENTS
-- ============================================================================
local function getOwnDmxFolder()
	local carModel = getOwnCarModel(player)
	if not carModel then return nil end
	local folder = carModel:FindFirstChild("Folder")
	return (folder and folder:FindFirstChild("DmxLights")) or carModel:FindFirstChild("DmxLights", true)
end

function refreshUI()
	fixtureNameLabel.Text = getSelectedFixtureName()
	universeBtn.Text = "Universe " .. state.universe
	pageLabel.Text = "page " .. state.page

	panBtn.BackgroundColor3 = (state.axisMode == "Pan") and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
	panBtn.TextColor3 = (state.axisMode == "Pan") and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)

	tiltBtn.BackgroundColor3 = (state.axisMode == "Tilt") and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 120)
	tiltBtn.TextColor3 = (state.axisMode == "Tilt") and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)

	for _, child in ipairs(channelFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Sinkron 1:1 jumlah kotak dengan yang muncul di patch
	local totalBoxes = state.addedCountByUniv[state.universe] or 0
	if totalBoxes > 0 then
		local startIdx = (state.page - 1) * state.slotsPerPage + 1
		local endIdx = math.min(totalBoxes, state.page * state.slotsPerPage)

		for idx = startIdx, endIdx do
			local isSelected = state.selectedChannels[idx] == true
			local fix = resolveFixtureForBox(idx)
			local card = Instance.new("TextButton")
			card.Name = "Box_" .. idx
			card.LayoutOrder = idx - startIdx + 1
			card.BackgroundColor3 = isSelected and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(72, 72, 75)
			card.Text = tostring(idx)
			card.TextColor3 = isSelected and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(240, 245, 255)
			card.TextSize = 14
			card.Font = Enum.Font.GothamBold
			card.BorderSizePixel = 0
			card.Parent = channelFrame

			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
			local stroke = Instance.new("UIStroke", card)
			stroke.Color = Color3.fromRGB(32, 32, 34)
			stroke.Thickness = 1.5

			card.MouseButton1Click:Connect(function()
				local nextSel = not state.selectedChannels[idx]
				state.selectedChannels[idx] = nextSel
				if nextSel then
					openGateForFixture(fix)
				end
				refreshUI()
			end)
		end
	end

	local selList = getSelectedChannelList()
	local selStr = (#selList > 0) and table.concat(selList, ",") or tostring(state.nextAddress)
	local connTag = transport.DataRemote and "UDP:OK" or "UDP:.."
	addrBadge.Text = "U" .. state.universe .. "•" .. selStr .. " " .. connTag
	mainPage.Text = "Selected CH: " .. ((#selList > 0) and table.concat(selList, ", ") or "None") .. "\nRemote: " .. (transport.DataRemote and transport.DataRemote:GetFullName() or "Waiting " .. REMOTE_NAME .. "...")
end

for _, tName in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(77, 26)
	btn.Text = tName
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = tabContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	tabButtons[tName] = btn

	btn.MouseButton1Click:Connect(function()
		state.activeTab = tName
		for name, b in pairs(tabButtons) do
			local active = (name == tName)
			b.BackgroundColor3 = active and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 119)
			b.TextColor3 = active and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)
		end
		sharedChannelHolder.Visible = (tName == "patch" or tName == "Preferensi")
		patchPage.Visible = (tName == "patch")
		prefPage.Visible = (tName == "Preferensi")
		mainPage.Visible = (tName == "main")
		settingPage.Visible = (tName == "Setting")
	end)
end

for name, b in pairs(tabButtons) do
	local active = (name == state.activeTab)
	b.BackgroundColor3 = active and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(115, 116, 119)
	b.TextColor3 = active and Color3.fromRGB(240, 250, 252) or Color3.fromRGB(32, 32, 34)
end

prevFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = ((state.fixtureIndex - 2) % #fixtureNames) + 1
	refreshUI()
end)

nextFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = (state.fixtureIndex % #fixtureNames) + 1
	refreshUI()
end)

universeBtn.MouseButton1Click:Connect(function()
	state.universe = (state.universe == 1) and 2 or 1
	state.page = 1
	refreshUI()
end)

autoCalcBtn.MouseButton1Click:Connect(function()
	local dmxFolder = getOwnDmxFolder()
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

	local highestEnd = 0
	for _, item in ipairs(patched) do
		if (item.EndAddress or 0) > highestEnd then
			highestEnd = item.EndAddress
		end
	end
	state.nextAddress = math.clamp(highestEnd + 1, 1, MAX_CHANNELS)
	state.addedCountByUniv[state.universe] = (state.addedCountByUniv[state.universe] or 0) + qty

	refreshUI()
end)

nextPageBtn.MouseButton1Click:Connect(function()
	local totalBoxes = state.addedCountByUniv[state.universe] or 0
	local totalPages = math.max(1, math.ceil(totalBoxes / state.slotsPerPage))
	state.page = (state.page % totalPages) + 1
	refreshUI()
end)

panBtn.MouseButton1Click:Connect(function()
	state.axisMode = "Pan"
	refreshUI()
end)

tiltBtn.MouseButton1Click:Connect(function()
	state.axisMode = "Tilt"
	refreshUI()
end)

clearAllBtn.MouseButton1Click:Connect(function()
	state.rawByUniv[state.universe] = {}
	state.patchedByUniv[state.universe] = {}
	state.addedCountByUniv[state.universe] = 0
	state.selectedChannels = {}
	state.nextAddress = 1
	state.page = 1
	refreshUI()
end)

minBtn.MouseButton1Click:Connect(function()
	local collapsed = mainFrame.Size.Y.Offset <= 52
	mainFrame.Size = collapsed and UDim2.fromOffset(360, 465) or UDim2.fromOffset(360, 48)
	tabContainer.Visible = collapsed
	bodyFrame.Visible = collapsed
end)

closeBtn.MouseButton1Click:Connect(function()
	if screenGui then
		screenGui:Destroy()
	end
end)

refreshUI()
