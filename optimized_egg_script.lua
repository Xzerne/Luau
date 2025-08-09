local rs = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local virtualInputManager = game:GetService("VirtualInputManager")
local player = players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local CONFIG = {
    LOOP_WAIT = 0, 
    TP_COOLDOWN = 0.5, 
    MAX_RETRY = 3 
}

local state = {
    eggSelected = nil,
    autoNoTP = false,
    autoWithTP = false,
    lastTeleport = 0,
    isProcessing = false
}

local function safeWait(duration)
    local startTime = tick()
    while tick() - startTime < duration and runService.Heartbeat:Wait() do end
end

local function getWorldList()
    local worldList = {}
    local worldsFolder = workspace:FindFirstChild("Worlds")
    
    if worldsFolder then
        for _, world in ipairs(worldsFolder:GetChildren()) do
            if world:IsA("Model") or world:IsA("Folder") then
                table.insert(worldList, world.Name)
            end
        end
    end
    
    
    table.sort(worldList, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    
    return worldList
end

local function safeTeleport(targetCFrame)
    local currentTime = tick()
    if currentTime - state.lastTeleport < CONFIG.TP_COOLDOWN then
        return false
    end
    
    state.lastTeleport = currentTime
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    if distance < 10 then
        return true 
    end
    
    hrp.CFrame = targetCFrame
    return true
end

local function attemptEggOpen(eggName, withTP)
    if state.isProcessing then return end
    state.isProcessing = true
    
    local success = false
    local retries = 0
    
    while retries < CONFIG.MAX_RETRY and not success do
        pcall(function()
            if withTP then
                
                local eggObject = workspace.Worlds:FindFirstChild(state.eggSelected .. "Egg")
                if eggObject and safeTeleport(eggObject:GetPivot()) then
                    safeWait(0.3) 
                end
            end
            
            local remote = rs:FindFirstChild("Remote")
            if remote then
                local attemptMultiOpen = remote:FindFirstChild("AttemptMultiOpen")
                if attemptMultiOpen then
                    attemptMultiOpen:FireServer(eggName)
                    success = true
                end
            end
        end)
        
        retries = retries + 1
        if not success then
            safeWait(0.1)
        end
    end
    
    state.isProcessing = false
    return success
end

local function ToogleButtonV()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DraggableControlButton"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    
    local button = Instance.new("TextButton")
    button.Name = "ControlButton"
    button.Parent = screenGui
    button.Size = UDim2.new(0, 60, 0, 60)
    button.Position = UDim2.new(0, 100, 0, 100)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Text = "CTRL"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Active = true
    button.Draggable = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button
    
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Parent = button
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, 2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = button.ZIndex - 1
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    local originalSize = button.Size
    local hoverSize = UDim2.new(0, 65, 0, 65)
    
    local hoverTween = tweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = hoverSize, BackgroundColor3 = Color3.fromRGB(55, 55, 55)}
    )
    
    local unhoverTween = tweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize, BackgroundColor3 = Color3.fromRGB(45, 45, 45)}
    )
    
    button.MouseEnter:Connect(function()
        hoverTween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        unhoverTween:Play()
    end)
    
    local clickTween = tweenService:Create(
        button,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(35, 35, 35)}
    )
    
    local unclickTween = tweenService:Create(
        button,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize, BackgroundColor3 = Color3.fromRGB(45, 45, 45)}
    )
    
    button.MouseButton1Click:Connect(function()
        clickTween:Play()
        
        pcall(function()
            virtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            task.wait(0.05)
            virtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end)
        
        button.Text = "✓"
        task.wait(0.1)
        button.Text = "CTRL"
        
        unclickTween:Play()
    end)
    
    button.ZIndex = 999
    shadow.ZIndex = 998
    
    return screenGui
end

local WorldList = getWorldList()
if #WorldList == 0 then
    warn("No worlds found in workspace.Worlds")
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Auto Open Egg | AFS",
    SubTitle = "By Someone In The World",
    TabWidth = 180,
    Size = UDim2.fromOffset(450, 350),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "" }),
}

local Options = Fluent.Options

do
    local onoffbutton = ToogleButtonV()
    
    local statusLabel = Tabs.Main:AddParagraph({
        Title = "Status",
        Content = "Ready"
    })

    local EggsDropdown = Tabs.Main:AddDropdown("EggsDropdown", {
        Title = "Select World",
        Values = WorldList,
        Multi = false,
        Default = "",
    })

    EggsDropdown:OnChanged(function(Value)
        state.eggSelected = Value
    end)

   

    local autoEggNoTP = Tabs.Main:AddToggle("autoEggNoTP", {
        Title = "Auto Open Egg",
        Default = false
    })
    autoEggNoTP:OnChanged(function(Value)
        state.autoNoTP = Value
        if Value then
            state.autoWithTP = false 
            Options.autoEggTP:SetValue(false)
        end
    end)

   

    local speedSlider = Tabs.Settings:AddSlider("Speed", {
        Title = "Loop Wait (seconds)",
        Description = "Adjust loop speed",
        Default = 0.1,
        Min = 0.05,
        Max = 2,
        Rounding = 2
    })
    speedSlider:OnChanged(function(Value)
        CONFIG.LOOP_WAIT = Value
    end)

    

    
    local connection
    connection = runService.Heartbeat:Connect(function()
        if state.eggSelected and state.eggSelected ~= "" then
            if state.autoNoTP or state.autoWithTP then
                if not state.isProcessing then
                    local eggName = state.eggSelected .. "Egg"
                    
                    
                    if state.autoWithTP then
                        local eggObject = workspace.Worlds:FindFirstChild(eggName)
                        if eggObject then
                            local distance = (hrp.Position - eggObject:GetPivot().Position).Magnitude
                            if distance > 50 then 
                                hrp.CFrame = eggObject:GetPivot()
                                safeWait(0.2) 
                                statusLabel:SetDesc("Teleported to: " .. eggName)
                            end
                        end
                    end
                    
                    local success = attemptEggOpen(eggName, false) -- Don't TP again in function
                    
                    statusLabel:SetDesc(success and 
                        ("Opening: " .. eggName) or 
                        ("Failed: " .. eggName)
                    )
                end
            else
                statusLabel:SetDesc("Automation stopped")
            end
        else
            statusLabel:SetDesc("No world selected")
        end
        
        safeWait(CONFIG.LOOP_WAIT)
    end)

    Tabs.Main:AddButton({
        Title = "TP To Egg",
        Description = "Teleport to selected egg",
        Callback = function()
            if state.eggSelected and state.eggSelected ~= "" then
                local eggName = state.eggSelected .. "Egg"
                local eggObject = workspace.Worlds:FindFirstChild(eggName)
                
                if eggObject then
                   
                    hrp.CFrame = eggObject:GetPivot()
                    statusLabel:SetDesc("Teleported to: " .. eggName)
                else
                    
                    local worldObject = workspace.Worlds:FindFirstChild(state.eggSelected)
                    if worldObject then
                        local eggInWorld = worldObject:FindFirstChild("Egg") or worldObject:FindFirstChild(eggName)
                        if eggInWorld then
                            hrp.CFrame = eggInWorld:GetPivot()
                            statusLabel:SetDesc("Teleported to: " .. eggName)
                        else
                            warn("Egg not found in world: " .. state.eggSelected)
                            statusLabel:SetDesc("Egg not found in world!")
                        end
                    else
                        warn("Egg not found: " .. eggName)
                        statusLabel:SetDesc("Egg not found!")
                    end
                end
            else
                warn("No egg selected!")
                statusLabel:SetDesc("No egg selected!")
            end
        end
    })

    Tabs.Main:AddButton({
        Title = "Stop All",
        Description = "Stop all automation",
        Callback = function()
            state.autoNoTP = false
            state.autoWithTP = false
            Options.autoEggNoTP:SetValue(false)
            Options.autoEggTP:SetValue(false)
            statusLabel:SetDesc("Emergency stopped")
        end
    })

  

   
    players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            if connection then
                connection:Disconnect()
            end
            if onoffbutton then
                onoffbutton:Destroy()
            end
        end
    end)

    
    player.CharacterAdded:Connect(function(newChar)
        char = newChar
        hrp = char:WaitForChild("HumanoidRootPart")
    end)
end

local vu = game:GetService("VirtualUser")
local plr = game.Players.LocalPlayer
plr.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)