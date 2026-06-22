-- ============================================================
-- БУМБОКС МЕНЕДЖЕР (расширенный до 10 000)
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- НАСТРОЙКИ (можно менять)
-- ============================================================
local CONFIG = {
    -- Максимальное значение громкости, которое может ввести пользователь
    MaxVolumeValue = 10000,   -- теперь можно ввести до 10 тысяч

    BoomVol = {
        enabled = false,
        volume = 100,         -- значение от 0 до MaxVolumeValue
    },
    MuteTaco = {
        enabled = false,
        targetAudioId = "142376088",
    },
    ClickBoom = {
        enabled = false,
    },
    AutoPlay = {
        enabled = false,
        audioId = "142376088",
    },
    DisableUI = {
        enabled = false,
    }
}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
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

-- Преобразование пользовательского значения в реальную громкость Roblox (0..10)
local function userValueToRobloxVolume(userValue)
    local maxVal = CONFIG.MaxVolumeValue
    if maxVal <= 0 then maxVal = 10000 end
    local clamped = math.clamp(userValue, 0, maxVal)
    return (clamped / maxVal) * 10   -- при maxVal даёт 10, при 0 даёт 0
end

-- ============================================================
-- ФУНКЦИЯ 1: BoomVol (регулировка громкости)
-- ============================================================

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
                -- пропускаем звук тако (он обрабатывается отдельно)
            else
                sound.Volume = volumeRoblox
            end
        end
    end
end

-- Включить/выключить BoomVol и установить громкость (value от 0 до MaxVolumeValue)
function SetBoomVol(enable, value)
    CONFIG.BoomVol.enabled = enable
    if value ~= nil then
        CONFIG.BoomVol.volume = math.clamp(value, 0, CONFIG.MaxVolumeValue)
    end
    if enable then
        applyVolumeToAll()
    else
        -- Сброс до 1.0 (стандартная громкость)
        local boomboxes = getAllBoomboxes()
        for _, box in ipairs(boomboxes) do
            local sound = getBoomboxSound(box)
            if sound then
                sound.Volume = 1.0
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "SuperFlyGoldBoombox" and desc:IsA("Tool") then
        task.wait(0.1)
        applyVolumeToAll()
    end
end)

-- ============================================================
-- ФУНКЦИЯ 2: Mute Taco
-- ============================================================

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

-- ============================================================
-- ФУНКЦИЯ 3: ClickBoom
-- ============================================================

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
        local boomboxes = getAllBoomboxes()
        for _, box in ipairs(boomboxes) do
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

-- ============================================================
-- ФУНКЦИЯ 4: AutoPlay
-- ============================================================

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

-- ============================================================
-- ФУНКЦИЯ 5: Disable UI
-- ============================================================

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
-- ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ
-- ============================================================

-- Включить BoomVol с громкостью 5000 (половина от максимума 10000)
-- SetBoomVol(true, 5000)

-- Включить Mute Taco
-- SetMuteTaco(true)

-- Включить ClickBoom
-- SetClickBoom(true)

-- Включить AutoPlay с ID 142376088
-- SetAutoPlay(true, "142376088")

-- Включить отключение UI
-- SetDisableUI(true)

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ (по желанию)
-- ============================================================

-- SetBoomVol(true, 100)   -- например, стартовая громкость 100 (из 10000)

print("[Boombox Manager] Загружен. Максимальное значение громкости:", CONFIG.MaxVolumeValue)
