local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("DmxFixtureUI") then
	playerGui.DmxFixtureUI:Destroy()
end

-- Data Fixture Presets (Channel & Nama)
local fixturePresets = {
	{name = "Beam (16ch)", ch = 16},
	{name = "Parled (6ch)", ch = 6},
	{name = "Strobo (8ch)", ch = 8},
	{name = "Wallwasher (8ch)", ch = 8},
	{name = "Blinder (8ch)", ch = 8},
	{name = "Kipas (8ch)", ch = 8},
	{name = "Flower (22ch)", ch = 22},
	{name = "Kipas Daun (27ch)", ch = 27}
}

local selectedPresetIndex = 1
local selectedUniverse = 1
local addedFixtures = {}
local isMinimized = false
local activeTab = "Patch"

-- Placeholder Hook Layer (disambung nanti)
local function onPatchUpdate(patchList)
	-- nanti: sambung ke PatchEngine / ConsoleEngine
end

local function onGerakanUpdate(state)
	-- nanti: sambung ke Layer Shape / OscilCapEngine
end

local function onMainAction(category, name)
	-- nanti: sambung ke Preset / Quick Override di ConsoleEngine
end

-- Main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxFixtureUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Frame Utama
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 480)
mainFrame.Position = UDim2.new(0.5, -190, 0.4, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 29, 36)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50, 60, 75)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

-- Title Bar
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 34)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🔵 DMX Mixer"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local btnClose = Instance.new("TextButton")
btnClose.Size = UDim2.new(0, 24, 0, 24)
btnClose.Position = UDim2.new(1, -30, 0, 5)
btnClose.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
btnClose.Text = "×"
btnClose.TextColor3 = Color3.fromRGB(220, 100, 100)
btnClose.TextSize = 14
btnClose.Font = Enum.Font.GothamBold
btnClose.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = btnClose

local btnMinimize = Instance.new("TextButton")
btnMinimize.Size = UDim2.new(0, 24, 0, 24)
btnMinimize.Position = UDim2.new(1, -58, 0, 5)
btnMinimize.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
btnMinimize.Text = "-"
btnMinimize.TextColor3 = Color3.fromRGB(200, 210, 225)
btnMinimize.TextSize = 14
btnMinimize.Font = Enum.Font.GothamBold
btnMinimize.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 5)
minCorner.Parent = btnMinimize

-- Container Konten
local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(1, 0, 1, -34)
contentContainer.Position = UDim2.new(0, 0, 0, 34)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainFrame

-- Tab Bar (3 Menu: Patch, Gerakan, Main Menu)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 30)
tabBar.Position = UDim2.new(0, 12, 0, 2)
tabBar.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
tabBar.BorderSizePixel = 0
tabBar.Parent = contentContainer

local tabBarCorner = Instance.new("UICorner")
tabBarCorner.CornerRadius = UDim.new(0, 7)
tabBarCorner.Parent = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingTop = UDim.new(0, 3)
tabPad.PaddingBottom = UDim.new(0, 3)
tabPad.PaddingLeft = UDim.new(0, 3)
tabPad.PaddingRight = UDim.new(0, 3)
tabPad.Parent = tabBar

local function makeTabButton(text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / 3, -3, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(180, 195, 215)
	btn.TextSize = 10
	btn.Font = Enum.Font.GothamBold
	btn.Parent = tabBar

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = btn
	return btn
end

local tabPatch = makeTabButton("Patch")
local tabGerakan = makeTabButton("Gerakan")
local tabMain = makeTabButton("Main Menu")

-- Area Isi Tiap Tab
local pageArea = Instance.new("Frame")
pageArea.Size = UDim2.new(1, -24, 1, -40)
pageArea.Position = UDim2.new(0, 12, 0, 36)
pageArea.BackgroundTransparency = 1
pageArea.Parent = contentContainer

-- =========================================================
-- 1. PAGE PATCH
-- =========================================================
local patchPage = Instance.new("Frame")
patchPage.Size = UDim2.new(1, 0, 1, 0)
patchPage.BackgroundTransparency = 1
patchPage.Visible = true
patchPage.Parent = pageArea

local inputBar = Instance.new("Frame")
inputBar.Size = UDim2.new(1, 0, 0, 40)
inputBar.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
inputBar.BorderSizePixel = 0
inputBar.Parent = patchPage

local inputBarCorner = Instance.new("UICorner")
inputBarCorner.CornerRadius = UDim.new(0, 8)
inputBarCorner.Parent = inputBar

local btnDropdown = Instance.new("TextButton")
btnDropdown.Size = UDim2.new(0, 145, 0, 28)
btnDropdown.Position = UDim2.new(0, 7, 0, 6)
btnDropdown.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
btnDropdown.Text = fixturePresets[1].name .. " 🗲"
btnDropdown.TextColor3 = Color3.fromRGB(220, 230, 245)
btnDropdown.TextSize = 10
btnDropdown.Font = Enum.Font.GothamMedium
btnDropdown.Parent = inputBar

local dropCorner = Instance.new("UICorner")
dropCorner.CornerRadius = UDim.new(0, 6)
dropCorner.Parent = btnDropdown

local btnUniv = Instance.new("TextButton")
btnUniv.Size = UDim2.new(0, 34, 0, 28)
btnUniv.Position = UDim2.new(0, 157, 0, 6)
btnUniv.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
btnUniv.Text = "U1"
btnUniv.TextColor3 = Color3.fromRGB(120, 200, 255)
btnUniv.TextSize = 10
btnUniv.Font = Enum.Font.GothamBold
btnUniv.Parent = inputBar

local univCorner = Instance.new("UICorner")
univCorner.CornerRadius = UDim.new(0, 6)
univCorner.Parent = btnUniv

local boxCount = Instance.new("TextBox")
boxCount.Size = UDim2.new(0, 38, 0, 28)
boxCount.Position = UDim2.new(0, 196, 0, 6)
boxCount.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
boxCount.Text = "1"
boxCount.TextColor3 = Color3.fromRGB(255, 255, 255)
boxCount.TextSize = 11
boxCount.Font = Enum.Font.GothamBold
boxCount.Parent = inputBar

local countCorner = Instance.new("UICorner")
countCorner.CornerRadius = UDim.new(0, 6)
countCorner.Parent = boxCount

local btnAdd = Instance.new("TextButton")
btnAdd.Size = UDim2.new(0, 108, 0, 28)
btnAdd.Position = UDim2.new(1, -115, 0, 6)
btnAdd.BackgroundColor3 = Color3.fromRGB(45, 145, 200)
btnAdd.Text = "Tambah"
btnAdd.TextColor3 = Color3.fromRGB(255, 255, 255)
btnAdd.TextSize = 11
btnAdd.Font = Enum.Font.GothamBold
btnAdd.Parent = inputBar

local addCorner = Instance.new("UICorner")
addCorner.CornerRadius = UDim.new(0, 6)
addCorner.Parent = btnAdd

local lblInfo = Instance.new("TextLabel")
lblInfo.Size = UDim2.new(0.65, 0, 0, 20)
lblInfo.Position = UDim2.new(0, 2, 0, 46)
lblInfo.BackgroundTransparency = 1
lblInfo.Text = "Fixture (0) | U1: 0ch | U2: 0ch"
lblInfo.TextColor3 = Color3.fromRGB(160, 175, 195)
lblInfo.TextSize = 10
lblInfo.Font = Enum.Font.GothamBold
lblInfo.TextXAlignment = Enum.TextXAlignment.Left
lblInfo.Parent = patchPage

local btnClearAll = Instance.new("TextButton")
btnClearAll.Size = UDim2.new(0.35, 0, 0, 20)
btnClearAll.Position = UDim2.new(0.65, 0, 0, 46)
btnClearAll.BackgroundTransparency = 1
btnClearAll.Text = "Hapus semua"
btnClearAll.TextColor3 = Color3.fromRGB(235, 90, 90)
btnClearAll.TextSize = 10
btnClearAll.Font = Enum.Font.GothamBold
btnClearAll.TextXAlignment = Enum.TextXAlignment.Right
btnClearAll.Parent = patchPage

local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, 0, 1, -72)
scrollList.Position = UDim2.new(0, 0, 0, 70)
scrollList.BackgroundTransparency = 1
scrollList.ScrollBarThickness = 3
scrollList.Parent = patchPage

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scrollList

local function buildPatchSnapshot()
	local list = {}
	local cursor = { [1] = 1, [2] = 1 }
	for i, fix in ipairs(addedFixtures) do
		local u = fix.universe or 1
		local s = cursor[u]
		local e = s + fix.ch - 1
		table.insert(list, { index = i, name = fix.name, ch = fix.ch, universe = u, startAddr = s, endAddr = e })
		cursor[u] = e + 1
	end
	return list
end

local function refreshPatchUI()
	for _, child in pairs(scrollList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local snap = buildPatchSnapshot()
	local used = { [1] = 0, [2] = 0 }

	for idx, item in ipairs(snap) do
		used[item.universe] = math.max(used[item.universe], item.endAddr)

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 34)
		row.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
		row.BorderSizePixel = 0
		row.Parent = scrollList

		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 6)
		rc.Parent = row

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 155, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("%d [U%d] %s", idx, item.universe, item.name)
		lbl.TextColor3 = Color3.fromRGB(215, 225, 240)
		lbl.TextSize = 10
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local bStart = Instance.new("TextLabel")
		bStart.Size = UDim2.new(0, 50, 0, 22)
		bStart.Position = UDim2.new(1, -152, 0.5, -11)
		bStart.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		bStart.Text = tostring(item.startAddr)
		bStart.TextColor3 = Color3.fromRGB(255, 255, 255)
		bStart.TextSize = 10
		bStart.Font = Enum.Font.GothamBold
		bStart.Parent = row

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 4)
		sCorner.Parent = bStart

		local bEnd = Instance.new("TextLabel")
		bEnd.Size = UDim2.new(0, 50, 0, 22)
		bEnd.Position = UDim2.new(1, -96, 0.5, -11)
		bEnd.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
		bEnd.Text = "+" .. tostring(item.endAddr)
		bEnd.TextColor3 = Color3.fromRGB(140, 155, 175)
		bEnd.TextSize = 9
		bEnd.Font = Enum.Font.Gotham
		bEnd.Parent = row

		local eCorner = Instance.new("UICorner")
		eCorner.CornerRadius = UDim.new(0, 4)
		eCorner.Parent = bEnd

		local btnDel = Instance.new("TextButton")
		btnDel.Size = UDim2.new(0, 22, 0, 22)
		btnDel.Position = UDim2.new(1, -30, 0.5, -11)
		btnDel.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
		btnDel.Text = "×"
		btnDel.TextColor3 = Color3.fromRGB(200, 100, 100)
		btnDel.TextSize = 12
		btnDel.Font = Enum.Font.GothamBold
		btnDel.Parent = row

		local dCorner = Instance.new("UICorner")
		dCorner.CornerRadius = UDim.new(0, 4)
		dCorner.Parent = btnDel

		btnDel.MouseButton1Click:Connect(function()
			table.remove(addedFixtures, idx)
			refreshPatchUI()
		end)
	end

	lblInfo.Text = string.format("Fixture (%d) | U1: %dch | U2: %dch", #snap, used[1], used[2])
	scrollList.CanvasSize = UDim2.new(0, 0, 0, #snap * 40)
	onPatchUpdate(snap)
end

-- =========================================================
-- 2. PAGE GERAKAN (Shape + CAP 1/2 + OSCIL + Speed)
-- =========================================================
local gerakanPage = Instance.new("Frame")
gerakanPage.Size = UDim2.new(1, 0, 1, 0)
gerakanPage.BackgroundTransparency = 1
gerakanPage.Visible = false
gerakanPage.Parent = pageArea

local gerakState = {
	shape = "Circle",
	cap1 = 255,
	cap2 = 0,
	oscil = false,
	speed = 1.0,
}

local function pushGerakan()
	onGerakanUpdate(gerakState)
end

local lblShape = Instance.new("TextLabel")
lblShape.Size = UDim2.new(1, 0, 0, 18)
lblShape.BackgroundTransparency = 1
lblShape.Text = "Shape"
lblShape.TextColor3 = Color3.fromRGB(190, 205, 225)
lblShape.TextSize = 10
lblShape.Font = Enum.Font.GothamBold
lblShape.TextXAlignment = Enum.TextXAlignment.Left
lblShape.Parent = gerakanPage

local shapeRow = Instance.new("Frame")
shapeRow.Size = UDim2.new(1, 0, 0, 32)
shapeRow.Position = UDim2.new(0, 0, 0, 20)
shapeRow.BackgroundTransparency = 1
shapeRow.Parent = gerakanPage

local shapeGrid = Instance.new("UIGridLayout")
shapeGrid.CellSize = UDim2.new(0.25, -4, 1, 0)
shapeGrid.CellPadding = UDim2.new(0, 5, 0, 0)
shapeGrid.Parent = shapeRow

for _, sName in ipairs({ "Circle", "Fig 8", "Wave", "Cermin" }) do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
	b.Text = sName
	b.TextColor3 = Color3.fromRGB(220, 230, 245)
	b.TextSize = 10
	b.Font = Enum.Font.GothamBold
	b.Parent = shapeRow
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b

	b.MouseButton1Click:Connect(function()
		gerakState.shape = sName
		pushGerakan()
	end)
end

local oscBox = Instance.new("Frame")
oscBox.Size = UDim2.new(1, 0, 0, 118)
oscBox.Position = UDim2.new(0, 0, 0, 62)
oscBox.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
oscBox.BorderSizePixel = 0
oscBox.Parent = gerakanPage

local oscCorner = Instance.new("UICorner")
oscCorner.CornerRadius = UDim.new(0, 8)
oscCorner.Parent = oscBox

local oscRow = Instance.new("Frame")
oscRow.Size = UDim2.new(1, -16, 0, 30)
oscRow.Position = UDim2.new(0, 8, 0, 8)
oscRow.BackgroundTransparency = 1
oscRow.Parent = oscBox

local oscGrid = Instance.new("UIGridLayout")
oscGrid.CellSize = UDim2.new(1 / 3, -5, 1, 0)
oscGrid.CellPadding = UDim2.new(0, 7, 0, 0)
oscGrid.Parent = oscRow

local btnCap1 = Instance.new("TextButton")
btnCap1.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
btnCap1.Text = "CAP 1: 255"
btnCap1.TextColor3 = Color3.fromRGB(220, 230, 245)
btnCap1.TextSize = 10
btnCap1.Font = Enum.Font.GothamBold
btnCap1.Parent = oscRow
Instance.new("UICorner", btnCap1).CornerRadius = UDim.new(0, 6)

local btnCap2 = Instance.new("TextButton")
btnCap2.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
btnCap2.Text = "CAP 2: 0"
btnCap2.TextColor3 = Color3.fromRGB(220, 230, 245)
btnCap2.TextSize = 10
btnCap2.Font = Enum.Font.GothamBold
btnCap2.Parent = oscRow
Instance.new("UICorner", btnCap2).CornerRadius = UDim.new(0, 6)

local btnOscil = Instance.new("TextButton")
btnOscil.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
btnOscil.Text = "OSCIL: OFF"
btnOscil.TextColor3 = Color3.fromRGB(220, 230, 245)
btnOscil.TextSize = 10
btnOscil.Font = Enum.Font.GothamBold
btnOscil.Parent = oscRow
Instance.new("UICorner", btnOscil).CornerRadius = UDim.new(0, 6)

local boxCap1 = Instance.new("TextBox")
boxCap1.Size = UDim2.new(0, 70, 0, 26)
boxCap1.Position = UDim2.new(0, 8, 0, 46)
boxCap1.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
boxCap1.Text = "255"
boxCap1.TextColor3 = Color3.fromRGB(255, 255, 255)
boxCap1.TextSize = 10
boxCap1.Font = Enum.Font.GothamBold
boxCap1.Parent = oscBox
Instance.new("UICorner", boxCap1).CornerRadius = UDim.new(0, 5)

local boxCap2 = Instance.new("TextBox")
boxCap2.Size = UDim2.new(0, 70, 0, 26)
boxCap2.Position = UDim2.new(0, 86, 0, 46)
boxCap2.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
boxCap2.Text = "0"
boxCap2.TextColor3 = Color3.fromRGB(255, 255, 255)
boxCap2.TextSize = 10
boxCap2.Font = Enum.Font.GothamBold
boxCap2.Parent = oscBox
Instance.new("UICorner", boxCap2).CornerRadius = UDim.new(0, 5)

local boxSpeed = Instance.new("TextBox")
boxSpeed.Size = UDim2.new(0, 70, 0, 26)
boxSpeed.Position = UDim2.new(0, 164, 0, 46)
boxSpeed.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
boxSpeed.Text = "1.0"
boxSpeed.TextColor3 = Color3.fromRGB(255, 255, 255)
boxSpeed.TextSize = 10
boxSpeed.Font = Enum.Font.GothamBold
boxSpeed.Parent = oscBox
Instance.new("UICorner", boxSpeed).CornerRadius = UDim.new(0, 5)

local btnApplyOsc = Instance.new("TextButton")
btnApplyOsc.Size = UDim2.new(0, 96, 0, 26)
btnApplyOsc.Position = UDim2.new(1, -104, 0, 46)
btnApplyOsc.BackgroundColor3 = Color3.fromRGB(45, 145, 200)
btnApplyOsc.Text = "Set Oscil"
btnApplyOsc.TextColor3 = Color3.fromRGB(255, 255, 255)
btnApplyOsc.TextSize = 10
btnApplyOsc.Font = Enum.Font.GothamBold
btnApplyOsc.Parent = oscBox
Instance.new("UICorner", btnApplyOsc).CornerRadius = UDim.new(0, 5)

local lblOscHint = Instance.new("TextLabel")
lblOscHint.Size = UDim2.new(1, -16, 0, 24)
lblOscHint.Position = UDim2.new(0, 8, 0, 82)
lblOscHint.BackgroundTransparency = 1
lblOscHint.Text = "Cap1 | Cap2 | Speed (1.0x)"
lblOscHint.TextColor3 = Color3.fromRGB(140, 155, 175)
lblOscHint.TextSize = 9
lblOscHint.Font = Enum.Font.Gotham
lblOscHint.TextXAlignment = Enum.TextXAlignment.Left
lblOscHint.Parent = oscBox

btnOscil.MouseButton1Click:Connect(function()
	gerakState.oscil = not gerakState.oscil
	btnOscil.Text = gerakState.oscil and "OSCIL: ON" or "OSCIL: OFF"
	pushGerakan()
end)

btnApplyOsc.MouseButton1Click:Connect(function()
	gerakState.cap1 = math.clamp(tonumber(boxCap1.Text) or 255, 0, 255)
	gerakState.cap2 = math.clamp(tonumber(boxCap2.Text) or 0, 0, 255)
	gerakState.speed = math.max(0.05, tonumber(boxSpeed.Text) or 1.0)
	btnCap1.Text = "CAP 1: " .. gerakState.cap1
	btnCap2.Text = "CAP 2: " .. gerakState.cap2
	lblOscHint.Text = string.format("Cap1 %d | Cap2 %d | Speed %.1fx", gerakState.cap1, gerakState.cap2, gerakState.speed)
	pushGerakan()
end)

-- =========================================================
-- 3. PAGE MAIN MENU (Preset & Quick Override)
-- =========================================================
local mainPage = Instance.new("Frame")
mainPage.Size = UDim2.new(1, 0, 1, 0)
mainPage.BackgroundTransparency = 1
mainPage.Visible = false
mainPage.Parent = pageArea

local mainScroll = Instance.new("ScrollingFrame")
mainScroll.Size = UDim2.new(1, 0, 1, 0)
mainScroll.BackgroundTransparency = 1
mainScroll.ScrollBarThickness = 3
mainScroll.Parent = mainPage

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 8)
mainLayout.Parent = mainScroll

local function addPresetSection(sectionTitle, items, category)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.BackgroundTransparency = 1
	lbl.Text = sectionTitle
	lbl.TextColor3 = Color3.fromRGB(190, 205, 225)
	lbl.TextSize = 10
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = mainScroll

	local gridFrame = Instance.new("Frame")
	gridFrame.Size = UDim2.new(1, -4, 0, math.ceil(#items / 4) * 32)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = mainScroll

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -4, 0, 28)
	grid.CellPadding = UDim2.new(0, 5, 0, 4)
	grid.Parent = gridFrame

	for _, label in ipairs(items) do
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
		b.Text = label
		b.TextColor3 = Color3.fromRGB(220, 230, 245)
		b.TextSize = 9
		b.Font = Enum.Font.GothamBold
		b.Parent = gridFrame
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

		b.MouseButton1Click:Connect(function()
			onMainAction(category, label)
		end)
	end
end

addPresetSection("Quick Override", { "Blinder", "Fog", "Hold", "Blackout" }, "Override")
addPresetSection("Dimmer & Strobe", { "Full", "Half", "Strobe Slow", "Strobe Fast" }, "DimmerStrobe")
addPresetSection("Colour", { "Red", "Green", "Blue", "White" }, "Colour")
addPresetSection("Beam / Prisma / Gobo", { "Gobo 1", "Prisma", "Prisma Lin", "Off" }, "BeamAttr")

mainScroll.CanvasSize = UDim2.new(0, 0, 0, 320)

-- =========================================================
-- NAVIGASI TAB, MINIMIZE, CLOSE & PATCH ACTION
-- =========================================================
local function setTab(tabName)
	activeTab = tabName
	patchPage.Visible = (tabName == "Patch")
	gerakanPage.Visible = (tabName == "Gerakan")
	mainPage.Visible = (tabName == "Main")

	local activeColor = Color3.fromRGB(45, 145, 200)
	local idleColor = Color3.fromRGB(28, 35, 45)
	tabPatch.BackgroundColor3 = (tabName == "Patch") and activeColor or idleColor
	tabGerakan.BackgroundColor3 = (tabName == "Gerakan") and activeColor or idleColor
	tabMain.BackgroundColor3 = (tabName == "Main") and activeColor or idleColor
end

tabPatch.MouseButton1Click:Connect(function() setTab("Patch") end)
tabGerakan.MouseButton1Click:Connect(function() setTab("Gerakan") end)
tabMain.MouseButton1Click:Connect(function() setTab("Main") end)

btnMinimize.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		contentContainer.Visible = false
		mainFrame.Size = UDim2.new(0, 380, 0, 34)
		btnMinimize.Text = "+"
	else
		contentContainer.Visible = true
		mainFrame.Size = UDim2.new(0, 380, 0, 480)
		btnMinimize.Text = "-"
	end
end)

btnClose.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

btnDropdown.MouseButton1Click:Connect(function()
	selectedPresetIndex = selectedPresetIndex + 1
	if selectedPresetIndex > #fixturePresets then selectedPresetIndex = 1 end
	btnDropdown.Text = fixturePresets[selectedPresetIndex].name .. " 🗲"
end)

btnUniv.MouseButton1Click:Connect(function()
	selectedUniverse = (selectedUniverse == 1) and 2 or 1
	btnUniv.Text = "U" .. tostring(selectedUniverse)
end)

btnAdd.MouseButton1Click:Connect(function()
	local qty = math.clamp(tonumber(boxCount.Text) or 1, 1, 64)
	local preset = fixturePresets[selectedPresetIndex]
	for _ = 1, qty do
		table.insert(addedFixtures, {
			name = preset.name:gsub(" %(%d+ch%)", ""),
			ch = preset.ch,
			universe = selectedUniverse,
		})
	end
	refreshPatchUI()
end)

btnClearAll.MouseButton1Click:Connect(function()
	addedFixtures = {}
	refreshPatchUI()
end)

setTab("Patch")
refreshPatchUI()
