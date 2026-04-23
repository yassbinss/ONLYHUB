local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- [1] UI 초기화
local uiName = "KichaRemake_Final_Stable"
for _, v in pairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
    if v.Name:find("Elite") or v.Name:find("Kicha") or v.Name == uiName then v:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
ScreenGui.Name = uiName
ScreenGui.ResetOnSpawn = false

----------------------------------------------------------------
-- [2] 설정값 (TP 딜레이 관련 기본값 포함)
----------------------------------------------------------------
local Config = {
    aimOn = false, 
    aimPart = "Head", 
    wallOn = true, teamOn = true, espOn = true, showFov = false,
    aimSmooth = 10, fovRadius = 150,
    -- ESP 세부 설정
    espName = true, espDist = true, espHealth = true,
    -- MISC/이동
    wsOn = false, walkSpeedVal = 16, 
    flyOn = false, flySpeedVal = 50, 
    noclipOn = false,
    tpTargetOn = false, 
    tpPosition = "Behind", 
    tpDelayEnable = true, -- TP 딜레이 활성화 여부 (기본 ON)
    tpDelay = 1.0,        -- 타겟 전환 주기 (초 단위)
    -- UI 및 키바인드
    uiColor = Color3.fromRGB(170, 85, 255),
    menuKey = Enum.KeyCode.Insert,
    aimKey = Enum.KeyCode.V,
    espKey = Enum.KeyCode.B
}

local lastTpTime = 0
local currentTpTarget = nil -- 현재 추적 중인 타겟 저장용

----------------------------------------------------------------
-- [3] UI 구조
----------------------------------------------------------------
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 450, 0, 380); Main.Position = UDim2.new(0.5, -225, 0.5, -190)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Main.BorderSizePixel = 0; Main.Active = true; Main.Draggable = true

local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1, 0, 0, 3); TopBar.BackgroundColor3 = Config.uiColor; TopBar.BorderSizePixel = 0

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 100, 1, -3); Sidebar.Position = UDim2.new(0, 0, 0, 3); Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20); Sidebar.BorderSizePixel = 0

local Container = Instance.new("Frame", Main)
Container.Size = UDim2.new(1, -110, 1, -13); Container.Position = UDim2.new(0, 105, 0, 8); Container.BackgroundTransparency = 1

local Pages = {}
local function CreatePage(name)
    local p = Instance.new("ScrollingFrame", Container)
    p.Size = UDim2.new(1, 0, 1, 0); p.BackgroundTransparency = 1; p.Visible = false; p.ScrollBarThickness = 0; p.CanvasSize = UDim2.new(0,0,0,650)
    Instance.new("UIListLayout", p).Padding = UDim.new(0, 5)
    Pages[name] = p; return p
end

local CombatPage = CreatePage("Aim"); CombatPage.Visible = true
local VisualsPage = CreatePage("Esp")
local MiscPage = CreatePage("Misc")
local SettingsPage = CreatePage("Set")

local function CreateTab(t, y, p)
    local b = Instance.new("TextButton", Sidebar)
    b.Size = UDim2.new(1, 0, 0, 40); b.Position = UDim2.new(0, 0, 0, y); b.Text = t; b.BackgroundColor3 = Color3.fromRGB(20, 20, 20); b.TextColor3 = Color3.fromRGB(150, 150, 150); b.Font = Enum.Font.Code; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        for _, v in pairs(Pages) do v.Visible = false end
        for _, v in pairs(Sidebar:GetChildren()) do if v:IsA("TextButton") then v.TextColor3 = Color3.fromRGB(150, 150, 150) end end
        p.Visible = true; b.TextColor3 = Config.uiColor
    end)
    if y == 0 then b.TextColor3 = Config.uiColor end
end
CreateTab("COMBAT", 0, CombatPage); CreateTab("VISUALS", 40, VisualsPage); CreateTab("MISC", 80, MiscPage); CreateTab("SETTINGS", 120, SettingsPage)

local function CreateToggle(t, p, k)
    local b = Instance.new("TextButton", p)
    b.Size = UDim2.new(1, 0, 0, 30); b.BackgroundColor3 = Color3.fromRGB(25, 25, 25); b.TextColor3 = Color3.new(0.8,0.8,0.8); b.Font = Enum.Font.Code; b.BorderSizePixel = 0
    local function up() b.TextColor3 = Config[k] and Config.uiColor or Color3.new(0.8,0.8,0.8); b.Text = t .. (Config[k] and " [ON]" or " [OFF]") end
    up(); b.MouseButton1Click:Connect(function() Config[k] = not Config[k]; up() end)
    return up
end

local function CreateSlider(t, p, min, max, k, isFloat)
    local f = Instance.new("Frame", p); f.Size = UDim2.new(1, 0, 0, 45); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f); l.Size = UDim2.new(1, 0, 0, 20); l.Text = t .. ": " .. Config[k]; l.TextColor3 = Color3.new(0.8,0.8,0.8); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code; l.TextXAlignment = Enum.TextXAlignment.Left
    local bg = Instance.new("Frame", f); bg.Size = UDim2.new(1, 0, 0, 4); bg.Position = UDim2.new(0, 0, 0, 28); bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30); bg.BorderSizePixel = 0
    local fill = Instance.new("Frame", bg); fill.Size = UDim2.new((Config[k]-min)/(max-min), 0, 1, 0); fill.BackgroundColor3 = Config.uiColor; fill.BorderSizePixel = 0
    bg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local conn; conn = RunService.RenderStepped:Connect(function()
                local pos = math.clamp((UserInputService:GetMouseLocation().X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
                local val = min + (max - min) * pos
                if isFloat then val = math.floor(val * 10) / 10 else val = math.floor(val) end
                Config[k] = val; fill.Size = UDim2.new(pos, 0, 1, 0); l.Text = t .. ": " .. val
                if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then conn:Disconnect() end
            end)
        end
    end)
end

local function CreateKeybind(t, p, k)
    local b = Instance.new("TextButton", p)
    b.Size = UDim2.new(1, 0, 0, 30); b.BackgroundColor3 = Color3.fromRGB(25, 25, 25); b.TextColor3 = Color3.new(0.8,0.8,0.8); b.Font = Enum.Font.Code; b.BorderSizePixel = 0
    b.Text = t .. ": " .. Config[k].Name
    b.MouseButton1Click:Connect(function()
        b.Text = "Press any key..."; local conn
        conn = UserInputService.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.Keyboard then
                Config[k] = io.KeyCode; b.Text = t .. ": " .. io.KeyCode.Name; conn:Disconnect()
            end
        end)
    end)
end

----------------------------------------------------------------
-- [4] 기능 배치
----------------------------------------------------------------
local upAim = CreateToggle("ENABLE AIMBOT", CombatPage, "aimOn")
local targetPartBtn = Instance.new("TextButton", CombatPage)
targetPartBtn.Size = UDim2.new(1, 0, 0, 30); targetPartBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25); targetPartBtn.TextColor3 = Config.uiColor; targetPartBtn.Font = Enum.Font.Code; targetPartBtn.BorderSizePixel = 0
targetPartBtn.Text = "TARGET: " .. Config.aimPart:upper()
targetPartBtn.MouseButton1Click:Connect(function()
    Config.aimPart = (Config.aimPart == "Head" and "HumanoidRootPart" or "Head")
    targetPartBtn.Text = "TARGET: " .. (Config.aimPart == "Head" and "HEAD" or "BODY")
end)
CreateToggle("WALL CHECK", CombatPage, "wallOn")
CreateToggle("TEAM CHECK", CombatPage, "teamOn")
CreateToggle("SHOW FOV", CombatPage, "showFov")
CreateSlider("SMOOTH", CombatPage, 1, 50, "aimSmooth")
CreateSlider("RADIUS", CombatPage, 10, 500, "fovRadius")

local upEsp = CreateToggle("MASTER ESP", VisualsPage, "espOn")
CreateToggle("SHOW NAMES", VisualsPage, "espName")
CreateToggle("SHOW DISTANCE", VisualsPage, "espDist")
CreateToggle("SHOW HEALTH", VisualsPage, "espHealth")

-- [Misc] TP 딜레이 관련 UI 추가
CreateToggle("AUTO TP (TARGET)", MiscPage, "tpTargetOn")
local posBtn = Instance.new("TextButton", MiscPage)
posBtn.Size = UDim2.new(1, 0, 0, 30); posBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25); posBtn.TextColor3 = Color3.new(1,1,1); posBtn.Font = Enum.Font.Code; posBtn.BorderSizePixel = 0
posBtn.Text = "TP POS: " .. Config.tpPosition:upper()
posBtn.MouseButton1Click:Connect(function()
    if Config.tpPosition == "Behind" then Config.tpPosition = "Under"
    elseif Config.tpPosition == "Under" then Config.tpPosition = "Above"
    else Config.tpPosition = "Behind" end
    posBtn.Text = "TP POS: " .. Config.tpPosition:upper()
end)
CreateToggle("TP DELAY SWITCH", MiscPage, "tpDelayEnable")
CreateSlider("TP DELAY SEC", MiscPage, 0.1, 5.0, "tpDelay", true)

CreateToggle("WALKSPEED", MiscPage, "wsOn"); CreateSlider("SPEED", MiscPage, 16, 250, "walkSpeedVal")
CreateToggle("FLY", MiscPage, "flyOn"); CreateSlider("FLY SPEED", MiscPage, 10, 500, "flySpeedVal")
CreateToggle("NOCLIP", MiscPage, "noclipOn")

CreateKeybind("MENU KEY", SettingsPage, "menuKey")
CreateKeybind("AIMBOT KEY", SettingsPage, "aimKey")
CreateKeybind("ESP KEY", SettingsPage, "espKey")

UserInputService.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if io.KeyCode == Config.menuKey then Main.Visible = not Main.Visible
    elseif io.KeyCode == Config.aimKey then Config.aimOn = not Config.aimOn; upAim()
    elseif io.KeyCode == Config.espKey then Config.espOn = not Config.espOn; upEsp() end
end)

----------------------------------------------------------------
-- [5] 메인 엔진 로직
----------------------------------------------------------------
local function IsVisible(targetPart)
    if not Config.wallOn then return true end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position), rayParams)
    return not result or result.Instance:IsDescendantOf(targetPart.Parent)
end

local FOVCircle = Instance.new("Frame", ScreenGui)
FOVCircle.BackgroundTransparency = 0.8; FOVCircle.BorderSizePixel = 0; FOVCircle.Visible = false; Instance.new("UICorner", FOVCircle).CornerRadius = UDim.new(1, 0)

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    -- [개선된 TP KILL 엔진 (딜레이 로직 포함)]
    if Config.tpTargetOn and hrp then
        local now = tick()
        
        -- 타겟이 없거나, 딜레이가 비활성화되었거나, 딜레이 시간이 지났을 때만 새로운 타겟 검색
        if not currentTpTarget or not Config.tpDelayEnable or (now - lastTpTime >= Config.tpDelay) then
            local closestDist = math.huge
            local newTarget = nil
            
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    if Config.teamOn and p.Team == LocalPlayer.Team then continue end
                    local tHum = p.Character:FindFirstChild("Humanoid")
                    if tHum and tHum.Health > 0 then
                        local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                        if d < closestDist then
                            closestDist = d
                            newTarget = p
                        end
                    end
                end
            end
            
            -- 타겟이 바뀌었을 경우에만 시간 초기화
            if newTarget ~= currentTpTarget then
                currentTpTarget = newTarget
                lastTpTime = now
            end
        end

        -- 현재 타겟 추적 로직
        if currentTpTarget and currentTpTarget.Character and currentTpTarget.Character:FindFirstChild("HumanoidRootPart") then
            local tHRP = currentTpTarget.Character.HumanoidRootPart
            local tHum = currentTpTarget.Character:FindFirstChild("Humanoid")
            
            -- 타겟이 죽으면 즉시 초기화하여 다음 타겟을 잡게 함
            if not tHum or tHum.Health <= 0 then
                currentTpTarget = nil
            else
                hrp.Velocity = Vector3.new(0, 0, 0)
                hrp.RotVelocity = Vector3.new(0, 0, 0)
                
                if Config.tpPosition == "Behind" then 
                    hrp.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3.5) * CFrame.Angles(0, math.pi, 0)
                elseif Config.tpPosition == "Under" then 
                    hrp.CFrame = tHRP.CFrame * CFrame.new(0, -6.5, 0) * CFrame.Angles(math.rad(90), 0, 0)
                elseif Config.tpPosition == "Above" then 
                    hrp.CFrame = tHRP.CFrame * CFrame.new(0, 6.5, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                end
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, tHRP.Position)
            end
        else
            currentTpTarget = nil
        end
    else
        currentTpTarget = nil
    end

    -- [ESP 엔진]
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local tChar = p.Character; local tHum = tChar:FindFirstChild("Humanoid"); local tHead = tChar:FindFirstChild("Head")
            if Config.espOn and tHum and tHum.Health > 0 and (not (Config.teamOn and p.Team == LocalPlayer.Team)) then
                if tHead then
                    local gui = tHead:FindFirstChild("EliteESP") or Instance.new("BillboardGui", tHead)
                    gui.Name = "EliteESP"; gui.Size = UDim2.new(0, 200, 0, 100); gui.AlwaysOnTop = true; gui.StudsOffset = Vector3.new(0, 3, 0)
                    local lbl = gui:FindFirstChild("Label") or Instance.new("TextLabel", gui)
                    lbl.Name = "Label"; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1, 1, 1); lbl.Font = Enum.Font.Code; lbl.TextSize = 14
                    lbl.TextStrokeTransparency = 0; lbl.TextYAlignment = Enum.TextYAlignment.Center
                    
                    local lines = {}
                    if Config.espName then table.insert(lines, p.Name) end
                    local subInfo = ""
                    if Config.espHealth then subInfo = subInfo .. math.floor(tHum.Health) .. "HP " end
                    if Config.espDist then 
                        local d = math.floor((tHead.Position - Camera.CFrame.Position).Magnitude)
                        subInfo = subInfo .. "[" .. d .. "m]"
                    end
                    if subInfo ~= "" then table.insert(lines, subInfo) end
                    
                    lbl.Text = table.concat(lines, "\n")
                    gui.Enabled = #lines > 0
                end
            else
                if tHead and tHead:FindFirstChild("EliteESP") then tHead.EliteESP.Enabled = false end
            end
        end
    end

    -- FOV & AIMBOT
    if Config.showFov then
        FOVCircle.Visible = true; FOVCircle.Size = UDim2.new(0, Config.fovRadius * 2, 0, Config.fovRadius * 2)
        FOVCircle.Position = UDim2.new(0, center.X - Config.fovRadius, 0, center.Y - Config.fovRadius); FOVCircle.BackgroundColor3 = Config.uiColor
    else FOVCircle.Visible = false end

    if Config.aimOn and not Config.tpTargetOn then
        local target, dist = nil, Config.fovRadius
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(Config.aimPart) and p.Character.Humanoid.Health > 0 then
                if Config.teamOn and p.Team == LocalPlayer.Team then continue end
                local tPart = p.Character[Config.aimPart]
                local pos, vis = Camera:WorldToViewportPoint(tPart.Position)
                if vis then
                    local mag = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if mag < dist and IsVisible(tPart) then target = p; dist = mag end
                end
            end
        end
        if target then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Character[Config.aimPart].Position), 1/math.max(Config.aimSmooth, 1)) end
    end
    
    if hum then hum.WalkSpeed = Config.wsOn and Config.walkSpeedVal or 16 end
    if Config.flyOn and hrp then
        hrp.Velocity = Vector3.new(0,0,0)
        hrp.CFrame = hrp.CFrame + (Camera.CFrame.LookVector * (Config.flySpeedVal/50) * (hum.MoveDirection.Magnitude > 0 and 1 or 0))
    end
end)

-- [물리 충돌 무시 로직]
RunService.Stepped:Connect(function()
    if (Config.noclipOn or Config.tpTargetOn) and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do 
            if v:IsA("BasePart") then v.CanCollide = false end 
        end
    end
end)
