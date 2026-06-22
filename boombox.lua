-- ============================================================
-- БУМБОКС МЕНЕДЖЕР + GUI
-- Полный скрипт с графическим интерфейсом
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- КОНФИГУРАЦИЯ
-- ============================================================
local CONFIG = {
    MaxVolumeValue = 10000,
    BoomVol = { enabled = false, volume = 100 },
    MuteTaco = { enabled = false, targetAudioId = "142376088" },
    ClickBoom = { enabled = false },
    AutoPlay = { enabled = false, audioId = "142376088" },
    DisableUI = { enabled = false }
}

-- ============================================================
-- ОСНОВНАЯ ЛОГИКА (без GUI)
-- ============================================================

local function getAllBoomboxes()
    local boomboxes = {}
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item.Name == "SuperFlyGoldBoombox" and item:IsA("Tool") then
            table.insert(boomboxes, item)
        end
    end
    return boomboxes
end

local function getBoomboxSound(boombox)
    local handle = boombox:FindFirstChild("Handle")
    if handle then
        return handle:FindFirstChild("Sound")
    end
    return nil
end

local function findAllSounds()
    local sounds = {}
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Sound") then
            table.insert(sounds, desc)
        end
    end
    return sounds
end

local function userValueToRobloxVolume(userValue)
    local maxVal = CONFIG.MaxVolumeValue
    if maxVal <= 0 then maxVal = 10000 end
    local clamped = math.clamp(userValue, 0, maxVal)
    return (clamped / maxVal) * 10
end

-- BoomVol
local function applyVolumeToAll()
    if not CONFIG.BoomVol.enabled then return end
    local volumeRoblox = userValueToRobloxVolume(CONFIG.BoomVol.volume)
    local boomboxes = getAllBoomboxes()
    local muteTaco = CONFIG.MuteTaco.enabled
    local targetAudioId = CONFIG.MuteTaco.targetAudioId

    for _, boombox in ipairs(boomboxes) do
        local sound = getBoomboxSound(boombox)
        if sound then
            if muteTaco and string.find(sound.SoundId or "", targetAudioId) then
                -- пропускаем
            else
                sound.Volume = volumeRoblox
            end
        end
    end
end

function SetBoomVol(enable, value)
    CONFIG.BoomVol.enabled = enable
    if value ~= nil then
        CONFIG.BoomVol.volume = math.clamp(value, 0, CONFIG.MaxVolumeValue)
    end
    if enable then
        applyVolumeToAll()
    else
        for _, box in ipairs(getAllBoomboxes()) do
            local sound = getBoomboxSound(box)
            if sound then sound.Volume = 1.0 end
        end
    end
end

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "SuperFlyGoldBoombox" and desc:IsA("Tool") then
        task.wait(0.1)
        applyVolumeToAll()
    end
end)

-- Mute Taco
local originalVolumes = {}

function SetMuteTaco(enable)
    CONFIG.MuteTaco.enabled = enable
    local targetAudioId = CONFIG.MuteTaco.targetAudioId
    local sounds = findAllSounds()

    for _, sound in ipairs(sounds) do
        if string.find(sound.SoundId or "", targetAudioId) then
            if enable then
                if not originalVolumes[sound] then
                    originalVolumes[sound] = sound.Volume
                end
                sound.Volume = 0
            else
                if originalVolumes[sound] then
                    local vol = originalVolumes[sound]
                    if CONFIG.BoomVol.enabled then
                        vol = userValueToRobloxVolume(CONFIG.BoomVol.volume)
                    end
                    sound.Volume = vol
                    originalVolumes[sound] = nil
                end
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") then
        desc:GetPropertyChangedSignal("SoundId"):Connect(function()
            if CONFIG.MuteTaco.enabled then
                if string.find(desc.SoundId or "", CONFIG.MuteTaco.targetAudioId) then
                    if not originalVolumes[desc] then
                        originalVolumes[desc] = desc.Volume
                    end
                    desc.Volume = 0
                else
                    if originalVolumes[desc] then
                        local vol = originalVolumes[desc]
                        if CONFIG.BoomVol.enabled then
                            vol = userValueToRobloxVolume(CONFIG.BoomVol.volume)
                        end
                        desc.Volume = vol
                        originalVolumes[desc] = nil
                    end
                end
            end
        end)
    end
end)

-- ClickBoom
local function setupClickDetection(boombox)
    local handle = boombox:FindFirstChild("Handle")
    if not handle then return end
    if handle:FindFirstChild("ClickDetector") then return end

    local detector = Instance.new("ClickDetector")
    detector.MaxActivationDistance = 32
    detector.Parent = handle

    detector.MouseClick:Connect(function(player)
        if not CONFIG.ClickBoom.enabled then return end
        if player ~= LocalPlayer then return end

        local sound = handle:FindFirstChild("Sound")
        if sound and sound:IsA("Sound") then
            local soundId = sound.SoundId
            if soundId ~= "" then
                local audioId = string.match(soundId, "%d+")
                if audioId then
                    setclipboard(audioId)
                    print("[ClickBoom] Скопирован ID: " .. audioId)
                    local flash = Instance.new("SelectionBox")
                    flash.Color3 = Color3.new(0,0,0)
                    flash.LineThickness = 0.05
                    flash.Transparency = 0
                    flash.Adornee = handle
                    flash.Parent = handle
                    task.spawn(function()
                        for i = 0, 1, 0.1 do
                            flash.Transparency = i
                            task.wait(0.05)
                        end
                        flash:Destroy()
                    end)
                end
            end
        end
    end)
end

function SetClickBoom(enable)
    CONFIG.ClickBoom.enabled = enable
    if enable then
        for _, box in ipairs(getAllBoomboxes()) do
            setupClickDetection(box)
        end
    else
        for _, box in ipairs(getAllBoomboxes()) do
            local handle = box:FindFirstChild("Handle")
            if handle then
                local det = handle:FindFirstChild("ClickDetector")
                if det then det:Destroy() end
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "SuperFlyGoldBoombox" and desc:IsA("Tool") and CONFIG.ClickBoom.enabled then
        task.wait(0.1)
        setupClickDetection(desc)
    end
end)

-- AutoPlay
local currentBoombox = nil

local function playOnBoombox(boombox, audioId)
    local remote = boombox:FindFirstChild("Remote")
    if remote then
        remote:FireServer("PlaySong", audioId)
        return true
    end
    return false
end

local function onToolEquipped(tool)
    if not CONFIG.AutoPlay.enabled then return end
    if tool.Name ~= "SuperFlyGoldBoombox" then return end

    currentBoombox = tool
    local audioId = tonumber(CONFIG.AutoPlay.audioId)
    if audioId then
        task.wait(0.05)
        playOnBoombox(tool, audioId)
    end
end

local function monitorCharacter(char)
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            onToolEquipped(tool)
        end
    end

    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            onToolEquipped(child)
        end
    end)

    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child.Name == "SuperFlyGoldBoombox" then
            currentBoombox = nil
        end
    end)
end

function SetAutoPlay(enable, audioId)
    CONFIG.AutoPlay.enabled = enable
    if audioId then
        CONFIG.AutoPlay.audioId = tostring(audioId)
    end

    if enable and currentBoombox then
        local id = tonumber(CONFIG.AutoPlay.audioId)
        if id then
            playOnBoombox(currentBoombox, id)
        end
    end
end

if LocalPlayer.Character then
    monitorCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(monitorCharacter)

-- Disable UI
local function disableChooseSongUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local chooseSongGui = playerGui:FindFirstChild("ChooseSongGui")
        if chooseSongGui then
            local frame = chooseSongGui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
            end
        end
    end
end

local function enableChooseSongUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local chooseSongGui = playerGui:FindFirstChild("ChooseSongGui")
        if chooseSongGui then
            local frame = chooseSongGui:FindFirstChild("Frame")
            if frame then
                frame.Visible = true
            end
        end
    end
end

function SetDisableUI(enable)
    CONFIG.DisableUI.enabled = enable
    if enable then
        disableChooseSongUI()
    else
        enableChooseSongUI()
    end
end

LocalPlayer:WaitForChild("PlayerGui").ChildAdded:Connect(function(child)
    if child.Name == "ChooseSongGui" and CONFIG.DisableUI.enabled then
        task.wait()
        disableChooseSongUI()
    end
end)

-- ============================================================
-- СОЗДАНИЕ GUI
-- ============================================================

local function createBoomboxGui()
    -- Проверяем, нет ли уже такого GUI
    if PlayerGui:FindFirstChild("BoomboxManagerGUI") then
        PlayerGui:FindFirstChild("BoomboxManagerGUI"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BoomboxManagerGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    -- Основной фрейм
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 380)
    mainFrame.Position = UDim2.new(0.5, -160, 0.5, -190)
    mainFrame.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    mainFrame.BorderColor3 = Color3.fromRGB(0, 124, 255)
    mainFrame.BorderSizePixel = 1
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(0, 124, 255)
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = "🎵 Boombox Manager"
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame

    -- Кнопка закрытия
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Контейнер для элементов (скролл)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -40)
    scrollFrame.Position = UDim2.new(0, 5, 0, 35)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = scrollFrame

    -- Вспомогательная функция для создания элемента управления
    local function createSlider(labelText, min, max, defaultValue, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.BorderSizePixel = 0
        frame.Parent = scrollFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = 14
        label.Font = Enum.Font.GothamSemibold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.35, 0, 0, 20)
        valueLabel.Position = UDim2.new(0.62, 0, 0, 2)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(defaultValue)
        valueLabel.TextColor3 = Color3.fromRGB(0, 124, 255)
        valueLabel.TextSize = 14
        valueLabel.Font = Enum.Font.GothamSemibold
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = frame

        local slider = Instance.new("Slider")
        slider.Size = UDim2.new(0.9, 0, 0, 16)
        slider.Position = UDim2.new(0.05, 0, 0, 28)
        slider.Min = min
        slider.Max = max
        slider.Value = defaultValue
        slider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        slider.BorderSizePixel = 0
        slider.Parent = frame

        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.new(0, 16, 1, 0)
        thumb.Position = UDim2.new((defaultValue - min) / (max - min), -8, 0, 0)
        thumb.BackgroundColor3 = Color3.fromRGB(0, 124, 255)
        thumb.BorderSizePixel = 0
        thumb.Parent = slider

        slider:GetPropertyChangedSignal("Value"):Connect(function()
            local val = math.round(slider.Value)
            valueLabel.Text = tostring(val)
            thumb.Position = UDim2.new((val - min) / (max - min), -8, 0, 0)
            callback(val)
        end)

        return slider, valueLabel
    end

    local function createCheckbox(labelText, defaultState, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.BorderSizePixel = 0
        frame.Parent = scrollFrame

        local check = Instance.new("TextButton")
        check.Size = UDim2.new(0, 20, 0, 20)
        check.Position = UDim2.new(0, 10, 0.5, -10)
        check.BackgroundColor3 = defaultState and Color3.fromRGB(0, 124, 255) or Color3.fromRGB(40, 40, 40)
        check.BorderColor3 = Color3.fromRGB(80, 80, 80)
        check.BorderSizePixel = 1
        check.Text = defaultState and "✔" or ""
        check.TextColor3 = Color3.new(1, 1, 1)
        check.TextSize = 16
        check.Font = Enum.Font.GothamSemibold
        check.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -40, 0, 20)
        label.Position = UDim2.new(0, 40, 0.5, -10)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = 14
        label.Font = Enum.Font.GothamSemibold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local state = defaultState
        check.MouseButton1Click:Connect(function()
            state = not state
            check.BackgroundColor3 = state and Color3.fromRGB(0, 124, 255) or Color3.fromRGB(40, 40, 40)
            check.Text = state and "✔" or ""
            callback(state)
        end)

        return check, label
    end

    -- BoomVol (слайдер)
    local boomVolSlider, boomVolLabel = createSlider("Громкость (0-10000)", 0, 10000, CONFIG.BoomVol.volume, function(val)
        CONFIG.BoomVol.volume = val
        if CONFIG.BoomVol.enabled then
            SetBoomVol(true, val)
        end
    end)

    -- BoomVol вкл/выкл
    local boomVolCheck, _ = createCheckbox("Включить BoomVol", CONFIG.BoomVol.enabled, function(state)
        SetBoomVol(state, CONFIG.BoomVol.volume)
        boomVolSlider.Visible = state
        boomVolLabel.Visible = state
    end)
    boomVolSlider.Visible = CONFIG.BoomVol.enabled
    boomVolLabel.Visible = CONFIG.BoomVol.enabled

    -- Mute Taco
    createCheckbox("Отключить звук тако", CONFIG.MuteTaco.enabled, function(state)
        SetMuteTaco(state)
    end)

    -- ClickBoom
    createCheckbox("ClickBoom (копировать ID)", CONFIG.ClickBoom.enabled, function(state)
        SetClickBoom(state)
    end)

    -- AutoPlay
    local autoPlayCheck, _ = createCheckbox("Автовоспроизведение", CONFIG.AutoPlay.enabled, function(state)
        SetAutoPlay(state, CONFIG.AutoPlay.audioId)
    end)

    -- Поле ввода ID для AutoPlay
    local idFrame = Instance.new("Frame")
    idFrame.Size = UDim2.new(1, 0, 0, 30)
    idFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    idFrame.BorderSizePixel = 0
    idFrame.Parent = scrollFrame

    local idLabel = Instance.new("TextLabel")
    idLabel.Size = UDim2.new(0.4, 0, 0, 20)
    idLabel.Position = UDim2.new(0, 10, 0.5, -10)
    idLabel.BackgroundTransparency = 1
    idLabel.Text = "ID аудио:"
    idLabel.TextColor3 = Color3.new(1, 1, 1)
    idLabel.TextSize = 14
    idLabel.Font = Enum.Font.GothamSemibold
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.Parent = idFrame

    local idBox = Instance.new("TextBox")
    idBox.Size = UDim2.new(0.5, 0, 0, 24)
    idBox.Position = UDim2.new(0.45, 0, 0.5, -12)
    idBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    idBox.BorderColor3 = Color3.fromRGB(80, 80, 80)
    idBox.Text = CONFIG.AutoPlay.audioId
    idBox.TextColor3 = Color3.new(1, 1, 1)
    idBox.TextSize = 14
    idBox.Font = Enum.Font.GothamSemibold
    idBox.PlaceholderText = "Введите ID"
    idBox.ClearTextOnFocus = false
    idBox.Parent = idFrame

    idBox.FocusLost:Connect(function()
        local newId = idBox.Text
        if newId ~= "" then
            CONFIG.AutoPlay.audioId = newId
            if CONFIG.AutoPlay.enabled then
                SetAutoPlay(true, newId)
            end
        end
    end)

    -- Disable UI
    createCheckbox("Отключить UI выбора песен", CONFIG.DisableUI.enabled, function(state)
        SetDisableUI(state)
    end)

    -- Обновляем CanvasSize
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    task.wait()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)

    return screenGui
end

-- ============================================================
-- ЗАПУСК GUI
-- ============================================================

-- Создаём GUI сразу
createBoomboxGui()

print("[Boombox Manager] GUI создан. Максимальное значение громкости: 10000")
