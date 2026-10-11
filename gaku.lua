-- Xeno/Solara-PC: inisialisasi awal _G.VH sebelum UI library dimuat
if type(_G.VH) ~= "table" then _G.VH = {} end

-- [FIX Xeno] Global require hook DIHAPUS.
-- hookfunction(require, ...) di Xeno/Solara mencegat require milik GAME (CombatInputReplication,
-- Network.Client) dan memicu "Cannot require a RobloxScript module from a non RobloxScript context"
-- serta "attempt to call a table value" -> mode bertarung tidak bisa dipencet.
-- Semua require internal script sudah dibungkus pcall/_safeReq masing-masing, jadi hook global tidak perlu.

-- [FIX Xeno v2] Penguras queue event "CombatHighlightClear".
-- Warning spam Blink "Event queue exceeded 256" terjadi kalau listener combat client game
-- tidak sempat connect. Pasang listener no-op (tanpa require modul, 100% aman dari identity
-- check) agar queue selalu terkuras -> warning tidak akan muncul lagi, apapun akar masalahnya.
task.spawn(function()
    pcall(function()
        local _rs = game:GetService("ReplicatedStorage")
        local _found = 0
        for _, _d in ipairs(_rs:GetDescendants()) do
            if _d:IsA("RemoteEvent") and (string.find(_d.Name, "HighlightClear", 1, true) or _d.Name == "CombatHighlightClear") then
                pcall(function() _d.OnClientEvent:Connect(function() end) end)
                _found = _found + 1
            end
        end
        -- kalau pakai RemoteFunction / bindable sekalian
        pcall(function()
            local _re = _rs:FindFirstChild("CombatHighlightClear", true)
            if _re and _re:IsA("RemoteEvent") then pcall(function() _re.OnClientEvent:Connect(function() end) end) end
        end)
    end)
end)

local Clavv
do
    local _uiOk, _uiLib = pcall(function()
        local _f = loadstring(game:HttpGet("https://raw.githubusercontent.com/clavvngep-stack/ngeanh/refs/heads/main/ui%20clavv.lua.txt"))
        if type(_f) ~= "function" then error("UI library loadstring gagal (HttpGet mati?)") end
        return _f()
    end)
    if not _uiOk or type(_uiLib) ~= "table" then
        warn("[Clavv Hub] Gagal memuat UI library: " .. tostring(_uiLib))
        return
    end
    Clavv = _uiLib
end

--[[============================================================================
  Clavv Hub | Gakuran — Clavv UI Edition (clean full migration)
  ----------------------------------------------------------------------------
  Sumber fitur : Clavv Hub (deobfuscated) — seluruh logika fitur, state _G.VH,
                 dan callback dipertahankan 100% apa adanya.
  UI Library   : Clavv UI Library (dimuat paling atas, baris pertama).
  Dibersihkan  : anti-tamper, do return end, loop beku while true, pengecekan
                 executor, key system, referensi Obsidian lama, heartbeat
                 server, dan seluruh kode sampah integritas.
  Toggle menu  : LeftControl (atau klik tombol logo).
  ============================================================================]]

local _ok, _err = xpcall(function()
	local lib, lib2, lib3, UserInputService, Players, RunService, ReplicatedStorage, VirtualInputManager, TeleportService, HttpService
	local Lighting, localPlayer, fn12, v16, tbl5, options, toggles, Block, vh, fn13
	local fn14, fn15, fn16, flag10, fn17, v17, v18, str5, n25, fn18
	local fn19, fn20, fn21, fn22, fn23, fn24, fn25, fn26, v19, v20
	local fn27, fn28

	do
--[[==========================================================================
  Replaces the 3 Obsidian loadstrings. All feature logic, callbacks,
  _G.VH state and behaviour are 100% original; only the UI renderer
  is swapped to Clavv. No Obsidian library is ever loaded.
  ==========================================================================]]
local _UIS = game:GetService("UserInputService")
local _Options, _Toggles, _Labels = {}, {}, {}
local _ClavvWin, _ClavvGui, _ClavvBg, _ClavvScale
local _KeybindListeners = {}
local _MenuCbs = {}
local _Palette = {
	Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 255, 50),
	Color3.fromRGB(50, 255, 50), Color3.fromRGB(0, 255, 120), Color3.fromRGB(50, 255, 255),
	Color3.fromRGB(50, 120, 255), Color3.fromRGB(124, 84, 196), Color3.fromRGB(180, 50, 255),
	Color3.fromRGB(255, 50, 200), Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 255, 255),
}
local function _hex(c) return string.format("%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)) end
local function _ensureGui()
	if _ClavvGui then return end
	local ok, parent = pcall(function() return Clavv:Parent() end)
	if not ok or not parent then return end
	_ClavvGui = parent:FindFirstChild("Clavv Hub")
	if _ClavvGui then
		_ClavvBg = _ClavvGui:FindFirstChild("Background")
		if _ClavvBg and not _ClavvBg:FindFirstChildOfClass("UIScale") then
			_ClavvScale = Instance.new("UIScale")
			_ClavvScale.Scale = 1
			_ClavvScale.Parent = _ClavvBg
		end
	end
end
_UIS.InputBegan:Connect(function(input, gp)
	for _, listener in ipairs(_KeybindListeners) do
		pcall(listener, input, gp)
	end
end)
local function _makeColorPicker(page, id, copts)
	local cur = copts.Default or Color3.fromRGB(255, 255, 255)
	_Options[id] = { Value = cur }
	local btn
	btn = page:Button({
		Title = copts.Title or id,
		Text = _hex(cur),
		Notify = false,
		Callback = function()
			local idx = 1
			for i, c in ipairs(_Palette) do
				if c.R == cur.R and c.G == cur.G and c.B == cur.B then idx = i break end
			end
			cur = _Palette[(idx % #_Palette) + 1]
			_Options[id].Value = cur
			pcall(function() btn.Parent.Title.Text = _hex(cur) end)
			if copts.Callback then pcall(copts.Callback, cur) end
		end,
	})
end
local _sectionOrders = setmetatable({}, { __mode = "k" })
local function makeSection(page, title, expanded)
	if expanded == nil then expanded = true end
	title = tostring(title or "Section")
	local section = {}
	local controls = {}
	local origHeights = {}
	local TS = game:GetService("TweenService")
	local PURPLE = Color3.fromRGB(108, 68, 170)
	_sectionOrders[page] = (_sectionOrders[page] or 0) + 1
	local baseOrder = _sectionOrders[page] * 1000
	local ctrlIdx = 0
	local function track(ctrl)
		pcall(function()
			local row = ctrl
			if typeof(row) ~= "Instance" then pcall(function() row = ctrl.Instance end) end
			if typeof(row) ~= "Instance" and typeof(ctrl) == "Instance" then
				local o = ctrl
				while o and o.Parent and not o.Parent:IsA("ScrollingFrame") do o = o.Parent end
				row = o
			end
			if typeof(row) ~= "Instance" and section._scroll then
				local kids = section._scroll:GetChildren()
				for i = #kids, 1, -1 do
					local c = kids[i]
					if c:IsA("GuiObject") and c.LayoutOrder == 0 and c.Name ~= "SectionSpacer" then row = c; break end
				end
			end
			if typeof(row) ~= "Instance" then return end
			ctrlIdx = ctrlIdx + 1
			row.LayoutOrder = baseOrder + ctrlIdx
			origHeights[row] = row.Size.Y.Offset
			table.insert(controls, row)
			if not expanded then
				row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, row.Size.Y.Scale, 0)
				row.Visible = false
			end
		end)
		return ctrl
	end
	function section:Toggle(a) return track(page:Toggle(a)) end
	function section:Slider(a) return track(page:Slider(a)) end
	function section:Button(a) return track(page:Button(a)) end
	function section:Dropdown(a) return track(page:Dropdown(a)) end
	function section:Input(a) return track(page:Input(a)) end
	function section:Paragraph(a) return track(page:Paragraph(a)) end
	local okH, arrowLabel = pcall(function()
		return page:RightLabel({ Title = title, Desc = "", Right = expanded and "v" or ">" })
	end)
	if not okH then arrowLabel = nil end
	pcall(function()
		local vec = arrowLabel and arrowLabel.Parent and arrowLabel.Parent.Parent
		if vec and typeof(vec) == "Instance" then
			local headerRows = vec.Parent
			if arrowLabel and arrowLabel.Text then arrowLabel.TextSize = 17 end
			local scrollFr = headerRows.Parent
			section._scroll = scrollFr
			local spacer = Instance.new("Frame")
			spacer.Name = "SectionSpacer"
			spacer.BackgroundTransparency = 1
			spacer.Size = UDim2.new(1, 0, 0, 10)
			spacer.LayoutOrder = baseOrder
			spacer.Parent = scrollFr
			headerRows.LayoutOrder = baseOrder + 1
			pcall(function()
				local s = headerRows:FindFirstChildOfClass("UIStroke")
				if s then s.Color = PURPLE; s.Thickness = 0.8 end
				for _, d in ipairs(headerRows:GetDescendants()) do
					if d:IsA("UIStroke") then d.Color = PURPLE; d.Thickness = 0.8 end
				end
			end)
			headerRows.BackgroundColor3 = Color3.fromRGB(34, 19, 56)
			headerRows.BackgroundTransparency = 0.3
			if not headerRows:FindFirstChildOfClass("UICorner") then
				local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 6); cr.Parent = headerRows
			end
			local vec2 = headerRows:FindFirstChild("Vectorize")
			if vec2 then
				local left = vec2:FindFirstChild("Left")
				if left then
					local txt = left:FindFirstChild("Text")
					if txt then
						local tl = txt:FindFirstChild("Title")
						if tl then tl.TextSize = 14; tl.Font = Enum.Font.GothamBold; tl.TextColor3 = Color3.fromRGB(190, 160, 255) end
					end
				end
			end
			local click = Instance.new("TextButton")
			click.Name = "SectionHeaderClick"
			click.BackgroundTransparency = 1
			click.Text = ""
			click.AutoButtonColor = false
			click.Position = UDim2.new(0, -12, 0, -6)
			click.Size = UDim2.new(1, 24, 1, 12)
			click.ZIndex = 200
			click.Parent = vec
			click.MouseButton1Click:Connect(function()
				expanded = not expanded
				pcall(function() if arrowLabel and arrowLabel.Text then arrowLabel.Text = expanded and "v" or ">" end end)
				for _, c in ipairs(controls) do
					pcall(function()
						if not (c and typeof(c) == "Instance") then return end
						local h = origHeights[c] or 40
						if expanded then
							c.Visible = true
							TS:Create(c, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, c.Size.Y.Scale, h),
							}):Play()
						else
							local tw = TS:Create(c, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
								Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, c.Size.Y.Scale, 0),
							})
							tw.Completed:Once(function() pcall(function() c.Visible = false end) end)
							tw:Play()
						end
					end)
				end
			end)
		end
	end)
	return section
end
local function _makeGroupbox(page)
	local gb = {}
	function gb:AddToggle(id, o)
		o = o or {}
		_Toggles[id] = { Value = o.Default or false }
		local syncing = false
		local clavvTog
		clavvTog = page:Toggle({
			Title = o.Text or id,
			Desc = o.Tooltip or "",
			Value = o.Default or false,
			Notify = false,
			Callback = function(v)
				if syncing then return end
				_Toggles[id].Value = v
				if o.Callback then pcall(o.Callback, v) end
			end,
		})
		local togShim = {}
		function togShim:AddKeyPicker(id2, ko)
			ko = ko or {}
			local kc = Enum.KeyCode[ko.Default or "P"] or Enum.KeyCode.P
			local st = o.Default or false
			if not ko.NoUI then
				local btn
				btn = page:Button({
					Title = ko.Text or id2,
					Text = ko.Default or "P",
					Notify = false,
					Callback = function()
						local conn
						conn = _UIS.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.Keyboard then
								kc = input.KeyCode
								pcall(function() btn.Parent.Title.Text = kc.Name end)
								conn:Disconnect()
								for _, cb in ipairs(_MenuCbs) do pcall(cb) end
							end
						end)
						task.delay(5, function() if conn then pcall(function() conn:Disconnect() end) end end)
					end,
				})
			end
			table.insert(_KeybindListeners, function(input, gp)
				if not gp and input.KeyCode == kc then
					st = not st
					syncing = true
					_Toggles[id].Value = st
					pcall(function() clavvTog.Value = st end)
					syncing = false
					if o.Callback then pcall(o.Callback, st) end
				end
			end)
			_Options[id2] = { Value = kc, OnChanged = function(self, cb) table.insert(_MenuCbs, cb) end }
			return togShim
		end
		return togShim
	end
	function gb:AddSlider(id, o)
		o = o or {}
		local s = page:Slider({
			Title = o.Text or id,
			Min = o.Min or 0,
			Max = o.Max or 100,
			Rounding = o.Rounding or 0,
			Value = o.Default or o.Min or 0,
			Notify = false,
			Callback = function(v) if o.Callback then pcall(o.Callback, v) end end,
		})
		_Options[id] = s
		return s
	end
	function gb:AddButton(a, f)
		local text, func
		if type(a) == "table" then text, func = a.Text or "Button", a.Func else text, func = a, f end
		return page:Button({ Title = text, Text = text, Notify = false, Callback = function() if func then pcall(func) end end })
	end
	function gb:AddDropdown(id, o)
		o = o or {}
		local vals = o.Values or {}
		local defVal = vals[o.Default or 1] or vals[1]
		local d = page:Dropdown({
			Title = o.Text or id,
			List = vals,
			Value = defVal,
			Notify = false,
			Callback = function(v) if o.Callback then pcall(o.Callback, v) end end,
		})
		_Options[id] = d
		return d
	end
	function gb:AddLabel(text, ...)
		local attr = page:Paragraph({ Title = tostring(text), Desc = "", Image = 129731842758907 })
		local lbl = {}
		function lbl:SetText(t) pcall(function() attr.Title = tostring(t) end) end
		function lbl:AddColorPicker(id, co) _makeColorPicker(page, id, co or {}); return lbl end
		function lbl:AddKeyPicker(id, ko)
			ko = ko or {}
			local kc = Enum.KeyCode[ko.Default or "LeftControl"] or Enum.KeyCode.LeftControl
			_Options[id] = { Value = kc, OnChanged = function(self, cb) table.insert(_MenuCbs, cb) end }
			if id == "MenuKeybind" then
				table.insert(_KeybindListeners, function(input, gp)
					if not gp and input.KeyCode == kc then
						_ensureGui()
						if _ClavvGui then _ClavvGui.Enabled = not _ClavvGui.Enabled end
					end
				end)
			elseif not ko.NoUI then
				local btn
				btn = page:Button({
					Title = ko.Text or id,
					Text = ko.Default or "P",
					Notify = false,
					Callback = function()
						local conn
						conn = _UIS.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.Keyboard then
								kc = input.KeyCode
								_Options[id].Value = kc
								pcall(function() btn.Parent.Title.Text = kc.Name end)
								conn:Disconnect()
								for _, cb in ipairs(_MenuCbs) do pcall(cb) end
							end
						end)
						task.delay(5, function() if conn then pcall(function() conn:Disconnect() end) end end)
					end,
				})
			end
			return lbl
		end
		table.insert(_Labels, { Text = "" })
		return lbl
	end
	function gb:AddInput(id, o)
		o = o or {}
		local i = page:Input({ Value = o.Default or "", Notify = false, Callback = function(v) if o.Callback then pcall(o.Callback, v) end end })
		_Options[id] = i
		return i
	end
	function gb:AddDivider() end
	return gb
end
local function _makeTab(page)
	local tab = {}
	function tab:AddLeftGroupbox(title, icon) return _makeGroupbox(makeSection(page, title)) end
	function tab:AddRightGroupbox(title, icon) return _makeGroupbox(makeSection(page, title)) end
	function tab:AddStaticLeftGroupbox(title, icon) pcall(function() page:Section(tostring(title or "")) end); return _makeGroupbox(page) end
	function tab:AddStaticRightGroupbox(title, icon) pcall(function() page:Section(tostring(title or "")) end); return _makeGroupbox(page) end
	return tab
end
lib = {
	ForceCheckbox = false,
	ShowToggleFrameInKeybinds = true,
	Options = _Options,
	Toggles = _Toggles,
	Labels = _Labels,
	Unloaded = false,
	ToggleKeybind = nil,
	ScreenGui = nil,
	WindowContainer = { Parent = nil },
	CreateWindow = function(self, args)
		args = args or {}
		_ClavvWin = Clavv:Window({ Title = args.Title or "Clavv Hub", SubTitle = "Gakuran | Clavv UI" })
		_ensureGui()
		self.ScreenGui = _ClavvGui
		self.WindowContainer = { Parent = _ClavvBg }
		local win = {}
		function win:AddTab(name, icon)
			local page = _ClavvWin:NewPage({ Title = tostring(name or "Tab"), Desc = tostring(name or ""), Icon = 129731842758907 })
			return _makeTab(page)
		end
		return win
	end,
	Toggle = function(self, vis) _ensureGui(); if _ClavvGui then _ClavvGui.Enabled = vis and true or false end end,
	SetDPIScale = function(self, n) _ensureGui(); if _ClavvScale then _ClavvScale.Scale = (tonumber(n) or 100) / 100 end end,
	Unload = function(self) self.Unloaded = true; _ensureGui(); if _ClavvGui then pcall(function() _ClavvGui:Destroy() end) end end,
	Notify = function(self, text, dur) local t = tostring(text or ""); if t:lower():find("block in") then return end; pcall(function() Clavv:Notify(t, dur) end) end, -- DISABLED: sembunyikan notifikasi "Animation, block in XXXms"
}
lib2 = { SetLibrary = function() end, SetFolder = function() end, SetDefaultTheme = function() end, ApplyToTab = function() end, LoadDefault = function() end }
lib3 = { SetLibrary = function() end, IgnoreThemeSettings = function() end, SetIgnoreIndexes = function() end, SetFolder = function() end, BuildConfigSection = function() end, LoadAutoloadConfig = function() end }
--[[==================== END CLAVV MIGRATION LAYER ======================]]
		lib.ForceCheckbox = false
		lib.ShowToggleFrameInKeybinds = true
		UserInputService = game:GetService("UserInputService")
		Players = game:GetService("Players")
		RunService = game:GetService("RunService")
		ReplicatedStorage = game:GetService("ReplicatedStorage")
		VirtualInputManager = game:GetService("VirtualInputManager")
		TeleportService = game:GetService("TeleportService")
		HttpService = game:GetService("HttpService")
		local Stats2
		Stats2 = game:GetService("Stats")
		Lighting = game:GetService("Lighting")
		localPlayer = Players.LocalPlayer
		local fn29

		do
			local MarketplaceService = game:GetService("MarketplaceService")
			local str6 = "https://discord.com/api/webhooks/1541130398522933270/yNkHYpMAdd3z2KrtgpftzgKHCI8GYHEVV9O-Ol4RWWq59baoSZU9qjcFAFCBylnrg5py"
			local value = rawget(_G, "VH")

			if type(value) == "table" then
				value.unloading = true
				value.silent = true

				if type(value.cleanup) == "function" then
					pcall(value.cleanup)
				end

				value.autoParryEnabled = false
				value.autoAttackEnabled = false
				value.autoEquipEnabled = false
				value.heartAutoEnabled = false
				value.rhythmAutoPerfectEnabled = false

				if value.AUTO_FACE_BIND_NAME then
					pcall(function()
						RunService:UnbindFromRenderStep(value.AUTO_FACE_BIND_NAME)
					end)
				end

				for _, v21 in ipairs({
					"noclipConnection",
					"noclipDescendantConnection",
					"flyConnection",
					"antiFlingConnection",
					"antiFlingPlayerAddedConnection",
					"noBlurConnection",
					"jetpackConnection",
					"spectateConnection",
					"spectateRespawnConnection",
					"hpM2Connection",
					"autoGreenConnection",
					"espConnection",
					"rhythmConnection",
					"visualsRenderConnection",
				}) do
					local v22 = value[v21]

					if v22 then
						pcall(function()
							v22:Disconnect()
						end)
					end
				end

				for _, v21 in ipairs({
					"connections",
					"returnByDeathConnections",
					"antiFlingCharConnections",
					"noBlurConnections",
					"noBlurEffectConnections",
				}) do
					local v22 = value[v21]

					if type(v22) == "table" then
						for _, v23 in pairs(v22) do
							pcall(function()
								v23:Disconnect()
							end)
						end
					end
				end

				if type(value.createdObjects) == "table" then
					for _, createdObject in ipairs(value.createdObjects) do
						pcall(function()
							createdObject:Destroy()
						end)
					end
				end

				if type(value.espHL) == "table" then
					for _, v21 in pairs(value.espHL) do
						if type(v21.connections) == "table" then
							for _, connection in ipairs(v21.connections) do
								pcall(function()
									connection:Disconnect()
								end)
							end
						end

						if v21.highlight then
							pcall(function()
								v21.highlight:Destroy()
							end)
						end

						if v21.billboard then
							pcall(function()
								v21.billboard:Destroy()
							end)
						end

						if v21.sideHud then
							pcall(function()
								v21.sideHud:Destroy()
							end)
						end

						if v21.hitboxVisual then
							pcall(function()
								v21.hitboxVisual:Destroy()
							end)
						end
					end
				end

				local library = value.library

				if type(library) == "table" and not library.Unloaded and type(library.Unload) == "function" then
					pcall(function()
						library:Unload()
					end)
				end
			end

			fn29 = function()
				local str7 = "Unknown"

				pcall(function()
					str7 = (identifyexecutor or getexecutorname or function()
						return "Unknown"
					end)()
				end)

				return str7
			end

			fn12 = function()
				if str6 == "" then
					return
				end
				local v21 = fn29()
				local str7 = "Unknown"

				pcall(function()
					local productInfo = MarketplaceService:GetProductInfo(game.PlaceId)

					if productInfo and productInfo.Name then
						str7 = productInfo.Name
					end
				end)

				local tbl6 = {}
				local embeds = {}
				local tbl7 = { title = "Clavv Hub Executed", color = 16711680 }
				local fields = {}
				local tbl8 = { name = "Player", value = localPlayer.Name .. " (" .. localPlayer.UserId .. ")", inline = true }
				local tbl9 = { name = "Game", value = str7 .. " (" .. game.PlaceId .. ")", inline = true }
				local tbl10 = { name = "Executor", value = v21, inline = true }
				local tbl11 = { name = "JobId", value = game.JobId, inline = false }
				local tbl12 = { name = "Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = false }
				fields[1] = tbl8
				fields[2] = tbl9
				fields[3] = tbl10
				fields[4] = tbl11
				fields[5] = tbl12
				tbl7.fields = fields
				embeds[1] = tbl7
				tbl6.embeds = embeds
				local v22 = http_request or request
				local request_

				if v22 then
					request_ = v22
				else
					request_ = syn and syn.request
				end

				local request_2 = request_ or http and http.request

				if request_2 then
					pcall(function()
						request_2({
							Url = str6,
							Method = "POST",
							Headers = { ["Content-Type"] = "application/json" },
							Body = HttpService:JSONEncode(tbl6),
						})
					end)
				end
			end
		end

		-- PC-only: deteksi mobile (fn30 / TouchEnabled) dihapus; paksa mode desktop
		v16 = false

		do
			-- PC-only: ukuran jendela tetap (tidak ada penyesuaian otomatis mobile)
			local v21, v22 = 580, 440

			local v23 = lib:CreateWindow({
				Title = "Clavv Hub",
				Footer = "Gakuran | discord.gg/zzxGxj27BN",
				Icon = 140588424731090,
				IconSize = UDim2.fromOffset(30, 30),
				NotifySide = "Right",
				ShowCustomCursor = true,
				Resizable = true,
				Center = true,
				AutoShow = true,
				Font = Enum.Font.Fantasy,
				Size = UDim2.fromOffset(v21, v22),
			})

			tbl5 = {
				Info = v23:AddTab("Info", "info"),
				Main = v23:AddTab("Combat", "swords"),
				Player = v23:AddTab("Player", "user"),
				Visuals = v23:AddTab("Visuals", "eye"),
				Fun = v23:AddTab("Fun", "gamepad"),
				Teleport = v23:AddTab("Teleport", "compass"),
				Settings = v23:AddTab("Settings", "settings"),
			}
		end

		options = lib.Options
		toggles = lib.Toggles
		_G.ESP_COLORS = { Players = Color3.fromRGB(255, 255, 255) }
		_G.ESP_TRANSPARENCY = { Players = 0.35 }
		_G.ESP_TYPE = { Players = "Outline" }
		_G.ESP_DISTANCE = 150
		_G.FLY_SPEED = 50
		_G.SHADOW_DIST = 40
		-- Solara-PC: tunggu Packages & CombatSystemClient siap (race condition saat inject awal;
		-- require yang gagal di-cache Roblox, jadi WAIT sebelum require pertama adalah kuncinya).
		pcall(function() ReplicatedStorage:WaitForChild("Packages", 8) end)
		pcall(function() ReplicatedStorage:WaitForChild("CombatSystemClient", 8) end)
		task.wait(1.5) -- [FIX Xeno v2] biarkan game init combat & require modulnya lebih dulu (hindari race require dari identitas executor)
		-- [FIX XENO v3] JANGAN PERNAH jadi yang pertama require() modul game di Xeno/Solara.
-- Executor (identity 2) akan mencemari cache package.loaded -> saat game (RobloxScript)
-- require modul yang sama (Block/M1/M2/Equip/Evasive & Shared.Utils/Config), error
-- "Cannot require a non-RobloxScript module from a RobloxScript" -> mode combat rusak.
-- _cachedReq hanya mengembalikan modul yang SUDAH di-cache game. Belum ada? return nil
-- (pakai fallback/stub). Loop background meng-upgrade stub ke modul asli begitu game
-- selesai me-require-nya (setelah player pertama kali masuk combat) -> fitur presisi
-- (timing parry, deteksi style) menyala otomatis tanpa pernah mencemari cache.
local _pkgLoaded = nil
pcall(function() _pkgLoaded = package.loaded end)
if not _pkgLoaded then pcall(function() _pkgLoaded = debug.getregistry()["LOADED"] end) end
local _VIMx = game:GetService("VirtualInputManager")
local _lastParryPress = 0
local function _pressKey(kc, hold)
	pcall(function() _VIMx:SendKeyEvent(true, kc, false, game) end)
	if hold ~= false then
		task.delay(hold or 0.12, function() pcall(function() _VIMx:SendKeyEvent(false, kc, false, game) end) end)
	end
end
-- stub aksi: kalau modul Block/Evasive belum bisa diambil, simulasi tombol (sama seperti N0YO HUB)
local _stubBlock = {
	Block = function() local n = os.clock(); if n - _lastParryPress < 0.2 then return end; _lastParryPress = n; _pressKey(Enum.KeyCode.F, false) end,
	Unblock = function() pcall(function() _VIMx:SendKeyEvent(false, Enum.KeyCode.F, false, game) end) end,
}
local _stubEvasive = { Evasive = function() _pressKey(Enum.KeyCode.Q, 0.1) end }
local _nilStub = setmetatable({}, { __index = function() return nil end })
local function _cachedReq(mod)
	if typeof(mod) ~= "Instance" then return nil end
	local cached = false
	pcall(function() if _pkgLoaded and rawget(_pkgLoaded, mod) ~= nil then cached = true end end)
	if cached then
		local _ok, _r = pcall(require, mod)
		if _ok then return _r end
	end
	return nil
end
local _safeReq = _cachedReq

		local CombatConfig
		CombatConfig = _safeReq(ReplicatedStorage.Shared.Config.CombatConfig)
		Block = _safeReq(ReplicatedStorage.CombatSystemClient.Combat.Base.Block)
		local M1
		M1 = _safeReq(ReplicatedStorage.CombatSystemClient.Combat.Base.M1)
		local Equip
		Equip = _safeReq(ReplicatedStorage.CombatSystemClient.Combat.Base.Equip)
		local Evasive
		Evasive = _safeReq(ReplicatedStorage.CombatSystemClient.Combat.Base.Evasive)
		local CombatAnimationUtils
		CombatAnimationUtils = _safeReq(ReplicatedStorage.Shared.Utils.CombatAnimationUtils)
		pcall(_cachedReq, ReplicatedStorage.Shared.Utils.CombatStepUtils)
		local CombatUtils
		CombatUtils = nil

		pcall(function()
			CombatUtils = _cachedReq(ReplicatedStorage.Shared.Utils.CombatUtils)
		end)

		local M2
		M2 = _safeReq(ReplicatedStorage.CombatSystemClient.Combat.Base.M2)
		local CombatConfig2
		CombatConfig2 = _safeReq(ReplicatedStorage.Shared.Config.CombatConfig)
		-- [FIX XENO v3] fallback stubs: indexing nil tidak crash; Block/Evasive pakai simulasi tombol
		CombatConfig = CombatConfig or _nilStub
		CombatConfig2 = CombatConfig2 or _nilStub
		CombatUtils = CombatUtils or _nilStub
		CombatAnimationUtils = CombatAnimationUtils or _nilStub
		Block = Block or _stubBlock
		M1 = M1 or _nilStub
		M2 = M2 or _nilStub
		Equip = Equip or _nilStub
		Evasive = Evasive or _stubEvasive
		task.spawn(function()
			for _ = 1, 40 do
				task.wait(3)
				pcall(function()
					if Block == _stubBlock then local r = _cachedReq(ReplicatedStorage.CombatSystemClient.Combat.Base.Block); if r then Block = r end end
					if M1 == _nilStub then local r = _cachedReq(ReplicatedStorage.CombatSystemClient.Combat.Base.M1); if r then M1 = r end end
					if M2 == _nilStub then local r = _cachedReq(ReplicatedStorage.CombatSystemClient.Combat.Base.M2); if r then M2 = r end end
					if Equip == _nilStub then local r = _cachedReq(ReplicatedStorage.CombatSystemClient.Combat.Base.Equip); if r then Equip = r end end
					if Evasive == _stubEvasive then local r = _cachedReq(ReplicatedStorage.CombatSystemClient.Combat.Base.Evasive); if r then Evasive = r end end
					if CombatConfig == _nilStub then local r = _cachedReq(ReplicatedStorage.Shared.Config.CombatConfig); if r then CombatConfig = r end end
					if CombatAnimationUtils == _nilStub then local r = _cachedReq(ReplicatedStorage.Shared.Utils.CombatAnimationUtils); if r then CombatAnimationUtils = r end end
					if CombatUtils == _nilStub then local r = _cachedReq(ReplicatedStorage.Shared.Utils.CombatUtils); if r then CombatUtils = r end end
				end)
			end
		end)

		-- [FIX] Inisialisasi _G.VH default SEBELUM module dipakai (spec urutan #3)
		if type(_G.VH) ~= "table" then _G.VH = {} end
		vh = _G.VH

		-- [FIX] Notifikasi jika module game penting gagal dimuat (spec #5)
		do
			local _failed = {}
			local _check = { Block=Block, M1=M1, Equip=Equip, Evasive=Evasive, M2=M2, CombatUtils=CombatUtils, CombatConfig=CombatConfig, CombatAnimationUtils=CombatAnimationUtils }
			for _name, _mod in pairs(_check) do
				if not _mod then table.insert(_failed, _name) end
			end
			if #_failed > 0 then
				warn("[SAFE-REQUIRE] Module gagal dimuat: " .. table.concat(_failed, ", "))
				pcall(function() lib:Notify("Beberapa fitur mungkin terbatas — module game tidak terdeteksi: " .. table.concat(_failed, ", "), 6) end)
			end
		end

		_G.VH = _G.VH or {}
		vh = _G.VH
		_G.VH.library = lib
		_G.VH.autoParryEnabled = false
		_G.VH.autoFaceEnabled = false
		_G.VH.pingCompEnabled = true -- Ping Compensation selalu aktif di background
		_G.VH.autoAttackEnabled = false
		_G.VH.autoEquipEnabled = false
		_G.VH.parryDistance = 20
		_G.VH.parryLead = 0.14
		_G.VH.noDodgeCooldownEnabled = false
		_G.VH.espEnabled = false
		_G.VH.espBodyEnabled = true
		_G.VH.espBodyMode = "Outline"
		_G.VH.espNameEnabled = true
		_G.VH.espNickEnabled = true
		_G.VH.espHealthEnabled = true
		_G.VH.espStyleEnabled = true
		_G.VH.espDistance = 150 -- ESP lag fix: reduced from 500
		_G.VH.espHitboxEnabled = false
		_G.VH.espDistanceEnabled = false
		_G.VH.enemyHudEnabled = false
		_G.VH.myStamina = 100
		_G.VH.m2Duration = 2.5
		_G.VH.m2EndsAt = 0
		_G.VH.colorHitbox = Color3.fromRGB(255, 50, 50)
		_G.VH.colorThreatClose = Color3.fromRGB(0, 255, 120)
		_G.VH.colorThreatFar = Color3.fromRGB(255, 50, 50)
		_G.VH.sideHudEnabled = false
		_G.VH.sideCooldownsEnabled = false
		_G.VH.colorHudM2 = Color3.fromRGB(255, 105, 105)
		_G.VH.colorHudDodge = Color3.fromRGB(255, 190, 60)
		_G.VH.colorHudLife = Color3.fromRGB(80, 235, 125)
		_G.VH.colorHudStamina = Color3.fromRGB(65, 165, 255)
		_G.VH.threatZoneEnabled = false
		_G.VH.parryIndicatorEnabled = false
		_G.VH.threatRangeInReach = 7.5
		_G.VH.threatRangeDanger = 18
		_G.VH.fpsBoostEnabled = false
		_G.VH.fpsBoostSaved = {}
		_G.VH.antiFlingEnabled = false
		_G.VH.antiVoidEnabled = false
		_G.VH.flyEnabled = false
		_G.VH.noclipEnabled = false
		_G.VH.blinkOn = false
		_G.VH.returnByDeathEnabled = false
		_G.VH.autoGreenEnabled = false
		_G.VH.rhythmAutoPerfectEnabled = false
		_G.VH.jetpackEnabled = false
		_G.VH.infCamZoomEnabled = false
		_G.VH.heartAutoEnabled = false
		_G.VH.heartMonitorRunning = false
		_G.VH.noBlurEnabled = false
		_G.VH.blinkDist = 40
		_G.VH.flySpeed = 50
		_G.VH.originalFallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight
		_G.VH.espHL = {}
		_G.VH.noclipConnection = nil
		_G.VH.flyConnection = nil
		_G.VH.blinkCooldown = false
		_G.VH.antiFlingConnection = nil
		_G.VH.originalCanCollide = setmetatable({}, { __mode = "k" })
		_G.VH.antiFlingPartsByChar = {}
		_G.VH.antiFlingCharConnections = {}
		_G.VH.noBlurConnection = nil
		_G.VH.noBlurConnections = {}
		_G.VH.noBlurEffectConnections = {}
		_G.VH.noBlurStates = {}
		_G.VH.noDodgeCooldownModule = nil
		_G.VH.noDodgeCooldownOriginal = nil
		_G.VH.noDodgeCooldownHook = nil
		_G.VH.returnByDeathPosition = nil
		_G.VH.returnByDeathToken = 0
		_G.VH.returnByDeathConnections = {}
		_G.VH.flyGyro = nil
		_G.VH.flyVelocity = nil
		_G.VH.flyAttachment = nil
		_G.VH.flyHumanoid = nil
		_G.VH.flyOriginalAutoRotate = nil
		_G.VH.flyEnabledNoclip = false
		_G.VH.flyLastUpdate = 0
		_G.VH.hpM2CooldownSchedule = nil
		_G.VH.hpM2CooldownFallbackStartedAt = nil
		_G.VH.dodgeEndsAt = 0
		_G.VH.dodgeDuration = 2.5
		_G.VH.autoParryPulse = 0
		_G.VH.faceCharacter = nil
		_G.VH.faceTarget = nil
		_G.VH.faceHumanoid = nil
		_G.VH.oldAutoRotate = nil
		_G.VH.faceUntil = 0
		_G.VH.spectateTarget = nil
		_G.VH.spectateConnection = nil
		_G.VH.spectateRespawnConnection = nil
		_G.VH.spectateName = ""
		_G.VH.teleportName = ""
		_G.VH.jetpackVelocity = nil
		_G.VH.jetpackConnection = nil
		_G.VH.jetpackLastUpdate = 0
		_G.VH.autoGreenReleased = false
		_G.VH.autoGreenMarker = nil
		_G.VH.autoGreenWindow = nil
		_G.VH.autoGreenReadyAt = 0
		_G.VH.autoGreenLastUpdate = 0
		_G.VH.rhythmService = nil
		_G.VH.rhythmSession = nil
		_G.VH.rhythmHeldNotes = {}
		_G.VH.rhythmHeldLanes = {}
		_G.VH.rhythmTapReleaseAt = {}
		_G.VH.rhythmNextScanAt = 0
		_G.VH.rhythmCacheTimer = 0
		_G.VH.rejoinCooldown = false
		_G.VH.serverHopCooldown = false
		_G.VH.infCamZoomController = nil
		_G.VH.infCamZoomOriginalPopper = nil
		_G.VH.infCamZoomSavedMaxZoom = nil
		_G.VH.CONTROL = { F = 0, B = 0, L = 0, R = 0 }
		_G.VH.AUTO_FACE_BIND_NAME = "VenenoAutoFace"
		_G.VH.panelVisible = true
		_G.VH.rhythmCacheValid = false
		_G.VH.rhythmCachedSession = nil
		_G.VH.rhythmCachedService = nil
		_G.VH.rhythmConnection = nil
		_G.VH.rhythmLastStep = 0
		_G.VH.rhythmLastHeartbeat = 0
		_G.VH.espLastUpdate = 0
		_G.VH.espUpdateThreshold = 0.3 -- ESP lag fix: throttled
		_G.VH.antiFlingLastUpdate = 0
		_G.VH.antiFlingThreshold = 0.12 -- PC-only (nilai desktop; cabang mobile dihapus)
		_G.VH.connections = {}
		_G.VH.createdObjects = {}
		_G.VH.attackCatalog = {}
		_G.VH.autoGreenConnection = nil
		_G.VH.espConnection = nil
		_G.VH.visualsRenderConnection = nil
		_G.VH.antiFlingPlayerAddedConnection = nil
		_G.VH.noclipParts = {}
		_G.VH.noclipOriginal = setmetatable({}, { __mode = "k" })
		_G.VH.noclipDescendantConnection = nil
		_G.VH._notifyDebounce = {}
		_G.VH._notifyDebounceWindow = 0.15
		_G.VH._notifyLastCleanup = 0

		fn13 = function(arg)
			table.insert(_G.VH.connections, arg)
			return arg
		end

		local fn31

		fn31 = function()
			local n26 = 0

			pcall(function()
				n26 = Stats2.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
			end)

			if n26 <= 0 then
				pcall(function()
					n26 = localPlayer:GetNetworkPing()
				end)
			end

			return math.clamp(n26 or 0, 0, 0.4)
		end

		fn14 = function()
			local character = localPlayer.Character

			if character and character:GetAttribute("Equip") ~= true then
				pcall(function()
					Equip.Equip()
				end)
			end
		end

		do
			local function fn32()
				local dodgeEndsAt = _G.VH.dodgeEndsAt or 0
				if os.clock() < dodgeEndsAt then
					return
				end
				local character = localPlayer.Character
				local dodgeDuration = 1.5

				if character then
					local playerData = character:FindFirstChild("PlayerData")
					local attribute2 = playerData and playerData:GetAttribute("CombatStyle") or character:GetAttribute("CombatStyle")

					pcall(function()
						if CombatConfig and typeof(CombatConfig.GetCharacterEvasiveCooldown) == "function" then
							local v21 = CombatConfig.GetCharacterEvasiveCooldown(character, attribute2)

							if v21 and typeof(v21) == "number" and v21 > 0 then
								dodgeDuration = v21
							end
						end
					end)
				end

				_G.VH.dodgeDuration = dodgeDuration
				_G.VH.dodgeEndsAt = os.clock() + dodgeDuration
			end

			local function fn33()
				local m2EndsAt = _G.VH.m2EndsAt or 0
				if os.clock() < m2EndsAt then
					return
				end
				local character = localPlayer.Character
				local m2Duration = 10

				if character then
					local playerData = character:FindFirstChild("PlayerData")
					local attribute2 = playerData and playerData:GetAttribute("CombatStyle") or character:GetAttribute("CombatStyle")

					pcall(function()
						if CombatConfig2 and typeof(CombatConfig2.GetStyleM2Cooldown) == "function" then
							local v21 = CombatConfig2.GetStyleM2Cooldown(attribute2)

							if v21 and typeof(v21) == "number" and v21 > 0 then
								m2Duration = v21
							end
						end
					end)
				end

				_G.VH.m2Duration = m2Duration
				_G.VH.m2EndsAt = os.clock() + m2Duration
			end

			-- Solara-PC: bungkus hook dengan pcall; jika gagal, fungsi asli tetap utuh
			pcall(function()
				if typeof(Evasive) == "table" and typeof(Evasive.Evasive) == "function" then
					local evasive = Evasive.Evasive

					Evasive.Evasive = function(...)
						pcall(fn32)
						return evasive(...)
					end
				end
			end)

			-- Solara-PC: bungkus hook dengan pcall; jika gagal, fungsi asli tetap utuh
			pcall(function()
				if typeof(M2) == "table" and typeof(M2.OnM2Activated) == "function" then
					local onM2Activated = M2.OnM2Activated

					M2.OnM2Activated = function(...)
						pcall(fn33)
						return onM2Activated(...)
					end
				end
			end)

			fn13(UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then
					return
				end

				if input.KeyCode == Enum.KeyCode.Q then
					local character = localPlayer.Character

					if character and character:GetAttribute("IFRAMECD") ~= true then
						fn32()
					end
				elseif input.KeyCode == Enum.KeyCode.R then
					local character = localPlayer.Character

					if character and character:GetAttribute("M2Cooldown") ~= true then
						fn33()
					end
				end
			end))

			local function fn34(character)
				if not character then
					return
				end

				fn13(character:GetAttributeChangedSignal("M2Cooldown"):Connect(function()
					if character:GetAttribute("M2Cooldown") == true then
						fn33()
					end
				end))

				fn13(character:GetAttributeChangedSignal("IFRAMECD"):Connect(function()
					if character:GetAttribute("IFRAMECD") == true then
						fn32()
					end
				end))
			end

			if localPlayer.Character then
				fn34(localPlayer.Character)
			end

			fn13(localPlayer.CharacterAdded:Connect(fn34))
		end

		pcall(function()
			local Client = _cachedReq(ReplicatedStorage.Shared.Network.Client)

			if Client and Client.MovementStaminaUpdate and typeof(Client.MovementStaminaUpdate.On) == "function" then
				Client.MovementStaminaUpdate.On(function(myStamina)
					if typeof(myStamina) == "number" then
						_G.VH.myStamina = myStamina
					end
				end)
			end
		end)

		local animations = ReplicatedStorage:FindFirstChild("Animations")

		if animations then
			for _, descendant in ipairs(animations:GetDescendants()) do
				if descendant:IsA("Animation") then
					local match = descendant.AnimationId:match("%d+")

					if match then
						local str6 = descendant.Name:lower()
						local parent = descendant.Parent
						local str7 = "default"

						if parent and parent.Name ~= "BaseCombat" then
							str7 = parent.Name:lower():gsub("otheranims$", ""):gsub("anims$", "")
						end

						local num = tonumber(str6:match("^(%d)"))
						local flag11 = num ~= nil and str6:find("m1", 1, true) ~= nil
						local flag12 = str6:find("momentum", 1, true) ~= nil
						local flag13 = str6:find("crit", 1, true) ~= nil
						local flag14 = str6:find("attacker", 1, true) ~= nil
						local flag15 = str6:sub(1, 2) == "m2" or flag12 or flag13 or flag14

						if flag11 or flag15 then
							local n26 = 0.35

							if flag15 then
								if flag12 and str7 == "hakari" then
									pcall(function()
										n26 = CombatConfig.GetStyleM2HitboxDelay("hakari", true)
									end)
								else
									pcall(function()
										n26 = CombatConfig.GetStyleM2HitboxDelay(str7)
									end)
								end

								if not n26 or typeof(n26) ~= "number" then
									n26 = 0.5
								end
							else
								pcall(function()
									local getScaledStyleM1HitboxDelay = CombatConfig.GetScaledStyleM1HitboxDelay
									local v21 = str7
									local v22 = num
									local n27

									if num then
										n27 = v22
									else
										n27 = 1
									end

									n26 = getScaledStyleM1HitboxDelay(v21, n27, 1)
								end)

								if not n26 or typeof(n26) ~= "number" then
									n26 = 0.32
								end
							end

							_G.VH.attackCatalog[match] = {
								isM2 = flag15,
								combo = num or 1,
								isMomentum = flag12,
								isCrit = flag13,
								isGrapple = flag14,
								baseStyle = str7,
								fallbackDelay = n26,
								name = descendant.Name,
								folder = parent and parent.Name or "",
							}
						end
					end
				end
			end
		end

		local Account = tbl5.Info:AddStaticLeftGroupbox("Account", "user")
		Account:AddLabel("Username: " .. localPlayer.Name, true)
		Account:AddLabel("Display name: " .. localPlayer.DisplayName, true)
		Account:AddLabel("User ID: " .. tostring(localPlayer.UserId), true)
		Account:AddLabel("Account age: " .. tostring(localPlayer.AccountAge) .. " days", true)

		do
			local Environment = tbl5.Info:AddStaticLeftGroupbox("Environment", "monitor")
			Environment:AddLabel("Device: Desktop (PC build)", true)
			local v21 = Environment:AddLabel("Executor: " .. fn29(), true)

			Environment:AddButton("Refresh Executor", function()
				v21:SetText("Executor: " .. fn29())
				lib:Notify("Executor information refreshed", 2)
			end)
		end

		do
			local Session = tbl5.Info:AddStaticRightGroupbox("Session", "server")
			Session:AddLabel("Experience: Gakuran", true)
			Session:AddLabel("Place ID: " .. tostring(game.PlaceId), true)
			local str6 = " / " .. Players.MaxPlayers
			local v21 = Session:AddLabel("Players: " .. #Players:GetPlayers() .. str6, true)
			Session:AddLabel("Job ID: " .. (game.JobId ~= "" and game.JobId or "Unavailable"), true)
			local Links = tbl5.Info:AddStaticRightGroupbox("Links", "link")

			local function fn32()
				if type(setclipboard) == "function" then
					return setclipboard
				end
				local value = rawget(_G, "getgenv")

				if type(value) == "function" then
					local ok, result = pcall(value)
					if ok and type(result) == "table" and type(result.setclipboard) == "function" then
						return result.setclipboard
					end
				end
			end

			local function fn33(arg, arg2)
				Links:AddButton(arg, function()
					local v22 = fn32()

					if v22 then
						pcall(v22, arg2)
						lib:Notify(arg .. " link copied", 2)
					else
						lib:Notify("Clipboard is not supported by this executor", 3)
					end
				end)
			end

			fn33("Discord", "https://discord.gg/zzxGxj27BN")

			fn13(Players.PlayerAdded:Connect(function()
				local str7 = " / " .. Players.MaxPlayers
				v21:SetText("Players: " .. #Players:GetPlayers() .. str7)
			end))

			fn13(Players.PlayerRemoving:Connect(function()
				task.defer(function()
					local str7 = " / " .. Players.MaxPlayers
					v21:SetText("Players: " .. #Players:GetPlayers() .. str7)
				end)
			end))
		end

		fn15 = function(arg)
			for _, v21 in pairs(arg) do
				pcall(function()
					v21:Disconnect()
				end)
			end

			table.clear(arg)
		end

		fn16 = function(arg)
			local v21 = _G.VH[arg]

			if v21 then
				pcall(function()
					v21:Disconnect()
				end)

				_G.VH[arg] = nil
			end
		end

		flag10 = false

		fn17 = function(arg, arg2, arg3)
			if not flag10 or _G.VH and (_G.VH.unloading or _G.VH.silent) then
				return
			end
			arg = arg or "Clavv Hub"
			local str6 = arg2 or ""
			local str7 = arg .. "|" .. str6
			local now2 = os.clock()
			local v21 = _G.VH._notifyDebounce[str7]
			if v21 and now2 - v21 < _G.VH._notifyDebounceWindow then
				return
			end
			_G.VH._notifyDebounce[str7] = now2
			lib:Notify(tostring(arg) .. (str6 ~= "" and (": " .. tostring(str6)) or ""), arg3 or 3)

			if now2 - (_G.VH._notifyLastCleanup or 0) > 30 then
				_G.VH._notifyLastCleanup = now2

				for k, v22 in pairs(_G.VH._notifyDebounce) do
					if now2 - v22 > 30 then
						_G.VH._notifyDebounce[k] = nil
					end
				end
			end
		end

		v17 = nil
		v18 = nil
		str5 = "idle"
		n25 = 0

		local function fn32()
			if v17 then
				return
			end
			local screenGui = Instance.new("ScreenGui")
			screenGui.Name = "Veneno_ParryRing"
			screenGui.ResetOnSpawn = false
			screenGui.DisplayOrder = 110
			local frame2 = Instance.new("Frame")
			frame2.Name = "HaloRing"
			frame2.AnchorPoint = Vector2.new(0.5, 0.5)
			frame2.Position = UDim2.fromScale(0.5, 0.5)
			frame2.Size = UDim2.fromOffset(48, 48)
			frame2.BackgroundTransparency = 1
			frame2.BorderSizePixel = 0
			frame2.Parent = screenGui
			local uiCorner = Instance.new("UICorner")
			uiCorner.CornerRadius = UDim.new(1, 0)
			uiCorner.Parent = frame2
			local uiStroke = Instance.new("UIStroke")
			uiStroke.Name = "HaloStroke"
			uiStroke.Color = Color3.fromRGB(255, 220, 0)
			uiStroke.Thickness = 1.5
			uiStroke.Transparency = 1
			uiStroke.Parent = frame2

			pcall(function()
				if gethui then
					screenGui.Parent = gethui()
				else
					screenGui.Parent = game:GetService("CoreGui")
				end
			end)

			if not screenGui.Parent then
				screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
			end

			table.insert(_G.VH.createdObjects, screenGui)
			v17 = screenGui
			v18 = frame2
		end

		fn18 = function(arg)
			if not _G.VH.parryIndicatorEnabled then
				if v18 then
					v18.BackgroundTransparency = 1
					local haloStroke = v18:FindFirstChild("HaloStroke")

					if haloStroke then
						haloStroke.Transparency = 1
					end
				end

				return
			end

			fn32()
			if not v18 then
				return
			end
			str5 = arg
			n25 = os.clock() + 0.6
			local haloStroke = v18:FindFirstChild("HaloStroke")
			v18.Position = UDim2.fromScale(math.random(22, 78) / 100, math.random(22, 78) / 100)

			if arg == "incoming" then
				v18.Size = UDim2.fromOffset(48, 48)
				v18.BackgroundTransparency = 1

				if haloStroke then
					haloStroke.Color = Color3.fromRGB(255, 225, 0)
					haloStroke.Transparency = 0
					haloStroke.Thickness = 1.5
				end
			elseif arg == "success" then
				v18.Size = UDim2.fromOffset(54, 54)
				v18.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
				v18.BackgroundTransparency = 0.85

				if haloStroke then
					haloStroke.Color = Color3.fromRGB(0, 255, 120)
					haloStroke.Transparency = 0
					haloStroke.Thickness = 1.5
				end
			elseif arg == "failed" then
				v18.Size = UDim2.fromOffset(42, 42)
				v18.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				v18.BackgroundTransparency = 0.85

				if haloStroke then
					haloStroke.Color = Color3.fromRGB(255, 50, 50)
					haloStroke.Transparency = 0
					haloStroke.Thickness = 1.5
				end
			elseif arg == "idle" then
				v18.BackgroundTransparency = 1

				if haloStroke then
					haloStroke.Transparency = 1
				end
			end
		end

		fn19 = function()
			pcall(function()
				RunService:UnbindFromRenderStep(_G.VH.AUTO_FACE_BIND_NAME)
			end)

			_G.VH.faceCharacter = nil
			_G.VH.faceTarget = nil
			_G.VH.faceUntil = 0
		end

		local fn33

		do
			local function fn34(faceCharacter, faceTarget, arg)
				local humanoidRootPart = faceCharacter and faceCharacter:FindFirstChild("HumanoidRootPart")
				if not humanoidRootPart or not faceTarget then
					return
				end
				local n26 = arg or 0.45
				_G.VH.faceCharacter = faceCharacter
				_G.VH.faceTarget = faceTarget
				_G.VH.faceUntil = os.clock() + n26
				local vector = Vector3.new(faceTarget.Position.X, humanoidRootPart.Position.Y, faceTarget.Position.Z)
				local n27 = vector - humanoidRootPart.Position

				if n27.X * n27.X + n27.Z * n27.Z > 0.0001 then
					humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, vector)
				end

				pcall(function()
					RunService:BindToRenderStep(_G.VH.AUTO_FACE_BIND_NAME, Enum.RenderPriority.Camera.Value - 1, function()
						if _G.VH ~= vh or not _G.VH.autoFaceEnabled then
							fn19()
							return
						end
						local faceUntil = _G.VH.faceUntil
						if os.clock() > faceUntil then
							fn19()
							return
						end
						local character = localPlayer.Character
						character = character and character:FindFirstChild("HumanoidRootPart")
						local faceTarget2 = _G.VH.faceTarget
						if not character or not faceTarget2 or not faceTarget2.Parent then
							fn19()
							return
						end
						local position = character.Position
						local vector2 = Vector3.new(faceTarget2.Position.X, position.Y, faceTarget2.Position.Z)
						local n28 = vector2 - position

						if n28.X * n28.X + n28.Z * n28.Z > 0.0001 then
							character.CFrame = CFrame.lookAt(position, vector2)
						end
					end)
				end)
			end

			local function fn35(arg)
				return arg and arg.Parent and arg:GetAttribute("Equip") == true and arg:GetAttribute("Ragdoll") ~= true and arg:GetAttribute("Downed") ~= true and arg:GetAttribute("GuardBroken") ~= true and arg:GetAttribute("Greenzone") ~= true and arg:GetAttribute("RpCombatLocked") ~= true
			end

			local function fn36(arg, arg2)
				local vector = Vector3.new(arg2.Position.X - arg.Position.X, 0, arg2.Position.Z - arg.Position.Z)
				local vector2 = Vector3.new(arg.CFrame.LookVector.X, 0, arg.CFrame.LookVector.Z)
				local magnitude = vector.Magnitude
				if magnitude < 0.1 or vector2.Magnitude < 0.1 then
					return true
				end

				if magnitude <= 8 then
					return true
				end
				return vector.Unit:Dot(vector2.Unit) > 0
			end

			local tbl6 = {
				boxing = 0.72,
				mishima = 1.2,
				ali = 0.75,
				cqc = 0.72,
				wrestling = 0.7,
				kure = 0.7,
				capoeira = 0.72,
				slugger = 0.7,
				bulky = 0.7,
				hakari = 0.7,
				karate = 0.68,
				muaythai = 0.68,
				kickboxing = 0.68,
				kyokushin = 0.68,
				wingchun = 0.68,
				lethwei = 0.68,
				striker = 0.68,
			}


		--[[====================================================================
		  AUTO PARRY (MASTER) — FIX KRITIS vs source asli:
		  Equip check = localPlayer, ping selalu dikurangi, trigger semua char.
		  ====================================================================]]
		do
			local AP = { tracked = {}, lastTrigger = {}, parryActive = false, dodgeActive = false }
			local ATTACK_DB = {}
			local savedParries = {}
			local saveDirty = false
			local CombatConfig = nil
			local HSS = nil
			pcall(function() CombatConfig = _cachedReq(ReplicatedStorage.Shared.Config.CombatConfig) end)
			pcall(function() HSS = game:GetService("HttpService") end)
			local canFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

			local function saveProfiles()
				if not canFS or not HSS then return end
				pcall(function() writefile("GakuranAutoParry.json", HSS:JSONEncode({ parries = savedParries })) end)
			end
			if canFS and HSS then
				pcall(function()
					if isfile("GakuranAutoParry.json") then
						local data = HSS:JSONDecode(readfile("GakuranAutoParry.json"))
						if type(data) == "table" and type(data.parries) == "table" then savedParries = data.parries end
					end
				end)
			end
			task.spawn(function()
				while true do
					task.wait(5)
					if lib.Unloaded then return end
					if saveDirty then saveDirty = false saveProfiles() end
				end
			end)
			_G.VH._resetSavedParries = function()
				savedParries = {}
				saveDirty = true
				saveProfiles()
				pcall(function() if type(delfile) == "function" and isfile("GakuranAutoParry.json") then delfile("GakuranAutoParry.json") end end)
			end

			local function buildDB()
				ATTACK_DB = {}
				if not CombatConfig then return end
				local anims = ReplicatedStorage:FindFirstChild("Animations")
				local combat = anims and anims:FindFirstChild("Combat")
				if not combat then return end
				local m1idx = { ["1stM1"] = 1, ["2ndM1"] = 2, ["3rdM1"] = 3, ["4thM1"] = 4 }
				for _, folder in ipairs(combat:GetChildren()) do
					if folder:IsA("Folder") and folder.Name:sub(-5) == "Anims" then
						local styleFull = folder.Name:sub(1, #folder.Name - 5)
						local style = styleFull:lower()
						for _, anim in ipairs(folder:GetChildren()) do
							if anim:IsA("Animation") then
								local idNum = anim.AnimationId:match("%d+")
								local delay, kind, idx = nil, nil, m1idx[anim.Name]
								if idx and type(CombatConfig.GetScaledStyleM1HitboxDelay) == "function" then
									kind = "M1"
									local ok, d = pcall(CombatConfig.GetScaledStyleM1HitboxDelay, CombatConfig, style, idx, 1)
									if ok and type(d) == "number" then delay = d end
								elseif anim.Name == "M2" and type(CombatConfig.GetStyleM2HitboxDelay) == "function" then
									kind = "M2"
									local ok, d = pcall(CombatConfig.GetStyleM2HitboxDelay, CombatConfig, style)
									if ok and type(d) == "number" then
										if type(CombatConfig.GetScaledHitboxDelay) == "function" then
											local ok2, d2 = pcall(CombatConfig.GetScaledHitboxDelay, CombatConfig, d, 1)
											if ok2 and type(d2) == "number" then delay = d2 end
										else delay = d end
									end
								elseif anim.Name == "MomentumM2" and type(CombatConfig.GetStyleM2HitboxDelay) == "function" then
									kind = "M2M"
									local ok, d = pcall(CombatConfig.GetStyleM2HitboxDelay, CombatConfig, style, true)
									if ok and type(d) == "number" then
										if type(CombatConfig.GetScaledHitboxDelay) == "function" then
											local ok2, d2 = pcall(CombatConfig.GetScaledHitboxDelay, CombatConfig, d, 1)
											if ok2 and type(d2) == "number" then delay = d2 end
										else delay = d end
									end
								end
								if idNum and type(delay) == "number" and delay > 0 and not ATTACK_DB[idNum] then
									ATTACK_DB[idNum] = { name = styleFull .. "/" .. anim.Name, delay = delay, kind = kind, style = style, idx = idx }
								end
							end
						end
					end
				end
			end
			pcall(buildDB)
			task.delay(3, function() pcall(buildDB) end) -- Solara-PC: hindari nested task.spawn

			local function getPing()
				local ok, p = pcall(function() return localPlayer:GetNetworkPing() end)
				return (ok and type(p) == "number") and p or 0
			end

			local function executeParry(hold)
				if AP.parryActive then return end
				AP.parryActive = true
				task.spawn(function()
					local untilT = os.clock() + math.max(hold or 0.35, 0.05)
					while os.clock() < untilT do
						pcall(function() if Block then Block.Block() end end)
						task.wait()
					end
					pcall(function() if Block then Block.Unblock() end end)
					AP.parryActive = false
				end)
			end

			local function executeDodge(atkChar, direction)
				if AP.dodgeActive then return end
				AP.dodgeActive = true
				task.spawn(function()
					pcall(function()
						if Evasive and type(Evasive.Evasive) == "function" then
							Evasive.Evasive()
							local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
							local lv = hrp and hrp:FindFirstChild("EvasiveDashLinearVelocity")
							if lv and atkChar then
								local ahrp = atkChar:FindFirstChild("HumanoidRootPart")
								if ahrp then
									local dir
									if direction == "back" then
										local look = hrp.CFrame.LookVector
										dir = Vector3.new(-look.X, 0, -look.Z)
									else
										local away = hrp.Position - ahrp.Position
										dir = Vector3.new(away.X, 0, away.Z)
									end
									if dir.Magnitude > 0.001 then
										local mag = lv.VectorVelocity.Magnitude
										if mag < 1 then mag = 60 end
										lv.VectorVelocity = dir.Unit * mag
									end
								end
							end
						end
					end)
					task.wait(0.2)
					AP.dodgeActive = false
				end)
			end

			local function isBehind(atkChar, cosTh)
				local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
				local ahrp = atkChar and atkChar:FindFirstChild("HumanoidRootPart")
				if not hrp or not ahrp then return false end
				local dir = ahrp.Position - hrp.Position
				local flat = Vector3.new(dir.X, 0, dir.Z)
				if flat.Magnitude < 0.001 then return false end
				return hrp.CFrame.LookVector:Dot(flat.Unit) < cosTh
			end

			local function onAttack(plr, char, track)
				local c = _G.VH
				if not c or not c.autoParryEnabled then return end
				if not track or track.Looped then return end
				local animIdNum = ""
				pcall(function() animIdNum = tostring(track.Animation and track.Animation.AnimationId or ""):match("%d+") or "" end)
				local animName = track.Name or ""
				if animName == "Movement" or animName:lower():find("idle") or animName:lower():find("walk") or animName:lower():find("run") then return end
				-- FIX #1: Equip check = LOCAL PLAYER (kamu), bukan attacker (persis asli v1033)
				local myChar = localPlayer.Character
				if not myChar or myChar:GetAttribute("Equip") ~= true then return end
				if not char then return end
				local skip = false
				pcall(function() if plr and plr ~= localPlayer and plr:IsFriendsWith(localPlayer.UserId) then skip = true end end)
				if skip then return end

				local delaySec, attackName, kind, holdSec
				local saved = (animIdNum ~= "") and savedParries[animIdNum] or nil
				if saved and type(saved.delay) == "number" then
					delaySec = saved.delay
					holdSec = saved.hold
					attackName = saved.name or animName
				else
					local info = (animIdNum ~= "") and ATTACK_DB[animIdNum] or nil
					if info then
						delaySec = info.delay
						attackName = info.name
						kind = info.kind
						local ping = getPing()
						if kind == "M1" and info.idx and CombatConfig and type(CombatConfig.GetScaledStyleM1HitboxDelay) == "function" then
							local ok, d = pcall(CombatConfig.GetScaledStyleM1HitboxDelay, CombatConfig, info.style, info.idx, ping)
							if ok and type(d) == "number" and d > 0 then delaySec = d end
						elseif (kind == "M2" or kind == "M2M") and CombatConfig and type(CombatConfig.GetStyleM2HitboxDelay) == "function" then
							local ok, d = pcall(CombatConfig.GetStyleM2HitboxDelay, CombatConfig, info.style, kind == "M2M")
							if ok and type(d) == "number" then
								if type(CombatConfig.GetScaledHitboxDelay) == "function" then
									local ok2, d2 = pcall(CombatConfig.GetScaledHitboxDelay, CombatConfig, d, ping)
									if ok2 and type(d2) == "number" and d2 > 0 then delaySec = d2 end
								else delaySec = d end
							end
						end
					else
						if not c.autoParryAll then return end
						local low = (animName .. " " .. animIdNum):lower()
						if low:find("m2") or low:find("heavy") or low:find("strong") then delaySec, kind = 0.50, "M2"
						elseif low:find("kick") then delaySec, kind = 0.40, "Kick"
						elseif low:find("dash") or low:find("lunge") then delaySec, kind = 0.22, "Dash"
						else delaySec, kind = 0.28, "M1" end
						attackName = animName
					end
				end
				if not delaySec then return end

				local now = os.clock()
				local key = animIdNum .. "|" .. animName
				if AP.lastTrigger[key] and now - AP.lastTrigger[key] < 0.10 then return end -- Throttle = 0.10 (100ms) siap parry lagi

				local hold = holdSec or 0.35
				-- FIX #2: ping SELALU dikurangi (persis asli v1052/v1055), tanpa toggle
				local ping = getPing()
				local waitT = math.max(delaySec - (track.TimePosition or 0) - ping * 0.5 - 0.065, 0) -- TimingOffset -65ms (~125ms target), PingComp pingx0.5 selalu aktif

				local myHrp = myChar:FindFirstChild("HumanoidRootPart")
				local atkHrp = char:FindFirstChild("HumanoidRootPart")
				local dist = (myHrp and atkHrp) and (myHrp.Position - atkHrp.Position).Magnitude or nil

				if c.autoDodge and kind and (kind == "M2" or kind == "M2M") and dist and dist <= 20 then
					AP.lastTrigger[key] = now
					task.delay(waitT, function()
						if _G.VH and _G.VH.autoParryEnabled and _G.VH.autoDodge then executeDodge(char, "back") end
					end)
					return
				end
				if c.autoDodge then
					local angle = c.dodgeAngle or 85
					local cosTh = math.cos(math.rad(angle))
					if dist and dist <= 20 and isBehind(char, cosTh) then
						AP.lastTrigger[key] = now
						task.delay(waitT, function()
							if _G.VH and _G.VH.autoParryEnabled and _G.VH.autoDodge then
								if isBehind(char, cosTh) then executeDodge(char, "side") else executeParry(hold) end
							end
						end)
						return
					end
				end

				if dist == nil or dist > 75 then return end -- MaxRange = 75 (deteksi dari jarak aman)

				if not saved and animIdNum ~= "" then
					savedParries[animIdNum] = { delay = delaySec, hold = hold, name = attackName }
					saveDirty = true
				end

				AP.lastTrigger[key] = now
				task.delay(waitT, function()
					local c2 = _G.VH
					if not c2 or not c2.autoParryEnabled then return end
					if c2.antiApBreaker then
						local preset = tostring(c2.antiApBreakerPreset or "Medium")
						local attacking = char and (char:GetAttribute("CombatAttacking") == true
							or char:GetAttribute("M1") == true
							or char:GetAttribute("M2") == true
							or char:GetAttribute("PendingM2") == true)
						if preset == "Easy" and not track.IsPlaying then return end
						if preset == "Medium" and (not track.IsPlaying or not attacking) then return end
						if preset == "Strict" and (not track.IsPlaying or char:GetAttribute("CombatAttacking") ~= true) then return end
					end
					executeParry(hold)
				end)
			end

			local function untrack(char)
				local t = AP.tracked[char]
				if t then
					for _, cn in ipairs(t) do pcall(function() cn:Disconnect() end) end
					AP.tracked[char] = nil
				end
			end

			local function trackChar(char)
				if not char or AP.tracked[char] or char == localPlayer.Character then return end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hum then return end
				local conns = {}
				AP.tracked[char] = conns
				local function hookIt(obj)
					local ok, cn = pcall(function()
						return obj.AnimationPlayed:Connect(function(track)
							-- FIX #3: trigger SEMUA karakter kecuali local (termasuk NPC), persis asli
							if char ~= localPlayer.Character then
								local plr = Players:GetPlayerFromCharacter(char)
								task.spawn(onAttack, plr, char, track)
							end
						end)
					end)
					if ok and cn then table.insert(conns, cn) end
				end
				local animator = hum:FindFirstChildOfClass("Animator")
				if animator then hookIt(animator) end
				hookIt(hum)
				local ok2, cn2 = pcall(function()
					return hum.ChildAdded:Connect(function(ch) if ch:IsA("Animator") then hookIt(ch) end end)
				end)
				if ok2 and cn2 then table.insert(conns, cn2) end
			end

			-- AP Breaker
			task.spawn(function()
				local lastFeint = 0
				while true do
					task.wait(0.05)
					if lib.Unloaded then return end
					local c = _G.VH
					if c and c.apBreakerEnabled then
						local preset = tostring(c.apBreakerPreset or "Medium")
						local intensity = tonumber(c.apBreakerIntensity) or 50
						local factor = (preset == "Easy" and 1.6) or (preset == "Strict" and 0.55) or 1
						local interval = math.max(0.25, factor * (1.15 - math.clamp(intensity, 1, 100) / 100))
						if os.clock() - lastFeint >= interval then
							lastFeint = os.clock()
							pcall(function()
								local char = localPlayer.Character
								if not char then return end
								local hum = char:FindFirstChildOfClass("Humanoid")
								local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum)
								if not animator then return end
								local pd = char:FindFirstChild("PlayerData")
								local style = pd and (pd:GetAttribute("CombatStyle") or pd:GetAttribute("CombatType"))
								local animsF = ReplicatedStorage:FindFirstChild("Animations")
								local combat = animsF and animsF:FindFirstChild("Combat")
								if not combat or type(style) ~= "string" then return end
								local folder = combat:FindFirstChild(style .. "Anims") or combat:FindFirstChild(style)
								if not folder then
									local sl = style:lower():gsub("[^%w]", "")
									for _, f in ipairs(combat:GetChildren()) do
										if f:IsA("Folder") then
											local fl = f.Name:lower():gsub("anims$", ""):gsub("[^%w]", "")
											if fl == sl or fl == sl .. "other" then folder = f break end
										end
									end
								end
								if not folder then return end
								local anims = {}
								for _, a in ipairs(folder:GetChildren()) do if a:IsA("Animation") then table.insert(anims, a) end end
								if #anims == 0 then return end
								local pick = anims[math.random(1, #anims)]
								local tr = animator:LoadAnimation(pick)
								tr:Play()
								task.delay(0.15, function() pcall(function() tr:Stop() end) end)
							end)
						end
					end
				end
			end)

			pcall(function()
				if _G.VH.autoParryAll == nil then _G.VH.autoParryAll = false end
				if _G.VH.autoDodge == nil then _G.VH.autoDodge = false end
				if _G.VH.dodgeAngle == nil then _G.VH.dodgeAngle = 85 end
				if _G.VH.antiApBreaker == nil then _G.VH.antiApBreaker = false end
				if _G.VH.antiApBreakerPreset == nil then _G.VH.antiApBreakerPreset = "Medium" end
				if _G.VH.apBreakerEnabled == nil then _G.VH.apBreakerEnabled = false end
				if _G.VH.apBreakerPreset == nil then _G.VH.apBreakerPreset = "Medium" end
				if _G.VH.apBreakerIntensity == nil then _G.VH.apBreakerIntensity = 50 end
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= localPlayer and p.Character then trackChar(p.Character) end
					p.CharacterAdded:Connect(function(ch) task.wait(0.5) trackChar(ch) end)
				end
				Players.PlayerAdded:Connect(function(p)
					p.CharacterAdded:Connect(function(ch) task.wait(0.5) trackChar(ch) end)
					if p.Character then trackChar(p.Character) end
				end)
				Players.PlayerRemoving:Connect(function(p) if p.Character then untrack(p.Character) end end)
				for _, d in ipairs(workspace:GetDescendants()) do
					if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
						task.defer(trackChar, d.Parent)
					end
				end
			end)
		end

			local function fn37(arg, arg2)
				if true then return end -- [AUTO PARRY MASTER] logika lama dinonaktifkan
				local character = localPlayer.Character
				if not _G.VH.autoParryEnabled or not fn35(character) then
					return
				end
				_G.VH.autoParryPulse = _G.VH.autoParryPulse + 1
				local autoParryPulse = _G.VH.autoParryPulse

				if character:GetAttribute("Blocking") == true then
					pcall(Block.Unblock)
				end

				pcall(Block.Block)
				local n26 = 0.24

				if arg then
					if arg2 then
						n26 = tostring(arg2):lower():gsub("%s+", "")
					else
						n26 = arg2
					end

					n26 = n26 and tbl6[n26] or 0.68
				end

				task.delay(0.12, function() -- Solara-PC: hindari nested task.spawn
					local character2 = localPlayer.Character

					if character2 then
						if character2:GetAttribute("Ragdoll") == true or character2:GetAttribute("GuardBroken") == true then
							fn18("failed")
						else
							fn18("success")
						end
					end
				end)

				task.delay(n26, function()
					if _G.VH ~= vh or not _G.VH.autoParryEnabled then
						return
					end

					if autoParryPulse == _G.VH.autoParryPulse and character == localPlayer.Character and character:GetAttribute("Blocking") == true then
						pcall(Block.Unblock)
					end
				end)
			end

			local function fn38(arg, arg2)
				local attribute2 = nil

				if arg then
					pcall(function()
						attribute2 = CombatAnimationUtils.GetCombatStyleForCharacter(arg)
					end)

					if not attribute2 then
						local playerData = arg:FindFirstChild("PlayerData")

						if playerData then
							attribute2 = playerData:GetAttribute("CombatStyle")
						end
					end

					attribute2 = attribute2 or arg:GetAttribute("CombatStyle")
				end

				attribute2 = attribute2 or arg2 or "default"
				if CombatConfig.NormalizeStyleKey then
					return CombatConfig.NormalizeStyleKey(attribute2)
				end
				return tostring(attribute2):lower():gsub("%s+", "")
			end

			local tbl7 = {
				basic = "Basic",
				karate = "Karate",
				muaythai = "Muay Thai",
				slugger = "Slugger",
				kickboxing = "Kickboxing",
				boxing = "Boxing",
				striker = "Striker",
				lethwei = "Lethwei",
				wrestling = "Wrestling",
				capoeira = "Capoeira",
				kure = "Kure",
				hakari = "Hakari",
				kyokushin = "Kyokushin",
				ali = "Ali",
				wingchun = "Wing Chun",
				cqc = "CQC",
				mishima = "Mishima",
				skygaolang = "Skygaolang",
				taekwondo = "Taekwondo",
				bulky = "Bulky",
				dirty = "Dirty",
				wild = "Wild",
				variant = "Variant",
			}

			local function fn39(arg)
				local str6 = tostring(arg or ""):lower():gsub("%s+", "")
				if str6 == "basic" or str6 == "dirty" or str6 == "wild" then
					return Color3.fromRGB(240, 240, 240)
				end

				if str6 == "karate" or str6 == "muaythai" or str6 == "slugger" or str6 == "kickboxing" or str6 == "skygaolang" or str6 == "taekwondo" then
					return Color3.fromRGB(90, 160, 255)
				end

				if str6 == "boxing" or str6 == "striker" or str6 == "lethwei" or str6 == "bulky" then
					return Color3.fromRGB(185, 95, 255)
				end

				if str6 == "wrestling" or str6 == "capoeira" or str6 == "kure" or str6 == "hakari" or str6 == "kyokushin" then
					return Color3.fromRGB(255, 215, 60)
				end

				if str6 == "ali" or str6 == "wingchun" or str6 == "cqc" or str6 == "mishima" then
					return Color3.fromRGB(130, 220, 255)
				end
				local v21 = nil

				pcall(function()
					v21 = _cachedReq(ReplicatedStorage.Shared.Config.CombatStyleRarityConfig).GetColorForStyle(arg)
				end)

				if v21 and typeof(v21) == "Color3" then
					return v21
				end
				return Color3.fromRGB(240, 240, 240)
			end

			local function fn40(arg, arg2)
				local value = nil
				local character = arg2 or arg and arg.Character

				if character then
					local playerData = character:FindFirstChild("PlayerData")

					if playerData then
						local attribute2 = playerData:GetAttribute("CombatStyle")

						if typeof(attribute2) == "string" and attribute2 ~= "" then
							value = attribute2
						end

						if not value then
							local combatStyle = playerData:FindFirstChild("CombatStyle")

							if combatStyle and combatStyle:IsA("StringValue") and combatStyle.Value ~= "" then
								value = combatStyle.Value
							end
						end
					end

					if not value then
						local attribute2 = character:GetAttribute("CombatStyle")

						if typeof(attribute2) == "string" and attribute2 ~= "" then
							value = attribute2
						end
					end
				end

				if not value and arg then
					local playerData = arg:FindFirstChild("PlayerData")

					if playerData then
						local attribute2 = playerData:GetAttribute("CombatStyle")

						if typeof(attribute2) == "string" and attribute2 ~= "" then
							value = attribute2
						end

						if not value then
							local combatStyle = playerData:FindFirstChild("CombatStyle")

							if combatStyle and combatStyle:IsA("StringValue") and combatStyle.Value ~= "" then
								value = combatStyle.Value
							end
						end
					end

					if not value then
						local attribute2 = arg:GetAttribute("CombatStyle")

						if typeof(attribute2) == "string" and attribute2 ~= "" then
							value = attribute2
						end
					end
				end

				if not value and character then
					pcall(function()
						local v21 = CombatAnimationUtils.GetCombatStyleForCharacter(character)

						if typeof(v21) == "string" and v21 ~= "" then
							value = v21
						end
					end)
				end

				local str6 = value or "Basic"
				return tbl7[str6:lower():gsub("%s+", "")] or str6
			end

			local function fn41(arg, arg2)
				local character = arg2 or arg and arg.Character
				local playerData = character and character:FindFirstChild("PlayerData") or arg and arg:FindFirstChild("PlayerData")
				local value = nil
				local value2 = nil

				if playerData then
					local firstName = playerData:FindFirstChild("FirstName")

					if firstName and firstName:IsA("StringValue") and firstName.Value ~= "" then
						value2 = firstName.Value
					else
						value2 = playerData:GetAttribute("FirstName")
					end

					local lastName = playerData:FindFirstChild("LastName")

					if lastName and lastName:IsA("StringValue") and lastName.Value ~= "" then
						value = lastName.Value
					else
						value = playerData:GetAttribute("LastName")
					end
				end

				if not value2 and character then
					value2 = character:GetAttribute("FirstName")
					value = character:GetAttribute("LastName")
				end

				local concat = table.concat
				local tbl8 = {}
				value2 = value2 or ""
				value = value or ""
				tbl8[1] = value2
				tbl8[2] = value
				local match = concat(tbl8, " "):match("^%s*(.-)%s*$")
				if match and match ~= "" then
					return match
				end
				return "No RP Name"
			end

			local function fn42(arg)
				if not arg then
					return "Unknown"
				end

				if arg.DisplayName and arg.DisplayName ~= arg.Name then
					return arg.DisplayName .. " (@" .. arg.Name .. ")"
				end
				return "@" .. arg.Name
			end

			fn33 = function(arg, arg2)
				if not arg then
					return 100, 100
				end

				if arg2 == localPlayer or arg == localPlayer.Character then
					if typeof(_G.VH.myStamina) == "number" then
						return _G.VH.myStamina, 100
					end
				end

				for _, v21 in ipairs({ "Stamina", "RunStamina", "CurrentStamina", "Energy" }) do
					local attribute2 = arg:GetAttribute(v21)
					if typeof(attribute2) == "number" then
						return attribute2, arg:GetAttribute("Max" .. v21) or 100
					end
				end

				local playerData = arg:FindFirstChild("PlayerData") or arg2 and arg2:FindFirstChild("PlayerData")

				if playerData then
					for _, v21 in ipairs({ "Stamina", "RunStamina", "CurrentStamina", "Energy" }) do
						local attribute2 = playerData:GetAttribute(v21)
						if typeof(attribute2) == "number" then
							return attribute2, playerData:GetAttribute("Max" .. v21) or 100
						end
						local v22 = playerData:FindFirstChild(v21)
						if v22 and (v22:IsA("NumberValue") or v22:IsA("IntValue")) then
							return v22.Value, 100
						end
					end
				end

				if arg2 == localPlayer then
					local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")

					if playerGui then
						for _, v21 in ipairs({ "Stamina", "StaminaBar", "Energy", "RunBar" }) do
							local v22 = playerGui:FindFirstChild(v21, true)

							if v22 and v22:IsA("Frame") then
								local bar = v22:FindFirstChild("Bar") or v22:FindFirstChild("Fill") or v22
								if bar:IsA("Frame") and bar.Size.X.Scale > 0 then
									return bar.Size.X.Scale * 100, 100
								end
							end
						end
					end
				elseif arg2 and arg2 ~= localPlayer then
					local humanoidRootPart = arg:FindFirstChild("HumanoidRootPart")
					local userId = arg2.UserId or 0

					if not _G.VH.enemyStaminaCache then
						_G.VH.enemyStaminaCache = {}
					end

					if not _G.VH.enemyStaminaCache[userId] then
						_G.VH.enemyStaminaCache[userId] = { val = 100, lastTick = os.clock() }
					end

					local v21 = _G.VH.enemyStaminaCache[userId]
					local lastTick = v21.lastTick
					local n26 = math.clamp(os.clock() - lastTick, 0, 0.5)
					v21.lastTick = os.clock()

					if humanoidRootPart and humanoidRootPart.AssemblyLinearVelocity.Magnitude > 19 then
						v21.val = math.clamp(v21.val - 12 * n26, 0, 100)
					else
						v21.val = math.clamp(v21.val + 16 * n26, 0, 100)
					end

					return math.floor(v21.val), 100
				end

				return 100, 100
			end

			local function fn43(arg, arg2)
				if not _G.VH.autoParryEnabled or _G.VH.unloading then
					return
				end
				local animation = arg2.Animation
				local match = animation and animation.AnimationId:match("%d+")
				local attackCatalog = match and _G.VH.attackCatalog and _G.VH.attackCatalog[match]
				local fallbackDelay = attackCatalog and attackCatalog.fallbackDelay
				local isM2 = attackCatalog and attackCatalog.isM2 or false
				local str6 = animation and animation.Name:lower() or ""
				local flag11 = isM2 or str6:find("m2", 1, true) ~= nil or str6:find("armored", 1, true) ~= nil or str6:find("crit", 1, true) ~= nil or str6:find("heavy", 1, true) ~= nil or str6:find("shuffle", 1, true) ~= nil or str6:find("counter", 1, true) ~= nil or str6:find("slam", 1, true) ~= nil or str6:find("grab", 1, true) ~= nil or str6:find("kick", 1, true) ~= nil or str6:find("axe", 1, true) ~= nil
				local flag12 = not flag11
				local flag13 = flag12 and (attackCatalog ~= nil or str6:find("m1", 1, true) ~= nil or str6:match("^(%d)") ~= nil)
				if flag12 and not flag13 then
					return
				end
				local v21 = flag11

				if v21 and arg then
					local v22 = _G.VH.espHL[Players:GetPlayerFromCharacter(arg)]
					local flag14

					if v22 then
						flag14 = (v22.m2EndsAt or 0) <= os.clock()
					else
						flag14 = v22
					end

					if flag14 then
						local m2Duration = 10

						pcall(function()
							if CombatConfig2 and typeof(CombatConfig2.GetStyleM2Cooldown) == "function" then
								local v23 = CombatConfig2.GetStyleM2Cooldown(cleanStyle)

								if v23 and typeof(v23) == "number" and v23 > 0 then
									m2Duration = v23
								end
							end
						end)

						v22.m2Duration = m2Duration
						v22.m2EndsAt = os.clock() + m2Duration
					end
				end

				local baseStyle = nil

				if attackCatalog and attackCatalog.baseStyle and attackCatalog.baseStyle ~= "default" and attackCatalog.baseStyle ~= "basic" then
					baseStyle = attackCatalog.baseStyle
				end

				if not baseStyle and animation and animation.Parent then
					local parent = animation.Parent

					while true do
						if parent and parent ~= game then
							local str7 = parent.Name:lower():gsub("otheranims$", ""):gsub("anims$", ""):gsub("vfx$", "")

							if tbl7[str7] then
								baseStyle = str7
								break
							else
								parent = parent.Parent
								continue
							end
						end

						break
					end
				end

				baseStyle = baseStyle or fn38(arg, "default")
				local n26 = 1

				if CombatUtils and typeof(CombatUtils.GetCharacterHeight) == "function" and typeof(CombatUtils.GetAttackSpeedMultiplier) == "function" then
					pcall(function()
						local v22 = CombatUtils.GetCharacterHeight(arg)
						n26 = CombatUtils.GetAttackSpeedMultiplier(v22) or 1
					end)
				end

				if v21 then
					if baseStyle == "hakari" and (str6:find("momentum") or attackCatalog and attackCatalog.isMomentum) then
						pcall(function()
							fallbackDelay = CombatConfig.GetStyleM2HitboxDelay("hakari", true)
						end)
					elseif baseStyle == "boxing" then
						fallbackDelay = 0.43
					else
						pcall(function()
							fallbackDelay = CombatConfig.GetStyleM2HitboxDelay(baseStyle)
						end)
					end

					if not fallbackDelay or typeof(fallbackDelay) ~= "number" then
						fallbackDelay = baseStyle == "boxing" and 0.43 or 0.35
					end
				else
					local combo = attackCatalog and attackCatalog.combo or tonumber(str6:match("^(%d)")) or 1

					pcall(function()
						fallbackDelay = CombatConfig.GetScaledStyleM1HitboxDelay(baseStyle, combo, n26)
					end)

					if not fallbackDelay or typeof(fallbackDelay) ~= "number" then
						fallbackDelay = 0.3
					end
				end

				local character = localPlayer.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				local humanoidRootPart2 = arg:FindFirstChild("HumanoidRootPart")
				if not humanoidRootPart or not humanoidRootPart2 then
					return
				end
				local n27 = humanoidRootPart.Position.X - humanoidRootPart2.Position.X
				local n28 = humanoidRootPart.Position.Z - humanoidRootPart2.Position.Z
				if _G.VH.parryDistance < math.sqrt(n27 * n27 + n28 * n28) then
					return
				end

				if v21 and baseStyle == "wrestling" then
					fallbackDelay = 0.3
				end

				if _G.VH.autoEquipEnabled and character:GetAttribute("Equip") ~= true then
					fn14()
				end

				if not _G.VH.autoFaceEnabled and not fn36(humanoidRootPart, humanoidRootPart2) then
					return
				end

				if character:GetAttribute("Equip") ~= true then
					return
				end
				local n29 = math.max(math.abs(arg2.Speed), 0.05)
				local parryLead = _G.VH.parryLead

				if _G.VH.pingCompEnabled then
					parryLead += math.clamp(fn31() * 0.4, 0, 0.08)
				end

				local n30 = math.max(0, fallbackDelay / n29 - parryLead)
				-- fn18("incoming") -- DISABLED: sembunyikan notifikasi/indicator parry di layar

				if _G.VH.autoFaceEnabled then
					fn34(character, humanoidRootPart2, n30 + 0.35)
				end

				if n30 <= 0.035 then
					if _G.VH.autoFaceEnabled or fn36(humanoidRootPart, humanoidRootPart2) then
						fn37(v21, baseStyle)
					end
				else
					task.delay(n30, function()
						if _G.VH ~= vh or not _G.VH.autoParryEnabled then
							return
						end
						character = localPlayer.Character
						humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
						humanoidRootPart2 = arg:FindFirstChild("HumanoidRootPart")

						if humanoidRootPart and humanoidRootPart2 then
							local n31 = humanoidRootPart.Position.X - humanoidRootPart2.Position.X
							local n32 = humanoidRootPart.Position.Z - humanoidRootPart2.Position.Z
							local flag14 = math.sqrt(n31 * n31 + n32 * n32) <= _G.VH.parryDistance
							local autoFaceEnabled

							if flag14 then
								autoFaceEnabled = _G.VH.autoFaceEnabled or fn36(humanoidRootPart, humanoidRootPart2)
							else
								autoFaceEnabled = flag14
							end

							if autoFaceEnabled then
								if _G.VH.autoFaceEnabled then
									fn34(character, humanoidRootPart2, 0.3)
								end

								fn37(v21, baseStyle)
							end
						end
					end)
				end
			end

			local function fn44(arg, arg2)
				if arg == localPlayer or not arg2 then
					return
				end
				local humanoid_ = arg2:FindFirstChildOfClass("Humanoid") or arg2:WaitForChild("Humanoid", 10)

				if humanoid_ then
					humanoid_ = humanoid_:FindFirstChildOfClass("Animator") or humanoid_:WaitForChild("Animator", 5)
				end

				if humanoid_ then
					fn13(humanoid_.AnimationPlayed:Connect(function(arg3)
						fn43(arg2, arg3)
					end))
				end
			end

			local function fn45(player)
				if player == localPlayer then
					return
				end

				if player.Character then
					task.spawn(fn44, player, player.Character)
				end

				fn13(player.CharacterAdded:Connect(function(character)
					fn44(player, character)
				end))
			end

			for _, player in ipairs(Players:GetPlayers()) do
				fn45(player)
			end

			fn13(Players.PlayerAdded:Connect(fn45))

			fn20 = function(arg)
				local character = localPlayer.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				if not humanoidRootPart then
					return nil
				end
				arg = arg or 9
				local character2 = nil

				for _, player in ipairs(Players:GetPlayers()) do
					if player ~= localPlayer and player.Character then
						local humanoidRootPart2 = player.Character:FindFirstChild("HumanoidRootPart")
						local humanoid_ = player.Character:FindFirstChildOfClass("Humanoid")

						if humanoidRootPart2 and humanoid_ and humanoid_.Health > 0 and player.Character:GetAttribute("Greenzone") ~= true then
							local magnitude = (humanoidRootPart.Position - humanoidRootPart2.Position).Magnitude

							if magnitude <= arg then
								character2 = player.Character
								arg = magnitude
							end
						end
					end
				end

				return character2
			end

			task.spawn(function()
				while not _G.VH.unloading and not lib.Unloaded do
					if _G.VH.autoAttackEnabled then
						local character = localPlayer.Character

						if character and character:GetAttribute("Equip") == true and fn35(character) and character:GetAttribute("Blocking") ~= true then
							if fn20(9) then
								pcall(M1.OnM1Activated)
							end
						end
					end

					task.wait(0.12)
				end
			end)

			task.spawn(function()
				while not _G.VH.unloading and not lib.Unloaded do
					if _G.VH.autoEquipEnabled then
						local character = localPlayer.Character

						if character and character:GetAttribute("Equip") ~= true and character:GetAttribute("Ragdoll") ~= true and character:GetAttribute("Downed") ~= true then
							fn14()
						end
					end

					task.wait(1.5)
				end
			end)

			fn21 = function(arg)
				if not arg then
					_G.VH.noDodgeCooldownEnabled = false

					if _G.VH.noDodgeCooldownModule and _G.VH.noDodgeCooldownOriginal and _G.VH.noDodgeCooldownModule.Evasive == _G.VH.noDodgeCooldownHook then
						_G.VH.noDodgeCooldownModule.Evasive = _G.VH.noDodgeCooldownOriginal
					end

					_G.VH.noDodgeCooldownModule = nil
					_G.VH.noDodgeCooldownOriginal = nil
					_G.VH.noDodgeCooldownHook = nil
					fn17("No Dodge Cooldown", "Disabled")
					return
				end

				if _G.VH.noDodgeCooldownEnabled and _G.VH.noDodgeCooldownHook then
					return
				end
				local _okE, Evasive2 = pcall(_cachedReq, ReplicatedStorage.CombatSystemClient.Combat.Base.Evasive)
				if not _okE or typeof(Evasive2) ~= "table" or typeof(Evasive2.Evasive) ~= "function" then
					fn17("No Dodge Cooldown", "Module failed to load")
					if toggles.NoDodgeCooldown then toggles.NoDodgeCooldown:SetValue(false) end
					return
				end
				local evasive = Evasive2.Evasive
				local setupvalue_ = debug and debug.setupvalue or setupvalue

				-- Solara-PC: longgar pengecekan; jika setupvalue tidak tersedia, hook tetap
				-- dipasang dengan pcall (fallback aman: fungsi asli tetap berjalan normal).
				if typeof(evasive) ~= "function" then
					fn17("No Dodge Cooldown", "Unsupported executor")

					if toggles.NoDodgeCooldown then
						toggles.NoDodgeCooldown:SetValue(false)
					end

					return
				end

				_G.VH.noDodgeCooldownEnabled = true
				_G.VH.noDodgeCooldownModule = Evasive2
				_G.VH.noDodgeCooldownOriginal = evasive

				_G.VH.noDodgeCooldownHook = function(...)
					if _G.VH.noDodgeCooldownEnabled then
						local character = localPlayer.Character

						if character then
							character:SetAttribute("IFRAMECD", nil)
							character:SetAttribute("EvasiveCooldownRemaining", nil)
						end

						pcall(setupvalue_, evasive, 4, 0)
					end

					return evasive(...)
				end

				Evasive2.Evasive = _G.VH.noDodgeCooldownHook
				fn17("No Dodge Cooldown", "Enabled")
			end

			fn22 = function(noBlurEnabled)
				_G.VH.noBlurEnabled = noBlurEnabled
				fn15(_G.VH.noBlurConnections)
				fn15(_G.VH.noBlurEffectConnections)

				if not noBlurEnabled then
					for k, noBlurState in pairs(_G.VH.noBlurStates) do
						if k.Parent then
							k.Enabled = noBlurState
						end
					end

					table.clear(_G.VH.noBlurStates)
					fn17("No Blur", "Disabled")
					return
				end

				local function fn46(descendant)
					if not (descendant:IsA("BlurEffect") or descendant:IsA("DepthOfFieldEffect")) then
						return
					end

					if _G.VH.noBlurStates[descendant] == nil then
						_G.VH.noBlurStates[descendant] = descendant.Enabled
					end

					descendant.Enabled = false

					if not _G.VH.noBlurEffectConnections[descendant] then
						_G.VH.noBlurEffectConnections[descendant] = descendant:GetPropertyChangedSignal("Enabled"):Connect(function()
							if _G.VH == vh and vh.noBlurEnabled and descendant.Parent and descendant.Enabled then
								descendant.Enabled = false
							end
						end)
					end
				end

				local function fn47(arg)
					if not arg then
						return
					end

					for _, descendant in ipairs(arg:GetDescendants()) do
						fn46(descendant)
					end

					table.insert(_G.VH.noBlurConnections, arg.DescendantAdded:Connect(fn46))
				end

				fn47(game:GetService("Lighting"))
				fn47(workspace.CurrentCamera)

				table.insert(_G.VH.noBlurConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
					if _G.VH == vh and vh.noBlurEnabled then
						fn47(workspace.CurrentCamera)
					end
				end))

				fn17("No Blur", "Enabled")
			end

			local function fn46(arg)
				if not arg then
					return false
				end

				if arg:GetAttribute("Attacking") == true or arg:GetAttribute("M2Attacking") == true or arg:GetAttribute("Combo") ~= nil or arg:GetAttribute("LightAttack") == true or arg:GetAttribute("HeavyAttack") == true then
					return true
				end
				local humanoid_ = arg:FindFirstChildOfClass("Humanoid")
				humanoid_ = humanoid_ and humanoid_:FindFirstChildOfClass("Animator")

				if humanoid_ then
					for _, v21 in ipairs(humanoid_:GetPlayingAnimationTracks()) do
						local animation = v21.Animation
						local match = animation and animation.AnimationId:match("%d+")
						if match and _G.VH.attackCatalog and _G.VH.attackCatalog[match] then
							return true
						end
						animation = animation and animation.Name:lower() or ""
						if animation:find("m1") or animation:find("m2") or animation:find("crit") or animation:find("heavy") or animation:find("slam") or animation:find("grab") then
							return true
						end
					end
				end

				return false
			end

			local function fn47(adornee)
				local billboardGui = Instance.new("BillboardGui")
				billboardGui.Name = "Veneno_EnemySideHUD"
				billboardGui.Adornee = adornee
				billboardGui.Size = UDim2.fromOffset(130, 48)
				billboardGui.StudsOffset = Vector3.new(-3.3, -0.7, 0)
				billboardGui.AlwaysOnTop = true
				billboardGui.MaxDistance = 150
				billboardGui.Parent = adornee
				table.insert(_G.VH.createdObjects, billboardGui)
				local frame2 = Instance.new("Frame")
				frame2.BackgroundTransparency = 1
				frame2.Size = UDim2.fromScale(1, 1)
				frame2.Parent = billboardGui
				local uiListLayout = Instance.new("UIListLayout")
				uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
				uiListLayout.Padding = UDim.new(0, 5)
				uiListLayout.Parent = frame2
				local frame3 = Instance.new("Frame")
				frame3.LayoutOrder = 1
				frame3.Size = UDim2.new(1, 0, 0, 18)
				frame3.BackgroundTransparency = 1
				frame3.Parent = frame2
				local frame4 = Instance.new("Frame")
				frame4.Size = UDim2.new(1, 0, 0, 12)
				frame4.BackgroundTransparency = 1
				frame4.Parent = frame3
				local textLabel = Instance.new("TextLabel")
				textLabel.Size = UDim2.fromScale(1, 1)
				textLabel.BackgroundTransparency = 1
				textLabel.Font = Enum.Font.Fantasy
				textLabel.Text = "HP: 100"
				textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel.TextStrokeTransparency = 0
				textLabel.TextSize = 12
				textLabel.TextXAlignment = Enum.TextXAlignment.Left
				textLabel.Parent = frame4
				local n26 = math.clamp(math.floor((humanoid and math.max(humanoid.MaxHealth, 1) or 100) * 1.1), 70, 140)
				local frame5 = Instance.new("Frame")
				frame5.Position = UDim2.fromOffset(0, 13)
				frame5.Size = UDim2.fromOffset(n26, 4)
				frame5.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame5.BorderSizePixel = 0
				frame5.Parent = frame3
				local frame6 = Instance.new("Frame")
				frame6.Size = UDim2.fromScale(1, 1)
				frame6.BackgroundColor3 = _G.VH.colorHudLife
				frame6.BorderSizePixel = 0
				frame6.Parent = frame5
				local frame7 = Instance.new("Frame")
				frame7.LayoutOrder = 2
				frame7.Size = UDim2.new(1, 0, 0, 18)
				frame7.BackgroundTransparency = 1
				frame7.Parent = frame2
				local frame8 = Instance.new("Frame")
				frame8.Size = UDim2.new(1, 0, 0, 12)
				frame8.BackgroundTransparency = 1
				frame8.Parent = frame7
				local textLabel2 = Instance.new("TextLabel")
				textLabel2.Size = UDim2.fromScale(1, 1)
				textLabel2.BackgroundTransparency = 1
				textLabel2.Font = Enum.Font.Fantasy
				textLabel2.Text = "Stamina: 100"
				textLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel2.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel2.TextStrokeTransparency = 0
				textLabel2.TextSize = 12
				textLabel2.TextXAlignment = Enum.TextXAlignment.Left
				textLabel2.Parent = frame8
				local frame9 = Instance.new("Frame")
				frame9.Position = UDim2.fromOffset(0, 13)
				frame9.Size = UDim2.new(1, 0, 0, 4)
				frame9.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame9.BorderSizePixel = 0
				frame9.Parent = frame7
				local frame10 = Instance.new("Frame")
				frame10.Size = UDim2.fromScale(1, 1)
				frame10.BackgroundColor3 = _G.VH.colorHudStamina
				frame10.BorderSizePixel = 0
				frame10.Parent = frame9
				local frame11 = Instance.new("Frame")
				frame11.Name = "M2Section"
				frame11.LayoutOrder = 3
				frame11.Size = UDim2.new(1, 0, 0, 18)
				frame11.BackgroundTransparency = 1
				frame11.Visible = false
				frame11.Parent = frame2
				local textLabel3 = Instance.new("TextLabel")
				textLabel3.Size = UDim2.new(1, 0, 0, 12)
				textLabel3.BackgroundTransparency = 1
				textLabel3.Font = Enum.Font.Fantasy
				textLabel3.Text = "M2: 0.0s"
				textLabel3.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel3.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel3.TextStrokeTransparency = 0
				textLabel3.TextSize = 12
				textLabel3.TextXAlignment = Enum.TextXAlignment.Left
				textLabel3.Parent = frame11
				local frame12 = Instance.new("Frame")
				frame12.Position = UDim2.fromOffset(0, 13)
				frame12.Size = UDim2.fromOffset(n26, 4)
				frame12.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame12.BorderSizePixel = 0
				frame12.Parent = frame11
				local frame13 = Instance.new("Frame")
				frame13.Size = UDim2.fromScale(0, 1)
				frame13.BackgroundColor3 = _G.VH.colorHudM2
				frame13.BorderSizePixel = 0
				frame13.Parent = frame12
				local frame14 = Instance.new("Frame")
				frame14.Name = "DodgeSection"
				frame14.LayoutOrder = 4
				frame14.Size = UDim2.new(1, 0, 0, 18)
				frame14.BackgroundTransparency = 1
				frame14.Visible = false
				frame14.Parent = frame2
				local textLabel4 = Instance.new("TextLabel")
				textLabel4.Size = UDim2.new(1, 0, 0, 12)
				textLabel4.BackgroundTransparency = 1
				textLabel4.Font = Enum.Font.Fantasy
				textLabel4.Text = "DODGE: 0.0s"
				textLabel4.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel4.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel4.TextStrokeTransparency = 0
				textLabel4.TextSize = 12
				textLabel4.TextXAlignment = Enum.TextXAlignment.Left
				textLabel4.Parent = frame14
				local frame15 = Instance.new("Frame")
				frame15.Position = UDim2.fromOffset(0, 13)
				frame15.Size = UDim2.fromOffset(n26, 4)
				frame15.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame15.BorderSizePixel = 0
				frame15.Parent = frame14
				local frame16 = Instance.new("Frame")
				frame16.Size = UDim2.fromScale(0, 1)
				frame16.BackgroundColor3 = _G.VH.colorHudDodge
				frame16.BorderSizePixel = 0
				frame16.Parent = frame15
				billboardGui.Size = UDim2.fromOffset(130, 82)
				return billboardGui, textLabel, frame6, textLabel2, frame10, frame11, textLabel3, frame13, frame14, textLabel4, frame16
			end

			fn23 = function(arg)
				if arg == localPlayer or _G.VH.espHL[arg] then
					return
				end
				local character = arg.Character
				if not character then
					return
				end
				local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if not head or not humanoidRootPart then
					return
				end
				local humanoid_ = character:FindFirstChildOfClass("Humanoid")
				local highlight = Instance.new("Highlight")
				highlight.Name = "Veneno_Players"
				highlight.FillColor = _G.ESP_COLORS.Players or Color3.fromRGB(255, 255, 255)
				highlight.OutlineColor = _G.ESP_COLORS.Players or Color3.fromRGB(255, 255, 255)
				highlight.FillTransparency = _G.VH.espBodyMode == "Fill" and 0.5 or 1
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Adornee = character
				highlight.Enabled = _G.VH.espEnabled and _G.VH.espBodyEnabled == true
				highlight.Parent = character
				table.insert(_G.VH.createdObjects, highlight)
				local billboardGui = Instance.new("BillboardGui")
				billboardGui.Name = "Veneno_ESPInfo"
				billboardGui.Adornee = head
				billboardGui.Size = UDim2.fromOffset(220, 85)
				billboardGui.StudsOffset = Vector3.new(0, 2.7, 0)
				billboardGui.AlwaysOnTop = true
				billboardGui.MaxDistance = _G.VH.espDistance or 150
				billboardGui.Enabled = _G.VH.espEnabled
				billboardGui.Parent = character
				table.insert(_G.VH.createdObjects, billboardGui)
				local frame2 = Instance.new("Frame")
				frame2.Name = "Container"
				frame2.BackgroundTransparency = 1
				frame2.Size = UDim2.fromScale(1, 1)
				frame2.Parent = billboardGui
				local uiListLayout = Instance.new("UIListLayout")
				uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
				uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
				uiListLayout.Padding = UDim.new(0, 2)
				uiListLayout.Parent = frame2
				local textLabel = Instance.new("TextLabel")
				textLabel.Name = "RealNameLabel"
				textLabel.LayoutOrder = 1
				textLabel.Size = UDim2.new(1, 0, 0, 16)
				textLabel.BackgroundTransparency = 1
				textLabel.Font = Enum.Font.Fantasy
				textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel.TextStrokeTransparency = 0
				textLabel.TextSize = 14
				textLabel.Visible = _G.VH.espNameEnabled == true
				textLabel.Parent = frame2
				local textLabel2 = Instance.new("TextLabel")
				textLabel2.Name = "NickLabel"
				textLabel2.LayoutOrder = 2
				textLabel2.Size = UDim2.new(1, 0, 0, 14)
				textLabel2.BackgroundTransparency = 1
				textLabel2.Font = Enum.Font.Fantasy
				textLabel2.TextColor3 = Color3.fromRGB(190, 220, 255)
				textLabel2.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel2.TextStrokeTransparency = 0
				textLabel2.TextSize = 12
				textLabel2.Visible = _G.VH.espNickEnabled == true
				textLabel2.Parent = frame2
				local textLabel3 = Instance.new("TextLabel")
				textLabel3.Name = "DistLabel"
				textLabel3.LayoutOrder = 3
				textLabel3.Size = UDim2.new(1, 0, 0, 13)
				textLabel3.BackgroundTransparency = 1
				textLabel3.Font = Enum.Font.Fantasy
				textLabel3.TextColor3 = Color3.fromRGB(220, 220, 220)
				textLabel3.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel3.TextStrokeTransparency = 0
				textLabel3.TextSize = 11
				textLabel3.Visible = _G.VH.espDistanceEnabled == true
				textLabel3.Parent = frame2
				local textLabel4 = Instance.new("TextLabel")
				textLabel4.Name = "HpLabel"
				textLabel4.LayoutOrder = 4
				textLabel4.Size = UDim2.new(1, 0, 0, 14)
				textLabel4.BackgroundTransparency = 1
				textLabel4.Font = Enum.Font.Fantasy
				textLabel4.TextColor3 = Color3.fromRGB(80, 245, 125)
				textLabel4.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel4.TextStrokeTransparency = 0
				textLabel4.TextSize = 13
				textLabel4.Visible = _G.VH.espHealthEnabled == true
				textLabel4.Parent = frame2
				local textLabel5 = Instance.new("TextLabel")
				textLabel5.Name = "SmartStatusLabel"
				textLabel5.LayoutOrder = 5
				textLabel5.Size = UDim2.new(1, 0, 0, 15)
				textLabel5.BackgroundTransparency = 1
				textLabel5.Font = Enum.Font.Fantasy
				textLabel5.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel5.TextStrokeTransparency = 0
				textLabel5.TextSize = 13
				textLabel5.Visible = _G.VH.espStyleEnabled == true
				textLabel5.Parent = frame2
				local boxHandleAdornment = Instance.new("BoxHandleAdornment")
				boxHandleAdornment.Name = "Veneno_Hitbox"
				boxHandleAdornment.Adornee = humanoidRootPart
				boxHandleAdornment.Size = Vector3.new(4.2, 5.2, 2.2)
				boxHandleAdornment.Color3 = _G.VH.colorHitbox
				boxHandleAdornment.Transparency = 0.65
				boxHandleAdornment.AlwaysOnTop = true
				boxHandleAdornment.ZIndex = 1
				boxHandleAdornment.Visible = _G.VH.espEnabled and _G.VH.espHitboxEnabled

				pcall(function()
					boxHandleAdornment.Parent = humanoidRootPart
				end)

				table.insert(_G.VH.createdObjects, boxHandleAdornment)
				local v21, v22, v23, v24, v25, v26, v27, v28, v29, v30, v31 = fn47(humanoidRootPart)

				local tbl8 = {
					player = arg,
					character = character,
					highlight = highlight,
					billboard = billboardGui,
					container = frame2,
					nameLabel = textLabel,
					nickLabel = textLabel2,
					distLabel = textLabel3,
					hpLabel = textLabel4,
					smartStatusLabel = textLabel5,
					hitboxVisual = boxHandleAdornment,
					sideHud = v21,
					enemyHpLbl = v22,
					enemyHpBar = v23,
					enemyStaLbl = v24,
					enemyStaBar = v25,
					enemyM2Sec = v26,
					enemyM2Lbl = v27,
					enemyM2Bar = v28,
					enemyDodgeSec = v29,
					enemyDodgeLbl = v30,
					enemyDodgeBar = v31,
					m2EndsAt = 0,
					m2Duration = 2.5,
					dodgeEndsAt = 0,
					dodgeDuration = 1.5,
					connections = {},
				}

				_G.VH.espHL[arg] = tbl8

				local function fn48()
					if not billboardGui.Parent or not character.Parent then
						return
					end
					textLabel.Text = fn41(arg, character)
					textLabel2.Text = fn42(arg)
					local health = humanoid_ and humanoid_.Health or 0
					local maxHealth = humanoid_ and humanoid_.MaxHealth or 100

					if health > 0 then
						local ceil = math.ceil
						textLabel4.Text = string.format("%d / %d HP", math.ceil(health), ceil(maxHealth))
					else
						textLabel4.Text = "0 HP"
					end

					local character2 = localPlayer.Character
					character2 = character2 and character2:FindFirstChild("HumanoidRootPart")
					local humanoidRootPart2 = character:FindFirstChild("HumanoidRootPart")

					if character2 and humanoidRootPart2 then
						textLabel3.Text = string.format("%dm", math.floor((character2.Position - humanoidRootPart2.Position).Magnitude / 3.57))
					else
						textLabel3.Text = ""
					end

					local flag11 = character:GetAttribute("Stunned") == true or character:GetAttribute("Ragdoll") == true or character:GetAttribute("GuardBroken") == true or character:GetAttribute("Downed") == true or character:GetAttribute("GrappleWinnerStun") == true
					local platformStand

					if flag11 then
						platformStand = flag11
					else
						local v32 = humanoid_

						if humanoid_ then
							platformStand = humanoid_.PlatformStand
						else
							platformStand = v32
						end
					end

					local v32 = fn46(character)
					local v33 = fn40(arg, character)

					if platformStand then
						textLabel5.Text = "Stunned"
						textLabel5.TextColor3 = Color3.fromRGB(255, 215, 0)
					elseif v32 then
						textLabel5.Text = "Attacking"
						textLabel5.TextColor3 = Color3.fromRGB(255, 45, 45)
					else
						textLabel5.Text = v33
						textLabel5.TextColor3 = fn39(v33)
					end

					textLabel.Visible = _G.VH.espEnabled and _G.VH.espNameEnabled
					textLabel2.Visible = _G.VH.espEnabled and _G.VH.espNickEnabled
					textLabel3.Visible = _G.VH.espEnabled and _G.VH.espDistanceEnabled and textLabel3.Text ~= ""
					textLabel4.Visible = _G.VH.espEnabled and _G.VH.espHealthEnabled
					textLabel5.Visible = _G.VH.espEnabled and _G.VH.espStyleEnabled
					highlight.Enabled = _G.VH.espEnabled and _G.VH.espBodyEnabled
					highlight.FillTransparency = _G.VH.espBodyMode == "Fill" and 0.5 or 1
					billboardGui.Enabled = _G.VH.espEnabled
					boxHandleAdornment.Visible = _G.VH.espEnabled and _G.VH.espHitboxEnabled

					if _G.VH.enemyHudEnabled and health > 0 then
						v21.Enabled = true
						v23.Size = UDim2.fromScale(math.clamp(health / math.max(maxHealth, 1), 0, 1), 1)
						v23.BackgroundColor3 = _G.VH.colorHudLife
						v22.Text = string.format("HP: %d", math.ceil(health))
						local v34, v35 = fn33(character, arg)
						v25.Size = UDim2.fromScale(math.clamp(v34 / math.max(v35, 1), 0, 1), 1)
						v25.BackgroundColor3 = _G.VH.colorHudStamina
						v24.Text = string.format("Stamina: %d", math.ceil(v34))
						local n26 = math.max(0, (tbl8.m2EndsAt or 0) - os.clock())
						local n27 = math.max(0.1, tbl8.m2Duration or 2.5)

						if n26 > 0 then
							v26.Visible = true
							v28.Size = UDim2.fromScale(math.clamp(n26 / n27, 0, 1), 1)
							v28.BackgroundColor3 = _G.VH.colorHudM2
							v27.Text = string.format("M2: %.1fs", n26)
						else
							v26.Visible = false
						end

						local n28 = math.max(0, (tbl8.dodgeEndsAt or 0) - os.clock())
						local n29 = math.max(0.1, tbl8.dodgeDuration or 1.5)

						if n28 > 0 then
							v29.Visible = true
							v31.Size = UDim2.fromScale(math.clamp(n28 / n29, 0, 1), 1)
							v31.BackgroundColor3 = _G.VH.colorHudDodge
							v30.Text = string.format("DODGE: %.1fs", n28)
						else
							v29.Visible = false
						end
					else
						v21.Enabled = false
					end
				end

				fn48()

				if humanoid_ then
					table.insert(tbl8.connections, humanoid_:GetPropertyChangedSignal("Health"):Connect(fn48))
					table.insert(tbl8.connections, humanoid_:GetPropertyChangedSignal("MaxHealth"):Connect(fn48))
				end

				local playerData = character:FindFirstChild("PlayerData") or arg:FindFirstChild("PlayerData")

				if playerData then
					for _, v32 in ipairs({ "FirstName", "LastName", "CombatStyle", "Stunned", "Attacking", "Stamina", "RunStamina" }) do
						table.insert(tbl8.connections, playerData:GetAttributeChangedSignal(v32):Connect(fn48))
					end
				end

				table.insert(tbl8.connections, character.AttributeChanged:Connect(function(attribute2)
					if attribute2 == "M2Cooldown" and character:GetAttribute("M2Cooldown") == true then
						if (tbl8.m2EndsAt or 0) <= os.clock() then
							local v32 = fn40(arg, character)
							local m2Duration = 10

							pcall(function()
								if CombatConfig2 and typeof(CombatConfig2.GetStyleM2Cooldown) == "function" then
									local v33 = CombatConfig2.GetStyleM2Cooldown(v32)

									if v33 and typeof(v33) == "number" and v33 > 0 then
										m2Duration = v33
									end
								end
							end)

							tbl8.m2Duration = m2Duration
							tbl8.m2EndsAt = os.clock() + m2Duration
						end
					elseif (attribute2 == "IFRAMECD" or attribute2 == "Evasive") and (character:GetAttribute("IFRAMECD") == true or character:GetAttribute("Evasive") == true) then
						if (tbl8.dodgeEndsAt or 0) <= os.clock() then
							local v32 = fn40(arg, character)
							local dodgeDuration = 1.5

							pcall(function()
								if CombatConfig and typeof(CombatConfig.GetCharacterEvasiveCooldown) == "function" then
									local v33 = CombatConfig.GetCharacterEvasiveCooldown(character, v32)

									if v33 and typeof(v33) == "number" and v33 > 0 then
										dodgeDuration = v33
									end
								end
							end)

							tbl8.dodgeDuration = dodgeDuration
							tbl8.dodgeEndsAt = os.clock() + dodgeDuration
						end
					end

					fn48()
				end))
			end
		end

		fn24 = function(player)
			local v21 = _G.VH.espHL[player]
			if not v21 then
				return
			end

			for _, connection in ipairs(v21.connections) do
				pcall(function()
					connection:Disconnect()
				end)
			end

			if v21.highlight then
				pcall(function()
					v21.highlight:Destroy()
				end)
			end

			if v21.billboard then
				pcall(function()
					v21.billboard:Destroy()
				end)
			end

			if v21.sideHud then
				pcall(function()
					v21.sideHud:Destroy()
				end)
			end

			if v21.hitboxVisual then
				pcall(function()
					v21.hitboxVisual:Destroy()
				end)
			end

			_G.VH.espHL[player] = nil
		end

		fn25 = function()
			for k in pairs(_G.VH.espHL) do
				fn24(k)
			end
		end

		fn26 = function()
			if not _G.VH.espEnabled then
				fn25()
				return
			end

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= localPlayer then
					fn23(player)
				end
			end
		end

		v19 = nil

		do
			local v21 = nil
			local v22 = nil
			local v23 = nil
			local v24 = nil
			local v25 = nil
			local v26 = nil

			local function fn34(adornee)
				if v19 then
					v19:Destroy()
					v19 = nil
				end

				adornee = adornee and adornee:FindFirstChild("HumanoidRootPart")
				if not adornee then
					return
				end
				local billboardGui = Instance.new("BillboardGui")
				billboardGui.Name = "Veneno_LeftStatusHUD"
				billboardGui.Adornee = adornee
				billboardGui.Size = UDim2.fromOffset(140, 46)
				billboardGui.StudsOffset = Vector3.new(-3.3, -0.7, 0)
				billboardGui.AlwaysOnTop = true
				billboardGui.MaxDistance = 150
				billboardGui.Parent = adornee
				table.insert(_G.VH.createdObjects, billboardGui)
				local frame2 = Instance.new("Frame")
				frame2.Name = "LeftContainer"
				frame2.BackgroundTransparency = 1
				frame2.Size = UDim2.fromScale(1, 1)
				frame2.Parent = billboardGui
				local uiListLayout = Instance.new("UIListLayout")
				uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
				uiListLayout.Padding = UDim.new(0, 4)
				uiListLayout.Parent = frame2
				local frame3 = Instance.new("Frame")
				frame3.Name = "HPSection"
				frame3.LayoutOrder = 1
				frame3.Size = UDim2.new(1, 0, 0, 18)
				frame3.BackgroundTransparency = 1
				frame3.Parent = frame2
				local frame4 = Instance.new("Frame")
				frame4.Size = UDim2.new(1, 0, 0, 12)
				frame4.BackgroundTransparency = 1
				frame4.Parent = frame3
				local textLabel = Instance.new("TextLabel")
				textLabel.Size = UDim2.fromScale(1, 1)
				textLabel.BackgroundTransparency = 1
				textLabel.Font = Enum.Font.Fantasy
				textLabel.Text = "HP: 100"
				textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel.TextStrokeTransparency = 0
				textLabel.TextSize = 12
				textLabel.TextXAlignment = Enum.TextXAlignment.Left
				textLabel.Parent = frame4
				local frame5 = Instance.new("Frame")
				frame5.Position = UDim2.fromOffset(0, 13)
				frame5.Size = UDim2.fromOffset(120, 4)
				frame5.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame5.BorderSizePixel = 0
				frame5.Parent = frame3
				local frame6 = Instance.new("Frame")
				frame6.Size = UDim2.fromScale(1, 1)
				frame6.BackgroundColor3 = _G.VH.colorHudLife
				frame6.BorderSizePixel = 0
				frame6.Parent = frame5
				local frame7 = Instance.new("Frame")
				frame7.Name = "StaminaSection"
				frame7.LayoutOrder = 2
				frame7.Size = UDim2.new(1, 0, 0, 18)
				frame7.BackgroundTransparency = 1
				frame7.Parent = frame2
				local frame8 = Instance.new("Frame")
				frame8.Size = UDim2.new(1, 0, 0, 12)
				frame8.BackgroundTransparency = 1
				frame8.Parent = frame7
				local textLabel2 = Instance.new("TextLabel")
				textLabel2.Size = UDim2.fromScale(1, 1)
				textLabel2.BackgroundTransparency = 1
				textLabel2.Font = Enum.Font.Fantasy
				textLabel2.Text = "Stamina: 100"
				textLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel2.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel2.TextStrokeTransparency = 0
				textLabel2.TextSize = 12
				textLabel2.TextXAlignment = Enum.TextXAlignment.Left
				textLabel2.Parent = frame8
				local frame9 = Instance.new("Frame")
				frame9.Position = UDim2.fromOffset(0, 13)
				frame9.Size = UDim2.fromOffset(120, 4)
				frame9.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame9.BorderSizePixel = 0
				frame9.Parent = frame7
				local frame10 = Instance.new("Frame")
				frame10.Size = UDim2.fromScale(1, 1)
				frame10.BackgroundColor3 = _G.VH.colorHudStamina
				frame10.BorderSizePixel = 0
				frame10.Parent = frame9
				v19 = billboardGui
				v21 = frame6
				v22 = frame5
				v23 = textLabel
				v24 = frame10
				v25 = frame9
				v26 = textLabel2
			end

			v20 = nil
			local v27 = nil
			local v28 = nil
			local v29 = nil
			local v30 = nil
			local v31 = nil
			local v32 = nil

			local function fn35(arg)
				if v20 then
					v20:Destroy()
					v20 = nil
				end

				local humanoidRootPart = arg and arg:FindFirstChild("HumanoidRootPart")
				if not humanoidRootPart then
					return
				end
				local billboardGui = Instance.new("BillboardGui")
				billboardGui.Name = "Veneno_RightCooldownsHUD"
				billboardGui.Adornee = humanoidRootPart
				billboardGui.Size = UDim2.fromOffset(130, 48)
				billboardGui.StudsOffset = Vector3.new(3.3, -0.7, 0)
				billboardGui.AlwaysOnTop = true
				billboardGui.MaxDistance = 150
				billboardGui.Parent = humanoidRootPart
				table.insert(_G.VH.createdObjects, billboardGui)
				local frame2 = Instance.new("Frame")
				frame2.Name = "RightContainer"
				frame2.BackgroundTransparency = 1
				frame2.Size = UDim2.fromScale(1, 1)
				frame2.Parent = billboardGui
				local uiListLayout = Instance.new("UIListLayout")
				uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
				uiListLayout.Padding = UDim.new(0, 5)
				uiListLayout.Parent = frame2
				local frame3 = Instance.new("Frame")
				frame3.Name = "M2Section"
				frame3.LayoutOrder = 1
				frame3.Size = UDim2.new(1, 0, 0, 18)
				frame3.BackgroundTransparency = 1
				frame3.Visible = false
				frame3.Parent = frame2
				local textLabel = Instance.new("TextLabel")
				textLabel.Size = UDim2.new(1, 0, 0, 12)
				textLabel.BackgroundTransparency = 1
				textLabel.Font = Enum.Font.Fantasy
				textLabel.Text = "M2: 0.0s"
				textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel.TextStrokeTransparency = 0
				textLabel.TextSize = 12
				textLabel.TextXAlignment = Enum.TextXAlignment.Left
				textLabel.Parent = frame3
				local frame4 = Instance.new("Frame")
				frame4.Position = UDim2.fromOffset(0, 13)
				frame4.Size = UDim2.new(1, 0, 0, 4)
				frame4.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame4.BorderSizePixel = 0
				frame4.Parent = frame3
				local frame5 = Instance.new("Frame")
				frame5.Size = UDim2.fromScale(0, 1)
				frame5.BackgroundColor3 = _G.VH.colorHudM2
				frame5.BorderSizePixel = 0
				frame5.Parent = frame4
				local frame6 = Instance.new("Frame")
				frame6.Name = "DodgeSection"
				frame6.LayoutOrder = 2
				frame6.Size = UDim2.new(1, 0, 0, 18)
				frame6.BackgroundTransparency = 1
				frame6.Visible = false
				frame6.Parent = frame2
				local textLabel2 = Instance.new("TextLabel")
				textLabel2.Size = UDim2.new(1, 0, 0, 12)
				textLabel2.BackgroundTransparency = 1
				textLabel2.Font = Enum.Font.Fantasy
				textLabel2.Text = "DODGE: 0.0s"
				textLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
				textLabel2.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel2.TextStrokeTransparency = 0
				textLabel2.TextSize = 12
				textLabel2.TextXAlignment = Enum.TextXAlignment.Left
				textLabel2.Parent = frame6
				local frame7 = Instance.new("Frame")
				frame7.Position = UDim2.fromOffset(0, 13)
				frame7.Size = UDim2.new(1, 0, 0, 4)
				frame7.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
				frame7.BorderSizePixel = 0
				frame7.Parent = frame6
				local frame8 = Instance.new("Frame")
				frame8.Size = UDim2.fromScale(0, 1)
				frame8.BackgroundColor3 = _G.VH.colorHudDodge
				frame8.BorderSizePixel = 0
				frame8.Parent = frame7
				v20 = billboardGui
				v27 = frame3
				v28 = frame5
				v29 = textLabel
				v30 = frame6
				v31 = frame8
				v32 = textLabel2
			end

			fn27 = function(arg)
				local n26 = arg or 0.016
				local character = localPlayer.Character
				local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid_ = character and character:FindFirstChildOfClass("Humanoid")

				if not character or not humanoidRootPart or not humanoid_ or humanoid_.Health <= 0 then
					if v19 then
						v19.Enabled = false
					end

					if v20 then
						v20.Enabled = false
					end

					return
				end

				if _G.VH.sideHudEnabled then
					if not v19 or v19.Adornee ~= humanoidRootPart then
						fn34(character)
					end

					if v19 then
						v19.Enabled = true
						local n27 = math.max(humanoid_.MaxHealth, 1)
						local myDisplayHp = math.clamp(humanoid_.Health, 0, n27)
						local n28 = math.clamp(math.floor(n27 * 1.1), 70, 160)

						if v22 then
							v22.Size = UDim2.fromOffset(n28, 4)
						end

						if not _G.VH.myDisplayHp then
							_G.VH.myDisplayHp = myDisplayHp
						end

						local n29 = myDisplayHp - _G.VH.myDisplayHp

						if math.abs(n29) < 0.2 then
							_G.VH.myDisplayHp = myDisplayHp
						else
							_G.VH.myDisplayHp = _G.VH.myDisplayHp + n29 * math.clamp(n26 * 12, 0, 1)
						end

						v21.Size = UDim2.fromScale(math.clamp(_G.VH.myDisplayHp / n27, 0, 1), 1)
						v21.BackgroundColor3 = _G.VH.colorHudLife
						local ceil = math.ceil
						v23.Text = string.format("HP: %d / %d", math.floor(_G.VH.myDisplayHp + 0.5), ceil(n27))
						local v33, v34 = fn33(character, localPlayer)

						if v25 then
							v25.Size = UDim2.fromOffset(n28, 4)
						end

						if not _G.VH.myDisplaySta then
							_G.VH.myDisplaySta = v33
						end

						local n30 = v33 - _G.VH.myDisplaySta

						if math.abs(n30) < 0.2 then
							_G.VH.myDisplaySta = v33
						else
							_G.VH.myDisplaySta = _G.VH.myDisplaySta + n30 * math.clamp(n26 * 12, 0, 1)
						end

						v24.Size = UDim2.fromScale(math.clamp(_G.VH.myDisplaySta / math.max(v34, 1), 0, 1), 1)
						v24.BackgroundColor3 = _G.VH.colorHudStamina
						v26.Text = string.format("Stamina: %d", math.floor(_G.VH.myDisplaySta + 0.5))
					end
				elseif v19 then
					v19.Enabled = false
				end

				if _G.VH.sideCooldownsEnabled then
					if not v20 or v20.Adornee ~= humanoidRootPart then
						fn35(character)
					end

					if v20 then
						v20.Enabled = true
						local n27 = math.max(0, (_G.VH.m2EndsAt or 0) - os.clock())
						local n28 = math.max(0.1, _G.VH.m2Duration or 2.5)

						if n27 > 0 then
							v27.Visible = true
							v28.Size = UDim2.fromScale(math.clamp(n27 / n28, 0, 1), 1)
							v28.BackgroundColor3 = _G.VH.colorHudM2
							v29.Text = string.format("M2: %.1fs", n27)
						else
							v27.Visible = false
						end

						local n29 = math.max(0, (_G.VH.dodgeEndsAt or 0) - os.clock())
						local n30 = math.max(0.1, _G.VH.dodgeDuration or 1.5)

						if n29 > 0 then
							v30.Visible = true
							v31.Size = UDim2.fromScale(math.clamp(n29 / n30, 0, 1), 1)
							v31.BackgroundColor3 = _G.VH.colorHudDodge
							v32.Text = string.format("DODGE: %.1fs", n29)
						else
							v30.Visible = false
						end
					end
				elseif v20 then
					v20.Enabled = false
				end
			end
		end

		fn28 = function(arg)
			if not _G.VH.espEnabled or not _G.VH.enemyHudEnabled then
				return
			end
			arg = arg or 0.016
			_G.VH._enemyHudAcc = (_G.VH._enemyHudAcc or 0) + arg
			if _G.VH._enemyHudAcc < 0.1 then return end -- ESP lag fix: throttle enemy HUD to ~10fps
			_G.VH._enemyHudAcc = 0

			for k, v21 in pairs(_G.VH.espHL) do
				local character = v21.character
				local humanoid_ = character and character:FindFirstChildOfClass("Humanoid")

				if v21.sideHud and character and character.Parent and humanoid_ and humanoid_.Health > 0 then
					v21.sideHud.Enabled = true
					local health = humanoid_.Health
					local maxHealth = humanoid_.MaxHealth or 100

					if not v21.displayHp then
						v21.displayHp = health
					end

					local n26 = health - v21.displayHp

					if math.abs(n26) < 0.2 then
						v21.displayHp = health
					else
						v21.displayHp = v21.displayHp + n26 * math.clamp(arg * 12, 0, 1)
					end

					v21.enemyHpBar.Size = UDim2.fromScale(math.clamp(v21.displayHp / math.max(maxHealth, 1), 0, 1), 1)
					v21.enemyHpBar.BackgroundColor3 = _G.VH.colorHudLife
					v21.enemyHpLbl.Text = string.format("HP: %d", math.floor(v21.displayHp + 0.5))
					local v22, v23 = fn33(character, k)

					if not v21.displaySta then
						v21.displaySta = v22
					end

					local n27 = v22 - v21.displaySta

					if math.abs(n27) < 0.2 then
						v21.displaySta = v22
					else
						v21.displaySta = v21.displaySta + n27 * math.clamp(arg * 12, 0, 1)
					end

					v21.enemyStaBar.Size = UDim2.fromScale(math.clamp(v21.displaySta / math.max(v23, 1), 0, 1), 1)
					v21.enemyStaBar.BackgroundColor3 = _G.VH.colorHudStamina
					v21.enemyStaLbl.Text = string.format("Stamina: %d", math.floor(v21.displaySta + 0.5))
					local n28 = math.max(0, (v21.m2EndsAt or 0) - os.clock())
					local n29 = math.max(0.1, v21.m2Duration or 2.5)

					if n28 > 0 then
						v21.enemyM2Sec.Visible = true
						v21.enemyM2Bar.Size = UDim2.fromScale(math.clamp(n28 / n29, 0, 1), 1)
						v21.enemyM2Bar.BackgroundColor3 = _G.VH.colorHudM2
						v21.enemyM2Lbl.Text = string.format("M2: %.1fs", n28)
					else
						v21.enemyM2Sec.Visible = false
					end

					local n30 = math.max(0, (v21.dodgeEndsAt or 0) - os.clock())
					local n31 = math.max(0.1, v21.dodgeDuration or 1.5)

					if n30 > 0 then
						v21.enemyDodgeSec.Visible = true
						v21.enemyDodgeBar.Size = UDim2.fromScale(math.clamp(n30 / n31, 0, 1), 1)
						v21.enemyDodgeBar.BackgroundColor3 = _G.VH.colorHudDodge
						v21.enemyDodgeLbl.Text = string.format("DODGE: %.1fs", n30)
					else
						v21.enemyDodgeSec.Visible = false
					end
				elseif v21.sideHud then
					v21.sideHud.Enabled = false
				end
			end
		end
	end

	local v21
	v21 = nil
	local v22
	v22 = nil
	local fn29

	do
		local function fn30()
			if not v21 then
				local part2 = Instance.new("Part")
				part2.Name = "Veneno_ThreatZonePlayer"
				part2.Shape = Enum.PartType.Cylinder
				part2.Size = Vector3.new(0.1, 14, 14)
				part2.Orientation = Vector3.new(0, 0, 90)
				part2.Material = Enum.Material.Neon
				part2.Color = _G.VH.colorThreatClose
				part2.Transparency = 0.35
				part2.CanCollide = false
				part2.Anchored = true
				part2.CastShadow = false

				pcall(function()
					part2.Parent = workspace.CurrentCamera
				end)

				table.insert(_G.VH.createdObjects, part2)
				v21 = part2
			end

			if not v22 then
				local part2 = Instance.new("Part")
				part2.Name = "Veneno_ThreatZoneEnemy"
				part2.Shape = Enum.PartType.Cylinder
				part2.Size = Vector3.new(0.1, 14, 14)
				part2.Orientation = Vector3.new(0, 0, 90)
				part2.Material = Enum.Material.Neon
				part2.Color = _G.VH.colorThreatClose
				part2.Transparency = 0.35
				part2.CanCollide = false
				part2.Anchored = true
				part2.CastShadow = false

				pcall(function()
					part2.Parent = workspace.CurrentCamera
				end)

				table.insert(_G.VH.createdObjects, part2)
				v22 = part2
			end
		end

		local function fn31()
			if not _G.VH.threatZoneEnabled then
				if v21 then
					v21.Transparency = 1
				end

				if v22 then
					v22.Transparency = 1
				end

				return
			end

			fn30()
			if not v21 or not v22 then
				return
			end
			local character = localPlayer.Character
			character = character and character:FindFirstChild("HumanoidRootPart")

			if not character then
				v21.Transparency = 1
				v22.Transparency = 1
				return
			end

			local humanoidRootPart = fn20((_G.VH.parryDistance or 20) + 15)
			humanoidRootPart = humanoidRootPart and humanoidRootPart:FindFirstChild("HumanoidRootPart")

			if not humanoidRootPart then
				v21.Transparency = 1
				v22.Transparency = 1
				return
			end

			local magnitude = (character.Position - humanoidRootPart.Position).Magnitude
			v21.CFrame = CFrame.new(character.Position - Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, 1.5707963267948966)
			v22.CFrame = CFrame.new(humanoidRootPart.Position - Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, 1.5707963267948966)

			if magnitude <= _G.VH.threatRangeInReach then
				v21.Color = _G.VH.colorThreatClose
				v21.Size = Vector3.new(0.1, _G.VH.threatRangeInReach * 2, _G.VH.threatRangeInReach * 2)
				v21.Transparency = 0.3
				v22.Color = _G.VH.colorThreatClose
				v22.Size = Vector3.new(0.1, _G.VH.threatRangeInReach * 2, _G.VH.threatRangeInReach * 2)
				v22.Transparency = 0.3
			elseif magnitude <= _G.VH.threatRangeDanger then
				v21.Color = _G.VH.colorThreatFar
				v21.Size = Vector3.new(0.1, _G.VH.threatRangeDanger * 2, _G.VH.threatRangeDanger * 2)
				v21.Transparency = 0.45
				v22.Transparency = 1
			else
				v21.Transparency = 1
				v22.Transparency = 1
			end
		end

		fn29 = function(fpsBoostEnabled)
			_G.VH.fpsBoostEnabled = fpsBoostEnabled

			if fpsBoostEnabled then
				_G.VH.fpsBoostSaved.GlobalShadows = Lighting.GlobalShadows
				_G.VH.fpsBoostSaved.FogEnd = Lighting.FogEnd

				pcall(function()
					Lighting.GlobalShadows = false
				end)

				pcall(function()
					Lighting.FogEnd = 9e9
				end)

				pcall(function()
					local level01 = Enum.QualityLevel.Level01
					settings().Rendering.QualityLevel = level01
				end)

				fn17("FPS Boost", "Enabled")
			else
				if _G.VH.fpsBoostSaved.GlobalShadows ~= nil then
					pcall(function()
						Lighting.GlobalShadows = _G.VH.fpsBoostSaved.GlobalShadows
					end)
				end

				if _G.VH.fpsBoostSaved.FogEnd ~= nil then
					pcall(function()
						Lighting.FogEnd = _G.VH.fpsBoostSaved.FogEnd
					end)
				end

				pcall(function()
					local automatic = Enum.QualityLevel.Automatic
					settings().Rendering.QualityLevel = automatic
				end)

				fn17("FPS Boost", "Disabled")
			end
		end

		_G.VH.visualsRenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
			if _G.VH.unloading or lib.Unloaded then
				return
			end
			pcall(fn27, deltaTime)
			pcall(fn31)
			pcall(fn28, deltaTime)

			if v18 and v18.Parent and str5 ~= "idle" then
				if os.clock() > n25 then
					fn18("idle")
				end
			end

			if not _G.VH.espEnabled then
				return
			end

			for _, v23 in pairs(_G.VH.espHL) do
				if v23.hitboxVisual then
					v23.hitboxVisual.Visible = _G.VH.espHitboxEnabled
					if _G.VH._lastHitboxColor ~= _G.VH.colorHitbox then
						_G.VH._lastHitboxColor = _G.VH.colorHitbox
						v23.hitboxVisual.Color3 = _G.VH.colorHitbox
					end
				end
			end
		end)
	end

	_G.VH.espConnection = RunService.Stepped:Connect(function()
		if lib.Unloaded then return end
		if not _G.VH.espEnabled then
			return
		end
		local now2 = tick()
		if now2 - _G.VH.espLastUpdate < _G.VH.espUpdateThreshold then
			return
		end
		_G.VH.espLastUpdate = now2
		local character = localPlayer.Character
		character = character and character:FindFirstChild("HumanoidRootPart")
		local espDistance = _G.VH.espDistance or 500
		local n26 = espDistance * espDistance

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				local v23 = _G.VH.espHL[player]

				if v23 and (not v23.character or not v23.character.Parent or v23.character ~= player.Character) then
					fn24(player)
					v23 = nil
				end

				if player.Character and not v23 then
					fn23(player)
					v23 = _G.VH.espHL[player]
				end

				if v23 then
					local enabled = true

					if character then
						local humanoidRootPart = v23.character and (v23.character:FindFirstChild("HumanoidRootPart") or v23.character:FindFirstChild("Head"))

						if humanoidRootPart then
							local n27 = character.Position - humanoidRootPart.Position
							enabled = n27.X * n27.X + n27.Y * n27.Y + n27.Z * n27.Z <= n26
						end
					end

					local enabled2 = enabled and _G.VH.espBodyEnabled == true
					enabled = enabled and (_G.VH.espNameEnabled or _G.VH.espNickEnabled or _G.VH.espHealthEnabled or _G.VH.espStyleEnabled or _G.VH.espDistanceEnabled)

					if v23.highlight and v23.highlight.Enabled ~= enabled2 then
						v23.highlight.Enabled = enabled2
					end

					if v23.billboard and v23.billboard.Enabled ~= enabled then
						v23.billboard.Enabled = enabled
					end
				end
			end
		end
	end)

	fn13(Players.PlayerAdded:Connect(function(player)
		if player == localPlayer then
			return
		end

		fn13(player.CharacterAdded:Connect(function()
			task.wait(0.5)

			if _G.VH.espEnabled then
				fn23(player)
			end
		end))

		if _G.VH.espEnabled then
			fn23(player)
		end
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			fn13(player.CharacterAdded:Connect(function()
				task.wait(0.5)

				if _G.VH.espEnabled then
					fn23(player)
				end
			end))
		end
	end

	fn13(Players.PlayerRemoving:Connect(fn24))
	local fn30

	do
		local function fn31(arg, arg2)
			if arg2:IsA("BasePart") then
				if _G.VH.originalCanCollide[arg2] == nil then
					_G.VH.originalCanCollide[arg2] = arg2.CanCollide
				end

				local v23 = _G.VH.antiFlingPartsByChar[arg]

				if v23 then
					table.insert(v23, arg2)
				end
			end
		end

		local function fn32(character)
			if _G.VH.antiFlingPartsByChar[character] then
				return
			end
			local tbl6 = {}

			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant:IsA("BasePart") then
					if _G.VH.originalCanCollide[descendant] == nil then
						_G.VH.originalCanCollide[descendant] = descendant.CanCollide
					end

					table.insert(tbl6, descendant)
				end
			end

			_G.VH.antiFlingPartsByChar[character] = tbl6

			table.insert(_G.VH.antiFlingCharConnections, character.DescendantAdded:Connect(function(descendant)
				fn31(character, descendant)
			end))

			table.insert(_G.VH.antiFlingCharConnections, character.DescendantRemoving:Connect(function(descendant)
				local v23 = _G.VH.antiFlingPartsByChar[character]

				if v23 and descendant:IsA("BasePart") then
					for i = #v23, 1, -1 do
						if v23[i] == descendant then
							table.remove(v23, i)
						end
					end
				end
			end))
		end

		local function fn33(player)
			if player == localPlayer then
				return
			end

			if player.Character then
				fn32(player.Character)
			end

			table.insert(_G.VH.antiFlingCharConnections, player.CharacterAdded:Connect(fn32))
		end

		local function fn34()
			for _, antiFlingCharConnection in ipairs(_G.VH.antiFlingCharConnections) do
				antiFlingCharConnection:Disconnect()
			end

			table.clear(_G.VH.antiFlingCharConnections)
			table.clear(_G.VH.antiFlingPartsByChar)
		end

		fn30 = function(antiFlingEnabled)
			fn16("antiFlingConnection")
			fn16("antiFlingPlayerAddedConnection")
			_G.VH.antiFlingEnabled = antiFlingEnabled

			if not antiFlingEnabled then
				for k, v23 in pairs(_G.VH.originalCanCollide) do
					if k and k.Parent then
						k.CanCollide = v23
					end
				end

				table.clear(_G.VH.originalCanCollide)
				fn34()
				fn17("Anti Fling", "Disabled")
				return
			end

			for _, player in ipairs(Players:GetPlayers()) do
				fn33(player)
			end

			_G.VH.antiFlingPlayerAddedConnection = Players.PlayerAdded:Connect(fn33)

			_G.VH.antiFlingConnection = RunService.Heartbeat:Connect(function()
				if lib.Unloaded then return end
				local now2 = tick()
				if now2 - _G.VH.antiFlingLastUpdate < _G.VH.antiFlingThreshold then
					return
				end
				_G.VH.antiFlingLastUpdate = now2

				for _, v23 in pairs(_G.VH.antiFlingPartsByChar) do
					for i = 1, #v23 do
						local v24 = v23[i]

						if v24 and v24.Parent and v24.CanCollide then
							v24.CanCollide = false
						end
					end
				end
			end)

			fn17("Anti Fling", "Enabled")
		end
	end

	local fn31

	fn31 = function(antiVoidEnabled)
		_G.VH.antiVoidEnabled = antiVoidEnabled

		if antiVoidEnabled then
			workspace.FallenPartsDestroyHeight = (0/0)
			fn17("Anti Void", "Enabled")
		else
			workspace.FallenPartsDestroyHeight = _G.VH.originalFallenPartsDestroyHeight
			fn17("Anti Void", "Disabled")
		end
	end

	local fn32

	fn32 = function(noclipEnabled, arg)
		_G.VH.noclipEnabled = noclipEnabled
		fn16("noclipConnection")
		fn16("noclipDescendantConnection")

		if not noclipEnabled then
			local character = localPlayer.Character

			if character then
				for _, descendant in ipairs(character:GetDescendants()) do
					if descendant:IsA("BasePart") then
						local v23 = _G.VH.noclipOriginal[descendant]

						if v23 ~= nil then
							descendant.CanCollide = v23
						elseif descendant.Name == "HumanoidRootPart" or descendant.Name == "Torso" or descendant.Name == "UpperTorso" or descendant.Name == "LowerTorso" or descendant.Name == "Head" then
							descendant.CanCollide = true
						end
					end
				end
			end

			table.clear(_G.VH.noclipOriginal)
			table.clear(_G.VH.noclipParts)

			if not arg then
				fn17("Noclip", "Disabled")
			end

			return
		end

		local character = localPlayer.Character
		table.clear(_G.VH.noclipParts)

		local function fn33(descendant)
			if descendant:IsA("BasePart") then
				if _G.VH.noclipOriginal[descendant] == nil then
					_G.VH.noclipOriginal[descendant] = descendant.CanCollide
				end

				descendant.CanCollide = false
				table.insert(_G.VH.noclipParts, descendant)
			end
		end

		if character then
			for _, descendant in ipairs(character:GetDescendants()) do
				fn33(descendant)
			end

			_G.VH.noclipDescendantConnection = character.DescendantAdded:Connect(fn33)
		end

		_G.VH.noclipConnection = RunService.Stepped:Connect(function()
			if lib.Unloaded then return end
			local noclipParts = _G.VH.noclipParts

			for i = 1, #noclipParts do
				local v23 = noclipParts[i]

				if v23 and v23.Parent and v23.CanCollide then
					v23.CanCollide = false
				end
			end
		end)

		if not arg then
			fn17("Noclip", "Enabled")
		end
	end

	local fn33

	fn33 = function()
		if _G.VH.flyEnabled then
			return
		end
		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
		local humanoid_ = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid_ or not humanoidRootPart then
			return
		end
		_G.VH.flyEnabled = true
		_G.VH.CONTROL.F = UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0 -- PC-only keyboard
		_G.VH.CONTROL.B = UserInputService:IsKeyDown(Enum.KeyCode.S) and -1 or 0
		_G.VH.CONTROL.L = UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0
		_G.VH.CONTROL.R = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0

		if not _G.VH.noclipEnabled then
			_G.VH.flyEnabledNoclip = true
			fn32(true, true)
		else
			_G.VH.flyEnabledNoclip = false
		end

		for _, v23 in ipairs({ "Veneno_FlyAttachment", "Veneno_FlyVelocity", "Veneno_FlyOrientation" }) do
			local v24 = humanoidRootPart:FindFirstChild(v23)

			if v24 then
				v24:Destroy()
			end
		end

		_G.VH.flyHumanoid = humanoid_
		_G.VH.flyOriginalAutoRotate = humanoid_.AutoRotate
		humanoid_.AutoRotate = false
		humanoid_.PlatformStand = true
		_G.VH.flyAttachment = Instance.new("Attachment")
		_G.VH.flyAttachment.Name = "Veneno_FlyAttachment"
		_G.VH.flyAttachment.Parent = humanoidRootPart
		table.insert(_G.VH.createdObjects, _G.VH.flyAttachment)
		_G.VH.flyVelocity = Instance.new("LinearVelocity")
		_G.VH.flyVelocity.Name = "Veneno_FlyVelocity"
		_G.VH.flyVelocity.Attachment0 = _G.VH.flyAttachment
		_G.VH.flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		_G.VH.flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		_G.VH.flyVelocity.MaxForce = math.huge
		_G.VH.flyVelocity.VectorVelocity = Vector3.zero
		_G.VH.flyVelocity.Parent = humanoidRootPart
		table.insert(_G.VH.createdObjects, _G.VH.flyVelocity)
		_G.VH.flyGyro = Instance.new("AlignOrientation")
		_G.VH.flyGyro.Name = "Veneno_FlyOrientation"
		_G.VH.flyGyro.Attachment0 = _G.VH.flyAttachment
		_G.VH.flyGyro.Mode = Enum.OrientationAlignmentMode.OneAttachment
		_G.VH.flyGyro.RigidityEnabled = false
		_G.VH.flyGyro.Responsiveness = 35
		_G.VH.flyGyro.MaxTorque = math.huge
		_G.VH.flyGyro.Parent = humanoidRootPart
		table.insert(_G.VH.createdObjects, _G.VH.flyGyro)

		if _G.VH.flyConnection then
			_G.VH.flyConnection:Disconnect()
		end

		_G.VH.flyConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if lib.Unloaded then return end
			if not _G.VH.flyEnabled or character ~= localPlayer.Character or not humanoidRootPart.Parent or not _G.VH.flyVelocity or not _G.VH.flyGyro then
				return
			end
			local currentCamera = workspace.CurrentCamera
			if not currentCamera then
				return
			end
			local unit = currentCamera.CFrame.LookVector.Unit
			local unit2 = currentCamera.CFrame.RightVector.Unit
			local n26

			-- PC-only: arah gerak dari keyboard (cabang mobile MoveDirection dihapus)
			n26 = unit * (_G.VH.CONTROL.F + _G.VH.CONTROL.B) + unit2 * (_G.VH.CONTROL.R + _G.VH.CONTROL.L)

			if n26.Magnitude > 1 then
				n26 = n26.Unit
			end

			_G.VH.flyVelocity.VectorVelocity = _G.VH.flyVelocity.VectorVelocity:Lerp(n26 * (_G.FLY_SPEED or 50), math.clamp(deltaTime * 12, 0, 1))
			local vector = Vector3.new(unit.X, 0, unit.Z)

			if vector.Magnitude < 0.01 then
				vector = Vector3.new(humanoidRootPart.CFrame.LookVector.X, 0, humanoidRootPart.CFrame.LookVector.Z)
			end

			if vector.Magnitude >= 0.01 then
				_G.VH.flyGyro.CFrame = CFrame.lookAt(Vector3.zero, vector.Unit, Vector3.new(0, 1, 0))
			end
		end)

		fn17("Fly", "Enabled")
	end

	local fn34

	fn34 = function()
		_G.VH.flyEnabled = false
		fn16("flyConnection")

		if _G.VH.flyGyro then
			_G.VH.flyGyro:Destroy()
			_G.VH.flyGyro = nil
		end

		if _G.VH.flyVelocity then
			_G.VH.flyVelocity:Destroy()
			_G.VH.flyVelocity = nil
		end

		if _G.VH.flyAttachment then
			_G.VH.flyAttachment:Destroy()
			_G.VH.flyAttachment = nil
		end

		_G.VH.CONTROL = { F = 0, B = 0, L = 0, R = 0 }

		if _G.VH.flyHumanoid and _G.VH.flyHumanoid.Parent then
			_G.VH.flyHumanoid.PlatformStand = false

			if _G.VH.flyOriginalAutoRotate ~= nil then
				_G.VH.flyHumanoid.AutoRotate = _G.VH.flyOriginalAutoRotate
			end
		end

		_G.VH.flyHumanoid = nil
		_G.VH.flyOriginalAutoRotate = nil

		if workspace.CurrentCamera then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		end

		if _G.VH.flyEnabledNoclip then
			fn32(false, true)
			_G.VH.flyEnabledNoclip = false
		end

		fn17("Fly", "Disabled")
	end

	local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not _G.VH.flyEnabled then
			return
		end

		if input.KeyCode == Enum.KeyCode.W then
			_G.VH.CONTROL.F = 1
		elseif input.KeyCode == Enum.KeyCode.S then
			_G.VH.CONTROL.B = -1
		elseif input.KeyCode == Enum.KeyCode.A then
			_G.VH.CONTROL.L = -1
		elseif input.KeyCode == Enum.KeyCode.D then
			_G.VH.CONTROL.R = 1
		end
	end)

	table.insert(_G.VH.connections, connection)

	local connection2 = UserInputService.InputEnded:Connect(function(input)
		if not _G.VH.flyEnabled then
			return
		end

		if input.KeyCode == Enum.KeyCode.W then
			_G.VH.CONTROL.F = 0
		elseif input.KeyCode == Enum.KeyCode.S then
			_G.VH.CONTROL.B = 0
		elseif input.KeyCode == Enum.KeyCode.A then
			_G.VH.CONTROL.L = 0
		elseif input.KeyCode == Enum.KeyCode.D then
			_G.VH.CONTROL.R = 0
		end
	end)

	table.insert(_G.VH.connections, connection2)

	fn13(localPlayer.CharacterAdded:Connect(function()
		if toggles.Fly and toggles.Fly.Value then
			fn34()

			task.delay(0.2, function()
				if toggles.Fly and toggles.Fly.Value then
					fn33()
				end
			end)
		elseif toggles.Noclip and toggles.Noclip.Value then
			task.delay(0.2, function()
				if toggles.Noclip and toggles.Noclip.Value then
					fn32(true, true)
				end
			end)
		end
	end))

	local fn35

	fn35 = function(arg)
		if not arg and not _G.VH.blinkOn or _G.VH.blinkCooldown then
			return
		end
		local character = localPlayer.Character
		if not character then
			return
		end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end
		local lookVector = workspace.CurrentCamera.CFrame.LookVector
		local vector = Vector3.new(lookVector.X, 0, lookVector.Z)

		if vector.Magnitude > 0 then
			vector = vector.Unit
		end

		humanoidRootPart.CFrame = humanoidRootPart.CFrame + vector * (_G.SHADOW_DIST or 40)

		task.spawn(function()
			local character2 = localPlayer.Character
			if not character2 then
				return
			end

			for _, descendant in ipairs(character2:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
					local material = descendant.Material
					descendant.Material = Enum.Material.Neon

					task.delay(0.12, function()
						if descendant and descendant.Parent then
							descendant.Material = material
						end
					end)
				end
			end
		end)

		_G.VH.blinkCooldown = true

		task.delay(0.1, function()
			if _G.VH == vh then
				vh.blinkCooldown = false
			end
		end)
	end

	local function fn36()
		fn35(false)
	end

	fn13(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q and _G.VH.blinkOn then
			fn36()
		end
	end))

	local fn37

	fn37 = function()
		fn16("spectateConnection")
		fn16("spectateRespawnConnection")
		_G.VH.spectateTarget = nil
		local character = localPlayer.Character

		if character then
			local humanoid_ = character:FindFirstChildOfClass("Humanoid")

			if humanoid_ then
				workspace.CurrentCamera.CameraSubject = humanoid_
			end
		end

		fn17("Spectate", "Stopped")
	end

	local fn38

	fn38 = function(arg)
		if arg == "" then
			fn17("Error", "Enter a player name.")
			return
		end
		local v23 = nil

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Name:lower():sub(1, #arg) == arg:lower() then
				v23 = player
				break
			else
				v23 = nil
			end
		end

		if not v23 then
			fn17("Error", "Player not found.")
			return
		end
		fn37()
		_G.VH.spectateTarget = v23

		local function fn39()
			if not _G.VH.spectateTarget then
				return
			end
			local character = _G.VH.spectateTarget.Character
			if not character then
				return
			end
			local humanoid_ = character:FindFirstChildOfClass("Humanoid")

			if humanoid_ then
				workspace.CurrentCamera.CameraSubject = humanoid_
			end
		end

		fn39()

		_G.VH.spectateRespawnConnection = v23.CharacterAdded:Connect(function()
			task.wait(0.2)
			fn39()
		end)

		_G.VH.spectateConnection = workspace.CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(fn39)
		fn17("Spectate", "Viewing " .. v23.Name)
	end

	local fn39

	fn39 = function(arg)
		if arg == "" then
			fn17("Error", "Enter a player name.")
			return
		end
		local v23 = nil

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Name:lower():sub(1, #arg) == arg:lower() then
				v23 = player
				break
			else
				v23 = nil
			end
		end

		if not v23 then
			fn17("Error", "Player not found.")
			return
		end
		local character = localPlayer.Character
		local character2 = v23.Character
		if not character or not character2 then
			fn17("Error", "Character unavailable.")
			return
		end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoidRootPart2 = character2:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart or not humanoidRootPart2 then
			fn17("Error", "HumanoidRootPart missing.")
			return
		end
		humanoidRootPart.CFrame = humanoidRootPart2.CFrame * CFrame.new(0, 0, -3)
		fn17("Teleported", "Teleported to " .. v23.Name)
	end

	local fn40

	local function fn41()
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return nil
		end
		local deathUI = playerGui:FindFirstChild("DeathUI")
		if not deathUI or not deathUI.Enabled then
			return nil
		end
		local frame2 = deathUI:FindFirstChild("Frame")
		if not frame2 then
			return nil
		end
		local heartButton = frame2:FindFirstChild("HeartButton")
		if not heartButton or not heartButton.Visible or not heartButton.Active then
			return nil
		end
		local absolutePosition = heartButton.AbsolutePosition
		local absoluteSize = heartButton.AbsoluteSize
		return absolutePosition.X + absoluteSize.X * 0.5, absolutePosition.Y + absoluteSize.Y * 0.5
	end

	fn40 = function()
		if not _G.VH.heartMonitorRunning then
			_G.VH.heartMonitorRunning = true

			task.spawn(function()
				while _G.VH == vh and vh.heartAutoEnabled and not lib.Unloaded do
					if fn41() then
						while true do
							if _G.VH == vh and vh.heartAutoEnabled and not lib.Unloaded then
								local v23, v24 = fn41()

								if v23 then
									VirtualInputManager:SendMouseButtonEvent(v23, v24, 0, true, game, 1)
									task.wait(0.05)
									VirtualInputManager:SendMouseButtonEvent(v23, v24, 0, false, game, 1)
									task.wait(0.1)
									continue
								end
							end

							break
						end
					else
						task.wait(0.25)
					end
				end

				vh.heartMonitorRunning = false
			end)
		end
	end

	local fn42

	local function fn43()
		if not _G.VH.infJumpEnabled then
			return
		end
		local character = localPlayer.Character
		local humanoid_ = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid_ then
			humanoid_:ChangeState(Enum.HumanoidStateType.Jumping)
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

			if humanoidRootPart then
				local z = humanoidRootPart.AssemblyLinearVelocity.Z
				humanoidRootPart.AssemblyLinearVelocity = Vector3.new(humanoidRootPart.AssemblyLinearVelocity.X, math.max(humanoidRootPart.AssemblyLinearVelocity.Y, 52), z)
			end
		end
	end

	fn42 = function(infJumpEnabled)
		_G.VH.infJumpEnabled = infJumpEnabled
		fn16("infJumpConnection")
		fn16("infJumpMobileConnection")
		if not infJumpEnabled then
			fn17("Inf Jump", "Disabled")
			return
		end
		_G.VH.infJumpConnection = UserInputService.JumpRequest:Connect(fn43)
		fn13(_G.VH.infJumpConnection)

		-- PC-only: koneksi TouchTapInWorld (mobile inf-jump) dihapus

		fn17("Inf Jump", "Enabled")
	end

	local fn44

	do
		local function fn45()
			local character = localPlayer.Character
			if not character then
				return false
			end
			return character:GetAttribute("ItemEquipped") == "Basketball" and character:GetAttribute("ItemPhase") == "Equipped" or character:GetAttribute("BasketballHoldingBall") == true
		end

		local function fn46(arg)
			return arg.G >= 0.7 and arg.R <= 0.4 and arg.B <= 0.55
		end

		local function fn47()
			local character = localPlayer.Character
			if not character then
				return nil
			end

			if _G.VH.autoGreenMarker and _G.VH.autoGreenMarker.Parent and _G.VH.autoGreenWindow and _G.VH.autoGreenWindow.Parent then
				return _G.VH.autoGreenMarker, _G.VH.autoGreenWindow
			end
			local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
			local tbl6 = { character, playerGui }

			for i = 1, #tbl6 do
				local v23 = tbl6[i]

				if v23 then
					local basketballShotBillboard = v23:FindFirstChild("BasketballShotBillboard") or v23:FindFirstChild("BasketballShotMeterBar") or v23:FindFirstChild("BasketballShotBillboard", true) or v23:FindFirstChild("BasketballShotMeterBar", true)

					if basketballShotBillboard and basketballShotBillboard.Enabled then
						local meter = basketballShotBillboard:FindFirstChild("Meter", true)
						local needle = meter and meter:FindFirstChild("Needle", true)

						if meter and needle and meter.Visible then
							for _, child in ipairs(meter:GetChildren()) do
								if child:IsA("Frame") and fn46(child.BackgroundColor3) and child.Size.Y.Scale > 0 then
									_G.VH.autoGreenMarker = needle
									_G.VH.autoGreenWindow = child
									return needle, child
								end
							end
						end

						local track = basketballShotBillboard:FindFirstChild("Track", true)
						local cap = track and track:FindFirstChild("Cap", true)
						local window = track and track:FindFirstChild("Window", true)

						if track and cap and window and window.Size.Y.Scale > 0 then
							_G.VH.autoGreenMarker = cap
							_G.VH.autoGreenWindow = window
							return cap, window
						end
					end
				end
			end

			return nil
		end

		local function fn48()
			if not _G.VH.autoGreenEnabled or not fn45() then
				_G.VH.autoGreenReleased = false
				_G.VH.autoGreenMarker = nil
				_G.VH.autoGreenWindow = nil
				_G.VH.autoGreenReadyAt = 0
				return
			end

			local v23, v24 = fn47()

			if not v23 or not v24 then
				_G.VH.autoGreenReleased = false
				_G.VH.autoGreenReadyAt = 0
				return
			end

			if _G.VH.autoGreenMarker ~= v23 then
				_G.VH.autoGreenMarker = v23
				_G.VH.autoGreenWindow = v24
				_G.VH.autoGreenReadyAt = os.clock() + 0.06
				_G.VH.autoGreenReleased = false
				return
			end

			local autoGreenReadyAt = _G.VH.autoGreenReadyAt
			if os.clock() < autoGreenReadyAt or v24.AbsoluteSize.Y < 2 then
				return
			end

			if _G.VH.autoGreenReleased or not UserInputService:IsKeyDown(Enum.KeyCode.E) then -- PC-only
				return
			end
			local n26 = v23.AbsolutePosition.Y + v23.AbsoluteSize.Y * 0.5
			local y = v24.AbsolutePosition.Y

			if y - 1 <= n26 and n26 <= y + v24.AbsoluteSize.Y + 1 then
				_G.VH.autoGreenReleased = true
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			end
		end

		fn44 = function(autoGreenEnabled)
			fn16("autoGreenConnection")
			_G.VH.autoGreenEnabled = autoGreenEnabled
			_G.VH.autoGreenReleased = false
			_G.VH.autoGreenMarker = nil
			_G.VH.autoGreenWindow = nil
			_G.VH.autoGreenReadyAt = 0

			if autoGreenEnabled then
				_G.VH.autoGreenConnection = RunService.Heartbeat:Connect(function()
					if lib.Unloaded then return end
					local now2 = tick()
					if now2 - _G.VH.autoGreenLastUpdate < 0.04 then -- PC-only timing
						return
					end
					_G.VH.autoGreenLastUpdate = now2
					fn48()
				end)
			end

			fn17("Auto Green", autoGreenEnabled and "Enabled" or "Disabled")
		end
	end

	local fn45

	do
		local function fn46(arg)
			if not arg or typeof(arg._handleLaneRelease) ~= "function" then
				table.clear(_G.VH.rhythmHeldNotes)
				table.clear(_G.VH.rhythmHeldLanes)
				table.clear(_G.VH.rhythmTapReleaseAt)
				return
			end

			local lanes = arg._lanes or 0

			for i = 1, lanes do
				if arg._laneTouchActive then
					arg._laneTouchActive[i] = false
				end

				if arg._laneKeyDown and arg._laneKeyDown[i] then
					pcall(arg._handleLaneRelease, arg, i)
				end
			end

			table.clear(_G.VH.rhythmHeldNotes)
			table.clear(_G.VH.rhythmHeldLanes)
			table.clear(_G.VH.rhythmTapReleaseAt)
		end

		local function fn47(arg, arg2, arg3, arg4)
			if not arg._onLanePressedCallbacks then
				return
			end

			for _, onLanePressedCallback in pairs(arg._onLanePressedCallbacks) do
				if onLanePressedCallback then
					pcall(onLanePressedCallback, arg2, arg3, arg4)
				end
			end
		end

		local function fn48(arg, arg2)
			_G.VH.rhythmTapReleaseAt[arg2.lane] = nil

			if arg._laneTouchActive then
				arg._laneTouchActive[arg2.lane] = true
			end

			if arg._laneKeyDown then
				arg._laneKeyDown[arg2.lane] = true
			end

			if typeof(arg._syncReceptorVisual) == "function" then
				pcall(arg._syncReceptorVisual, arg, arg2.lane)
			end

			_G.VH.rhythmHeldNotes[arg2] = true
			_G.VH.rhythmHeldLanes[arg2.lane] = arg2
		end

		local function fn49(arg, arg2)
			if arg._laneTouchActive then
				arg._laneTouchActive[arg2.lane] = false
			end

			if arg._laneKeyDown then
				arg._laneKeyDown[arg2.lane] = false
			end

			if not arg2.resolved and arg2.holding then
				pcall(arg._onReleaseLane, arg, arg2.lane, arg2.t + arg2.len)
			end

			if typeof(arg._syncReceptorVisual) == "function" then
				pcall(arg._syncReceptorVisual, arg, arg2.lane)
			end

			_G.VH.rhythmHeldNotes[arg2] = nil

			if _G.VH.rhythmHeldLanes[arg2.lane] == arg2 then
				_G.VH.rhythmHeldLanes[arg2.lane] = nil
			end
		end

		local function fn50(arg, arg2, arg3)
			if _G.VH.rhythmTapReleaseAt[arg2.lane] and not _G.VH.rhythmHeldLanes[arg2.lane] then
				if arg._laneTouchActive then
					arg._laneTouchActive[arg2.lane] = false
				end

				if arg._laneKeyDown then
					arg._laneKeyDown[arg2.lane] = false
				end

				if typeof(arg._syncReceptorVisual) == "function" then
					pcall(arg._syncReceptorVisual, arg, arg2.lane)
				end
			end

			if arg._laneTouchActive then
				arg._laneTouchActive[arg2.lane] = true
			end

			if arg._laneKeyDown then
				arg._laneKeyDown[arg2.lane] = true
			end

			if typeof(arg._syncReceptorVisual) == "function" then
				pcall(arg._syncReceptorVisual, arg, arg2.lane)
			end

			_G.VH.rhythmTapReleaseAt[arg2.lane] = arg3 + 0.045 -- PC-only timing
		end

		local function fn51(arg, arg2)
			for k, v23 in pairs(_G.VH.rhythmTapReleaseAt) do
				if v23 <= arg2 then
					if not _G.VH.rhythmHeldLanes[k] then
						if arg._laneTouchActive then
							arg._laneTouchActive[k] = false
						end

						if arg._laneKeyDown then
							arg._laneKeyDown[k] = false
						end

						if typeof(arg._syncReceptorVisual) == "function" then
							pcall(arg._syncReceptorVisual, arg, k)
						end
					end

					_G.VH.rhythmTapReleaseAt[k] = nil
				end
			end
		end

		local function fn52()
			local ok, result = pcall(function()
				return _cachedReq(ReplicatedStorage.Shared.Services.RhythmService.RhythmServiceClient)
			end)

			if ok and type(result) == "table" then
				return result
			end
			return nil
		end

		local function fn53(arg)
			if type(arg) ~= "table" then
				return false
			end

			if type(rawget(arg, "_liveNotes") or arg._liveNotes) ~= "table" then
				return false
			end

			if typeof(arg._onPressLane) ~= "function" or typeof(arg._onReleaseLane) ~= "function" then
				return false
			end

			if arg._destroyed then
				return false
			end

			if arg._started ~= true then
				return false
			end
			return true
		end

		local function fn54()
			if _G.VH.rhythmCachedService then
				local session = rawget(_G.VH.rhythmCachedService, "_session") or _G.VH.rhythmCachedService._session
				if fn53(session) then
					_G.VH.rhythmCachedSession = session
					return session
				end
				return nil
			end

			local v23 = fn52()

			if v23 then
				local session = rawget(v23, "_session") or v23._session

				if fn53(session) then
					_G.VH.rhythmCachedService = v23
					_G.VH.rhythmCachedSession = session
					return session
				end
			end

			local v24 = getloadedmodules

			if typeof(v24) == "function" then
				local ok, result = pcall(v24)

				if ok and type(result) == "table" then
					for i = 1, #result do
						local v25 = result[i]

						if typeof(v25) == "Instance" and v25:IsA("ModuleScript") and v25.Name == "RhythmServiceClient" then
							local ok2, rhythmCachedService = pcall(require, v25)

							if ok2 and type(rhythmCachedService) == "table" then
								_G.VH.rhythmCachedService = rhythmCachedService
								local session = rawget(rhythmCachedService, "_session") or rhythmCachedService._session
								if fn53(session) then
									_G.VH.rhythmCachedSession = session
									return session
								end
							end
						end
					end
				end
			end

			local v25 = getgc

			if typeof(v25) == "function" then
				local ok, result = pcall(v25, true)

				if ok and type(result) == "table" then
					for i = 1, #result do
						local v26 = result[i]
						if type(v26) ~= "table" then
							continue
						end
						local session = rawget(v26, "_session") or v26._session

						if fn53(session) then
							_G.VH.rhythmCachedService = v26
							_G.VH.rhythmCachedSession = session
							return session
						end
					end
				end
			end

			return nil
		end

		local function fn55()
			local rhythmCachedSession = _G.VH.rhythmCachedSession
			if rhythmCachedSession and fn53(rhythmCachedSession) then
				return rhythmCachedSession
			end

			if _G.VH.rhythmCachedService then
				local session = rawget(_G.VH.rhythmCachedService, "_session") or _G.VH.rhythmCachedService._session
				if fn53(session) then
					_G.VH.rhythmCachedSession = session
					return session
				end
				return nil
			end

			local now2 = os.clock()
			if now2 < _G.VH.rhythmNextScanAt then
				return nil
			end
			_G.VH.rhythmNextScanAt = now2 + 3
			return fn54()
		end

		local function fn56()
			local v23 = fn55()

			if v23 ~= _G.VH.rhythmSession then
				fn46(_G.VH.rhythmSession)
				_G.VH.rhythmSession = v23
			end

			if not v23 or not v23._started or v23._destroyed then
				return
			end
			local ok, result = pcall(v23._now, v23)
			if not ok or typeof(result) ~= "number" then
				return
			end

			if next(_G.VH.rhythmTapReleaseAt) ~= nil then
				fn51(v23, result)
			end

			local liveNotes = v23._liveNotes
			if not liveNotes then
				return
			end
			local n26 = result - 0.1
			local n27 = result + 0.5

			for i = 1, #liveNotes do
				local v24 = liveNotes[i]

				if not v24.resolved then
					if v24.t <= n27 and v24.t + (v24.len or 0) >= n26 then
						local v25 = _G.VH.rhythmHeldNotes[v24]
						local resolved

						if v25 then
							resolved = v24.resolved or result >= v24.t + v24.len - 0.02
						else
							resolved = v25
						end

						if resolved then
							fn49(v23, v24)
						end

						if not v24.hit and result >= v24.t then
							local ok2, result2 = pcall(v23._onPressLane, v23, v24.lane, v24.t)

							if ok2 and result2 then
								fn47(v23, v24.lane, v24.t, true)

								if v24.len > 0 and v24.holding then
									fn48(v23, v24)
								elseif v24.len <= 0 then
									fn50(v23, v24, result)
								end
							end
						end

						if v24.len > 0 and v24.hit and v24.holding and not _G.VH.rhythmHeldNotes[v24] and result >= v24.t + v24.len then
							pcall(v23._onReleaseLane, v23, v24.lane, v24.t + v24.len)
						end
					end
				end
			end
		end

		fn45 = function(rhythmAutoPerfectEnabled)
			_G.VH.rhythmAutoPerfectEnabled = rhythmAutoPerfectEnabled
			fn16("rhythmConnection")
			_G.VH.rhythmNextScanAt = 0
			_G.VH.rhythmCacheValid = false
			_G.VH.rhythmLastStep = 0
			_G.VH.rhythmLastHeartbeat = 0

			if not rhythmAutoPerfectEnabled then
				fn46(_G.VH.rhythmSession)
				_G.VH.rhythmSession = nil
				_G.VH.rhythmCachedSession = nil
				fn17("Auto Perfect", "Disabled")
				return
			end

			_G.VH.rhythmConnection = RunService.Heartbeat:Connect(function()
				if _G.VH ~= vh or not vh.rhythmAutoPerfectEnabled or lib.Unloaded then
					return
				end
				local now2 = os.clock()
				if now2 - vh.rhythmLastStep < 0.016 then -- PC-only timing
					return
				end
				vh.rhythmLastStep = now2
				fn56()
			end)

			fn17("Auto Perfect", "Enabled")
		end
	end

	local fn46

	do
		local function fn47(arg)
			if _G.VH ~= vh then
				return
			end

			for _, returnByDeathConnection in ipairs(vh.returnByDeathConnections) do
				returnByDeathConnection:Disconnect()
			end

			table.clear(vh.returnByDeathConnections)
			if not vh.returnByDeathEnabled then
				return
			end
			local humanoid_ = arg:FindFirstChildOfClass("Humanoid") or arg:WaitForChild("Humanoid", 10)
			if _G.VH ~= vh or not humanoid_ then
				return
			end

			local function fn48()
				if _G.VH ~= vh then
					return
				end
				local humanoidRootPart = arg:FindFirstChild("HumanoidRootPart")

				if vh.returnByDeathEnabled and humanoidRootPart then
					local position = humanoidRootPart.Position
					local originalFallenPartsDestroyHeight = vh.originalFallenPartsDestroyHeight

					if originalFallenPartsDestroyHeight ~= originalFallenPartsDestroyHeight then
						originalFallenPartsDestroyHeight = -500
					end

					local raycastParams = RaycastParams.new()
					raycastParams.FilterType = Enum.RaycastFilterType.Exclude
					raycastParams.FilterDescendantsInstances = { arg }
					local flag11 = workspace:Raycast(position, Vector3.new(0, -250, 0), raycastParams) ~= nil
					if position.Y <= originalFallenPartsDestroyHeight + 50 or position.Y <= originalFallenPartsDestroyHeight + 200 and not flag11 then
						vh.returnByDeathPosition = nil
						return
					end
					vh.returnByDeathPosition = position
				end
			end

			table.insert(vh.returnByDeathConnections, humanoid_.Died:Connect(fn48))

			table.insert(vh.returnByDeathConnections, arg:GetAttributeChangedSignal("Dead"):Connect(function()
				if arg:GetAttribute("Dead") == true then
					fn48()
				end
			end))

			if arg:GetAttribute("Dead") == true then
				fn48()
			end
		end

		local function fn48(arg)
			local returnByDeathPosition = _G.VH.returnByDeathPosition
			if not _G.VH.returnByDeathEnabled or not returnByDeathPosition then
				return
			end
			_G.VH.returnByDeathToken = _G.VH.returnByDeathToken + 1
			local returnByDeathToken = _G.VH.returnByDeathToken

			task.spawn(function()
				local humanoidRootPart = arg:WaitForChild("HumanoidRootPart", 10)
				local humanoid_ = arg:FindFirstChildOfClass("Humanoid") or arg:WaitForChild("Humanoid", 10)
				if _G.VH ~= vh or not humanoidRootPart or not humanoid_ or not vh.returnByDeathEnabled or returnByDeathToken ~= vh.returnByDeathToken then
					return
				end
				local now2 = os.clock()
				local flag11 = false

				while true do
					if _G.VH ~= vh or not vh.returnByDeathEnabled or returnByDeathToken ~= vh.returnByDeathToken or arg ~= localPlayer.Character or not humanoidRootPart.Parent or lib.Unloaded then
						return
					end
					local sit = humanoid_.Sit or humanoid_.SeatPart ~= nil
					flag11 = flag11 or sit
					arg:PivotTo(CFrame.new(returnByDeathPosition + Vector3.new(0, 3, 0)) * arg:GetPivot().Rotation)
					if flag11 and not sit then
						break
					end

					if not flag11 and os.clock() - now2 >= 1 then
						break
					end

					if os.clock() - now2 >= 3 then
						break
					end
					task.wait(0.033) -- PC-only timing
				end

				vh.returnByDeathPosition = nil
			end)
		end

		fn46 = function(returnByDeathEnabled)
			_G.VH.returnByDeathEnabled = returnByDeathEnabled
			_G.VH.returnByDeathToken = _G.VH.returnByDeathToken + 1

			if not returnByDeathEnabled then
				_G.VH.returnByDeathPosition = nil

				for _, returnByDeathConnection in ipairs(_G.VH.returnByDeathConnections) do
					returnByDeathConnection:Disconnect()
				end

				table.clear(_G.VH.returnByDeathConnections)
				fn17("Return by Death", "Disabled")
				return
			end

			local character = localPlayer.Character

			if character then
				task.spawn(fn47, character)
			end

			fn17("Return by Death", "Enabled")
		end

		fn13(localPlayer.CharacterAdded:Connect(function(character)
			local flag11 = _G.VH.returnByDeathEnabled and _G.VH.returnByDeathPosition ~= nil
			task.spawn(fn47, character)

			if flag11 then
				fn48(character)
			end
		end))
	end

	local fn47

	fn47 = function(infCamZoomEnabled)
		_G.VH.infCamZoomEnabled = infCamZoomEnabled
		fn16("infCamZoomConnection")

		if not infCamZoomEnabled then
			if _G.VH.infCamZoomSavedMaxZoom ~= nil then
				localPlayer.CameraMaxZoomDistance = _G.VH.infCamZoomSavedMaxZoom
				_G.VH.infCamZoomSavedMaxZoom = nil
			end

			fn17("Inf Cam Zoom", "Disabled")
			return
		end

		_G.VH.infCamZoomSavedMaxZoom = _G.VH.infCamZoomSavedMaxZoom or localPlayer.CameraMaxZoomDistance
		localPlayer.CameraMaxZoomDistance = math.huge
		localPlayer.CameraMinZoomDistance = 0.5

		_G.VH.infCamZoomConnection = localPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
			if _G.VH.infCamZoomEnabled and localPlayer.CameraMaxZoomDistance < 100000 then
				localPlayer.CameraMaxZoomDistance = math.huge
			end
		end)

		fn13(_G.VH.infCamZoomConnection)

		pcall(function()
			local ZoomController = _cachedReq(localPlayer.PlayerScripts.PlayerModule.CameraModule.ZoomController)
			local setupvalue_ = debug and debug.setupvalue or setupvalue

			if ZoomController and typeof(setupvalue_) == "function" then
				pcall(setupvalue_, ZoomController.Update, 7, function(arg, arg2)
					return arg2
				end)
			end
		end)

		fn17("Inf Cam Zoom", "Enabled")
	end

	local fn48

	fn48 = function()
		if _G.VH.rejoinCooldown then
			fn17("Cooldown", "Wait a few seconds")
			return
		end
		_G.VH.rejoinCooldown = true
		fn17("Rejoining", "Teleporting...")

		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
		end)

		task.delay(10, function()
			if _G.VH == vh then
				vh.rejoinCooldown = false
			end
		end)
	end

	local fn49

	fn49 = function()
		if _G.VH.serverHopCooldown then
			fn17("Cooldown", "Wait a few seconds")
			return
		end
		_G.VH.serverHopCooldown = true
		fn17("Server Hop", "Searching...")

		task.spawn(function()
			local ok, result = pcall(function()
				local response = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
				return HttpService:JSONDecode(response)
			end)

			if _G.VH ~= vh then
				return
			end
			local tbl6 = {}

			if ok then
				local v23 = ipairs
				local data = result.data or {}

				for _, v24 in v23(data) do
					if v24.id ~= game.JobId and v24.playing < v24.maxPlayers then
						table.insert(tbl6, v24)
					end
				end
			end

			if #tbl6 > 0 then
				local v23 = tbl6[math.random(1, #tbl6)]

				pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, v23.id, localPlayer)
				end)
			else
				fn17("Server Hop", "No server found.")
			end

			task.delay(5, function()
				if _G.VH == vh then
					vh.serverHopCooldown = false
				end
			end)
		end)
	end

	local fn50

	fn50 = function()
		if _G.VH.serverHopCooldown then
			fn17("Cooldown", "Wait a few seconds")
			return
		end
		_G.VH.serverHopCooldown = true
		fn17("Empty Server Hop", "Searching for empty server...")

		task.spawn(function()
			local ok, result = pcall(function()
				local response = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
				return HttpService:JSONDecode(response)
			end)

			if _G.VH ~= vh then
				return
			end

			if ok and result then
				local id = nil
				local data = result and result.data
				local huge = math.huge

				if data then
					for _, v23 in ipairs(result.data) do
						if v23.playing < huge and v23.playing < 5 and v23.id ~= game.JobId then
							huge = v23.playing
							id = v23.id
						end
					end
				end

				if id then
					pcall(function()
						TeleportService:TeleportToPlaceInstance(game.PlaceId, id, localPlayer)
					end)

					fn17("Empty Server Hop", "Found server with " .. huge .. " players!")
				else
					fn17("Empty Server Hop", "No low-player server found.")
				end
			else
				fn17("Empty Server Hop", "Search failed.")
			end

			task.delay(5, function()
				if _G.VH == vh then
					vh.serverHopCooldown = false
				end
			end)
		end)
	end

	local cleanup

	cleanup = function()
		if _G.VH.unloading then
			return
		end
		_G.VH.unloading = true
		_G.VH.silent = true
		flag10 = false
		_G.VH.autoParryEnabled = false
		_G.VH.autoFaceEnabled = false
		_G.VH.autoAttackEnabled = false
		_G.VH.autoEquipEnabled = false

		pcall(function()
			local character = localPlayer.Character

			if character and character:GetAttribute("Blocking") == true then
				Block.Unblock()
			end
		end)

		fn19()
		fn21(false)
		fn22(false)
		_G.VH.espEnabled = false
		fn25()
		fn30(false)
		fn31(false)
		fn32(false, true)

		if _G.VH.flyEnabled then
			fn34()
		end

		fn44(false)
		fn45(false)
		fn42(false)
		fn46(false)
		fn47(false)
		fn37()
		_G.VH.heartAutoEnabled = false

		if _G.VH.fpsBoostEnabled then
			fn29(false)
		end

		for _, v23 in ipairs({
			"noclipConnection",
			"antiFlingConnection",
			"noBlurConnection",
			"espConnection",
			"hpM2Connection",
			"autoGreenConnection",
			"antiFlingPlayerAddedConnection",
			"noclipDescendantConnection",
			"jetpackConnection",
			"rhythmConnection",
			"visualsRenderConnection",
		}) do
			fn16(v23)
		end

		fn15(_G.VH.noBlurConnections)
		fn15(_G.VH.noBlurEffectConnections)

		if _G.VH.jetpackVelocity then
			_G.VH.jetpackVelocity:Destroy()
			_G.VH.jetpackVelocity = nil
		end

		if v19 then
			v19:Destroy()
			v19 = nil
		end

		if v20 then
			v20:Destroy()
			v20 = nil
		end

		if v17 then
			v17:Destroy()
			v17 = nil
		end

		if v21 then
			v21:Destroy()
			v21 = nil
		end

		if v22 then
			v22:Destroy()
			v22 = nil
		end

		for _, connection3 in ipairs(_G.VH.connections) do
			pcall(connection3.Disconnect, connection3)
		end

		table.clear(_G.VH.connections)

		for _, createdObject in ipairs(_G.VH.createdObjects) do
			pcall(createdObject.Destroy, createdObject)
		end

		table.clear(_G.VH.createdObjects)
		_G.VH = {}
		lib:Unload()
	end

	_G.VH.cleanup = cleanup


local _cb={conn=nil,followConn=nil,tpTarget=nil,tpOffset=3}
local function _cbRefresh()
	local any=_G.VH.cb_infStamina or _G.VH.cb_noStun or _G.VH.cb_noRagdoll or _G.VH.cb_noParryCD
	if any and not _cb.conn then
		_cb.conn=game:GetService("RunService").Heartbeat:Connect(function()
			if lib.Unloaded then return end
			local char=game.Players.LocalPlayer.Character; if not char then return end
			if _G.VH.cb_noStun then for _,a in ipairs({"Stunned","CantAnything","CombatAttacking","CombatRecovery"}) do if char:GetAttribute(a)==true then char:SetAttribute(a,nil) end end end
			if _G.VH.cb_infStamina and char:GetAttribute("Stamina")~=100 then char:SetAttribute("Stamina",100) end
			if _G.VH.cb_noRagdoll then
				for _,a in ipairs({"Ragdoll","Downed","RespawnLocked"}) do if char:GetAttribute(a)==true then char:SetAttribute(a,nil) end end
				local h=char:FindFirstChildOfClass("Humanoid"); if h then h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false) end
			end
			if _G.VH.cb_noParryCD then for _,a in ipairs({"BlockCooldown","Stunned","CantAnything"}) do if char:GetAttribute(a)==true then char:SetAttribute(a,nil) end end end
		end)
	elseif not any and _cb.conn then _cb.conn:Disconnect(); _cb.conn=nil end
end
local function _cbToggle(k,v) _G.VH[k]=v; _cbRefresh() end
local function _cbFollowStart()
	if _cb.followConn then return end
	_cb.followConn=game:GetService("RunService").Heartbeat:Connect(function()
		if lib.Unloaded then return end
		if not _cb.tpTarget then return end
		local plr=game.Players:FindFirstChild(_cb.tpTarget); if not plr or not plr.Character then return end
		local thr=plr.Character:FindFirstChild("HumanoidRootPart"); local me=game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if thr and me then me.CFrame=thr.CFrame*CFrame.new(0,0,_cb.tpOffset) end
	end)
end
local function _cbFollowStop() if _cb.followConn then _cb.followConn:Disconnect(); _cb.followConn=nil end end
local function _cbTeleportNow()
	if not _cb.tpTarget then lib:Notify("Select a player first",2); return end
	local plr=game.Players:FindFirstChild(_cb.tpTarget)
	if plr and plr.Character then
		local thr=plr.Character:FindFirstChild("HumanoidRootPart"); local me=game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if thr and me then me.CFrame=thr.CFrame; lib:Notify("Teleported to ".._cb.tpTarget,2); return end
	end
	lib:Notify("Player not found",2)
end
	do
		local Combat = tbl5.Main:AddLeftGroupbox("Combat", "swords")

		local Self = tbl5.Player:AddRightGroupbox("Self", "shield")
		local Movement = tbl5.Player:AddLeftGroupbox("Movement", "move")

		Combat:AddToggle("CB_InfStamina",{Text="Infinite Stamina",Default=false,Callback=function(v)_cbToggle("cb_infStamina",v); fn17("Infinite Stamina", v and "Enabled" or "Disabled") end})
		Self:AddToggle("CB_NoStun",{Text="No Stun",Default=false,Callback=function(v)_cbToggle("cb_noStun",v); fn17("No Stun", v and "Enabled" or "Disabled") end})
		Self:AddToggle("CB_NoRagdoll",{Text="No Ragdoll",Default=false,Callback=function(v)_cbToggle("cb_noRagdoll",v); fn17("No Ragdoll", v and "Enabled" or "Disabled") end})
		Combat:AddToggle("CB_NoParryCD",{Text="No Parry Cooldown",Default=false,Callback=function(v)_cbToggle("cb_noParryCD",v); fn17("No Parry Cooldown", v and "Enabled" or "Disabled") end})
		Combat:AddToggle("AutoParry", {
			Text = "Auto Parry",
			Default = false,
			Callback = function(autoParryEnabled)
				_G.VH.autoParryEnabled = autoParryEnabled

				if not autoParryEnabled then
					_G.VH.autoParryPulse = _G.VH.autoParryPulse + 1
					fn19()
					local character = localPlayer.Character

					if character and character:GetAttribute("Blocking") == true then
						pcall(Block.Unblock)
					end

					fn18("idle")
				end

				fn17("Auto Parry", autoParryEnabled and "Enabled" or "Disabled")
			end,
		})

		Combat:AddToggle("AutoFace", {
			Text = "Auto Face",
			Default = false,
			Callback = function(autoFaceEnabled)
				_G.VH.autoFaceEnabled = autoFaceEnabled

				if not autoFaceEnabled then
					fn19()
				end

				fn17("Auto Face", autoFaceEnabled and "Enabled" or "Disabled")
			end,
		})

		Combat:AddToggle("PingComp", {
			Text = "Ping Compensation",
			Default = true,
			Tooltip = "Compensates latency for parry timing calculation",
			Callback = function(pingCompEnabled)
				_G.VH.pingCompEnabled = pingCompEnabled
				fn17("Ping Compensation", pingCompEnabled and "Enabled" or "Disabled")
			end,
		})


		Combat:AddToggle("AutoParryAll", {
			Text = "Auto Parry All Attacks",
			Default = false,
			Callback = function(v)
				_G.VH.autoParryAll = v
				fn17("Auto Parry All Attacks", v and "Enabled" or "Disabled")
			end,
		})

		Combat:AddToggle("AutoDodge", {
			Text = "Auto Dodge",
			Default = false,
			Callback = function(v)
				_G.VH.autoDodge = v
				fn17("Auto Dodge", v and "Enabled" or "Disabled")
			end,
		})

		Combat:AddSlider("DodgeAngle", {
			Text = "Dodge Angle Threshold",
			Min = 0,
			Max = 180,
			Default = 85,
			Callback = function(v)
				_G.VH.dodgeAngle = v
			end,
		})

		Combat:AddToggle("APBreaker", {
			Text = "AP Breaker",
			Default = false,
			Callback = function(v)
				_G.VH.apBreakerEnabled = v
				fn17("AP Breaker", v and "Enabled" or "Disabled")
			end,
		})

		Combat:AddDropdown("APBreakerPreset", {
			Text = "AP Breaker Preset",
			Values = {"Easy", "Medium", "Strict"},
			Default = 2,
			Callback = function(v)
				_G.VH.apBreakerPreset = v
			end,
		})

		Combat:AddSlider("APBreakerIntensity", {
			Text = "AP Breaker Intensity",
			Min = 1,
			Max = 100,
			Default = 50,
			Rounding = 0,
			Suffix = "%",
			Callback = function(v)
				_G.VH.apBreakerIntensity = v
			end,
		})

		Combat:AddToggle("AntiAPBreaker", {
			Text = "Anti AP Breaker",
			Default = false,
			Tooltip = "OFF = selalu parry (paling agresif)",
			Callback = function(v)
				_G.VH.antiApBreaker = v
				fn17("Anti AP Breaker", v and "Enabled" or "Disabled")
			end,
		})

		Combat:AddDropdown("AntiAPBreakerPreset", {
			Text = "Anti AP Breaker Preset",
			Values = {"Easy", "Medium", "Strict"},
			Default = 2,
			Callback = function(v)
				_G.VH.antiApBreakerPreset = v
			end,
		})

		Combat:AddToggle("AutoAttack", {
			Text = "Auto Attack",
			Default = false,
			Tooltip = "Automatically attacks opponents within reach",
			Callback = function(autoAttackEnabled)
				_G.VH.autoAttackEnabled = autoAttackEnabled
				fn17("Auto Attack", autoAttackEnabled and "Enabled" or "Disabled")
			end,
		})

		Combat:AddToggle("AutoEquip", {
			Text = "Auto Equip Fists",
			Default = false,
			Tooltip = "Re-equips combat fists after ragdoll or downed state",
			Callback = function(autoEquipEnabled)
				_G.VH.autoEquipEnabled = autoEquipEnabled

				if autoEquipEnabled then
					fn14()
				end

				fn17("Auto Equip", autoEquipEnabled and "Enabled" or "Disabled")
			end,
		})

		Combat:AddToggle("NoDodgeCooldown", {
			Text = "No Dodge Cooldown",
			Default = false,
			Callback = function(arg)
				fn21(arg)
			end,
		})

		Self:AddToggle("AntiFling", {
			Text = "Anti Fling",
			Default = false,
			Callback = function(arg)
				fn30(arg)
			end,
		})

		Self:AddToggle("AntiVoid", {
			Text = "Anti Void",
			Default = false,
			Callback = function(arg)
				fn31(arg)
			end,
		})

		Self:AddToggle("AutoHeartbeat", {
			Text = "Auto Heartbeat",
			Default = false,
			Callback = function(heartAutoEnabled)
				_G.VH.heartAutoEnabled = heartAutoEnabled

				if heartAutoEnabled then
					fn40()
				end

				fn17("Auto Heartbeat", heartAutoEnabled and "Enabled" or "Disabled")
			end,
		})

		Self:AddToggle("NoBlur", {
			Text = "No Blur",
			Default = false,
			Callback = function(arg)
				fn22(arg)
			end,
		})

		Self:AddDivider()

		Movement:AddToggle("Fly", {
			Text = "Fly",
			Default = false,
			Callback = function(arg)
				if arg then
					fn33()
				else
					fn34()
				end
			end,
		})

		Movement:AddSlider("FlySpeed", {
			Text = "Fly Speed",
			Default = 50,
			Min = 10,
			Max = 700,
			Rounding = 0,
			Suffix = "",
			Callback = function(flySpeed)
				_G.FLY_SPEED = flySpeed
			end,
		})

		Movement:AddDivider()

		Movement:AddToggle("Noclip", {
			Text = "Noclip",
			Default = false,
			Callback = function(arg)
				fn32(arg)
			end,
		})

		Movement:AddDivider()



	end

	do
		local v23 = tbl5.Visuals:AddLeftGroupbox("Personal HUD", "shield")
		local Players2 = tbl5.Visuals:AddRightGroupbox("Players", "eye")
		local v24 = tbl5.Visuals:AddLeftGroupbox("Combat Indicator", "swords")

		v23:AddToggle("SideHudToggle", {
			Text = "Status Hud",
			Default = false,
			Callback = function(sideHudEnabled)
				_G.VH.sideHudEnabled = sideHudEnabled

				if not sideHudEnabled and v19 then
					v19.Enabled = false
				end
			end,
		})

		v23:AddToggle("SideCooldownsToggle", {
			Text = "Dynamic Cooldown",
			Default = false,
			Callback = function(sideCooldownsEnabled)
				_G.VH.sideCooldownsEnabled = sideCooldownsEnabled

				if not sideCooldownsEnabled and v20 then
					v20.Enabled = false
				end
			end,
		})

		v23:AddDivider()


		Players2:AddToggle("EspMaster", {
			Text = "Active",
			Default = false,
			Callback = function(espEnabled)
				_G.VH.espEnabled = espEnabled

				if not espEnabled then
					fn25()
				else
					fn26()
				end

				fn17("Players ESP", espEnabled and "Enabled" or "Disabled")
			end,
		})

		Players2:AddToggle("EspBody", {
			Text = "Player Highlight",
			Default = true,
			Callback = function(espBodyEnabled)
				_G.VH.espBodyEnabled = espBodyEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.highlight then
						v25.highlight.Enabled = espBodyEnabled
					end
				end
			end,
		})

		Players2:AddDropdown("EspBodyMode", {
			Values = { "Outline", "Fill" },
			Default = 1,
			Multi = false,
			Text = "Type",
			Callback = function(espBodyMode)
				_G.VH.espBodyMode = espBodyMode

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.highlight then
						v25.highlight.FillTransparency = espBodyMode == "Fill" and 0.5 or 1
					end
				end
			end,
		})

		Players2:AddToggle("EspRealName", {
			Text = "RP Name",
			Default = true,
			Callback = function(espNameEnabled)
				_G.VH.espNameEnabled = espNameEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.nameLabel then
						v25.nameLabel.Visible = espNameEnabled
					end
				end
			end,
		})

		Players2:AddToggle("EspNick", {
			Text = "Real Name",
			Default = true,
			Callback = function(espNickEnabled)
				_G.VH.espNickEnabled = espNickEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.nickLabel then
						v25.nickLabel.Visible = espNickEnabled
					end
				end
			end,
		})

		Players2:AddToggle("EspHealth", {
			Text = "Health Text",
			Default = true,
			Callback = function(espHealthEnabled)
				_G.VH.espHealthEnabled = espHealthEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.hpLabel then
						v25.hpLabel.Visible = espHealthEnabled
					end
				end
			end,
		})

		Players2:AddToggle("EspFightingStyle", {
			Text = "Combat Style",
			Default = true,
			Callback = function(espStyleEnabled)
				_G.VH.espStyleEnabled = espStyleEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.smartStatusLabel then
						v25.smartStatusLabel.Visible = espStyleEnabled
					end
				end
			end,
		})

		Players2:AddToggle("EspDistance", {
			Text = "Distance Counter",
			Default = false,
			Callback = function(espDistanceEnabled)
				_G.VH.espDistanceEnabled = espDistanceEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.distLabel then
						v25.distLabel.Visible = espDistanceEnabled
					end
				end
			end,
		})

		Players2:AddToggle("EnemyHudToggle", {
			Text = "Enemy Hud",
			Default = false,
			Callback = function(enemyHudEnabled)
				_G.VH.enemyHudEnabled = enemyHudEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.sideHud then
						v25.sideHud.Enabled = enemyHudEnabled
					end
				end
			end,
		})

		Players2:AddToggle("EspHitbox", {
			Text = "Enemy Hitbox",
			Default = false,
			Callback = function(espHitboxEnabled)
				_G.VH.espHitboxEnabled = espHitboxEnabled

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.hitboxVisual then
						v25.hitboxVisual.Visible = espHitboxEnabled
					end
				end
			end,
		})

		Players2:AddSlider("EspDistanceMax", {
			Text = "Max Render Distance",
			Default = 150, -- ESP lag fix: default 150 (was 500)
			Min = 50,
			Max = 2000,
			Rounding = 0,
			Suffix = "m",
			Callback = function(espDistance)
				_G.VH.espDistance = espDistance

				for _, v25 in pairs(_G.VH.espHL) do
					if v25.billboard then
						v25.billboard.MaxDistance = espDistance
					end
				end
			end,
		})

		v24:AddToggle("ThreatZoneToggle", {
			Text = "Threat Zone",
			Default = false,
			Callback = function(threatZoneEnabled)
				_G.VH.threatZoneEnabled = threatZoneEnabled

				if not threatZoneEnabled then
					if v21 then
						v21.Transparency = 1
					end

					if v22 then
						v22.Transparency = 1
					end
				end
			end,
		})

		v24:AddToggle("ParryIndicatorToggle", {
			Text = "Parry Alert Ring",
			Default = false,
			Callback = function(parryIndicatorEnabled)
				_G.VH.parryIndicatorEnabled = parryIndicatorEnabled

				if not parryIndicatorEnabled and v18 then
					v18.BackgroundTransparency = 1
					local haloStroke = v18:FindFirstChild("HaloStroke")

					if haloStroke then
						haloStroke.Transparency = 1
					end
				end
			end,
		})

		v24:AddSlider("ThreatReachSlider", {
			Text = "Strike Reach",
			Default = 7.5,
			Min = 4,
			Max = 12,
			Rounding = 1,
			Suffix = " studs",
			Callback = function(threatRangeInReach)
				_G.VH.threatRangeInReach = threatRangeInReach
			end,
		})

		v24:AddSlider("ThreatDangerSlider", {
			Text = "Danger Proximity",
			Default = 18,
			Min = 10,
			Max = 30,
			Rounding = 0,
			Suffix = " studs",
			Callback = function(threatRangeDanger)
				_G.VH.threatRangeDanger = threatRangeDanger
			end,
		})

		v24:AddDivider()

		v24:AddLabel("In Reach Color"):AddColorPicker("ThreatCloseColor", {
			Default = Color3.fromRGB(0, 255, 120),
			Title = "In Strike Reach",
			Callback = function(colorThreatClose)
				_G.VH.colorThreatClose = colorThreatClose
			end,
		})

		v24:AddLabel("Danger Color"):AddColorPicker("ThreatFarColor", {
			Default = Color3.fromRGB(255, 50, 50),
			Title = "Danger Proximity",
			Callback = function(colorThreatFar)
				_G.VH.colorThreatFar = colorThreatFar
			end,
		})
	
		local Colors = tbl5.Visuals:AddLeftGroupbox("Color Settings", "palette")
		Colors:AddLabel("M2 Bar Color"):AddColorPicker("HudM2Color", {
			Default = Color3.fromRGB(255, 105, 105),
			Title = "M2 Cooldown Color",
			Callback = function(colorHudM2)
				_G.VH.colorHudM2 = colorHudM2
			end,
		})
		Colors:AddLabel("Dodge Bar Color"):AddColorPicker("HudDodgeColor", {
			Default = Color3.fromRGB(255, 190, 60),
			Title = "Dodge Cooldown Color",
			Callback = function(colorHudDodge)
				_G.VH.colorHudDodge = colorHudDodge
			end,
		})
		Colors:AddLabel("Life Bar Color"):AddColorPicker("HudLifeColor", {
			Default = Color3.fromRGB(80, 235, 125),
			Title = "Life Bar Color",
			Callback = function(colorHudLife)
				_G.VH.colorHudLife = colorHudLife
			end,
		})
		Colors:AddLabel("Stamina Bar Color"):AddColorPicker("HudStaminaColor", {
			Default = Color3.fromRGB(65, 165, 255),
			Title = "Stamina Bar Color",
			Callback = function(colorHudStamina)
				_G.VH.colorHudStamina = colorHudStamina
			end,
		})
	end

	local Extras = tbl5.Player:AddLeftGroupbox("Extras", "gamepad")
	local Fun = tbl5.Fun:AddStaticLeftGroupbox("Fun", "gamepad")

	Extras:AddToggle("ReturnByDeath", {
		Text = "Return by Death",
		Default = false,
		Callback = function(arg)
			fn46(arg)
		end,
	})

	Fun:AddToggle("AutoGreen", {
		Text = "Auto Green Basketball",
		Default = false,
		Callback = function(arg)
			fn44(arg)
		end,
	})

	Fun:AddToggle("RhythmAutoPerfect", {
		Text = "Auto Perfect Music",
		Default = false,
		Callback = function(arg)
			fn45(arg)
		end,
	})

	Fun:AddDivider()

	Extras:AddToggle("InfJump", {
		Text = "Inf Jump",
		Default = false,
		Callback = function(arg)
			fn42(arg)
		end,
	})

	Extras:AddToggle("InfCamZoom", {
		Text = "Inf Cam Zoom",
		Default = false,
		Callback = function(arg)
			fn47(arg)
		end,
	})

	Extras:AddToggle("FpsBoostToggle", {
		Text = "FPS Boost",
		Default = false,
		Callback = function(arg)
			fn29(arg)
		end,
	})

	do
		local v23 = nil

		local function fn51(arg, arg2)
			if arg2 then
				local areaHitboxes = workspace:FindFirstChild("AreaHitboxes")

				if areaHitboxes then
					local str6 = arg2:lower():gsub("%s+", "")

					for _, descendant in ipairs(areaHitboxes:GetDescendants()) do
						if descendant:IsA("BasePart") then
							local str7 = descendant.Name:lower():gsub("%s+", "")
							if str7 == str6 or str7:find(str6, 1, true) or str6:find(str7, 1, true) then
								return descendant.Position
							end
						end
					end
				end
			end

			return arg
		end

		local function fn52(arg, arg2)
			local character = localPlayer.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid_ = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoidRootPart or not humanoid_ or humanoid_.Health <= 0 then
				return
			end
			local v24 = fn51(arg, arg2)

			pcall(function()
				localPlayer:RequestStreamingAroundAsync(v24)
			end)

			if v23 and v23.Parent then
				pcall(function()
					v23:Destroy()
				end)

				v23 = nil
			end

			local part2 = Instance.new("Part")
			part2.Name = "Veneno_SafetyPlatform"
			part2.Size = Vector3.new(24, 2, 24)
			part2.CFrame = CFrame.new(v24 - Vector3.new(0, 0.5, 0))
			part2.Anchored = true
			part2.CanCollide = true
			part2.Transparency = 1
			part2.Parent = workspace
			v23 = part2

			if _G.VH and type(_G.VH.createdObjects) == "table" then
				table.insert(_G.VH.createdObjects, part2)
			end

			if humanoid_.Sit then
				humanoid_.Sit = false
			end

			humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
			humanoidRootPart.Anchored = true
			humanoidRootPart.CFrame = CFrame.new(v24 + Vector3.new(0, 4, 0))

			task.spawn(function()
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = { character, part2 }
				raycastParams.IgnoreWater = true
				local flag11 = false

				for i = 1, 15 do
					task.wait(0.1)

					if not (not humanoidRootPart or not humanoidRootPart.Parent) then
						humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
						humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
						local hit = workspace:Raycast(v24 + Vector3.new(0, 15, 0), Vector3.new(0, -35, 0), raycastParams)

						if hit and hit.Position then
							part2.CFrame = CFrame.new(v24.X, hit.Position.Y - 1, v24.Z)
							humanoidRootPart.CFrame = CFrame.new(v24.X, hit.Position.Y + 3.5, v24.Z)
							flag11 = true
							break
						else
							continue
						end
					end

					break
				end

				if not flag11 and humanoidRootPart and humanoidRootPart.Parent then
					humanoidRootPart.CFrame = CFrame.new(v24 + Vector3.new(0, 4, 0))
				end

				task.wait(0.15)

				if humanoidRootPart and humanoidRootPart.Parent then
					humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
					humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
					humanoidRootPart.Anchored = false
				end

				task.wait(4)

				if part2 and part2.Parent then
					part2:Destroy()
				end

				if v23 == part2 then
					v23 = nil
				end
			end)
		end

		local v24 = tbl5.Teleport:AddStaticLeftGroupbox("Campus & School", "school")

		v24:AddButton({
			Text = "Indoor Gymnasium",
			Func = function()
				fn52(Vector3.new(3.4, -230.6, 502.9), "Indoor Gymnasium")
			end,
		})

		v24:AddButton({
			Text = "Basketball Court",
			Func = function()
				fn52(Vector3.new(38.6, -233, 504.8), "Basketball Court")
			end,
		})

		v24:AddButton({
			Text = "Volleyball Court",
			Func = function()
				fn52(Vector3.new(-30.1, -232.2, 504.8), "Volleyball Court")
			end,
		})

		v24:AddButton({
			Text = "Dojo Room",
			Func = function()
				fn52(Vector3.new(85.3, -225.7, 273.1), "Dojo Room")
			end,
		})

		v24:AddButton({
			Text = "Music Room",
			Func = function()
				fn52(Vector3.new(141.9, -220.9, 49.2), "Music Room")
			end,
		})

		v24:AddButton({
			Text = "Secondary Music Room",
			Func = function()
				fn52(Vector3.new(74.3, -221, 261.3), "Secondary Music Room")
			end,
		})

		v24:AddButton({
			Text = "Rooftop",
			Func = function()
				fn52(Vector3.new(146.8, -202.4, 248.4), "Rooftop")
			end,
		})

		v24:AddButton({
			Text = "Cafeteria",
			Func = function()
				fn52(Vector3.new(-49.6, -248, 273.8), "Cafeteria")
			end,
		})

		v24:AddButton({
			Text = "Courtyard",
			Func = function()
				fn52(Vector3.new(18.5, -242.9, 164.1), "Courtyard")
			end,
		})

		v24:AddButton({
			Text = "Infirmary",
			Func = function()
				fn52(Vector3.new(206.3, -235.7, 112), "Infirmary")
			end,
		})

		v24:AddButton({
			Text = "School Entrance",
			Func = function()
				fn52(Vector3.new(253.2, -256.6, 155.7), "Nishikata High Entrance")
			end,
		})

		local v25 = tbl5.Teleport:AddStaticRightGroupbox("Town & District", "map-pin")

		v25:AddButton({
			Text = "Club Akuma (Fight Club)",
			Func = function()
				fn52(Vector3.new(-284.7, -283.5, 316.8), "Club Akuma")
			end,
		})

		v25:AddButton({
			Text = "GAKUMART",
			Func = function()
				fn52(Vector3.new(-206.8, -272, 199.9), "GAKUMART")
			end,
		})

		v25:AddButton({
			Text = "Skatepark",
			Func = function()
				fn52(Vector3.new(98.6, -290.9, -147.6), "Skatepark")
			end,
		})

		v25:AddButton({
			Text = "Dante's Yakiniku",
			Func = function()
				fn52(Vector3.new(-84.8, -283.9, -160.5), "Dante's Yakiniku")
			end,
		})

		v25:AddButton({
			Text = "Karaoke Center",
			Func = function()
				fn52(Vector3.new(13.1, -286.8, -144.7), "Karaoke Center")
			end,
		})

		v25:AddButton({
			Text = "Arcade Clubroom",
			Func = function()
				fn52(Vector3.new(206.3, -237.8, 197.8), "Arcade Clubroom")
			end,
		})

		v25:AddButton({
			Text = "Nishikata District",
			Func = function()
				fn52(Vector3.new(-148.9, -272, 146.3), "Nishikata District")
			end,
		})

		v25:AddButton({
			Text = "Parking Lot",
			Func = function()
				fn52(Vector3.new(88.2, -263.2, 291.5), "Parking Lot")
			end,
		})
	end


	local TP=tbl5.Teleport:AddStaticLeftGroupbox("Teleport Player","compass")
	local _tpn={}; for _,plr in ipairs(game.Players:GetPlayers()) do if plr~=game.Players.LocalPlayer then table.insert(_tpn,plr.Name) end end; if #_tpn==0 then _tpn={"(no players)"} end
	TP:AddDropdown("TPTarget",{Text="Target Player",Values=_tpn,Default=1,Callback=function(v)_cb.tpTarget=v end})
	TP:AddSlider("TPOffset",{Text="Follow Distance",Min=0,Max=20,Default=3,Rounding=0,Suffix=" studs",Callback=function(v)_cb.tpOffset=v end})
	TP:AddButton({Text="Teleport Now",Func=_cbTeleportNow})
	TP:AddToggle("TPFollow",{Text="Follow Player",Default=false,Callback=function(v) if v then _cbFollowStart() else _cbFollowStop() end; fn17("Follow Player", v and "Enabled" or "Disabled") end})

	local Gen = tbl5.Settings:AddLeftGroupbox("General Settings", "settings")
	Gen:AddButton({ Text = "Rejoin Server", Func = fn48 })
	Gen:AddButton({ Text = "Server Hop", Func = fn49 })
	Gen:AddButton({ Text = "Empty Server Hop", Func = fn50 })
	Gen:AddButton({ Text = "Unload Hub", Func = cleanup })

	lib2:SetLibrary(lib)
	lib2:SetFolder("Clavv Hub/Gakuran")

	lib2:SetDefaultTheme({
		BackgroundColor = Color3.fromRGB(10, 10, 10),
		MainColor = Color3.fromRGB(20, 20, 20),
		AccentColor = Color3.fromRGB(255, 0, 0),
		OutlineColor = Color3.fromRGB(40, 40, 40),
		FontColor = Color3.fromRGB(255, 255, 255),
		FontFace = Enum.Font.Fantasy,
	})


	local function fn51()
		pcall(function()
			local v24 = ipairs
			local labels = lib.Labels or {}

			for _, label in v24(labels) do
				local text = label and label.Text

				if text then
					text = tostring(label.Text):lower():find("contrast", 1, true)
				end

				if text then
					pcall(function()
						label:Destroy()
					end)
				end
			end

			local screenGui = lib.ScreenGui

			if screenGui then
				for _, descendant in ipairs(screenGui:GetDescendants()) do
					if descendant:IsA("TextLabel") and descendant.Text:lower():find("contrast", 1, true) then
						pcall(function()
							descendant:Destroy()
						end)
					end
				end
			end
		end)
	end

	fn51()
	lib3:SetLibrary(lib)
	lib3:IgnoreThemeSettings()
	lib3:SetIgnoreIndexes({ "MenuKeybind" })
	lib3:SetFolder("Clavv Hub/Gakuran")
	fn51()
	task.spawn(fn12)

	task.delay(0.25, function()
		flag10 = true
		fn17("Clavv Hub", "Loaded successfully!", 4)
	end)

end, function(e)
    return tostring(e) .. "\n" .. ((debug and debug.traceback) and debug.traceback() or "")
end)

if not _ok then
    warn("[Clavv Hub] Execution error: " .. tostring(_err))
    pcall(function() if Clavv and Clavv.Notify then Clavv:Notify("Script error: " .. tostring(_err), 6) end end)
else
    pcall(function() if Clavv and Clavv.Notify then Clavv:Notify("Clavv Hub loaded !", 3) end end)
end
