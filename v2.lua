local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local bridge = require(LocalPlayer.PlayerScripts:WaitForChild("KnitRemoteBridge"))
local W = bridge.WrapReplicatedStorage(ReplicatedStorage)
local FR = W:WaitForChild("FishingRemotes", 10)

local function knitService(name)
    local idx = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("_Index")
    if not idx then return nil end
    for _, pack in ipairs(idx:GetChildren()) do
        if pack.Name:find("sleitnick_knit", 1, true) then
            local svc = pack:FindFirstChild("knit")
                and pack.knit:FindFirstChild("Services")
                and pack.knit.Services:FindFirstChild(name)
            if svc then return svc end
        end
    end
    return nil
end

local reward = knitService("FishingRewardService")
local Knit = require(W:WaitForChild("Packages"):WaitForChild("Knit"))
local spawnSvc
pcall(function()
    spawnSvc = Knit.GetService("SpawnService")
end)

local R = {
    StartFishing    = FR and FR:WaitForChild("StartFishing", 5),
    ThrowFloater    = FR and FR:WaitForChild("ThrowFloater", 5),
    Confirm         = FR and FR:WaitForChild("ConfirmFloatingCast", 5),
    StartPulling    = FR and FR:WaitForChild("StartPulling", 5),
    StopFishing     = FR and FR:WaitForChild("StopFishing", 5),
    RequestFishBite = reward and reward.RF:FindFirstChild("RequestFishBite"),
    PullInput       = (reward and reward.RF and reward.RF:FindFirstChild("FishingPullInput")) or W:FindFirstChild("FishingPullInput"),
    PullState       = (reward and reward.RE and reward.RE:FindFirstChild("FishingPullState")) or W:FindFirstChild("FishingPullState"),
    FishCaught      = (reward and reward.RE and reward.RE:FindFirstChild("FishCaught")) or W:FindFirstChild("FishCaughtEvent"),
    SetAfkMode      = W:FindFirstChild("SetAfkMode"),
    RodShop         = W:FindFirstChild("RodShopRemotes"),
    Shop            = W:FindFirstChild("FishermanShopRemotes"),
}

local BossComm = W:FindFirstChild("BossEventComm") or W:WaitForChild("BossEventComm", 5)
local Boss = {
    Announce  = BossComm and BossComm:FindFirstChild("BossEventAnnounce"),
    Ready     = BossComm and BossComm:FindFirstChild("BossEventReadyUpdate"),
    CastSync  = BossComm and BossComm:FindFirstChild("BossEventCastSync"),
    Bite      = BossComm and BossComm:FindFirstChild("BossEventBiteAlert"),
    Start     = BossComm and BossComm:FindFirstChild("BossEventStart"),
    Progress  = BossComm and BossComm:FindFirstChild("BossEventProgressUpdate"),
    Rage      = BossComm and BossComm:FindFirstChild("BossEventRageMode"),
    Monster   = BossComm and BossComm:FindFirstChild("BossEventMonsterAppear"),
    End       = BossComm and BossComm:FindFirstChild("BossEventEnd"),
    ReadyUp   = BossComm and BossComm:FindFirstChild("BossEventFishMonsterReady"),
    Quit      = BossComm and BossComm:FindFirstChild("BossEventQuitParticipate"),
    Tap       = BossComm and BossComm:FindFirstChild("BossEventPlayerTap"),
    GetActive = BossComm and BossComm:FindFirstChild("BossEventGetActiveEvents"),
}

local BOSS_CLICK_CD = 0.08
pcall(function()
    local cfg = require(W.Modules:WaitForChild("BossFishConfig"))
    if type(cfg) == "table" and tonumber(cfg.ClickCooldown) then
        BOSS_CLICK_CD = tonumber(cfg.ClickCooldown)
    end
end)

local LINE = {
    Width = 0.16,
    Transparency = 0.12,
    LightInfluence = 0,
    LightEmission = 0.6,
    FaceCamera = true,
    Color = Color3.fromRGB(0, 255, 255),
}

local RARITIES = { 
    "Common", 
    "Uncommon", 
    "Rare", 
    "Epic", 
    "Legendary", 
    "Mythic", 
    "Secret", 
    "Monster" 
}

local state = {
    v2 = false,
    autoSell = false,
    sellEvery = 500,
    sellSince = 0,
    returnAfterSell = true,
    skipFavorite = true,
    sellRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = false,
        Mythic = false,
        Secret = false,
        Monster = false,
    },
    castDist = 28,
    throwPower = 10,
    autoUsePotion = false,
    potionUseInterval = 600,
    speedFishingDelay = 0.01,
    tapMultiplier = 1,
    caught = 0,
    fails = 0,
    lastFish = "-",
    status = "idle",
    stop = false,
    progress = 0,
    cycleGen = 0,
    cycleBusy = false,
    sellBusy = false,
    returnCFrame = nil,
    autoBoss = false,
    autoTap = true,
    pauseFishOnBoss = true,
    bossStatus = "idle",
    bossName = "-",
    bossHp = "-",
    bossState = "-",
    bossTaps = 0,
    bossInFight = false,
    wasFishingBeforeBoss = false,
    lightBoost = false,
    fpsBoost = false,
    blackScreen = false,
    autoFavorite = false,
    autoFavoriteByFish = false,
    favRarities = {
        Common = false,
        Uncommon = false,
        Rare = false,
        Epic = false,
        Legendary = true,
        Mythic = true,
        Secret = true,
        Monster = true,
    },
    favFishNames = {},
    favStatus = "idle",
    favLast = "-",
    autoTreasure = false,
    treasureChestsOpened = 0,
    autoEasterEgg = false,
    easterEggTriggered = 0,
    easterEggSkipOof = true,
    autoHatch = false,
    hatchEggId = nil,
    potionQty = 1,
    eggQty = 1,
    autoClaimQuest = true,
    questStatus = "idle",
    questLast = "-",
}
local lightBoostObjects = {}
local fpsBoostObjects = {}
local blackScreenGui = nil

local function fire(re, ...)
    if not re then return false end
    return pcall(function(...)
        re:FireServer(...)
    end, ...)
end

local ANIM_IDS = {
    Cast    = "rbxassetid://116773778525284",
    Pulling = "rbxassetid://139562788652214",
}
local animTracks = {}
local activeAnimName = nil

local function getAnimator()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if hum and not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    return hum, animator
end

local function getAnimTrack(name)
    local id = ANIM_IDS[name]
    if not id then return nil end
    local hum, animator = getAnimator()
    if not hum or not animator then return nil end
    local cache = animTracks[hum]
    if not cache then
        cache = {}
        animTracks[hum] = cache
    end
    local track = cache[name]
    if track and track.Animation and track.Animation.AnimationId == id then
        return track
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    local ok, newTrack = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if not ok or not newTrack then return nil end
    newTrack.Priority = Enum.AnimationPriority.Action
    cache[name] = newTrack
    return newTrack
end

local function stopAllFishAnims()
    for name in pairs(ANIM_IDS) do
        for _, cache in pairs(animTracks) do
            local track = cache[name]
            if track and track.IsPlaying then
                pcall(function() track:Stop(0.15) end)
            end
        end
    end
    activeAnimName = nil
end

local function playFishAnim(name, looped)
    if activeAnimName == name then return end
    stopAllFishAnims()
    local track = getAnimTrack(name)
    if not track then return end
    track.Looped = looped or false
    pcall(function() track:Play(0.15) end)
    activeAnimName = name
end

local function stopFishingRemote(...)
    stopAllFishAnims()
    return fire(R.StopFishing, ...)
end

local function publicStatus(raw)
    raw = tostring(raw or "")
    local low = raw:lower()
    if low == "idle" then return "Idle"
    elseif low == "cast" then return "Casting"
    elseif low == "bite" then return "Waiting"
    elseif low:find("bite fail") or low:find("bite:") then return "Waiting"
    elseif low == "pull" then return "Reeling"
    elseif low:find("^caught #") then
        local n = raw:match("#(%d+)")
        return "Caught " .. (n or "")
    elseif low:find("failed pull") or low:find("pull timeout") then return "Reeling"
    elseif low:find("resume fish") then return "Fishing"
    elseif low:find("v2 run") then return "Fishing"
    elseif low:find("stopped") then return "Stopped"
    elseif low:find("no character") or low:find("remotes missing") then return "Waiting"
    elseif low:find("restart") or low:find("stuck") then return "Restarting"
    elseif low:find("err") then return "Error"
    elseif low:find("sold") or low:find("sell") or low:find("tp seller") or low:find("return spot") then return "Selling"
    else return "Fishing"
    end
end

local equippedCache = { rod = nil, floater = nil, lastCheck = 0 }
local EQUIP_CACHE_TTL = 15 -- detik, cukup jarang rod/floater berubah saat auto fishing

local function equipInfo(forceRefresh)
    local now = os.clock()
    if not forceRefresh and equippedCache.rod and (now - equippedCache.lastCheck) < EQUIP_CACHE_TTL then
        -- Masih pakai cache: tetap pastikan tool yang benar di-equip tanpa network call.
        local rod = equippedCache.rod
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local bag = LocalPlayer:FindFirstChild("Backpack")
        if hum and bag then
            local held = char:FindFirstChildOfClass("Tool")
            if not (held and held.Name == rod) then
                local t = bag:FindFirstChild(rod) or char:FindFirstChild(rod)
                if t and t:IsA("Tool") then
                    hum:EquipTool(t)
                    task.wait(0.15)
                end
            end
        end
        return equippedCache.rod, equippedCache.floater
    end

    local rod, floater = "DriedBananaRod", "Floater_Doll"
    local getOwned = R.RodShop and R.RodShop:FindFirstChild("GetOwnedItems")
    if getOwned then
        local ok, res = pcall(function()
            return getOwned:InvokeServer()
        end)
        if ok and type(res) == "table" then
            rod = res.EquippedRod or rod
            floater = res.EquippedFloater or floater
        end
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local bag = LocalPlayer:FindFirstChild("Backpack")
    if hum and bag then
        local held = char:FindFirstChildOfClass("Tool")
        if not (held and held.Name == rod) then
            local t = bag:FindFirstChild(rod) or char:FindFirstChild(rod)
            if t and t:IsA("Tool") then
                hum:EquipTool(t)
                task.wait(0.15)
            end
        end
    end
    equippedCache.rod = rod
    equippedCache.floater = floater
    equippedCache.lastCheck = now
    return rod, floater
end

LocalPlayer.CharacterAdded:Connect(function()
    equippedCache.rod = nil
    equippedCache.floater = nil
    equippedCache.lastCheck = 0
end)

local function waterLand(dist)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local start = hrp.Position
    local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
    look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.IgnoreWater = false
    local hit = workspace:Raycast(start + look * dist + Vector3.new(0, 12, 0), Vector3.new(0, -100, 0), params)
    local land = hit and (hit.Position + Vector3.new(0, 0.5, 0)) or (start + look * dist + Vector3.new(0, -2, 0))
    return start, land
end

local function closeCatchUI()
    if typeof(_G.closeAllUIsOnFishCaught) == "function" then
        pcall(_G.closeAllUIsOnFishCaught)
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, name in ipairs({
        "NewFishDiscovery_Display",
        "FishCaughtCenter_Display",
        "SimpleFishNotif_Instance",
        "NewFishDiscovery",
    }) do
        local g = pg:FindFirstChild(name)
        if g then
            pcall(function()
                g:Destroy()
            end)
        end
    end
end

local function getInventory()
    local getInv = R.Shop and R.Shop:FindFirstChild("GetFishInventory")
    if not getInv then return nil end
    local ok, inv = pcall(function()
        return getInv:InvokeServer()
    end)
    if ok and type(inv) == "table" then return inv end
    return nil
end

local function getFishCount()
    local inv = getInventory()
    if not inv then return 0 end
    if type(inv.TotalFish) == "number" then return inv.TotalFish end
    if type(inv.FishList) == "table" then return #inv.FishList end
    return 0
end

local function isFavorited(instanceId, entryKey, favMap)
    if not state.skipFavorite or type(favMap) ~= "table" then return false end
    if instanceId and (favMap[tostring(instanceId)] or favMap[instanceId]) then return true end
    if entryKey and (favMap[tostring(entryKey)] or favMap[entryKey]) then return true end
    if _G.FavoritedFish then
        if instanceId and _G.FavoritedFish[tostring(instanceId)] then return true end
        if entryKey and _G.FavoritedFish[tostring(entryKey)] then return true end
    end
    return false
end

local function buildSellPayload(inv)
    local payload = {}
    if type(inv) ~= "table" or type(inv.FishList) ~= "table" then return payload end
    local fav = inv.FavoritedFish
    for _, group in ipairs(inv.FishList) do
        if type(group) == "table" then
            local rarity = tostring(group.Rarity or "Common")
            if state.sellRarities[rarity] then
                if type(group.Instances) == "table" and #group.Instances > 0 then
                    for _, inst in ipairs(group.Instances) do
                        if type(inst) == "table" then
                            local id = inst.InstanceId or inst.instanceId
                            local fid = inst.FishId or group.FishId
                            local ir = tostring(inst.Rarity or rarity)
                            if state.sellRarities[ir] and fid and id and not isFavorited(id, id, fav) then
                                table.insert(payload, {
                                    FishId = fid,
                                    InstanceId = id,
                                    Count = 1,
                                })
                            end
                        end
                    end
                else
                    local id = group.InstanceId or group.EntryKey
                    local fid = group.FishId
                    if fid and id and not isFavorited(id, group.EntryKey, fav) then
                        table.insert(payload, {
                            FishId = fid,
                            InstanceId = id,
                            Count = tonumber(group.Count) or 1,
                        })
                    end
                end
            end
        end
    end
    return payload
end

local function getSellerTarget()
    local best, bestDist
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local origin = hrp and hrp.Position
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and (d.Name == "FishermanSellPrompt" or (tostring(d.ActionText):lower():find("sell") and tostring(d.ObjectText):lower():find("fish"))) then
            local part = d.Parent
            local pos
            if part:IsA("BasePart") then
                pos = part.Position
            elseif part:IsA("Attachment") then
                pos = part.WorldPosition
            elseif part:IsA("Model") then
                local pp = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
                pos = pp and pp.Position
            end
            if pos and origin then
                local dist = (pos - origin).Magnitude
                if not bestDist or dist < bestDist then
                    bestDist = dist
                    best = { pos = pos, prompt = d, dist = dist }
                end
            elseif pos and not best then
                best = { pos = pos, prompt = d, dist = math.huge }
            end
        end
    end
    local gso = workspace:FindFirstChild("GameSystemObject")
    local shopPart = gso and gso:FindFirstChild("FishermanShop")
    if shopPart and shopPart:IsA("BasePart") then
        if not best then
            best = { pos = shopPart.Position, prompt = shopPart:FindFirstChild("FishermanSellPrompt"), dist = math.huge }
        end
    end
    return best
end

local function tryAutoSell(force)
    if state.sellBusy then return end
    if not force and not state.autoSell then return end
    if not R.Shop then
        state.status = "no shop remotes"
        return
    end
    local count = getFishCount()
    if not force and count <= 0 then return end
    state.sellBusy = true
    local wasFishing = state.v2
    if wasFishing then
        state.stop = true
        stopFishingRemote()
    end

    -- Everything below runs inside pcall so ANY error (bad remote, nil hrp,
    -- network hiccup, etc.) can never leave sellBusy/stop stuck true forever.
    -- That stuck-true state is exactly what silently defeats the no-catch
    -- watchdog, since it treats state.stop/sellBusy as an intentional pause.
    local ok, err = pcall(function()
        task.wait(0.2)
        state.status = "tp seller"
        local seller = getSellerTarget()
        local sellerPos = seller and seller.pos or Vector3.new(280, 203, 1552)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            state.returnCFrame = hrp.CFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(sellerPos + Vector3.new(0, 3, 0))
        end
        task.wait(0.25)
        state.status = "sell filter"
        local inv = getInventory()
        local payload = buildSellPayload(inv)
        local soldN = #payload
        local sellSelected = R.Shop:FindFirstChild("SellSelectedFish")
        local sellAll = R.Shop:FindFirstChild("SellAllFish")
        if soldN > 0 and sellSelected then
            sellSelected:FireServer(payload)
        elseif sellAll then
            local allOn = true
            for _, r in ipairs(RARITIES) do
                if not state.sellRarities[r] then
                    allOn = false
                    break
                end
            end
            if allOn then
                fire(sellAll)
                soldN = count
            else
                state.status = "sell: 0 match filter"
                soldN = 0
            end
        end
        task.wait(0.3)
        local after = getFishCount()
        state.sellSince = 0
        state.status = string.format("sold %d (%d->%d)", soldN, count, after)
        if state.returnAfterSell and state.returnCFrame then
            state.status = "return spot"
            local hrp2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp2 then
                hrp2.AssemblyLinearVelocity = Vector3.zero
                hrp2.AssemblyAngularVelocity = Vector3.zero
                hrp2.CFrame = state.returnCFrame
            end
            task.wait(0.2)
        end
    end)

    -- ALWAYS release the locks, success or not.
    state.sellBusy = false
    if not ok then
        state.status = "sell err " .. tostring(err):sub(1, 40)
    end
    if wasFishing then
        state.stop = false
        if ok then
            state.status = "resume fish"
        end
    end
end

local function runCycle(myGen)
    local function orphaned()
        return myGen ~= nil and myGen ~= state.cycleGen
    end
    if not (R.StartFishing and R.ThrowFloater and R.Confirm and R.RequestFishBite and R.PullInput) then
        state.status = "remotes missing"
        return false
    end
    local rod, floater = equipInfo()
    local start, land = waterLand(state.castDist)
    if not start then
        state.status = "no character"
        return false
    end
    if orphaned() then return false end
    stopFishingRemote()
    task.wait(0.3)
    if orphaned() then return false end
    state.status = "cast"
    state.progress = 0
    playFishAnim("Cast", false)
    fire(R.StartFishing, rod, floater)
    task.wait(0.08)
    if orphaned() then return false end
    fire(R.ThrowFloater, start, land, rod, floater, LINE, state.throwPower)
    task.wait(0.08)
    if orphaned() then return false end
    fire(R.Confirm, land)
    state.status = "bite"
    local bite
    for _ = 1, 22 do
        if orphaned() or state.stop or not state.v2 then
            stopAllFishAnims()
            return false
        end
        task.wait(0.12)
        local ok, res = pcall(function()
            return R.RequestFishBite:InvokeServer(land)
        end)
        if ok and type(res) == "table" then
            if type(res.SessionId) == "string" then
                bite = res
                break
            end
            if res.isImpossible then
                local reason = tostring(res.reason)
                if reason == "no_active_cast" or reason == "cast_expired" then
                    fire(R.StartFishing, rod, floater)
                    task.wait(0.08)
                    fire(R.ThrowFloater, start, land, rod, floater, LINE, state.throwPower)
                    task.wait(0.08)
                    fire(R.Confirm, land)
                else
                    state.status = "bite: " .. reason
                    state.fails += 1
                    stopAllFishAnims()
                    stopFishingRemote()
                    task.wait(0.35)
                    return false
                end
            end
        end
    end
    if not bite then
        state.status = "bite fail"
        state.fails += 1
        stopAllFishAnims()
        stopFishingRemote()
        task.wait(0.35)
        return false
    end
    -- Server memerlukan RequestFishBite dipanggil KEDUA kalinya (dengan land yang sama)
    -- setelah sesi bite pertama didapat, sebelum benar-benar mengizinkan pulling. Tanpa
    -- panggilan kedua ini, tap pertama selalu ditolak server dengan reason=too_early.
    task.wait(0.2)
    pcall(function()
        local ok2, res2 = pcall(function()
            return R.RequestFishBite:InvokeServer(land)
        end)
        if ok2 and type(res2) == "table" and type(res2.SessionId) == "string" then
            bite = res2
        end
    end)
    state.status = "pull"
    local resolved, success, catchPayload = false, false, nil
    local sid = bite.SessionId
    local connPull, connCatch
    local tooEarly = false
    local pullReady = false
    if R.PullState then
        connPull = R.PullState.OnClientEvent:Connect(function(payload)
            if type(payload) ~= "table" then return end
            if payload.sessionId and payload.sessionId ~= sid then return end
            if payload.type == "begin" or payload.type == "started" or payload.type == "ready" then
                pullReady = true
            elseif payload.type == "progress" then
                pullReady = true
                state.progress = tonumber(payload.progress) or state.progress
            elseif payload.type == "resolved" then
                if payload.reason == "too_early" then
                    -- Sesi belum siap menerima tap; jangan anggap gagal, tandai untuk restart cycle.
                    tooEarly = true
                    return
                end
                resolved = true
                success = payload.success == true or payload.reason == "caught"
                state.progress = tonumber(payload.progress) or state.progress
            end
        end)
    end
    if R.FishCaught then
        connCatch = R.FishCaught.OnClientEvent:Connect(function(payload)
            if type(payload) == "table" then
                catchPayload = payload
                resolved = true
                success = true
            end
        end)
    end
    fire(R.StartPulling)
    playFishAnim("Pulling", true)
    -- Server mengirim sinyal "begin" lewat PullState (bukan kita yang InvokeServer "begin").
    -- Tunggu sinyal itu sebelum kirim tap pertama, alih-alih delay buta.
    do
        local waitDeadline = os.clock() + 3
        while not pullReady and not resolved and os.clock() < waitDeadline and state.v2 and not state.stop and not orphaned() do
            task.wait(0.05)
        end
    end
    local ppt = tonumber(bite.progressPerTap) or 0.06
    local delay = state.speedFishingDelay or math.clamp(0.055 + (ppt < 0.05 and 0.02 or 0), 0.05, 0.12)
    local deadline = os.clock() + (tonumber(bite.timeLimit) or 15) + 2
    while os.clock() < deadline and not resolved and state.v2 and not state.stop and not orphaned() do
        if tooEarly then
            -- sid ini sudah dianggap dead oleh server (tidak lagi broadcast PullState untuk
            -- sid ini walau kita retry tap). Jangan retry di sid lama; keluar dan biarkan
            -- cycle baru minta bite baru (sid baru) dari awal.
            if connPull then connPull:Disconnect() end
            if connCatch then connCatch:Disconnect() end
            stopAllFishAnims()
            state.status = "bite: too_early (retry)"
            task.wait(0.3)
            return false
        end
        pcall(function()
            local mult = state.tapMultiplier or 1
            for i = 1, mult do
                if resolved or state.stop or not state.v2 or orphaned() or tooEarly then break end
                pcall(function()
                    R.PullInput:InvokeServer(sid, "tap")
                end)
            end
        end)
        task.wait(delay)
    end
    if connPull then connPull:Disconnect() end
    if connCatch then connCatch:Disconnect() end
    stopAllFishAnims()
    if orphaned() then return false end
    if success or catchPayload then
        state.caught += 1
        state.sellSince += 1
        if catchPayload then
            local priceVal = catchPayload.Price or catchPayload.Value or catchPayload.Coins or catchPayload.Worth or catchPayload.SellPrice
            local priceStr = priceVal and (" | $" .. tostring(priceVal)) or ""
            state.lastFish = tostring(catchPayload.FishID or catchPayload.FishId or "?")
                .. " "
                .. tostring(catchPayload.WeightFormatted or catchPayload.Weight or "")
                .. priceStr
        else
            state.lastFish = tostring(bite.FishRarity or "") .. " " .. tostring(bite.tier or "")
        end
        state.status = "caught #" .. state.caught
        closeCatchUI()
        if state.autoSell and state.sellSince >= math.max(1, state.sellEvery) then
            tryAutoSell(false)
        end
        if state.stopAtCatchLimit and state.caught >= math.max(1, tonumber(state.catchLimit) or 50) then
            state.status = "catch limit reached"
            state.stop = true
            state.v2 = false
            if AutoFishToggleRef then
                pcall(function() AutoFishToggleRef:Set(false) end)
            end
        end
    else
        state.fails += 1
        state.status = resolved and "failed pull" or "pull timeout"
    end
    stopFishingRemote()
    task.wait(0.25)
    return success or catchPayload ~= nil
end

local setV2

local function spawnCycleRunner(myGen)
    -- Runs one runCycle() attempt tagged with myGen. If the generation has
    -- moved on (hard restart happened) by the time this returns, its result
    -- is discarded so it can never clobber a newer cycle's state.
    task.spawn(function()
        state.cycleBusy = true
        local ok, err = pcall(runCycle, myGen)
        if myGen ~= state.cycleGen then
            -- stale cycle finished after a hard restart; ignore its result entirely
            return
        end
        if not ok then
            state.status = "err " .. tostring(err):sub(1, 48)
            state.fails += 1
        end
        state.cycleBusy = false
    end)
end

setV2 = function(on)
    if on then
        state.stop = false
        state.v2 = true
        state.cycleGen += 1
        state.status = "v2 run"
        local myWatchdogGen = state.cycleGen
        task.spawn(function()
            while state.v2 do
                if state.stop or state.sellBusy then
                    task.wait(0.15)
                elseif not state.cycleBusy then
                    spawnCycleRunner(state.cycleGen)
                    task.wait(0.12)
                else
                    task.wait(0.1)
                end
            end
        end)
        task.spawn(function()
            local NO_CATCH_TIMEOUT = 10
            local SELL_STUCK_TIMEOUT = 10 -- selling normally takes ~3s max; 10s = definitely stuck
            local lastCaught = state.caught
            local lastCatchAt = os.clock()
            local pauseSince = nil
            while state.v2 and state.cycleGen == myWatchdogGen do
                task.wait(0.5)
                if state.wasFishingBeforeBoss then
                    -- genuine boss-fight pause: resumes via Boss.End/Boss.Quit server event,
                    -- can legitimately run long. Don't count it against any timer.
                    lastCaught = state.caught
                    lastCatchAt = os.clock()
                    pauseSince = nil
                elseif state.stop or state.sellBusy then
                    -- paused for selling (or a stray stop flag e.g. mid-teleport): these
                    -- never legitimately take more than a few seconds, so cap it.
                    lastCaught = state.caught
                    lastCatchAt = os.clock()
                    pauseSince = pauseSince or os.clock()
                    if os.clock() - pauseSince >= SELL_STUCK_TIMEOUT then
                        state.status = "sell/stop stuck " .. SELL_STUCK_TIMEOUT .. "s: restarting"
                        setV2(false)
                        task.wait(0.25)
                        setV2(true)
                        return
                    end
                else
                    pauseSince = nil
                    if state.caught ~= lastCaught then
                        lastCaught = state.caught
                        lastCatchAt = os.clock()
                    elseif os.clock() - lastCatchAt >= NO_CATCH_TIMEOUT then
                        -- No fish caught in 10s while toggle is active: full restart,
                        -- exactly like manually turning the toggle off then on.
                        state.status = "no catch 10s: restarting"
                        setV2(false)
                        task.wait(0.25)
                        setV2(true)
                        return -- this watchdog instance is done; setV2(true) spawned a new one
                    end
                end
            end
        end)
    else
        state.v2 = false
        state.stop = true
        state.cycleGen += 1
        state.cycleBusy = false
        stopFishingRemote()
        state.status = "stopped"
    end
end
local function getActiveBosses()
    if not Boss.GetActive then return {} end
    local ok, res = pcall(function()
        return Boss.GetActive:InvokeServer()
    end)
    if not ok or type(res) ~= "table" then return {} end
    local list = {}
    for k, v in pairs(res) do
        if type(v) == "table" and (v.BossName or v.bossName) then
            table.insert(list, v)
        elseif type(k) == "string" and type(v) == "table" then
            v.BossName = v.BossName or k
            table.insert(list, v)
        end
    end
    return list
end

local function pickBoss(list)
    if #list == 0 then return nil end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local best, bestD
    for _, b in ipairs(list) do
        local name = b.BossName or b.bossName
        if state.bossName ~= "-" and name == state.bossName then
            return b
        end
        local pos = b.EventPosition
        local p
        if typeof(pos) == "Vector3" then
            p = pos
        elseif type(pos) == "table" then
            p = Vector3.new(tonumber(pos[1]) or tonumber(pos.X) or 0, tonumber(pos[2]) or tonumber(pos.Y) or 0, tonumber(pos[3]) or tonumber(pos.Z) or 0)
        end
        if hrp and p then
            local d = (hrp.Position - p).Magnitude
            if not bestD or d < bestD then
                bestD, best = d, b
            end
        elseif not best then
            best = b
        end
    end
    return best or list[1]
end

local function bossEventPosition(b)
    if type(b) ~= "table" then return nil end
    local pos = b.EventPosition
    if typeof(pos) == "Vector3" then return pos end
    if type(pos) == "table" then
        return Vector3.new(
            tonumber(pos[1]) or tonumber(pos.X) or 0,
            tonumber(pos[2]) or tonumber(pos.Y) or 0,
            tonumber(pos[3]) or tonumber(pos.Z) or 0
        )
    end
    return nil
end

local function stopBeforeTeleport()
    if state.v2 then
        state.stop = true
        stopFishingRemote()
        task.wait(0.2)
        state.stop = false
    else
        stopFishingRemote()
    end
    if typeof(_G.hardResetFishing) == "function" then
        pcall(_G.hardResetFishing, "hub_teleport")
    elseif typeof(_G.cancelFishing) == "function" then
        pcall(_G.cancelFishing)
    end
end

local function teleportCFrame(pos)
    if typeof(pos) ~= "Vector3" then return false, "bad pos" end
    stopBeforeTeleport()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false, "no character" end
    if hum then
        pcall(function()
            hum.Sit = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    local ok = pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
    return ok, ok and "ok" or "cframe fail"
end

local function teleportToBoss(b)
    local pos = bossEventPosition(b)
    if not pos then return false, "no EventPosition" end
    return teleportCFrame(pos + Vector3.new(0, 5, 0))
end

local function bossParticipate(bossName)
    if not Boss.ReadyUp or not bossName then return false end
    if state.pauseFishOnBoss and state.v2 then
        state.wasFishingBeforeBoss = true
        state.stop = true
        stopFishingRemote()
    end
    if typeof(_G.pauseAfkAutoThrow) == "function" then
        pcall(_G.pauseAfkAutoThrow)
    end
    if typeof(_G.hardResetFishing) == "function" then
        pcall(_G.hardResetFishing, "boss_auto_join")
    end
    local ok = pcall(function()
        Boss.ReadyUp:FireServer(bossName)
    end)
    if ok then
        _G.isParticipatingInBossEvent = true
        state.bossName = bossName
        state.bossStatus = "joined " .. bossName
    end
    return ok
end

local function bossQuit()
    local name = state.bossName ~= "-" and state.bossName or nil
    if Boss.Quit and name then
        pcall(function()
            Boss.Quit:FireServer(name)
        end)
    end
    _G.isParticipatingInBossEvent = false
    state.bossInFight = false
    state.bossStatus = "quit"
    if state.wasFishingBeforeBoss and state.v2 then
        state.stop = false
        state.wasFishingBeforeBoss = false
        state.status = "resume fish"
    end
    if typeof(_G.resumeAfkAutoThrow) == "function" then
        pcall(_G.resumeAfkAutoThrow)
    end
end

local function wireBossEvents()
    if Boss.Announce then
        Boss.Announce.OnClientEvent:Connect(function(data)
            if type(data) == "table" then
                state.bossName = data.BossName or state.bossName
                state.bossState = data.CurrentState or "Announce"
                state.bossStatus = "announce " .. tostring(state.bossName)
                if state.autoBoss and data.BossName then
                    task.defer(bossParticipate, data.BossName)
                end
            end
        end)
    end
    if Boss.Ready then
        Boss.Ready.OnClientEvent:Connect(function(data)
            if type(data) == "table" then
                state.bossState = "Ready"
                state.bossStatus = string.format("ready %s", tostring(data.BossName or state.bossName))
            end
        end)
    end
    if Boss.Start then
        Boss.Start.OnClientEvent:Connect(function(data)
            state.bossInFight = true
            state.bossState = "Combat"
            if type(data) == "table" and data.BossName then
                state.bossName = data.BossName
            end
            state.bossStatus = "combat start"
            if state.pauseFishOnBoss then
                state.stop = true
                stopFishingRemote()
            end
        end)
    end
    if Boss.Progress then
        Boss.Progress.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            state.bossInFight = true
            if data.BossName then state.bossName = data.BossName end
            local hp = data.CurrentHealth or data.BossHealth or data.Health
            local max = data.MaxHealth or data.BossMaxHealth
            if hp and max then
                state.bossHp = string.format("%s/%s (%.0f%%)", tostring(hp), tostring(max), (tonumber(hp) or 0) / math.max(1, tonumber(max) or 1) * 100)
            elseif hp then
                state.bossHp = tostring(hp)
            end
            if data.Progress then
                state.bossHp = string.format("%.0f%%", (tonumber(data.Progress) or 0) * 100)
            end
            state.bossStatus = "fighting"
        end)
    end
    if Boss.Bite then
        Boss.Bite.OnClientEvent:Connect(function()
            state.bossInFight = true
            state.bossStatus = "bite — tap!"
        end)
    end
    if Boss.CastSync then
        Boss.CastSync.OnClientEvent:Connect(function()
            state.bossStatus = "cast sync"
            if typeof(_G.ForceBossCast) == "function" then
                pcall(_G.ForceBossCast, 1, true)
            end
        end)
    end
    if Boss.Rage then
        Boss.Rage.OnClientEvent:Connect(function()
            state.bossStatus = "RAGE"
        end)
    end
    if Boss.End then
        Boss.End.OnClientEvent:Connect(function()
            state.bossInFight = false
            state.bossState = "Ended"
            state.bossStatus = "ended"
            if typeof(_G.ForceBossPulling) == "function" then
                pcall(_G.ForceBossPulling, false)
            end
            if state.wasFishingBeforeBoss and state.v2 then
                state.stop = false
                state.wasFishingBeforeBoss = false
                state.status = "resume fish"
            end
            if typeof(_G.resumeAfkAutoThrow) == "function" then
                pcall(_G.resumeAfkAutoThrow)
            end
        end)
    end
end
wireBossEvents()

task.spawn(function()
    while not (getgenv().byteIcon_Window and getgenv().byteIcon_Window._isDestroying) do
        if state.autoBoss then
            local participating = LocalPlayer:GetAttribute("IsParticipatingBossEvent") == true
                or _G.isParticipatingInBossEvent == true
            if not participating then
                local list = getActiveBosses()
                local b = pickBoss(list)
                if b and b.BossName then
                    state.bossName = b.BossName
                    state.bossState = b.CurrentState or state.bossState
                    if b.BossHealth then
                        state.bossHp = tostring(b.BossHealth)
                    end
                    bossParticipate(b.BossName)
                else
                    state.bossStatus = "waiting event"
                end
            else
                state.bossStatus = state.bossInFight and "in fight" or "participating"
            end
        end
        task.wait(1.5)
    end
end)

task.spawn(function()
    local last = 0
    while not (getgenv().byteIcon_Window and getgenv().byteIcon_Window._isDestroying) do
        local participating = LocalPlayer:GetAttribute("IsParticipatingBossEvent") == true
            or _G.isParticipatingInBossEvent == true
        if state.autoTap and participating and Boss.Tap then
            local name = state.bossName
            if name == "-" or name == nil or name == "" then
                local list = getActiveBosses()
                local b = pickBoss(list)
                name = b and b.BossName
                if name then state.bossName = name end
            end
            if name and name ~= "-" then
                local now = tick()
                if now - last >= BOSS_CLICK_CD then
                    last = now
                    local ok = pcall(function()
                        Boss.Tap:FireServer(name)
                    end)
                    if ok then
                        state.bossTaps += 1
                    end
                end
            end
            task.wait(BOSS_CLICK_CD)
        else
            task.wait(0.2)
        end
    end
end)

local function getFishShopRemotes()
    local shop = W:FindFirstChild("FishermanShopRemotes") or W:WaitForChild("FishermanShopRemotes", 5)
    if not shop then return nil end
    return shop, shop:FindFirstChild("GetFishInventory"), shop:FindFirstChild("ToggleFavoriteFish")
end

local function buildFishNameList()
    local names, seen = {}, {}
    local okFc, FishConfig = pcall(function()
        return require(W.Modules.FishConfig)
    end)
    if okFc and type(FishConfig) == "table" then
        for _ = 1, 2500 do
            local ok, id = pcall(function()
                return FishConfig.GetRandomFish()
            end)
            if ok and type(id) == "string" and id ~= "" and not seen[id] then
                seen[id] = true
                table.insert(names, id)
            end
        end
        for _, r in ipairs(RARITIES) do
            for _ = 1, 400 do
                local ok, id = pcall(function()
                    return FishConfig.GetRandomFishByRarity(r)
                end)
                if ok and type(id) == "string" and id ~= "" and not seen[id] then
                    seen[id] = true
                    table.insert(names, id)
                end
            end
        end
    end
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    local labels = {}
    local labelToId = {}
    for _, id in ipairs(names) do
        local label = id:gsub("_", " ")
        if labelToId[label] and labelToId[label] ~= id then
            label = id
        end
        labelToId[label] = id
        table.insert(labels, label)
    end
    if #labels == 0 then
        table.insert(labels, "(no fish list)")
    end
    return labels, labelToId, names
end
local FISH_LABELS, FISH_LABEL_TO_ID, FISH_IDS = buildFishNameList()

local function fishMatchesFavFilter(fishId, displayName)
    if not fishId and not displayName then return false end
    local id = tostring(fishId or "")
    local name = tostring(displayName or "")
    local pretty = id:gsub("_", " ")
    local pretty2 = name:gsub("_", " ")
    local map = state.favFishNames
    return map[id] or map[name] or map[pretty] or map[pretty2]
        or map[id:lower()] or map[name:lower()] or map[pretty:lower()]
end

local function favoriteMatchingOnce(forceRarities, byFishOnly)
    local _, getInv, toggle = getFishShopRemotes()
    if not (getInv and toggle) then
        state.favStatus = "no remotes"
        return 0, 0, 0
    end
    _G.FavoritedFish = _G.FavoritedFish or {}
    local ok, inv = pcall(function()
        return getInv:InvokeServer()
    end)
    if not ok or type(inv) ~= "table" then
        state.favStatus = "inv fail"
        return 0, 0, 0
    end
    local favMap = inv.FavoritedFish or {}
    local rarities = forceRarities or state.favRarities
    local newly, already, failed = 0, 0, 0
    local useRarity = state.autoFavorite and not byFishOnly
    local useFish = state.autoFavoriteByFish or byFishOnly
    for _, group in ipairs(inv.FishList or {}) do
        if type(group) == "table" and type(group.Instances) == "table" then
            local groupR = tostring(group.Rarity or "")
            local groupFish = tostring(group.FishId or group.Name or "")
            for _, inst in ipairs(group.Instances) do
                if type(inst) == "table" and inst.InstanceId then
                    local id = tostring(inst.InstanceId)
                    local r = tostring(inst.Rarity or groupR)
                    local fishId = tostring(inst.FishId or groupFish)
                    local fishName = tostring(inst.Name or group.Name or fishId)
                    local match = false
                    if useRarity and rarities[r] then match = true end
                    if useFish and fishMatchesFavFilter(fishId, fishName) then match = true end
                    if not state.autoFavorite and not state.autoFavoriteByFish and not byFishOnly then
                        if rarities[r] or fishMatchesFavFilter(fishId, fishName) then
                            match = true
                        end
                    end
                    if match then
                        if favMap[id] or _G.FavoritedFish[id] then
                            already += 1
                            _G.FavoritedFish[id] = true
                        else
                            local ok2 = pcall(function()
                                return toggle:InvokeServer(id)
                            end)
                            if ok2 then
                                _G.FavoritedFish[id] = true
                                newly += 1
                                state.favLast = r .. " " .. fishId
                            else
                                failed += 1
                            end
                            task.wait(0.08)
                        end
                    end
                end
            end
        end
    end
    state.favStatus = string.format("+%d already %d fail %d", newly, already, failed)
    return newly, already, failed
end

local function getQuestService()
    local ok, qs = pcall(function()
        return Knit.GetService("QuestService")
    end)
    if ok then return qs end
    return nil
end

local function questStatusPack()
    local qs = getQuestService()
    if not qs then return nil, "no QuestService" end
    local ok, st = pcall(function()
        return qs:GetDailyQuestStatus()
    end)
    if ok and type(st) == "table" then return st end
    return nil, tostring(st)
end

local function autoClaimQuestsOnce()
    local qs = getQuestService()
    if not qs then
        state.questStatus = "no service"
        return
    end
    local st = select(1, questStatusPack())
    if not st then
        state.questStatus = "status fail"
        return
    end
    local claimed = 0
    local active = st.ActiveQuests or {}
    for id, q in pairs(active) do
        if type(q) == "table" and (q.State == "Completed" or q.State == "Complete") then
            local ok = pcall(function()
                return qs:ClaimReward(id)
            end)
            if ok then
                claimed += 1
                state.questLast = "claim " .. tostring(id)
            end
            task.wait(0.15)
        end
    end
    state.questStatus = string.format("claim %d", claimed)
end

local function acceptQuestsOnce(mode)
    local qs = getQuestService()
    if not qs then
        state.questStatus = "no service"
        return
    end
    local st = select(1, questStatusPack())
    if not st then
        state.questStatus = "status fail"
        return
    end
    local accepted = 0
    local active = st.ActiveQuests or {}
    local completedDaily = st.CompletedDailyQuests or {}
    local completedWeekly = st.CompletedWeeklyQuests or {}
    local doDaily = mode == "daily" or mode == "all"
    local doWeekly = mode == "weekly" or mode == "all"
    local doStory = mode == "story" or mode == "all"
    if doDaily and type(st.DailyQuests) == "table" then
        for _, id in pairs(st.DailyQuests) do
            id = tostring(id)
            if not active[id] and not completedDaily[id] then
                local ok, res = pcall(function()
                    return qs:AcceptDailyQuest(id)
                end)
                if ok and res ~= false then
                    accepted += 1
                    state.questLast = "daily " .. id
                end
                task.wait(0.2)
            end
        end
    end
    if doWeekly and type(st.WeeklyQuests) == "table" then
        for _, id in pairs(st.WeeklyQuests) do
            id = tostring(id)
            if not active[id] and not completedWeekly[id] then
                local ok, res = pcall(function()
                    return qs:AcceptWeeklyQuest(id)
                end)
                if ok and res ~= false then
                    accepted += 1
                    state.questLast = "weekly " .. id
                end
                task.wait(0.2)
            end
        end
    end
    if doStory then
        local okCfg, QuestConfig = pcall(function()
            return require(W.Modules.QuestConfig)
        end)
        if okCfg and type(QuestConfig) == "table" and type(QuestConfig.NPCQuests) == "table" then
            local completed
            pcall(function()
                completed = qs:GetCompletedQuests()
            end)
            completed = type(completed) == "table" and completed or {}
            for id in pairs(QuestConfig.NPCQuests) do
                id = tostring(id)
                if not active[id] and not completed[id] then
                    local ok, res = pcall(function()
                        return qs:AcceptQuest(id)
                    end)
                    if ok and res ~= false then
                        accepted += 1
                        state.questLast = "story " .. id
                    end
                    task.wait(0.12)
                end
            end
        end
    end
    state.questStatus = string.format("%s +%d", mode, accepted)
end

local treasureChestConnection = nil
local treasureOpened = {}
local TREASURE_MAX_DIST = 12
local treasureReturnCFrame = nil
local treasureAwayFromHome = false

local function getTreasureService()
    local ok, svc = pcall(function()
        return Knit.GetService("TreasureService")
    end)
    if ok and svc then return svc end
    return nil
end

local function treasurePos(attachment)
    if not attachment or not attachment.Parent then return nil end
    local ok, pos = pcall(function()
        return attachment.WorldPosition
    end)
    if ok and pos then return pos end
    ok, pos = pcall(function()
        return attachment.WorldCFrame.Position
    end)
    if ok and pos then return pos end
    return nil
end

local function captureTreasureHome()
    if treasureAwayFromHome then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        treasureReturnCFrame = hrp.CFrame
        treasureAwayFromHome = true
    end
end

local function returnToTreasureHome()
    if not treasureAwayFromHome then return end
    if treasureReturnCFrame then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = treasureReturnCFrame
            end)
            task.wait(0.2)
        end
    end
    treasureAwayFromHome = false
end

local function tpToTreasure(attachment)
    local pos = treasurePos(attachment)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hrp and pos) then return false end
    captureTreasureHome()
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    task.wait(0.35)
    local d = (hrp.Position - pos).Magnitude
    if d > TREASURE_MAX_DIST then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
        task.wait(0.25)
        d = (hrp.Position - pos).Magnitude
    end
    return d <= TREASURE_MAX_DIST
end

local function openChest(chestId)
    if not chestId or treasureOpened[chestId] then return false end
    local svc = getTreasureService()
    if not svc then return false end
    local ok, success = pcall(function()
        return svc:RequestOpenChest(chestId)
    end)
    if ok and success then
        treasureOpened[chestId] = true
        state.treasureChestsOpened += 1
        return true
    end
    return false
end

local function scanAndOpenChests()
    local svc = getTreasureService()
    if not svc then
        return
    end
    local ok, chests = pcall(function()
        return svc:GetActiveChests()
    end)
    if not (ok and type(chests) == "table") then
        return
    end
    local list = {}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local origin = hrp and hrp.Position or Vector3.zero
    for chestId, data in pairs(chests) do
        if type(data) == "table" and data.Attachment and data.Attachment.Parent and not treasureOpened[chestId] then
            local pos = treasurePos(data.Attachment)
            if pos then
                table.insert(list, {
                    id = chestId,
                    att = data.Attachment,
                    dist = (origin - pos).Magnitude,
                })
            end
        end
    end
    table.sort(list, function(a, b)
        return a.dist < b.dist
    end)
    local opened = 0
    for _, item in ipairs(list) do
        if not state.autoTreasure then break end
        if tpToTreasure(item.att) then
            if openChest(item.id) then
                opened += 1
            end
        end
        task.wait(0.45)
    end
    returnToTreasureHome()
    if opened > 0 then
        WindUI:Notify({
            Title = "Treasure",
            Content = string.format("Scan: +%d (total %d)", opened, state.treasureChestsOpened),
            Duration = 2,
        })
    end
end

local function startTreasureLoop()
    if treasureChestConnection then
        pcall(function()
            treasureChestConnection:Disconnect()
        end)
        treasureChestConnection = nil
    end
    local svc = getTreasureService()
    if not svc then
        WindUI:Notify({ Title = "Treasure", Content = "TreasureService nil", Duration = 3 })
        return
    end
    if svc.ChestSpawned then
        treasureChestConnection = svc.ChestSpawned:Connect(function(chestId, attachment)
            if not state.autoTreasure then return end
            if not attachment or not attachment.Parent then return end
            if treasureOpened[chestId] then return end
            if tpToTreasure(attachment) then
                openChest(chestId)
            end
            returnToTreasureHome()
        end)
    end
    task.spawn(function()
        while state.autoTreasure do
            scanAndOpenChests()
            task.wait(4)
        end
    end)
end

local function stopTreasureLoop()
    if treasureChestConnection then
        pcall(function()
            treasureChestConnection:Disconnect()
        end)
        treasureChestConnection = nil
    end
    returnToTreasureHome()
    treasureReturnCFrame = nil
    treasureAwayFromHome = false
end

local easterEggConfig = nil
local easterEggPartMap = {}
local easterEggDone = {}
local easterEggStreamConn = nil

local function loadEasterEggConfig()
    if easterEggConfig then return easterEggConfig end
    local ok, cfg = pcall(function()
        return require(W.Modules:WaitForChild("EasterEggConfig"))
    end)
    if ok and type(cfg) == "table" then
        easterEggConfig = cfg
        easterEggPartMap = {}
        if type(cfg.Eggs) == "table" then
            for id, egg in pairs(cfg.Eggs) do
                if type(egg) == "table" and egg.PartName then
                    easterEggPartMap[egg.PartName] = id
                end
            end
        end
        return cfg
    end
    return nil
end

local function getEasterEggService()
    local ok, svc = pcall(function()
        return Knit.GetService("EasterEggService")
    end)
    if ok and svc then return svc end
    return nil
end

local function resolveEggId(inst)
    if not inst then return nil end
    local id = inst:GetAttribute("EggId")
    if type(id) == "string" and id ~= "" then return id end
    if easterEggPartMap[inst.Name] then return easterEggPartMap[inst.Name] end
    return nil
end

local function eggNeedsServer(egg)
    if not egg then return false end
    if egg.KillOnTrigger and state.easterEggSkipOof then return false end
    return egg.Reward or egg.Buff or egg.PotionReward or egg.ScreenEffect or egg.DirectBuffId or egg.KillOnTrigger
end

local function eggWorldPos(inst)
    if not inst or not inst.Parent then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, pivot = pcall(function() return inst:GetPivot().Position end)
        if ok and pivot then return pivot end
        local pp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        return pp and pp.Position
    end
    return nil
end

local function triggerEasterEgg(eggId)
    if not eggId or easterEggDone[eggId] then return false end
    local cfg = loadEasterEggConfig()
    local egg = cfg and cfg.Eggs and cfg.Eggs[eggId]
    if egg and not eggNeedsServer(egg) then
        return false
    end
    if egg and egg.KillOnTrigger and state.easterEggSkipOof then
        return false
    end
    local svc = getEasterEggService()
    if not svc then return false end
    local ok, result = pcall(function()
        return svc:TriggerEasterEgg(eggId)
    end)
    if ok and result then
        easterEggDone[eggId] = true
        state.easterEggTriggered += 1
        WindUI:Notify({
            Title = "Easter Egg",
            Content = tostring(eggId) .. " OK (" .. state.easterEggTriggered .. ")",
            Duration = 2,
        })
        return true
    end
    return false
end

local function stopEasterEggLoop()
    if easterEggStreamConn then
        pcall(function() easterEggStreamConn:Disconnect() end)
        easterEggStreamConn = nil
    end
end

local function scanAndTriggerEasterEggs()
    loadEasterEggConfig()
    local tag = (easterEggConfig and easterEggConfig.CollectionTag) or "EasterEgg"
    local seen = {}
    for _, inst in ipairs(CollectionService:GetTagged(tag)) do
        if not state.autoEasterEgg then break end
        local eggId = resolveEggId(inst)
        if eggId and not seen[eggId] and not easterEggDone[eggId] then
            seen[eggId] = true
            local cfg = easterEggConfig and easterEggConfig.Eggs and easterEggConfig.Eggs[eggId]
            if eggNeedsServer(cfg) then
                local pos = eggWorldPos(inst)
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and pos then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                    task.wait(0.35)
                end
                triggerEasterEgg(eggId)
                task.wait(0.6)
            end
        end
    end
end

local function startEasterEggLoop()
    stopEasterEggLoop()
    loadEasterEggConfig()
    local tag = (easterEggConfig and easterEggConfig.CollectionTag) or "EasterEgg"
    easterEggStreamConn = CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
        if not state.autoEasterEgg then return end
        task.defer(function()
            local eggId = resolveEggId(inst)
            if not eggId or easterEggDone[eggId] then return end
            local cfg = easterEggConfig and easterEggConfig.Eggs and easterEggConfig.Eggs[eggId]
            if not eggNeedsServer(cfg) then return end
            local pos = eggWorldPos(inst)
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and pos then
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                task.wait(0.35)
            end
            triggerEasterEgg(eggId)
        end)
    end)
    task.spawn(function()
        while state.autoEasterEgg do
            scanAndTriggerEasterEggs()
            task.wait(4)
        end
    end)
    scanAndTriggerEasterEggs()
end

local function moneyFmt(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n))
    local k
    repeat
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return "$" .. s
end

local function loadShopCatalogs()
    local rods, floats, potions, gadgets, eggs = {}, {}, {}, {}, {}
    local okRod, RodShopConfig = pcall(function()
        return require(W.Modules.RodShopConfig)
    end)
    if okRod and type(RodShopConfig) == "table" then
        for _, data in pairs(RodShopConfig.Rods or {}) do
            if type(data) == "table" and data.IsPremium ~= true then
                local id = data.RodId or data.ModelName
                local price = tonumber(data.Price) or 0
                if id and price > 0 then
                    table.insert(rods, {
                        id = tostring(id),
                        name = tostring(data.DisplayName or data.Name or id),
                        price = price,
                        rarity = tostring(data.Rarity or ""),
                    })
                end
            end
        end
        for _, data in pairs(RodShopConfig.Floaters or {}) do
            if type(data) == "table" and data.IsPremium ~= true then
                local id = data.FloaterId or data.Id or data.ModelName
                local price = tonumber(data.Price) or 0
                if id and price > 0 then
                    table.insert(floats, {
                        id = tostring(id),
                        name = tostring(data.DisplayName or data.Name or id),
                        price = price,
                        rarity = tostring(data.Rarity or ""),
                    })
                end
            end
        end
    end
    table.sort(rods, function(a, b) return a.price < b.price end)
    table.sort(floats, function(a, b) return a.price < b.price end)
    local okPot, PotionShopConfig = pcall(function()
        return require(W.Modules.PotionShopConfig)
    end)
    local okPC, PotionConfig = pcall(function()
        return require(W.Modules.PotionConfig)
    end)
    if okPot and type(PotionShopConfig) == "table" then
        local listings = PotionShopConfig.Listings
        if type(listings) == "table" then
            for k, v in pairs(listings) do
                local pid = type(v) == "table" and (v.PotionId or k) or k
                pid = tostring(pid)
                local price = 0
                pcall(function()
                    price = tonumber(PotionShopConfig.GetCoinPrice(pid, 1)) or 0
                end)
                local name = pid
                if okPC and type(PotionConfig) == "table" then
                    local pd = PotionConfig[pid]
                    if type(pd) ~= "table" and PotionConfig.Get then
                        pcall(function()
                            pd = PotionConfig.Get(pid)
                        end)
                    end
                    if type(pd) == "table" then
                        name = tostring(pd.Name or pd.DisplayName or name)
                    end
                end
                if name == pid then
                    name = pid:gsub("^Potion", ""):gsub("(%l)(%u)", "%1 %2")
                end
                table.insert(potions, { id = pid, name = name, price = price })
            end
        end
    end
    table.sort(potions, function(a, b) return a.price < b.price end)
    local okShop, ShopConfig = pcall(function()
        return require(W.Modules.ShopConfig)
    end)
    if okShop and type(ShopConfig) == "table" then
        for _, data in pairs(ShopConfig.Tools or {}) do
            if type(data) == "table" and data.IsPremium ~= true then
                local id = data.ToolId or data.Id
                local price = tonumber(data.Price) or 0
                if id then
                    table.insert(gadgets, {
                        id = tostring(id),
                        name = tostring(data.Title or data.Name or id),
                        price = price,
                        kind = "Tool",
                    })
                end
            end
        end
        for _, data in pairs(ShopConfig.Auras or {}) do
            if type(data) == "table" and data.IsPremium ~= true then
                local id = data.AuraId or data.Id
                local price = tonumber(data.Price) or 0
                if id then
                    table.insert(gadgets, {
                        id = tostring(id),
                        name = tostring(data.Title or data.Name or id),
                        price = price,
                        kind = "Aura",
                    })
                end
            end
        end
    end
    table.sort(gadgets, function(a, b) return a.price < b.price end)
    local okEgg, PetShopConfig = pcall(function()
        return require(W.Modules.PetShopConfig)
    end)
    if okEgg and type(PetShopConfig) == "table" then
        for id, data in pairs(PetShopConfig.Eggs or {}) do
            if type(data) == "table" then
                local price = tonumber(data.Price)
                table.insert(eggs, {
                    id = tostring(id),
                    name = tostring(data.Name or id),
                    price = price,
                    currency = tostring(data.Currency or "Money"),
                    typ = tostring(data.Type or ""),
                })
            end
        end
    end
    table.sort(eggs, function(a, b)
        return (a.price or 1e18) < (b.price or 1e18)
    end)
    return rods, floats, potions, gadgets, eggs
end
local SHOP_RODS, SHOP_FLOATS, SHOP_POTIONS, SHOP_GADGETS, SHOP_EGGS = loadShopCatalogs()

local function shopLabels(list, withPrice)
    local labels = {}
    for _, item in ipairs(list) do
        if withPrice then
            local p = item.price
            local pstr = p and moneyFmt(p) or "ROBUX?"
            table.insert(labels, string.format("%s — %s", item.name, pstr))
        else
            table.insert(labels, item.name)
        end
    end
    if #labels == 0 then
        table.insert(labels, "(empty)")
    end
    return labels
end

local function shopPick(list, label)
    if not label then return nil end
    for _, item in ipairs(list) do
        local full = string.format("%s — %s", item.name, item.price and moneyFmt(item.price) or "ROBUX?")
        if label == full or label == item.name or label:find(item.name, 1, true) then
            return item
        end
    end
    return nil
end

local function buyRod(id)
    local rem = R.RodShop and R.RodShop:FindFirstChild("BuyRod")
    if not rem then return false, "no BuyRod" end
    return pcall(function()
        rem:FireServer(id)
    end)
end

local function buyFloater(id)
    local rem = R.RodShop and R.RodShop:FindFirstChild("BuyFloater")
    if not rem then return false, "no BuyFloater" end
    return pcall(function()
        rem:FireServer(id)
    end)
end

local function buyPotion(id, qty)
    local rem = W:FindFirstChild("PotionShopRemotes")
    local buy = rem and rem:FindFirstChild("BuyPotion")
    if not buy then return false, "no BuyPotion" end
    return pcall(function()
        buy:FireServer(id, qty or 1)
    end)
end

local potionService = knitService("PotionService")

local function consumePotion(potionId)
    local rf = potionService and potionService:FindFirstChild("RF")
    local consumeRF = rf and rf:FindFirstChild("ConsumePotion")
    if not consumeRF then return false, "no ConsumePotion" end
    return pcall(function()
        return consumeRF:InvokeServer(potionId)
    end)
end

local function buyGadget(item)
    local rem = W:FindFirstChild("ShopRemotes")
    local buy = rem and rem:FindFirstChild("PurchaseItem")
    if not buy then return false, "no PurchaseItem" end
    local kind = item.kind or "Tool"
    return pcall(function()
        buy:FireServer(kind, item.id, item.price or 0, false, nil)
    end)
end

local function buyEgg(id, qty)
    qty = qty or 1
    local ok, err = pcall(function()
        local svc = Knit.GetService("PetShopService")
        if svc and svc.BuyEgg then
            return svc:BuyEgg(id, qty)
        end
        error("no PetShopService.BuyEgg")
    end)
    if ok then return true end
    local rem = W:FindFirstChild("PetShopRemotes")
    if rem and rem:FindFirstChild("BuyEgg") then
        return pcall(function()
            rem.BuyEgg:FireServer(id, qty)
        end)
    end
    return false, tostring(err)
end

-- Teleport destinations
local HUB_TP = {
    { Name = "Port / Base", Key = "base", Kind = "hud" },
    { Name = "Dock", Key = "dock", Kind = "hud" },
    { Name = "Shop", Key = "shop", Kind = "hud" },
    { Name = "Boat Shop", Key = "boat", Kind = "boat" },
    { Name = "Fisherman Market", Kind = "cframe", Pos = Vector3.new(280, 203, 1552) },
    { Name = "Sea Gate", Kind = "cframe", Pos = Vector3.new(-1061, 242, 1567) },
}
local ISLAND_TP = {
    { Name = "Bamboo Island", Kind = "cframe", Pos = Vector3.new(-1549, 167, 255), Unlock = 1 },
    { Name = "Iceberg Island", Kind = "cframe", Pos = Vector3.new(-518, 163, -253), Unlock = 1 },
    { Name = "Lost Whale Island", Kind = "cframe", Pos = Vector3.new(-2812, 168, -129), Unlock = 10 },
    { Name = "Bora Reef", Kind = "cframe", Pos = Vector3.new(-4118, 188, 2061), Unlock = 20 },
    { Name = "Redhook Outpost", Kind = "cframe", Pos = Vector3.new(-4118, 165, 2055), Unlock = 20 },
    { Name = "Volcano Summit", Kind = "cframe", Pos = Vector3.new(-1969, 294, 5515), Unlock = 30 },
    { Name = "Cape Town / Crystal Tide", Kind = "cframe", Pos = Vector3.new(-583, 167, -542), Unlock = 35 },
    { Name = "Lavafin Shore", Kind = "cframe", Pos = Vector3.new(-815, 195, 4261), Unlock = 30 },
    { Name = "Crimson Lava", Kind = "cframe", Pos = Vector3.new(1658, 259, 3121), Unlock = 30 },
    { Name = "Seabreeze Peak", Kind = "cframe", Pos = Vector3.new(-3256, 275, -4364), Unlock = 45 },
    { Name = "Fishing Village", Kind = "cframe", Pos = Vector3.new(322, 212, 1401), Unlock = 1 },
}

local function teleportHud(key)
    if not spawnSvc then
        pcall(function()
            spawnSvc = Knit.GetService("SpawnService")
        end)
    end
    if not spawnSvc then return false, "no SpawnService" end
    stopBeforeTeleport()
    if key == "boat" then
        local ok, res = pcall(function()
            return spawnSvc:RequestBoatShopTeleport()
        end)
        return ok and res ~= false, tostring(res)
    end
    local ok, res = pcall(function()
        return spawnSvc:RequestHudTeleport(key)
    end)
    return ok and res ~= false, tostring(res)
end

local function doTeleport(entry)
    if not entry then return false, "nil" end
    if entry.Kind == "hud" or entry.Kind == "boat" then
        return teleportHud(entry.Key or entry.Kind)
    end
    return teleportCFrame(entry.Pos)
end

local function partPosOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local pp = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart", true)
        return pp and pp.Position
    end
    local pp = inst:FindFirstChildWhichIsA("BasePart", true)
    return pp and pp.Position
end

local function scanNpcs()
    local list = {}
    local seen = {}
    local function add(name, pos, folder)
        if not pos then return end
        local label = name
        if seen[label] then
            label = name .. " (" .. tostring(folder) .. ")"
            local n = 2
            while seen[label] do
                label = name .. " " .. n
                n += 1
            end
        end
        seen[label] = true
        table.insert(list, {
            Name = label,
            Kind = "cframe",
            Pos = pos + Vector3.new(0, 0, 0),
            Folder = folder,
        })
    end
    for _, folderName in ipairs({ "NPC Repeatable Quest", "StoryNPC", "NPC" }) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child.Name ~= "Fish" then
                    add(child.Name, partPosOf(child), folderName)
                end
            end
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
            if not Players:FindFirstChild(child.Name) and child.Name ~= LocalPlayer.Name then
                add(child.Name, partPosOf(child), "Workspace")
            end
        end
    end
    table.sort(list, function(a, b)
        return a.Name < b.Name
    end)
    return list
end

-- background loops for favorite / hatch / quest
task.spawn(function()
    while not (getgenv().byteIcon_Window and getgenv().byteIcon_Window._isDestroying) do
        if state.autoFavorite or state.autoFavoriteByFish then
            pcall(favoriteMatchingOnce)
            task.wait(4)
        else
            task.wait(1)
        end
    end
end)

task.spawn(function()
    while not (getgenv().byteIcon_Window and getgenv().byteIcon_Window._isDestroying) do
        task.wait(2)
        if state.autoHatch and state.hatchEggId then
            pcall(buyEgg, state.hatchEggId, 1)
        end
    end
end)

task.spawn(function()
    while not (getgenv().byteIcon_Window and getgenv().byteIcon_Window._isDestroying) do
        if state.autoClaimQuest then
            pcall(autoClaimQuestsOnce)
            task.wait(8)
        else
            task.wait(1.5)
        end
    end
end)

-- ============================================================
-- END FISHING CORE LOGIC
-- ============================================================

local AUTO_EXEC_URL = "https://raw.githubusercontent.com/bytecode00010/roblox-scripts/refs/heads/main/bytecode.lua"
local _autoExecQueued = false

local function queueOnTeleport()
    if not queue_on_teleport then
        return false
    end
    if _autoExecQueued then
        return true
    end
    _autoExecQueued = true
    pcall(queue_on_teleport, game:HttpGet(AUTO_EXEC_URL, true))
    return true
end

local function _autoExecReload(reason)
    task.spawn(function()
        task.wait(3)
        if getgenv().byteIcon_Window and not getgenv().byteIcon_Window._isDestroying then
            return
        end

        getgenv().__lshub_autoexec_running = nil
        getgenv().byteIcon_Window = nil
        getgenv().byteIcon_Floating = nil

        local ok, result = pcall(function()
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end
            local source = game:HttpGet(AUTO_EXEC_URL, true)
            return loadstring(source)()
        end)
        if not ok then
            warn("[AutoExec] Failed to reload after " .. tostring(reason) .. ": " .. tostring(result))
        end
    end)
end

if not getgenv().__lshub_autoexec_running then
    getgenv().__lshub_autoexec_running = true
    queueOnTeleport()

    TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
        if queueOnTeleport() then
            return
        end
        _autoExecReload("TeleportArrived")
    end)

    if LocalPlayer and LocalPlayer.OnTeleport then
        LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.InProgress or state == Enum.TeleportState.Started then
                if queueOnTeleport() then
                    return
                end
                _autoExecReload("LocalPlayer.OnTeleport")
            end
        end)
    end

    local _wasLoaded = game:IsLoaded()
    RunService.Heartbeat:Connect(function()
        local nowLoaded = game:IsLoaded()
        if not _wasLoaded and nowLoaded then
            _autoExecReload("GameLoaded / Reconnect")
        end
        _wasLoaded = nowLoaded
    end)
end

local WindUI
do
    local ok, result = pcall(require, "./src/Init")
    if ok then
        WindUI = result
    else
        local _version = "1.6.64-fix"
        WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" ..
            _version .. "/main.lua"))()
    end
end

local function typingSequence(callback)
    task.spawn(function()
        local text1 = "developed by EL"
        local text2 = "Fish and Monsters!"
        local function typeText(text)
            local current = ""
            for i = 1, # text do
                current = string.sub(text, 1, i)
                callback(current)
                task.wait(math.random(40, 80) / 1000)
            end
            return current
        end
        local function deleteText(text)
            for i = # text, 0, -1 do
                local current = string.sub(text, 1, i)
                callback(current)
                task.wait(0.025)
            end
        end
        local function blink(text, duration)
            local timePassed = 0
            local show = true
            while timePassed < duration do
                if show then
                    callback(text .. "|")
                else
                    callback(text)
                end
                show = not show
                task.wait(0.5)
                timePassed = timePassed + 0.5
            end
        end
        while true do
            local full = typeText(text1)
            blink(full, 4)
            deleteText(text1)
            task.wait(2)
            full = typeText(text2)
            blink(full, 4)
            deleteText(text2)
            task.wait(2)
        end
    end)
end

WindUI:AddTheme({
    Name = "ByteCodeTheme",

    Icon = Color3.fromRGB(255, 255, 255),

    Accent = WindUI:Gradient({
        ["0"] = {
            Color = Color3.fromRGB(40, 40, 40),
            Transparency = 0
        },
        ["100"] = {
            Color = Color3.fromRGB(90, 90, 90),
            Transparency = 0
        }
    }),

    Dialog = Color3.fromRGB(10, 10, 10),

    Outline = Color3.fromRGB(120, 120, 120),

    Text = Color3.fromRGB(240, 240, 240),

    Placeholder = Color3.fromRGB(150, 150, 150),

    Button = WindUI:Gradient({
        ["0"] = {
            Color = Color3.fromRGB(20, 20, 20),
            Transparency = 0
        },
        ["100"] = {
            Color = Color3.fromRGB(45, 45, 45),
            Transparency = 0
        }
    }),

    WindowBackground = WindUI:Gradient({
        ["0"] = {
            Color = Color3.fromRGB(5, 5, 5),
            Transparency = 0
        },
        ["100"] = {
            Color = Color3.fromRGB(25, 25, 25),
            Transparency = 0
        }
    })
})

local function CreateFloatingIcon()
    if getgenv().byteIcon_Floating then
        pcall(function()
            getgenv().byteIcon_Floating:Destroy()
        end)
        getgenv().byteIcon_Floating = nil
    end
    local existing = PlayerGui:FindFirstChild("byteIcon")
    if existing then
        existing:Destroy()
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "byteIcon"
    gui.DisplayOrder = 9999
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local frame = Instance.new("Frame")
    frame.Name = "FloatingFrame"
    frame.Position = UDim2.new(1, -55, 0, 55)
    frame.Size = UDim2.fromOffset(45, 45)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.ZIndex = 9999
    frame.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(32, 28, 26)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    local icon = Instance.new("ImageLabel")
    icon.Image = "rbxassetid://90205264511012"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(1, -4, 1, -4)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Parent = frame
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 10)
    iconCorner.Parent = icon
    gui.Parent = PlayerGui
    getgenv().byteIcon_Floating = gui
    return gui, frame
end
local function SetupFloatingIcon(gui, frame)
    if getgenv().byteIcon_Session then
        pcall(function() getgenv().byteIcon_Session:Disconnect() end)
        getgenv().byteIcon_Session = nil
    end
    getgenv().byteIcon_Session = frame.InputBegan:Connect(function(input)
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
        if not (isTouch or isMouse) then
            return
        end
        local dragStart = input.Position
        local startPos = frame.Position
        local didMove = false
        local isDragging = true
        local function applyDrag(currentPos)
            if not isDragging then return end
            if not didMove and (currentPos - dragStart).Magnitude > 6 then
                didMove = true
            end
            if didMove then
                local delta = currentPos - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
        local function stopDragFn()
            isDragging = false
            if not didMove then
                local win = getgenv().byteIcon_Window
                if win and win.Toggle and not win._isDestroying then
                    win:Toggle()
                end
            end
        end
        if isTouch then
            local moveC, endC
            moveC = input.Changed:Connect(function()
                applyDrag(input.Position)
            end)
            endC = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    moveC:Disconnect()
                    endC:Disconnect()
                    stopDragFn()
                end
            end)
        elseif isMouse then
            local moveC, endC
            moveC = UserInputService.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement then
                    applyDrag(m.Position)
                end
            end)
            endC = UserInputService.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 then
                    moveC:Disconnect()
                    endC:Disconnect()
                    stopDragFn()
                end
            end)
        end
    end)
end
local function InitializeIcon()
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    local g, f = CreateFloatingIcon()
    if g and f then
        SetupFloatingIcon(g, f)
    end
end
if not getgenv().byteIcon_Char then
    getgenv().byteIcon_Char = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if getgenv().byteIcon_Window and not getgenv().byteIcon_Window._isDestroying then
            InitializeIcon()
        end
    end)
end

do
    if getgenv().byteIcon_Window then
        pcall(function()
            getgenv().byteIcon_Window:Destroy()
        end)
    end

    local Window = WindUI:CreateWindow({
        Title = "ByteCode v1.15",
        Theme = "ByteCodeTheme",
        Author = "bytecode",
        Folder = "bytecode",
        Icon = "rbxassetid://90205264511012",
        Transparent = true,
        IconSize = 30,
        NewElements = true,
        ToggleKey = Enum.KeyCode.G,
        Size = UDim2.fromOffset(530, 350),
        User = {
            Enabled = true,
            Anonymous = false
        },
        HideSearchBar = false,
        Topbar = {
            Height = 50,
            ButtonsType = "Default"
        },
    })
    getgenv().byteIcon_Window = Window

    local oldDestroy = Window.Destroy
    function Window:Destroy()
        if self._isDestroying then
            return
        end
        self._isDestroying = true
        if getgenv().byteIcon_Floating then
            pcall(function()
                getgenv().byteIcon_Floating:Destroy()
            end)
            getgenv().byteIcon_Floating = nil
        end
        if getgenv().byteIcon_Session then
            pcall(function() getgenv().byteIcon_Session:Disconnect() end)
            getgenv().byteIcon_Session = nil
        end
        if getgenv().byteIcon_Char then
            pcall(function() getgenv().byteIcon_Char:Disconnect() end)
            getgenv().byteIcon_Char = nil
        end
        if getgenv().byteIcon_FFishNotify then
            pcall(function() getgenv().byteIcon_FFishNotify:Disconnect() end)
            getgenv().byteIcon_FFishNotify = nil
        end
        if oldDestroy then
            oldDestroy(self)
        end
    end

    local _Http       = game:GetService("HttpService")
    local _CFG_FOLDER = "bytecode"
    local _CFG_FILE   = _CFG_FOLDER .. "/dashboardsettings.json"
    local _cfg        = {}

    local _uiReady = false
    local function _saveCfg()
        if not _uiReady then return end
        pcall(function()
            if not isfolder(_CFG_FOLDER) then makefolder(_CFG_FOLDER) end
            writefile(_CFG_FILE, _Http:JSONEncode(_cfg))
        end)
    end

    local function _loadCfg()
        pcall(function()
            if isfolder and isfile and isfolder(_CFG_FOLDER) and isfile(_CFG_FILE) then
                local raw = readfile(_CFG_FILE)
                local ok, data = pcall(function() return _Http:JSONDecode(raw) end)
                if ok and type(data) == "table" then
                    _cfg = data
                end
            end
        end)
    end
    _loadCfg()

    typingSequence(function(text)
        if Window.SetAuthor then
            Window:SetAuthor(text)
        else
            Window:SetTitle("ByteCode | " .. text)
        end
    end)
    InitializeIcon()

    local about = Window:Tab({
        Title = "ByteCode.id",
        Icon = "solar:verified-check-bold",
        IconColor = Color3.fromHex("#3245f7"),
    })
    local MainCore = Window:Section({
        Title = "ByteCode Core",
    })
    local MainTab = MainCore:Tab({
        Title = "Dashboard",
        Icon = "solar:home-angle-bold",
        IconColor = Color3.fromRGB(255, 255, 255),

    })
    local BossTab = MainCore:Tab({
        Title     = "Boss",
        Icon      = "solar:danger-triangle-bold",
        IconColor = Color3.fromRGB(255, 255, 255),

    })
    do
        local StatusPara = MainTab:Paragraph({
            Title = "Live Status",
            Desc  = "idle",
            Image = "solar:pulse-bold",
            ImageSize = 32,
        })

        task.spawn(function()
            while getgenv().byteIcon_Window and not getgenv().byteIcon_Window._isDestroying do
                local sellTarget = math.max(1, state.sellEvery)
                local content = string.format(
                    "Status: %s\nCaught: %d | Fails: %d\nSell Count: %d/%d\nLast: %s\nReel: %.0f%%",
                    publicStatus(state.status),
                    state.caught,
                    state.fails,
                    math.min(state.sellSince, sellTarget),
                    sellTarget,
                    state.lastFish,
                    (state.progress or 0) * 100
                )
                pcall(function()
                    StatusPara:SetDesc(content)
                end)
                task.wait(0.1)
            end
        end)

        -- ============================================================
        -- External Live Status Panel (draggable overlay, dark theme)
        -- ============================================================
        local _extPanel        = nil
        local _extPanelConn    = nil
        local _extPanelEnabled = false
        local _extPanelToggle  = nil

        local function isMobileViewport()
            local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
            return (vp and vp.X < 700) or UserInputService.TouchEnabled
        end

        local function destroyExternalPanel()
            _extPanelEnabled = false
            if _extPanelConn then
                pcall(function() _extPanelConn:Disconnect() end)
                _extPanelConn = nil
            end
            if _extPanel then
                pcall(function() _extPanel:Destroy() end)
                _extPanel = nil
            end
        end

        local function createExternalPanel()
            destroyExternalPanel()

            local mobile   = isMobileViewport()
            local panelW    = mobile and 198 or 232
            local titleH    = mobile and 24 or 27
            local rowH      = mobile and 15 or 17
            local barH      = 4
            local gap       = 4
            local padX      = 8
            local fontSize  = mobile and 11 or 12
            local titleSize = mobile and 12 or 13

            local COLOR_BG        = Color3.fromRGB(20, 20, 23)   -- hitam
            local COLOR_BG_ROW    = Color3.fromRGB(46, 48, 53)   -- abu-abu agak terang
            local COLOR_BORDER    = Color3.fromRGB(60, 62, 68)
            local COLOR_TITLE     = Color3.fromRGB(235, 235, 240)
            local COLOR_LABEL     = Color3.fromRGB(150, 152, 158)
            local COLOR_VALUE     = Color3.fromRGB(230, 230, 235)
            local COLOR_ACCENT    = Color3.fromRGB(90, 200, 160)
            local COLOR_WARN      = Color3.fromRGB(224, 168, 82)
            local COLOR_BAD       = Color3.fromRGB(224, 100, 100)
            local HEX_LABEL       = "96989E"
            local HEX_VALUE       = "E6E6EB"
            local HEX_ACCENT      = "5AC8A0"

            -- content height for the compact block: status line, 2x2 stat grid,
            -- sell-progress bar, last-fish line
            local contentH = rowH * 4 + barH + gap * 4
            local panelH   = titleH + gap + contentH + padX

            local sg                  = Instance.new("ScreenGui")
            sg.Name                   = "KAL_LiveStatusPanel"
            sg.ResetOnSpawn           = false
            sg.IgnoreGuiInset         = true
            sg.DisplayOrder           = 9997
            sg.ZIndexBehavior         = Enum.ZIndexBehavior.Sibling
            sg.Parent                 = PlayerGui

            local root                = Instance.new("Frame")
            root.Name                 = "Root"
            root.Size                 = UDim2.fromOffset(panelW, panelH)
            root.Position              = UDim2.new(0, 12, 0.5, -(panelH / 2))
            root.BackgroundColor3     = COLOR_BG
            root.BackgroundTransparency = 0.06
            root.BorderSizePixel      = 0
            root.ZIndex               = 9997
            root.Active               = true
            root.Parent               = sg
            Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)
            local rootStroke          = Instance.new("UIStroke", root)
            rootStroke.Color          = COLOR_BORDER
            rootStroke.Thickness      = 1

            -- Title bar (drag handle)
            local titleBar             = Instance.new("Frame")
            titleBar.Name              = "TitleBar"
            titleBar.Size              = UDim2.new(1, 0, 0, titleH)
            titleBar.BackgroundTransparency = 1
            titleBar.ZIndex            = 9998
            titleBar.Parent            = root

            local dot                  = Instance.new("Frame")
            dot.Size                   = UDim2.fromOffset(8, 8)
            dot.Position               = UDim2.new(0, 12, 0.5, -4)
            dot.BackgroundColor3       = COLOR_ACCENT
            dot.BorderSizePixel        = 0
            dot.ZIndex                 = 9999
            dot.Parent                 = titleBar
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

            local titleLabel            = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Position         = UDim2.new(0, 28, 0, 0)
            titleLabel.Size             = UDim2.new(1, -60, 1, 0)
            titleLabel.Font             = Enum.Font.GothamBold
            titleLabel.Text             = "ByteCode Panel"
            titleLabel.TextSize         = titleSize
            titleLabel.TextColor3       = COLOR_TITLE
            titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
            titleLabel.ZIndex           = 9999
            titleLabel.Parent           = titleBar

            local closeBtn               = Instance.new("TextButton")
            closeBtn.Size                = UDim2.fromOffset(18, 18)
            closeBtn.Position            = UDim2.new(1, -24, 0.5, -9)
            closeBtn.BackgroundColor3    = COLOR_BG_ROW
            closeBtn.BorderSizePixel     = 0
            closeBtn.Font                = Enum.Font.GothamBold
            closeBtn.Text                = "×"
            closeBtn.TextSize            = 14
            closeBtn.TextColor3          = COLOR_LABEL
            closeBtn.AutoButtonColor     = true
            closeBtn.ZIndex              = 9999
            closeBtn.Parent              = titleBar
            Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

            local sep                  = Instance.new("Frame")
            sep.Size                   = UDim2.new(1, -16, 0, 1)
            sep.Position               = UDim2.new(0, 8, 0, titleH - 2)
            sep.BackgroundColor3       = COLOR_BORDER
            sep.BorderSizePixel        = 0
            sep.ZIndex                 = 9998
            sep.Parent                 = root

            -- Compact content block: one status line, a 2x2 stat grid,
            -- a thin sell-progress bar, then a last-fish line.
            local content               = Instance.new("Frame")
            content.BackgroundTransparency = 1
            content.Position            = UDim2.new(0, padX, 0, titleH + gap)
            content.Size                = UDim2.new(1, -padX * 2, 0, contentH)
            content.ZIndex              = 9998
            content.Parent              = root

            local colGap = 8
            local colW   = (panelW - padX * 2 - colGap) / 2

            local function chip(x, w, y, h, xAlign)
                local t = Instance.new("TextLabel")
                t.BackgroundTransparency = 1
                t.Position           = UDim2.new(0, x, 0, y)
                t.Size               = UDim2.new(0, w, 0, h)
                t.Font               = Enum.Font.Gotham
                t.RichText           = true
                t.Text               = ""
                t.TextSize           = fontSize
                t.TextColor3         = COLOR_VALUE
                t.TextXAlignment     = xAlign or Enum.TextXAlignment.Left
                t.TextYAlignment     = Enum.TextYAlignment.Center
                t.TextTruncate       = Enum.TextTruncate.AtEnd
                t.ZIndex             = 9999
                t.Parent             = content
                return t
            end

            local function rich(label, value, valueHex)
                return string.format(
                    '<font color="#%s">%s</font>  <font color="#%s">%s</font>',
                    HEX_LABEL, label, valueHex or HEX_VALUE, value
                )
            end

            local y = 0
            local statusLbl = chip(0, panelW - padX * 2, y, rowH)
            y = y + rowH + gap

            local caughtLbl = chip(0, colW, y, rowH)
            local failsLbl  = chip(colW + colGap, colW, y, rowH)
            y = y + rowH + gap

            local sellLbl = chip(0, colW, y, rowH)
            local pullLbl = chip(colW + colGap, colW, y, rowH)
            y = y + rowH + gap

            local barTrack             = Instance.new("Frame")
            barTrack.BackgroundColor3  = COLOR_BG_ROW
            barTrack.BorderSizePixel   = 0
            barTrack.Position          = UDim2.new(0, 0, 0, y)
            barTrack.Size              = UDim2.new(1, 0, 0, barH)
            barTrack.ZIndex            = 9998
            barTrack.Parent            = content
            Instance.new("UICorner", barTrack).CornerRadius = UDim.new(1, 0)

            local barFill              = Instance.new("Frame")
            barFill.BackgroundColor3   = COLOR_ACCENT
            barFill.BorderSizePixel    = 0
            barFill.Size               = UDim2.new(0, 0, 1, 0)
            barFill.ZIndex             = 9999
            barFill.Parent             = barTrack
            Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
            y = y + barH + gap

            local lastLbl = chip(0, panelW - padX * 2, y, rowH)

            -- Dragging support (mouse + touch)
            do
                local dragging   = false
                local dragStart  = nil
                local startPos   = nil

                local function beginDrag(input)
                    dragging  = true
                    dragStart = input.Position
                    startPos  = root.Position
                end

                local function updateDrag(input)
                    if not dragging then return end
                    local delta = input.Position - dragStart
                    root.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end

                titleBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        beginDrag(input)
                    end
                end)
                titleBar.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch then
                        updateDrag(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        updateDrag(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
            end

            closeBtn.MouseButton1Click:Connect(function()
                destroyExternalPanel()
                pcall(function()
                    if _extPanelToggle then _extPanelToggle:Set(false) end
                end)
            end)

            _extPanel = sg

            _extPanelConn = RunService.Heartbeat:Connect(function()
                if not (_extPanel and _extPanel.Parent) then return end
                local statusText = publicStatus(state.status)
                local statusHex = HEX_VALUE
                local low = statusText:lower()
                if low:find("err") or low:find("stuck") then
                    statusHex = "E06464"
                elseif low:find("restart") then
                    statusHex = "E0A852"
                elseif low:find("caught") then
                    statusHex = HEX_ACCENT
                end

                local sellTarget = math.max(1, state.sellEvery)
                local sellNow    = math.min(state.sellSince, sellTarget)
                local sellRatio  = sellNow / sellTarget

                statusLbl.Text = rich("Status", statusText, statusHex)
                caughtLbl.Text = rich("Caught", tostring(state.caught))
                failsLbl.Text  = rich("Fails", tostring(state.fails))
                sellLbl.Text   = rich("Sell", string.format("%d/%d", sellNow, sellTarget))
                pullLbl.Text   = rich("Reel", string.format("%.0f%%", (state.progress or 0) * 100))
                lastLbl.Text   = rich("Last", tostring(state.lastFish))
                barFill.Size   = UDim2.new(math.clamp(sellRatio, 0, 1), 0, 1, 0)
            end)
        end
        _extPanelToggle = MainTab:Toggle({
            Title    = "External Panel",
            Icon     = "solar:widget-5-bold",
            Default  = false,
            Callback = function(v)
                if v then
                    createExternalPanel()
                    WindUI:Notify({ Title = "Live Status Panel", Content = "Enabled", Duration = 2 })
                else
                    destroyExternalPanel()
                    WindUI:Notify({ Title = "Live Status Panel", Content = "Disabled", Duration = 2 })
                end
            end,
        })

        MainTab:Button({
            Title    = "Reset Counters",
            Icon     = "solar:restart-bold",
            Justify  = "Center",
            Callback = function()
                state.caught   = 0
                state.fails    = 0
                state.lastFish = "-"
                WindUI:Notify({ Title = "FAM", Content = "Counters reset", Duration = 2 })
            end,
        })

        MainTab:Space({ Columns = 0.5 })

        local AutoFishSection = MainTab:Section({
            Title = "Auto Fish",
            Icon = "solar:bolt-bold",
            Box = true,
            BoxBorder = true,
        })

        AutoFishSection:Toggle({
            Title    = "Auto Fish",
            Default  = false,
            Callback = function(v)
                setV2(v)
                if v then
                    WindUI:Notify({ Title = "FAM", Content = "Auto Fish ON", Duration = 3 })
                else
                    WindUI:Notify({ Title = "FAM", Content = "Auto Fish OFF", Duration = 2 })
                end
            end,
        })

        AutoFishSection:Input({
            Title       = "Fishing Delay",
            Value       = tostring(state.speedFishingDelay),
            Placeholder = "0.001 - 1",
            Callback    = function(v)
                local num = tonumber(v)
                state.speedFishingDelay = num and math.clamp(num, 0.001, 1) or 0.08
            end,
        })

        local _fishNotifyConn

        local blockedNotifNames = {
            NewFishDiscovery_Display = true,
            FishCaughtCenter_Display = true,
            SimpleFishNotif_Instance = true,
            NewFishDiscovery = true,
        }

        local function nukeDefaultNotif(inst)
            pcall(function()
                if inst:IsA("GuiObject") or inst:IsA("ScreenGui") then
                    inst.Enabled = false
                end
                inst:Destroy()
            end)
        end

        local function checkGuiInstance(inst)
            if blockedNotifNames[inst.Name] then
                nukeDefaultNotif(inst)
            end
        end

        local function startGuiScanner()
            if getgenv().byteIcon_FFishNotify then return end
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            for _, inst in ipairs(pg:GetDescendants()) do
                checkGuiInstance(inst)
            end
            getgenv().byteIcon_FFishNotify = pg.DescendantAdded:Connect(checkGuiInstance)
        end

        local function stopGuiScanner()
            if getgenv().byteIcon_FFishNotify then
                pcall(function() getgenv().byteIcon_FFishNotify:Disconnect() end)
                getgenv().byteIcon_FFishNotify = nil
            end
        end

        local function showCustomFishNotify(payload)
            local fd     = type(payload.FishData) == "table" and payload.FishData or {}
            local name   = payload.FishID or fd.Name or "Unknown Fish"
            local rarity = fd.Rarity or "-"
            local weight = payload.WeightFormatted or (payload.Weight and (tostring(payload.Weight) .. " Kg")) or "-"
            local price  = payload.Price or fd.Price or 0

            local mutText = ""
            if type(payload.Mutations) == "table" and #payload.Mutations > 0 then
                mutText = " ✦ " .. table.concat(payload.Mutations, ", ")
            elseif payload.MutationLabel and payload.MutationLabel ~= "" then
                mutText = " ✦ " .. tostring(payload.MutationLabel)
            end
            local newTag = payload.IsNewDiscovery and " 🆕" or ""

            WindUI:Notify({
                Title    = string.format("%s%s [%s]", tostring(name), newTag, tostring(rarity)),
                Content  = string.format("%s | $%s%s", tostring(weight), tostring(price), mutText),
                Icon     = "solar:water-bold",
                Duration = 4,
            })
        end

        AutoFishSection:Toggle({
            Title    = "Custom Fish Notify",
            Default  = false,
            Callback = function(v)
                if v then
                    startGuiScanner()
                    if R.FishCaught and not _fishNotifyConn then
                        _fishNotifyConn = R.FishCaught.OnClientEvent:Connect(function(payload)
                            if type(payload) ~= "table" then return end
                            closeCatchUI()
                            local ok = pcall(showCustomFishNotify, payload)
                            if not ok then
                                WindUI:Notify({ Title = "FAM", Content = tostring(payload.FishID or "Fish caught"), Duration = 3 })
                            end
                        end)
                    end
                    WindUI:Notify({ Title = "FAM", Content = "Custom Fish Notify ON", Duration = 2 })
                else
                    stopGuiScanner()
                    if _fishNotifyConn then
                        _fishNotifyConn:Disconnect()
                        _fishNotifyConn = nil
                    end
                    WindUI:Notify({ Title = "FAM", Content = "Custom Fish Notify OFF", Duration = 2 })
                end
            end,
        })

        MainTab:Space({ Columns = 0.5 })

        local AutoSellSection = MainTab:Section({
            Title = "Auto Sell",
            Icon = "solar:dollar-bold",
            Box = true,
            BoxBorder = true,
        })

        AutoSellSection:Toggle({
            Title    = "Auto Sell",
            Default  = false,
            Callback = function(v)
                state.autoSell = v
            end,
        })

        AutoSellSection:Dropdown({
            Title    = "Sell Rarities",
            Values   = RARITIES,
            Multi    = true,
            Search   = false,
            Value    = { "Common", "Uncommon", "Rare", "Epic" },
            Callback = function(value)
                for _, r in ipairs(RARITIES) do
                    state.sellRarities[r] = false
                end
                if type(value) == "table" then
                    for k, v in pairs(value) do
                        if v == true and type(k) == "string" then
                            state.sellRarities[k] = true
                        elseif type(v) == "string" then
                            state.sellRarities[v] = true
                        end
                    end
                end
            end,
        })

        AutoSellSection:Input({
            Title       = "Sell Count",
            Value       = tostring(state.sellEvery),
            Placeholder = "1 - 1000",
            Callback    = function(v)
                local num = tonumber(v)
                state.sellEvery = num and math.clamp(num, 1, 1000) or 500
            end,
        })

        AutoSellSection:Button({
            Title    = "Sell Filtered Now",
            Icon     = "solar:cart-check-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    tryAutoSell(true)
                    WindUI:Notify({ Title = "FAM", Content = state.status, Duration = 3 })
                end)
            end,
        })

        MainTab:Space({ Columns = 0.5 })

        local CastSection = MainTab:Section({
            Title = "Cast",
            Icon = "solar:target-bold",
            Box = true,
            BoxBorder = true,
        })

        CastSection:Input({
            Title       = "Cast Distance",
            Value       = tostring(state.castDist),
            Placeholder = "Enter distance",
            Callback    = function(v)
                state.castDist = tonumber(v) or 28
            end,
        })

        CastSection:Input({
            Title       = "Throw Power",
            Desc        = "ThrowFloater power arg",
            Value       = tostring(state.throwPower),
            Placeholder = "Enter power",
            Callback    = function(v)
                state.throwPower = tonumber(v) or 10
            end,
        })

        MainTab:Space({ Columns = 0.5 })

        local AutoPotionSection = MainTab:Section({
            Title = "Auto Potion",
            Icon = "solar:test-tube-bold",
            Box = true,
            BoxBorder = true,
        })

        local potionUseLabels = shopLabels(SHOP_POTIONS, false)
        local selectedPotionIds = {}

        local function useSelectedPotions(silent)
            if #selectedPotionIds == 0 then
                if not silent then
                    WindUI:Notify({ Title = "FAM", Content = "Select at least one potion first", Duration = 2 })
                end
                return
            end
            local usedCount = 0
            for _, id in ipairs(selectedPotionIds) do
                local ok = consumePotion(id)
                if ok then usedCount += 1 end
                task.wait(0.2)
            end
            if not silent then
                WindUI:Notify({
                    Title = "FAM",
                    Content = string.format("Used %d/%d potion(s)", usedCount, #selectedPotionIds),
                    Duration = 3,
                })
            end
        end

        AutoPotionSection:Dropdown({
            Title    = "Potions",
            Desc     = string.format("%d potion available", #SHOP_POTIONS),
            Values   = potionUseLabels,
            Multi    = true,
            Search   = true,
            Value    = {},
            Callback = function(value)
                selectedPotionIds = {}
                if type(value) ~= "table" then return end
                local labels = {}
                for k, v in pairs(value) do
                    if v == true and type(k) == "string" then
                        table.insert(labels, k)
                    elseif type(v) == "string" then
                        table.insert(labels, v)
                    end
                end
                for _, label in ipairs(labels) do
                    local item = shopPick(SHOP_POTIONS, label)
                    if item then
                        table.insert(selectedPotionIds, item.id)
                    end
                end
            end,
        })

        AutoPotionSection:Input({
            Title       = "Auto Use Interval",
            Value       = tostring(state.potionUseInterval),
            Placeholder = "1 - 3600",
            Callback    = function(v)
                local num = tonumber(v)
                state.potionUseInterval = num and math.clamp(num, 1, 3600) or 600
            end,
        })

        local _potionAutoGen = 0

        AutoPotionSection:Toggle({
            Title    = "Auto Use Potion",
            Default  = false,
            Callback = function(v)
                state.autoUsePotion = v
                if v then
                    _potionAutoGen += 1
                    local myGen = _potionAutoGen
                    task.spawn(function()
                        while state.autoUsePotion and _potionAutoGen == myGen do
                            useSelectedPotions(true)
                            local target = math.max(1, state.potionUseInterval)
                            local waited = 0
                            while waited < target and state.autoUsePotion and _potionAutoGen == myGen do
                                task.wait(1)
                                waited += 1
                            end
                        end
                    end)
                    WindUI:Notify({ Title = "FAM", Content = "Auto Use Potion ON", Duration = 2 })
                else
                    _potionAutoGen += 1
                    WindUI:Notify({ Title = "FAM", Content = "Auto Use Potion OFF", Duration = 2 })
                end
            end,
        })

        AutoPotionSection:Button({
            Title    = "Use Selected Now",
            Icon     = "solar:test-tube-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    useSelectedPotions(false)
                end)
            end,
        })
    end

    about:Paragraph({
        Title = "ByteCode.id",
        Desc = "Join Our Community Discord Server to get the latest updates, support, and connect with other users!",
        Image = "rbxassetid://90205264511012",
        ImageSize = 48,
    })

    about:Button({
        Title = "Destroy Window",
        Icon = "solar:archive-down-bold",
        Transparency = 0.4,
        Color = Color3.fromRGB(0, 0, 0),
        Justify = "Center",
        Callback = function()
            if getgenv().byteIcon_Floating then
                pcall(function()
                    getgenv().byteIcon_Floating:Destroy()
                end)
                getgenv().byteIcon_Floating = nil
            end
            local existing = PlayerGui:FindFirstChild("byteIcon")
            if existing then
                existing:Destroy()
            end
            Window:Destroy()
        end,
    })

    do
        local BossStatusSection = BossTab:Section({
            Title = "Boss Raid",
            Icon = "solar:danger-triangle-bold",
            Box = true,
            BoxBorder = true,
        })

        local BossStatusPara = BossStatusSection:Paragraph({
            Title = "Boss Status",
            Desc  = "idle",
            Image = "solar:danger-triangle-bold",
            ImageSize = 32,
        })

        task.spawn(function()
            while getgenv().byteIcon_Window and not getgenv().byteIcon_Window._isDestroying do
                local content = string.format(
                    "Status: %s\nBoss: %s\nState: %s\nHP: %s\nTaps: %d\nParticipating: %s\nFight: %s",
                    state.bossStatus,
                    tostring(state.bossName),
                    tostring(state.bossState),
                    tostring(state.bossHp),
                    state.bossTaps,
                    tostring(LocalPlayer:GetAttribute("IsParticipatingBossEvent") == true or _G.isParticipatingInBossEvent == true),
                    tostring(state.bossInFight)
                )
                pcall(function()
                    BossStatusPara:SetDesc(content)
                end)
                task.wait(0.4)
            end
        end)

        BossStatusSection:Toggle({
            Title    = "Auto Participate",
            Desc     = "Join active boss via FishMonsterReady",
            Default  = false,
            Callback = function(v)
                state.autoBoss = v
                if state.autoBoss then
                    WindUI:Notify({ Title = "Boss", Content = "Auto Participate ON", Duration = 2 })
                end
            end,
        })

        BossStatusSection:Toggle({
            Title    = "Auto Tap",
            Desc     = string.format("Spam PlayerTap (cd %.2fs)", BOSS_CLICK_CD),
            Value    = true,
            Callback = function(v)
                state.autoTap = v
            end,
        })

        BossStatusSection:Toggle({
            Title    = "Pause Fish On Boss",
            Desc     = "Pause fishing during boss events",
            Value    = true,
            Callback = function(v)
                state.pauseFishOnBoss = v
            end,
        })

        BossStatusSection:Button({
            Title    = "Join Active Boss",
            Desc     = "Join closest active boss",
            Icon     = "solar:shield-check-bold",
            Justify  = "Center",
            Callback = function()
                local list = getActiveBosses()
                local b = pickBoss(list)
                if not b then
                    WindUI:Notify({ Title = "Boss", Content = "No active boss", Duration = 3 })
                    return
                end
                if bossParticipate(b.BossName) then
                    WindUI:Notify({ Title = "Boss", Content = "Joined " .. tostring(b.BossName), Duration = 3 })
                else
                    WindUI:Notify({ Title = "Boss", Content = "Join failed", Duration = 3 })
                end
            end,
        })

        BossStatusSection:Button({
            Title    = "Teleport to Boss",
            Desc     = "Teleport to active boss",
            Icon     = "solar:map-arrow-square-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    local list = getActiveBosses()
                    local b = pickBoss(list)
                    if not b then
                        WindUI:Notify({ Title = "Boss", Content = "No active boss", Duration = 3 })
                        return
                    end
                    local ok, msg = teleportToBoss(b)
                    WindUI:Notify({
                        Title = "Boss",
                        Content = ok and ("TP → " .. tostring(b.BossName or b.BossDisplayName or "boss"))
                            or ("Fail: " .. tostring(msg)),
                        Duration = 3,
                    })
                end)
            end,
        })

        BossStatusSection:Button({
            Title    = "Quit Boss",
            Icon     = "solar:exit-bold",
            Justify  = "Center",
            Callback = function()
                bossQuit()
                WindUI:Notify({ Title = "Boss", Content = "Quit sent", Duration = 2 })
            end,
        })

        BossStatusSection:Button({
            Title    = "Refresh Active",
            Icon     = "solar:refresh-bold",
            Justify  = "Center",
            Callback = function()
                local list = getActiveBosses()
                if #list == 0 then
                    state.bossStatus = "no active"
                    WindUI:Notify({ Title = "Boss", Content = "No active events", Duration = 2 })
                    return
                end
                local names = {}
                for _, b in ipairs(list) do
                    table.insert(names, tostring(b.BossName) .. " [" .. tostring(b.CurrentState or "?") .. "]")
                end
                state.bossStatus = table.concat(names, ", ")
                WindUI:Notify({ Title = "Boss", Content = state.bossStatus, Duration = 4 })
            end,
        })
    end

    do
        local TeleportTab = MainCore:Tab({
            Title     = "Teleport",
            Icon      = "solar:map-point-bold",
            IconColor = Color3.fromRGB(255, 255, 255),
        })

        local function dropdownValue(value, fallback)
            local name = value
            if type(value) == "table" then
                for k, v in pairs(value) do
                    if v == true and type(k) == "string" then
                        name = k
                        break
                    elseif type(v) == "string" then
                        name = v
                        break
                    end
                end
            end
            return tostring(name or fallback or "")
        end

        local ServerTpSection = TeleportTab:Section({
            Title = "TP Server",
            Icon = "solar:server-bold",
            Box = true,
            BoxBorder = true,
        })

        local SERVER_TP_PLACES = {
            { Name = "Main Server (Return to Lobby)", PlaceId = 111385005478215 },
            { Name = "Sea Server", PlaceId = 90457367396205 },
        }

        for _, dest in ipairs(SERVER_TP_PLACES) do
            ServerTpSection:Button({
                Title    = dest.Name,
                Desc     = "Teleport to place " .. tostring(dest.PlaceId),
                Icon     = "solar:map-arrow-square-bold",
                Justify  = "Center",
                Callback = function()
                    task.spawn(function()
                        if dest.PlaceId == game.PlaceId then
                            WindUI:Notify({ Title = "TP Server", Content = "Already on this server", Duration = 2 })
                            return
                        end
                        stopBeforeTeleport()
                        WindUI:Notify({ Title = "TP Server", Content = "Teleporting to " .. dest.Name .. "...", Duration = 3 })
                        local ok, err = pcall(function()
                            TeleportService:Teleport(dest.PlaceId, LocalPlayer)
                        end)
                        if not ok then
                            WindUI:Notify({ Title = "TP Server", Content = "Fail: " .. tostring(err), Duration = 3 })
                        end
                    end)
                end,
            })
        end

        TeleportTab:Space({ Columns = 0.5 })

        local TpSection = TeleportTab:Section({
            Title = "Teleport",
            Icon = "solar:map-point-bold",
            Box = true,
            BoxBorder = true,
        })

        local ALL_TP = {}
        local TP_LABELS = {}
        for _, e in ipairs(HUB_TP) do
            table.insert(ALL_TP, e)
            table.insert(TP_LABELS, e.Name)
        end
        for _, e in ipairs(ISLAND_TP) do
            table.insert(ALL_TP, e)
            table.insert(TP_LABELS, e.Name)
        end
        local function entryByName(name)
            for _, e in ipairs(ALL_TP) do
                if e.Name == name then return e end
            end
            return nil
        end

        local selectedTp = TP_LABELS[1]
        TpSection:Dropdown({
            Title    = "Destination",
            Desc     = "Select location, then click Teleport",
            Values   = TP_LABELS,
            Multi    = false,
            Search   = true,
            Value    = TP_LABELS[1],
            Callback = function(value)
                selectedTp = dropdownValue(value, TP_LABELS[1])
            end,
        })
        TpSection:Button({
            Title    = "Teleport",
            Desc     = "Teleport to selected destination",
            Icon     = "solar:point-on-map-bold",
            Justify  = "Center",
            Callback = function()
                local entry = entryByName(selectedTp)
                if not entry then
                    WindUI:Notify({ Title = "Teleport", Content = "Select a destination first", Duration = 2 })
                    return
                end
                task.spawn(function()
                    local ok, msg = doTeleport(entry)
                    WindUI:Notify({
                        Title = "Teleport",
                        Content = ok and ("OK → " .. entry.Name) or ("Fail: " .. tostring(msg)),
                        Duration = 3,
                    })
                end)
            end,
        })

        TeleportTab:Space({ Columns = 0.5 })

        local NpcSection = TeleportTab:Section({
            Title = "NPC",
            Icon = "solar:user-bold",
            Box = true,
            BoxBorder = true,
        })

        local NPC_LIST = scanNpcs()
        local NPC_LABELS = {}
        for _, e in ipairs(NPC_LIST) do
            table.insert(NPC_LABELS, e.Name)
        end
        if #NPC_LABELS == 0 then
            table.insert(NPC_LABELS, "(no NPC found)")
        end

        local selectedNpc = NPC_LABELS[1]
        local NpcDropdown = NpcSection:Dropdown({
            Title    = "NPC",
            Desc     = "Select NPC, then click Teleport",
            Values   = NPC_LABELS,
            Multi    = false,
            Search   = true,
            Value    = NPC_LABELS[1],
            Callback = function(value)
                selectedNpc = dropdownValue(value, NPC_LABELS[1])
            end,
        })
        NpcSection:Button({
            Title    = "Teleport to NPC",
            Desc     = "Teleport to selected NPC",
            Icon     = "solar:point-on-map-bold",
            Justify  = "Center",
            Callback = function()
                local name = selectedNpc
                local entry
                for _, e in ipairs(NPC_LIST) do
                    if e.Name == name then
                        entry = e
                        break
                    end
                end
                if not entry or not entry.Pos then
                    WindUI:Notify({ Title = "NPC", Content = "Invalid NPC — Refresh first", Duration = 2 })
                    return
                end
                task.spawn(function()
                    local fresh = scanNpcs()
                    for _, e in ipairs(fresh) do
                        if e.Name == name then
                            entry = e
                            break
                        end
                    end
                    local ok, msg = doTeleport(entry)
                    WindUI:Notify({
                        Title = "NPC",
                        Content = ok and ("OK → " .. entry.Name) or ("Fail: " .. tostring(msg)),
                        Duration = 3,
                    })
                end)
            end,
        })
        NpcSection:Button({
            Title    = "Refresh NPC List",
            Desc     = "Scan NPCs in world",
            Icon     = "solar:refresh-bold",
            Justify  = "Center",
            Callback = function()
                NPC_LIST = scanNpcs()
                NPC_LABELS = {}
                for _, e in ipairs(NPC_LIST) do
                    table.insert(NPC_LABELS, e.Name)
                end
                if #NPC_LABELS == 0 then
                    table.insert(NPC_LABELS, "(no NPC found)")
                end
                selectedNpc = NPC_LABELS[1]
                pcall(function()
                    if NpcDropdown.Refresh then
                        NpcDropdown:Refresh(NPC_LABELS)
                    elseif NpcDropdown.SetValues then
                        NpcDropdown:SetValues(NPC_LABELS)
                    end
                end)
                WindUI:Notify({
                    Title = "NPC",
                    Content = #NPC_LIST .. " NPC found",
                    Duration = 2,
                })
            end,
        })

        TeleportTab:Space({ Columns = 0.5 })

        local PlayerTpSection = TeleportTab:Section({
            Title = "Player",
            Icon = "solar:users-group-rounded-bold",
            Box = true,
            BoxBorder = true,
        })

        local function getPlayerList()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(list, p.Name)
                end
            end
            if #list == 0 then
                table.insert(list, "(no other players)")
            end
            table.sort(list)
            return list
        end

        local playerLabels = getPlayerList()
        local selectedPlayer = playerLabels[1]
        local PlayerDropdown = PlayerTpSection:Dropdown({
            Title    = "Select Player",
            Desc     = "Select a player to teleport to",
            Values   = playerLabels,
            Multi    = false,
            Search   = true,
            Value    = playerLabels[1],
            Callback = function(value)
                selectedPlayer = dropdownValue(value, playerLabels[1])
            end,
        })
        PlayerTpSection:Button({
            Title    = "Teleport to Player",
            Desc     = "Teleport to the selected player's character",
            Icon     = "solar:point-on-map-bold",
            Justify  = "Center",
            Callback = function()
                local name = selectedPlayer
                if name == "(no other players)" or name == "" then
                    WindUI:Notify({ Title = "Teleport", Content = "No player selected", Duration = 2 })
                    return
                end
                local targetPlayer = Players:FindFirstChild(name)
                local targetChar = (targetPlayer and targetPlayer.Character) or workspace:FindFirstChild(name)
                local targetHrp = targetChar and (targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChildWhichIsA("BasePart"))
                if not targetHrp then
                    WindUI:Notify({ Title = "Teleport", Content = "Player character not found", Duration = 2 })
                    return
                end
                task.spawn(function()
                    local ok, msg = teleportCFrame(targetHrp.Position)
                    WindUI:Notify({
                        Title = "Teleport",
                        Content = ok and ("OK -> " .. name) or ("Fail: " .. tostring(msg)),
                        Duration = 3,
                    })
                end)
            end,
        })
        PlayerTpSection:Button({
            Title    = "Refresh Player List",
            Desc     = "Scan active players in the server",
            Icon     = "solar:refresh-bold",
            Justify  = "Center",
            Callback = function()
                playerLabels = getPlayerList()
                selectedPlayer = playerLabels[1]
                pcall(function()
                    if PlayerDropdown.Refresh then
                        PlayerDropdown:Refresh(playerLabels)
                    elseif PlayerDropdown.SetValues then
                        PlayerDropdown:SetValues(playerLabels)
                    end
                end)
                WindUI:Notify({
                    Title = "Teleport",
                    Content = string.format("Found %d other players", (#playerLabels == 1 and playerLabels[1] == "(no other players)") and 0 or #playerLabels),
                    Duration = 2,
                })
            end,
        })
    end

    do
        local QuestTab = MainCore:Tab({
            Title     = "Quest",
            Icon      = "solar:notebook-bold",
            IconColor = Color3.fromRGB(255, 255, 255),
        })

        local AcceptSection = QuestTab:Section({
            Title = "Accept",
            Icon = "solar:document-add-bold",
            Box = true,
            BoxBorder = true,
        })

        local QuestStatusPara = AcceptSection:Paragraph({
            Title = "Quest Status",
            Desc  = "idle",
            Image = "solar:notebook-bold",
            ImageSize = 32,
        })

        task.spawn(function()
            while getgenv().byteIcon_Window and not getgenv().byteIcon_Window._isDestroying do
                local st = select(1, questStatusPack())
                local dailyN, weeklyN, activeN, claimable = 0, 0, 0, 0
                if st then
                    if type(st.DailyQuests) == "table" then
                        for _ in pairs(st.DailyQuests) do dailyN += 1 end
                    end
                    if type(st.WeeklyQuests) == "table" then
                        for _ in pairs(st.WeeklyQuests) do weeklyN += 1 end
                    end
                    if type(st.ActiveQuests) == "table" then
                        for _, q in pairs(st.ActiveQuests) do
                            activeN += 1
                            if type(q) == "table" and (q.State == "Completed" or q.State == "Complete") then
                                claimable += 1
                            end
                        end
                    end
                end
                local content = string.format(
                    "Last: %s\n%s\nDaily slots: %d | Weekly: %d\nActive: %d | claimable: %d",
                    state.questLast,
                    state.questStatus,
                    dailyN,
                    weeklyN,
                    activeN,
                    claimable
                )
                pcall(function()
                    QuestStatusPara:SetDesc(content)
                end)
                task.wait(1)
            end
        end)

        local AcceptGroup = AcceptSection:Group({})
        AcceptGroup:Button({
            Title    = "Accept All",
            Icon     = "solar:document-add-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    acceptQuestsOnce("all")
                    WindUI:Notify({ Title = "Quest", Content = state.questStatus .. " | " .. state.questLast, Duration = 3 })
                end)
            end,
        })
        AcceptGroup:Space()
        AcceptGroup:Button({
            Title    = "Accept Story",
            Icon     = "solar:book-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    acceptQuestsOnce("story")
                    WindUI:Notify({ Title = "Quest", Content = state.questStatus .. " | " .. state.questLast, Duration = 3 })
                end)
            end,
        })

        local AcceptGroup2 = AcceptSection:Group({})
        AcceptGroup2:Button({
            Title    = "Accept Daily",
            Icon     = "solar:calendar-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    acceptQuestsOnce("daily")
                    WindUI:Notify({ Title = "Quest", Content = state.questStatus .. " | " .. state.questLast, Duration = 3 })
                end)
            end,
        })
        AcceptGroup2:Space()
        AcceptGroup2:Button({
            Title    = "Accept Weekly",
            Icon     = "solar:calendar-mark-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    acceptQuestsOnce("weekly")
                    WindUI:Notify({ Title = "Quest", Content = state.questStatus .. " | " .. state.questLast, Duration = 3 })
                end)
            end,
        })

        QuestTab:Space({ Columns = 0.5 })

        local RewardSection = QuestTab:Section({
            Title = "Rewards",
            Icon = "solar:gift-bold",
            Box = true,
            BoxBorder = true,
        })

        RewardSection:Toggle({
            Title    = "Auto Claim Rewards",
            Desc     = "ClaimReward quest State=Completed",
            Value    = true,
            Callback = function(on)
                state.autoClaimQuest = on
            end,
        })
        RewardSection:Button({
            Title    = "Claim Once Now",
            Desc     = "Claim all completed quests",
            Icon     = "solar:gift-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    autoClaimQuestsOnce()
                    WindUI:Notify({ Title = "Quest", Content = state.questStatus .. " | " .. state.questLast, Duration = 3 })
                end)
            end,
        })
    end

    do
        local TreasureTab = MainCore:Tab({
            Title     = "Treasure",
            Icon      = "solar:box-bold",
            IconColor = Color3.fromRGB(255, 255, 255),
        })

        local ChestSection = TreasureTab:Section({
            Title = "Chest",
            Icon = "solar:box-bold",
            Box = true,
            BoxBorder = true,
        })

        ChestSection:Toggle({
            Title    = "Auto Treasure",
            Desc     = "Scan, TP, and open chests automatically",
            Default  = false,
            Callback = function(on)
                state.autoTreasure = on
                if on then
                    startTreasureLoop()
                    WindUI:Notify({ Title = "Treasure", Content = "Auto Treasure ON", Duration = 2 })
                else
                    stopTreasureLoop()
                    WindUI:Notify({ Title = "Treasure", Content = "Auto Treasure OFF", Duration = 2 })
                end
            end,
        })
        local ChestGroup = ChestSection:Group({})
        ChestGroup:Button({
            Title    = "Open Chests Now",
            Icon     = "solar:box-minimalistic-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    local was = state.autoTreasure
                    state.autoTreasure = true
                    scanAndOpenChests()
                    state.autoTreasure = was
                    WindUI:Notify({
                        Title = "Treasure",
                        Content = "Done. Opened total: " .. state.treasureChestsOpened,
                        Duration = 3,
                    })
                end)
            end,
        })
        ChestGroup:Space()
        ChestGroup:Button({
            Title    = "Reset Chest Session",
            Icon     = "solar:restart-bold",
            Justify  = "Center",
            Callback = function()
                table.clear(treasureOpened)
                WindUI:Notify({ Title = "Treasure", Content = "Chest cache cleared", Duration = 2 })
            end,
        })

        TreasureTab:Space({ Columns = 0.5 })

        local EggSection2 = TreasureTab:Section({
            Title = "Easter Egg",
            Icon = "solar:gift-bold",
            Box = true,
            BoxBorder = true,
        })

        EggSection2:Toggle({
            Title    = "Auto Easter Egg",
            Desc     = "TP + TriggerEasterEgg (skip dialog-only)",
            Default  = false,
            Callback = function(on)
                state.autoEasterEgg = on
                if on then
                    startEasterEggLoop()
                    WindUI:Notify({ Title = "Easter Egg", Content = "Auto ON", Duration = 2 })
                else
                    stopEasterEggLoop()
                    WindUI:Notify({ Title = "Easter Egg", Content = "Auto OFF", Duration = 2 })
                end
            end,
        })
        EggSection2:Toggle({
            Title    = "Skip OOF Egg",
            Desc     = "Skip eggs that kill the player",
            Value    = true,
            Callback = function(on)
                state.easterEggSkipOof = on
            end,
        })
        local EggGroup2 = EggSection2:Group({})
        EggGroup2:Button({
            Title    = "Trigger Eggs Now",
            Icon     = "solar:gift-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    local was = state.autoEasterEgg
                    state.autoEasterEgg = true
                    scanAndTriggerEasterEggs()
                    state.autoEasterEgg = was
                    WindUI:Notify({
                        Title = "Easter Egg",
                        Content = "Done. Triggered: " .. state.easterEggTriggered,
                        Duration = 3,
                    })
                end)
            end,
        })
        EggGroup2:Space()
        EggGroup2:Button({
            Title    = "Reset Egg Session",
            Icon     = "solar:restart-bold",
            Justify  = "Center",
            Callback = function()
                table.clear(easterEggDone)
                WindUI:Notify({ Title = "Easter Egg", Content = "Session cache cleared", Duration = 2 })
            end,
        })
    end

    local SellTab = MainCore:Tab({
        Title = "Sellitems",
        Icon = "solar:cart-large-minimalistic-bold",
        IconColor = Color3.fromRGB(255, 255, 255),

    })

    do
        local FavStatusSection = SellTab:Section({
            Title = "Favorite Status",
            Icon = "solar:star-bold",
            Box = true,
            BoxBorder = true,
        })

        local FavStatusPara = FavStatusSection:Paragraph({
            Title = "Favorite Status",
            Desc  = "idle",
            Image = "solar:star-bold",
            ImageSize = 32,
        })

        task.spawn(function()
            while getgenv().byteIcon_Window and not getgenv().byteIcon_Window._isDestroying do
                local selected = {}
                for _, r in ipairs(RARITIES) do
                    if state.favRarities[r] then
                        table.insert(selected, r)
                    end
                end
                local fishN = 0
                for _ in pairs(state.favFishNames) do
                    fishN += 1
                end
                local content = string.format(
                    "Rarity auto: %s | Fish auto: %s\nRarity: %s\nFish selected: %d\n%s\nLast: %s",
                    state.autoFavorite and "ON" or "OFF",
                    state.autoFavoriteByFish and "ON" or "OFF",
                    #selected > 0 and table.concat(selected, ", ") or "(none)",
                    fishN,
                    state.favStatus,
                    state.favLast
                )
                pcall(function()
                    FavStatusPara:SetDesc(content)
                end)
                task.wait(1)
            end
        end)

        SellTab:Space({ Columns = 0.5 })

        local AutoFavSection = SellTab:Section({
            Title = "Auto Favorite (Rarity)",
            Icon = "solar:star-bold",
            Box = true,
            BoxBorder = true,
        })

        AutoFavSection:Dropdown({
            Title    = "Favorite Rarities",
            Desc     = "Auto-favorite fish of these rarities",
            Values   = RARITIES,
            Multi    = true,
            Search   = false,
            Value    = { "Legendary", "Mythic", "Secret", "Monster" },
            Callback = function(value)
                for _, r in ipairs(RARITIES) do
                    state.favRarities[r] = false
                end
                if type(value) == "table" then
                    for k, v in pairs(value) do
                        if v == true and type(k) == "string" then
                            state.favRarities[k] = true
                        elseif type(v) == "string" then
                            state.favRarities[v] = true
                        end
                    end
                end
            end,
        })

        AutoFavSection:Toggle({
            Title    = "Auto Favorite (Rarity)",
            Desc     = "Auto-favorite by rarity filter",
            Default  = false,
            Callback = function(v)
                state.autoFavorite = v
                if v then
                    WindUI:Notify({ Title = "Favorite", Content = "Auto Favorite (Rarity) ON", Duration = 2 })
                    task.spawn(function()
                        favoriteMatchingOnce()
                    end)
                else
                    WindUI:Notify({ Title = "Favorite", Content = "Auto Favorite (Rarity) OFF", Duration = 2 })
                end
            end,
        })

        SellTab:Space({ Columns = 0.5 })

        local FavByFishSection = SellTab:Section({
            Title = "Auto Favorite (Fish)",
            Icon = "solar:heart-bold",
            Box = true,
            BoxBorder = true,
        })

        FavByFishSection:Dropdown({
            Title    = "Favorite Fish",
            Desc     = string.format("A–Z · %d species", #FISH_LABELS),
            Values   = FISH_LABELS,
            Multi    = true,
            Search   = true,
            Value    = {},
            Callback = function(value)
                state.favFishNames = {}
                if type(value) == "table" then
                    for k, v in pairs(value) do
                        local label
                        if v == true and type(k) == "string" then
                            label = k
                        elseif type(v) == "string" then
                            label = v
                        end
                        if label then
                            state.favFishNames[label] = true
                            state.favFishNames[label:lower()] = true
                            local id = FISH_LABEL_TO_ID[label] or label:gsub(" ", "_")
                            state.favFishNames[id] = true
                            state.favFishNames[id:lower()] = true
                            state.favFishNames[id:gsub("_", " ")] = true
                        end
                    end
                end
            end,
        })

        FavByFishSection:Toggle({
            Title    = "Auto Favorite (Fish)",
            Desc     = "Auto-favorite by fish name filter",
            Default  = false,
            Callback = function(v)
                state.autoFavoriteByFish = v
                if v then
                    WindUI:Notify({ Title = "Favorite", Content = "Auto Favorite (Fish) ON", Duration = 2 })
                    task.spawn(function()
                        favoriteMatchingOnce(nil, true)
                    end)
                else
                    WindUI:Notify({ Title = "Favorite", Content = "Auto Favorite (Fish) OFF", Duration = 2 })
                end
            end,
        })

        local FavActionsGroup = FavByFishSection:Group({})

        FavActionsGroup:Button({
            Title    = "Favorite Now",
            Icon     = "solar:star-bold",
            Justify  = "Center",
            Callback = function()
                task.spawn(function()
                    local n, a, f = favoriteMatchingOnce()
                    WindUI:Notify({
                        Title = "Favorite",
                        Content = string.format("New %d | already %d | fail %d", n, a, f),
                        Duration = 3,
                    })
                end)
            end,
        })

        FavActionsGroup:Space()

        FavActionsGroup:Button({
            Title    = "Unfavorite All",
            Icon     = "solar:star-fall-bold",
            Justify  = "Center",
            Color    = Color3.fromRGB(180, 60, 60),
            Callback = function()
                task.spawn(function()
                    local _, getInv, toggle = getFishShopRemotes()
                    if not (getInv and toggle) then
                        WindUI:Notify({ Title = "Favorite", Content = "no remotes", Duration = 2 })
                        return
                    end
                    _G.FavoritedFish = _G.FavoritedFish or {}
                    local ok, inv = pcall(function()
                        return getInv:InvokeServer()
                    end)
                    if not ok or type(inv) ~= "table" then
                        WindUI:Notify({ Title = "Favorite", Content = "inv fail", Duration = 2 })
                        return
                    end
                    local fav = inv.FavoritedFish or {}
                    local n = 0
                    for id, v in pairs(fav) do
                        if v then
                            local sid = tostring(id)
                            local ok2 = pcall(function()
                                return toggle:InvokeServer(sid)
                            end)
                            if ok2 then
                                _G.FavoritedFish[sid] = nil
                                n += 1
                            end
                            task.wait(0.08)
                        end
                    end
                    _G.FavoritedFish = {}
                    state.favStatus = "unfav " .. n
                    WindUI:Notify({ Title = "Favorite", Content = "Unfavorited " .. n, Duration = 3 })
                end)
            end,
        })
    end

    local ShopTab = MainCore:Tab({
        Title = "Shopitems",
        Icon = "solar:shop-bold",
        IconColor = Color3.fromRGB(255, 255, 255),

    })

    local function shopLabelValue(dropdownValue)
        local label = dropdownValue
        if type(label) == "table" then
            for k, v in pairs(label) do
                if type(v) == "string" then label = v break end
                if v == true and type(k) == "string" then label = k break end
            end
        end
        return tostring(label or "")
    end

    do
        local RodSection = ShopTab:Section({
            Title = "Rods",
            Icon = "solar:magic-stick-bold",
            Box = true,
            BoxBorder = true,
        })

        local rodLabels = shopLabels(SHOP_RODS, true)
        local selectedRod = rodLabels[1]
        RodSection:Dropdown({
            Title    = "Rod",
            Desc     = "Coin rods only (premium skipped)",
            Values   = rodLabels,
            Multi    = false,
            Search   = true,
            Value    = rodLabels[1],
            Callback = function(value)
                selectedRod = shopLabelValue(value)
            end,
        })
        RodSection:Button({
            Title    = "Buy Rod",
            Icon     = "solar:cart-check-bold",
            Justify  = "Center",
            Callback = function()
                local item = shopPick(SHOP_RODS, selectedRod)
                if not item then
                    WindUI:Notify({ Title = "Shop", Content = "Select a rod first", Duration = 2 })
                    return
                end
                local ok = buyRod(item.id)
                WindUI:Notify({
                    Title = "Shop",
                    Content = ok and ("BuyRod " .. item.name) or "Buy rod failed",
                    Duration = 3,
                })
            end,
        })

        ShopTab:Space({ Columns = 0.5 })

        local FloatSection = ShopTab:Section({
            Title = "Floaters",
            Icon = "solar:water-bold",
            Box = true,
            BoxBorder = true,
        })

        local floatLabels = shopLabels(SHOP_FLOATS, true)
        local selectedFloat = floatLabels[1]
        FloatSection:Dropdown({
            Title    = "Floater",
            Values   = floatLabels,
            Multi    = false,
            Search   = true,
            Value    = floatLabels[1],
            Callback = function(value)
                selectedFloat = shopLabelValue(value)
            end,
        })
        FloatSection:Button({
            Title    = "Buy Floater",
            Icon     = "solar:cart-check-bold",
            Justify  = "Center",
            Callback = function()
                local item = shopPick(SHOP_FLOATS, selectedFloat)
                if not item then
                    WindUI:Notify({ Title = "Shop", Content = "Select a floater first", Duration = 2 })
                    return
                end
                local ok = buyFloater(item.id)
                WindUI:Notify({
                    Title = "Shop",
                    Content = ok and ("BuyFloater " .. item.name) or "Buy floater failed",
                    Duration = 3,
                })
            end,
        })

        ShopTab:Space({ Columns = 0.5 })

        local PotionSection = ShopTab:Section({
            Title = "Potions",
            Icon = "solar:test-tube-bold",
            Box = true,
            BoxBorder = true,
        })

        local potLabels = shopLabels(SHOP_POTIONS, true)
        local selectedPotion = potLabels[1]
        PotionSection:Dropdown({
            Title    = "Potion",
            Values   = potLabels,
            Multi    = false,
            Search   = true,
            Value    = potLabels[1],
            Callback = function(value)
                selectedPotion = shopLabelValue(value)
            end,
        })
        PotionSection:Input({
            Title       = "Quantity",
            Desc        = "Amount of potions to buy",
            Value       = tostring(state.potionQty),
            Placeholder = "Enter quantity",
            Callback    = function(v)
                state.potionQty = tonumber(v) or 1
            end,
        })
        PotionSection:Button({
            Title    = "Buy Potion",
            Icon     = "solar:cart-check-bold",
            Justify  = "Center",
            Callback = function()
                local item = shopPick(SHOP_POTIONS, selectedPotion)
                if not item then
                    WindUI:Notify({ Title = "Shop", Content = "Select a potion first", Duration = 2 })
                    return
                end
                local qty = state.potionQty or 1
                local ok = buyPotion(item.id, qty)
                WindUI:Notify({
                    Title = "Shop",
                    Content = ok and string.format("Buy %dx %s", qty, item.name) or "Buy potion failed",
                    Duration = 3,
                })
            end,
        })

        ShopTab:Space({ Columns = 0.5 })

        local GadgetSection = ShopTab:Section({
            Title = "Auras & Gadgets",
            Icon = "solar:magic-stick-3-bold",
            Box = true,
            BoxBorder = true,
        })

        local gadgetLabels = shopLabels(SHOP_GADGETS, true)
        local selectedGadget = gadgetLabels[1]
        GadgetSection:Dropdown({
            Title    = "Item",
            Desc     = "Tools + Auras (coin)",
            Values   = gadgetLabels,
            Multi    = false,
            Search   = true,
            Value    = gadgetLabels[1],
            Callback = function(value)
                selectedGadget = shopLabelValue(value)
            end,
        })
        GadgetSection:Button({
            Title    = "Buy Gadget / Aura",
            Icon     = "solar:cart-check-bold",
            Justify  = "Center",
            Callback = function()
                local item = shopPick(SHOP_GADGETS, selectedGadget)
                if not item then
                    WindUI:Notify({ Title = "Shop", Content = "Select an item first", Duration = 2 })
                    return
                end
                local ok = buyGadget(item)
                WindUI:Notify({
                    Title = "Shop",
                    Content = ok and ("Buy " .. item.kind .. " " .. item.name) or "Buy failed",
                    Duration = 3,
                })
            end,
        })

        ShopTab:Space({ Columns = 0.5 })

        local EggSection = ShopTab:Section({
            Title = "Pet Eggs",
            Icon = "solar:gift-bold",
            Box = true,
            BoxBorder = true,
        })

        local eggLabels = shopLabels(SHOP_EGGS, true)
        local selectedEgg = eggLabels[1]
        EggSection:Dropdown({
            Title    = "Egg",
            Values   = eggLabels,
            Multi    = false,
            Search   = true,
            Value    = eggLabels[1],
            Callback = function(value)
                selectedEgg = shopLabelValue(value)
            end,
        })
        EggSection:Input({
            Title       = "Quantity",
            Desc        = "Buy amount",
            Value       = tostring(state.eggQty),
            Placeholder = "Enter quantity",
            Callback    = function(v)
                state.eggQty = tonumber(v) or 1
            end,
        })
        EggSection:Button({
            Title    = "Buy Egg",
            Desc     = "PetShopService:BuyEgg",
            Icon     = "solar:cart-check-bold",
            Justify  = "Center",
            Callback = function()
                local item = shopPick(SHOP_EGGS, selectedEgg)
                if not item then
                    WindUI:Notify({ Title = "Shop", Content = "Select an egg first", Duration = 2 })
                    return
                end
                if not item.price then
                    WindUI:Notify({ Title = "Shop", Content = "This egg might be Robux-only", Duration = 3 })
                end
                local qty = state.eggQty or 1
                local ok = buyEgg(item.id, qty)
                state.hatchEggId = item.id
                WindUI:Notify({
                    Title = "Shop",
                    Content = ok and string.format("BuyEgg %dx %s", qty, item.name) or "Buy egg failed",
                    Duration = 3,
                })
            end,
        })
        EggSection:Button({
            Title    = "Buy + Hatch (x1)",
            Desc     = "Beli 1 egg (server hatch via EggHatched)",
            Icon     = "solar:gift-bold",
            Justify  = "Center",
            Callback = function()
                local item = shopPick(SHOP_EGGS, selectedEgg)
                if not item then
                    WindUI:Notify({ Title = "Shop", Content = "Select an egg first", Duration = 2 })
                    return
                end
                state.hatchEggId = item.id
                local ok = buyEgg(item.id, 1)
                WindUI:Notify({
                    Title = "Shop",
                    Content = ok and ("Hatch " .. item.name) or "Hatch buy failed",
                    Duration = 3,
                })
            end,
        })
        EggSection:Toggle({
            Title    = "Auto Hatch",
            Desc     = "Buy selected egg every 2s",
            Default  = false,
            Callback = function(on)
                state.autoHatch = on
                local item = shopPick(SHOP_EGGS, selectedEgg)
                if item then state.hatchEggId = item.id end
                if on and not state.hatchEggId then
                    WindUI:Notify({ Title = "Shop", Content = "Select an egg first", Duration = 2 })
                end
            end,
        })
    end

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local MV = {
        flying = false,
        flySpeed = 100,
        bodyGyro = nil,
        bodyVel = nil,
        hbConn = nil,
        _flyGui = nil,
        noclipEnabled = false,
        noclipConn = nil,
        CurrentWalkSpeed = 16,
        PermanentSpeed = false,
        LastHumanoid = nil,
        infJumpEnabled = false,
        isTpWalkEnabled = false,
        tpWalkSpeed = 1,
        goodMode = false,
        goodModeConn = nil,
        walkOnWater = false,
        walkOnWaterConn = nil,
    }

    local function startFlight(char)
        if MV.bodyGyro or MV.bodyVel then
            return
        end
        if not (char and char.Parent) then
            return
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not (hrp and hum) then
            return
        end
        MV.flying = true
        hum.PlatformStand = true
        MV.bodyGyro = Instance.new("BodyGyro")
        MV.bodyGyro.P = 9e4
        MV.bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        MV.bodyGyro.CFrame = hrp.CFrame
        MV.bodyGyro.Parent = hrp
        MV.bodyVel = Instance.new("BodyVelocity")
        MV.bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        MV.bodyVel.Velocity = Vector3.zero
        MV.bodyVel.Parent = hrp
        local flyUpHeld, flyDownHeld = false, false
        if isMobile then
            local flyGui = Instance.new("ScreenGui")
            flyGui.Name = "FlyControlGui_KAL"
            flyGui.ResetOnSpawn = false
            flyGui.DisplayOrder = 998
            flyGui.Parent = PlayerGui
            local function makeBtn(label, pos, onDown, onUp)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.fromOffset(70, 70)
                btn.Position = pos
                btn.AnchorPoint = Vector2.new(0.5, 0.5)
                btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                btn.BackgroundTransparency = 0.4
                btn.Text = label
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextScaled = true
                btn.Font = Enum.Font.GothamBold
                btn.ZIndex = 10
                Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
                btn.Parent = flyGui
                btn.MouseButton1Down:Connect(onDown)
                btn.MouseButton1Up:Connect(onUp)
                btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.Touch then
                        onDown()
                    end
                end)
                btn.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.Touch then
                        onUp()
                    end
                end)
            end
            makeBtn("▲ UP", UDim2.new(1, -90, 0.5, -80), function()
                flyUpHeld = true
            end, function()
                flyUpHeld = false
            end)
            makeBtn("▼ DN", UDim2.new(1, -90, 0.5, 0), function()
                flyDownHeld = true
            end, function()
                flyDownHeld = false
            end)
            MV._flyGui = flyGui
        end
        MV.hbConn = RunService.RenderStepped:Connect(function()
            if not MV.flying or not hrp or not hrp.Parent then
                MV.hbConn:Disconnect()
                return
            end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            if isMobile then
                local md = hum.MoveDirection
                if md.Magnitude > 0.1 then
                    local camFlat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
                    local camRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
                    local mdFlat = Vector3.new(md.X, 0, md.Z)
                    dir = dir + cam.CFrame.LookVector * camFlat:Dot(mdFlat)
                    dir = dir + cam.CFrame.RightVector * camRight:Dot(mdFlat)
                end
                if flyUpHeld then
                    dir = dir + Vector3.new(0, 1, 0)
                end
                if flyDownHeld then
                    dir = dir - Vector3.new(0, 1, 0)
                end
            else
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    dir = dir + cam.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    dir = dir - cam.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    dir = dir - cam.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    dir = dir + cam.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    dir = dir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    dir = dir - Vector3.new(0, 1, 0)
                end
            end
            MV.bodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * MV.flySpeed or Vector3.zero
            MV.bodyGyro.CFrame = cam.CFrame
        end)
    end
    local function stopFlight()
        MV.flying = false
        if MV.hbConn then
            MV.hbConn:Disconnect()
        end
        if MV.bodyGyro then
            MV.bodyGyro:Destroy()
        end
        if MV.bodyVel then
            MV.bodyVel:Destroy()
        end
        MV.hbConn, MV.bodyGyro, MV.bodyVel = nil, nil, nil
        if MV._flyGui then
            pcall(function()
                MV._flyGui:Destroy()
            end)
            MV._flyGui = nil
        end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end

    local function enableNoclip()
        if MV.noclipConn then
            MV.noclipConn:Disconnect()
        end
        MV.noclipConn = RunService.Stepped:Connect(function()
            if not MV.noclipEnabled then
                return
            end
            local char = LocalPlayer.Character
            if not char then
                return
            end
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
        end)
    end
    local function disableNoclip()
        if MV.noclipConn then
            MV.noclipConn:Disconnect()
            MV.noclipConn = nil
        end
        local char = LocalPlayer.Character
        if not char then
            return
        end
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = true
            end
        end
    end

    local function enableGoodMode()
        if MV.goodModeConn then
            MV.goodModeConn:Disconnect()
            MV.goodModeConn = nil
        end
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then
                h.WalkSpeed = 16
                if h.UseJumpPower then
                    h.JumpPower = 50
                else
                    h.JumpHeight = 7.2
                end
            end
        end
        MV.goodModeConn = RunService.Heartbeat:Connect(function()
            if not MV.goodMode then return end
            local c = LocalPlayer.Character
            if not c then return end
            local h = c:FindFirstChildOfClass("Humanoid")
            if not h then return end
            if h.WalkSpeed ~= 16 then
                h.WalkSpeed = 16
            end
            if h.UseJumpPower then
                if h.JumpPower ~= 50 then
                    h.JumpPower = 50
                end
            else
                if h.JumpHeight ~= 7.2 then
                    h.JumpHeight = 7.2
                end
            end
        end)
    end
    local function disableGoodMode()
        MV.goodMode = false
        if MV.goodModeConn then
            MV.goodModeConn:Disconnect()
            MV.goodModeConn = nil
        end
    end

    local WATER_HOVER_OFFSET = 2.2
    local waterPlatform = nil
    local function getOrCreateWaterPlatform(char)
        if waterPlatform and waterPlatform.Parent then return waterPlatform end
        local p = Instance.new("Part")
        p.Name = "WalkOnWaterPlatform_KAL"
        p.Size = Vector3.new(6, 1, 6)
        p.Anchored = true
        p.CanCollide = true
        p.CanQuery = false
        p.Transparency = 1
        p.Material = Enum.Material.SmoothPlastic
        p.Parent = char or workspace
        waterPlatform = p
        return p
    end
    local function destroyWaterPlatform()
        if waterPlatform then
            pcall(function()
                waterPlatform:Destroy()
            end)
            waterPlatform = nil
        end
    end
    local function enableWalkOnWater()
        if MV.walkOnWaterConn then
            MV.walkOnWaterConn:Disconnect()
            MV.walkOnWaterConn = nil
        end
        destroyWaterPlatform()
        local plat = getOrCreateWaterPlatform(LocalPlayer.Character)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = false
        local rayAccum = 0
        local RAY_INTERVAL = 1 / 15
        local cachedSurfaceY = nil
        local onWater = false
        local lastChar = nil
        MV.walkOnWaterConn = RunService.Heartbeat:Connect(function(dt)
            if not MV.walkOnWater then return end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum) then
                if plat and plat.Parent then plat.CFrame = CFrame.new(0, -500, 0) end
                return
            end
            if char ~= lastChar then
                destroyWaterPlatform()
                plat = getOrCreateWaterPlatform(char)
                lastChar = char
                cachedSurfaceY = nil
            end
            if hum:GetState() == Enum.HumanoidStateType.Seated then
                onWater = false
                cachedSurfaceY = nil
                plat.CFrame = CFrame.new(0, -500, 0)
                return
            end
            rayAccum += dt
            if rayAccum >= RAY_INTERVAL or cachedSurfaceY == nil then
                rayAccum = 0
                params.FilterDescendantsInstances = { char, plat }
                -- absolute world position only; never derived from hrp.CFrame's own Y so it can't
                -- compound upward when the character jumps (jump raises hrp, ray still reads the
                -- fixed water surface height, platform Y stays pinned to that same surface)
                local origin = Vector3.new(hrp.Position.X, cachedSurfaceY and (cachedSurfaceY + 15) or (hrp.Position.Y + 25), hrp.Position.Z)
                local hit = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
                if hit and hit.Material == Enum.Material.Water then
                    cachedSurfaceY = hit.Position.Y
                    onWater = true
                else
                    cachedSurfaceY = nil
                    onWater = false
                end
            end
            if onWater and cachedSurfaceY then
                -- absolute X/Z from current position, absolute fixed Y from the cached water
                -- surface reading — never hrp.CFrame * offset, which is what compounds on jump
                plat.CFrame = CFrame.new(hrp.Position.X, cachedSurfaceY + (WATER_HOVER_OFFSET - 0.5), hrp.Position.Z)
            else
                plat.CFrame = CFrame.new(0, -500, 0)
            end
        end)
    end
    local function disableWalkOnWater()
        if MV.walkOnWaterConn then
            MV.walkOnWaterConn:Disconnect()
            MV.walkOnWaterConn = nil
        end
        destroyWaterPlatform()
    end

    local function applyMVSpeed(hum)
        if MV.PermanentSpeed and hum and hum.WalkSpeed ~= MV.CurrentWalkSpeed then
            hum.WalkSpeed = MV.CurrentWalkSpeed
        end
    end
    RunService.Heartbeat:Connect(function()
        if not MV.PermanentSpeed then
            return
        end
        local c = LocalPlayer.Character
        if not c then
            return
        end
        local h = c:FindFirstChildOfClass("Humanoid")
        if not h then
            return
        end
        if h ~= MV.LastHumanoid then
            MV.LastHumanoid = h
            applyMVSpeed(h)
        elseif h.WalkSpeed ~= MV.CurrentWalkSpeed then
            applyMVSpeed(h)
        end
    end)

    local tpWalkConn_MV
    local function startTpWalk()
        if tpWalkConn_MV then
            tpWalkConn_MV:Disconnect()
        end
        tpWalkConn_MV = RunService.Heartbeat:Connect(function()
            if not MV.isTpWalkEnabled or not LocalPlayer.Character then
                return
            end
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then
                return
            end
            local dir = hum.MoveDirection
            if dir.Magnitude > 0 then
                hrp.CFrame = CFrame.new(hrp.Position + dir * (MV.tpWalkSpeed / 10))
            end
        end)
    end
    LocalPlayer.CharacterAdded:Connect(function(c)
        task.defer(function()
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then
                MV.LastHumanoid = h
                applyMVSpeed(h)
            end
            if MV.noclipEnabled then
                task.wait(0.5)
                enableNoclip()
            end
        end)
    end)

    local Lock = {
        position = false,
        cframe = nil,
        noAnim = false,
        animConn = nil
    }
    local function lockPosition()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            return
        end
        if not Lock.cframe then
            Lock.cframe = root.CFrame
        end
        hum.AutoRotate = false
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        root.Anchored = true
        root.CFrame = Lock.cframe
    end
    local function unlockPosition()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            return
        end
        root.Anchored = false
        hum.AutoRotate = true
        hum.WalkSpeed = MV.PermanentSpeed and MV.CurrentWalkSpeed or 16
        hum.JumpPower = 50
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
    local function enableNoAnimation()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local anim = hum and hum:FindFirstChildOfClass("Animator")
        if not hum or not anim then
            return
        end
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
        Lock.animConn = anim.AnimationPlayed:Connect(function(t)
            t:Stop(0)
        end)
    end
    local function disableNoAnimation()
        if Lock.animConn then
            Lock.animConn:Disconnect()
            Lock.animConn = nil
        end
    end
    task.spawn(function()
        while task.wait(0.5) do
            if Lock.position then
                pcall(lockPosition)
            end
        end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        Lock.cframe = nil
        if Lock.position then
            lockPosition()
        end
        if Lock.noAnim then
            enableNoAnimation()
        end
    end)

    local AntiLag = {}
    function AntiLag.removeVisualEffects()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj:Destroy()
                n = n + 1
            end
        end
        WindUI:Notify({
            Title = "Anti-Lag",
            Content = "Removed " .. n .. " visual effects.",
            Duration = 3
        })
    end

    function AntiLag.removeAllTextures()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                for _, t in ipairs(obj:GetChildren()) do
                    if t:IsA("Texture") or t:IsA("Decal") then
                        t:Destroy()
                        n = n + 1
                    end
                end
                obj.Material = Enum.Material.Plastic
            end
        end
        WindUI:Notify({
            Title = "Anti-Lag",
            Content = "Removed textures from " .. n .. " objects.",
            Duration = 3
        })
    end

    function AntiLag.simplifyMeshes()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("MeshPart") then
                local np = Instance.new("Part")
                np.Name = obj.Name
                np.Size = obj.Size
                np.Position = obj.Position
                np.Orientation = obj.Orientation
                np.Anchored = obj.Anchored
                np.CanCollide = obj.CanCollide
                np.Transparency = obj.Transparency
                np.Material = Enum.Material.Plastic
                np.Color = Color3.new(0.5, 0.5, 0.5)
                np.Parent = obj.Parent
                obj:Destroy()
                n = n + 1
            elseif obj:IsA("SpecialMesh") then
                obj:Destroy()
                n = n + 1
            end
        end
        WindUI:Notify({
            Title = "Anti-Lag",
            Content = "Simplified " .. n .. " mesh objects.",
            Duration = 3
        })
    end

    function AntiLag.optimizeLighting()
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
                e.Enabled = false
            end
        end
        WindUI:Notify({
            Title = "Anti-Lag",
            Content = "Lighting optimized.",
            Duration = 3
        })
    end

    function AntiLag.restoreLighting()
        Lighting.GlobalShadows = true
        Lighting.ShadowSoftness = 0.5
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
                e.Enabled = true
            end
        end
        WindUI:Notify({
            Title = "Anti-Lag",
            Content = "Lighting restored.",
            Duration = 3
        })
    end

    function AntiLag.removeAllSounds()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Sound") then
                obj:Destroy()
                n = n + 1
            end
        end
        WindUI:Notify({
            Title = "Anti-Lag",
            Content = "Removed " .. n .. " sounds.",
            Duration = 3
        })
    end

    local AS = {
        active = false,
        groupId = 35102746,
        conn = nil
    }
    function AS.isStaff(plr)
        if plr == LocalPlayer then
            return false
        end
        local ok, rank = pcall(function()
            return plr:GetRankInGroup(AS.groupId)
        end)
        if ok and rank > 0 then
            local ok2, role = pcall(function()
                return plr:GetRoleInGroup(AS.groupId)
            end)
            if ok2 and role then
                local r = role:lower()
                if r:find("moderator") or r:find("staff") or r:find("dev") or r:find("admin") or rank >= 50 then
                    return true, role .. " (Rank: " .. rank .. ")"
                end
            end
        end
        return false
    end

    function AS.leaveServer()
        WindUI:Notify({
            Title = "LEAVING SERVER",
            Content = "Staff detected!",
            Duration = 2
        })
        task.wait(2)
        TeleportService:Teleport(game.PlaceId)
    end

    function AS.toggleAntiStaff(enabled)
        AS.active = enabled
        if AS.conn then
            AS.conn:Disconnect()
            AS.conn = nil
        end
        if enabled then
            task.spawn(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    local isS, role = AS.isStaff(plr)
                    if isS then
                        WindUI:Notify({
                            Title = "STAFF DETECTED",
                            Content = plr.Name .. " (" .. role .. ")",
                            Duration = 2
                        })
                        AS.leaveServer()
                        return
                    end
                end
            end)
            AS.conn = Players.PlayerAdded:Connect(function(plr)
                task.wait(2)
                if AS.active then
                    local isS, role = AS.isStaff(plr)
                    if isS then
                        WindUI:Notify({
                            Title = "STAFF JOINED",
                            Content = plr.Name .. " (" .. role .. ")",
                            Duration = 2
                        })
                        AS.leaveServer()
                    end
                end
            end)
            WindUI:Notify({
                Title = "Anti-Staff",
                Content = "Protection activated",
                Duration = 2
            })
        else
            WindUI:Notify({
                Title = "Anti-Staff",
                Content = "Protection deactivated",
                Duration = 2
            })
        end
    end

    do
        local PlayerTab = MainCore:Tab({
            Title = "Movements",
            Icon = "solar:user-circle-bold",
            IconColor = Color3.fromRGB(255, 255, 255),

        })
        local MovementSection = PlayerTab:Section({
            Title = "Movement",
            Icon = "solar:ufo-3-bold",
            Box = true,
            BoxBorder = true,
            Opened = false,
        })
        MovementSection:Toggle({
            Title = "Fly Mode",
            Default = false,
            Callback = function(v)
                MV.flying = v
                if v then
                    startFlight(LocalPlayer.Character)
                else
                    stopFlight()
                end
            end,
        })
        MovementSection:Input({
            Title = "Fly Speed",
            Desc = "Flight speed (10-200)",
            Value = tostring(MV.flySpeed),
            Placeholder = "Enter value (10-200)",
            Callback = function(input)
                local n = tonumber(input)
                if n and n >= 10 and n <= 200 then
                    MV.flySpeed = n
                end
            end,
        })
        MovementSection:Toggle({
            Title = "Noclip",
            Default = false,
            Callback = function(v)
                MV.noclipEnabled = v
                if v then
                    enableNoclip()
                    WindUI:Notify({
                        Title = "Noclip",
                        Content = "Enabled",
                        Duration = 2
                    })
                else
                    disableNoclip()
                    WindUI:Notify({
                        Title = "Noclip",
                        Content = "Disabled",
                        Duration = 2
                    })
                end
            end,
        })
        local jumpConn_MV
        MovementSection:Toggle({
            Title = "Infinite Jump",
            Default = false,
            Callback = function(v)
                MV.infJumpEnabled = v
                if jumpConn_MV then
                    jumpConn_MV:Disconnect()
                    jumpConn_MV = nil
                end
                if v then
                    jumpConn_MV = UserInputService.JumpRequest:Connect(function()
                        if MV.infJumpEnabled and LocalPlayer.Character then
                            local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if h then
                                h:ChangeState(Enum.HumanoidStateType.Jumping)
                            end
                        end
                    end)
                end
            end,
        })
        MovementSection:Input({
            Title = "WalkSpeed",
            Desc = "Walk speed (10-100)",
            Value = tostring(MV.CurrentWalkSpeed),
            Placeholder = "Enter value",
            Callback = function(input)
                local n = tonumber(input)
                if n and n >= 10 and n <= 100 then
                    MV.CurrentWalkSpeed = math.floor(n)
                    if MV.PermanentSpeed and LocalPlayer.Character then
                        local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if h then
                            h.WalkSpeed = MV.CurrentWalkSpeed
                        end
                    end
                end
            end,
        })
        MovementSection:Toggle({
            Title = "Permanent Speed",
            Default = false,
            Callback = function(v)
                MV.PermanentSpeed = v
                local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    h.WalkSpeed = v and MV.CurrentWalkSpeed or 16
                end
            end,
        })
        MovementSection:Input({
            Title = "JumpHeight",
            Desc = "Jump height (20-200)",
            Value = "50",
            Placeholder = "Enter value",
            Callback = function(input)
                local n = tonumber(input)
                if n and n >= 20 and n <= 200 then
                    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if h then
                        if h.UseJumpPower then
                            h.JumpPower = n
                        else
                            h.JumpHeight = n / 10
                        end
                    end
                end
            end,
        })
        MovementSection:Input({
            Title = "Field of View",
            Desc = "Camera FOV (60-120)",
            Value = "70",
            Placeholder = "Enter value",
            Callback = function(input)
                local n = tonumber(input)
                if n and n >= 60 and n <= 120 and Workspace.CurrentCamera then
                    Workspace.CurrentCamera.FieldOfView = n
                end
            end,
        })
        MovementSection:Button({
            Title = "Reset Default",
            Callback = function()
                local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    h.WalkSpeed = 16
                    if h.UseJumpPower then
                        h.JumpPower = 50
                    else
                        h.JumpHeight = 5
                    end
                end
                if Workspace.CurrentCamera then
                    Workspace.CurrentCamera.FieldOfView = 70
                end
                WindUI:Notify({
                    Title = "Reset",
                    Content = "Values restored to default",
                    Duration = 2
                })
            end,
        })
        MovementSection:Toggle({
            Title = "Good Mode",
            Desc = "Locks WalkSpeed & Jump to default values (look legit)",
            Default = false,
            Callback = function(v)
                MV.goodMode = v
                if v then
                    if MV.PermanentSpeed then
                        MV.PermanentSpeed = false
                        WindUI:Notify({ Title = "Good Mode", Content = "Turned off Permanent Speed", Duration = 2 })
                    end
                    enableGoodMode()
                    WindUI:Notify({ Title = "Good Mode", Content = "ON — speed & jump locked to default", Duration = 3 })
                else
                    disableGoodMode()
                    WindUI:Notify({ Title = "Good Mode", Content = "OFF", Duration = 2 })
                end
            end,
        })
        MovementSection:Toggle({
            Title = "Walk On Water",
            Desc = "Float on top of water instead of sinking",
            Default = false,
            Callback = function(v)
                MV.walkOnWater = v
                if v then
                    enableWalkOnWater()
                    WindUI:Notify({ Title = "Walk On Water", Content = "Enabled", Duration = 2 })
                else
                    disableWalkOnWater()
                    WindUI:Notify({ Title = "Walk On Water", Content = "Disabled", Duration = 2 })
                end
            end,
        })
        PlayerTab:Space({
            Columns = 0.5
        })
        local AnimeSection = PlayerTab:Section({
            Title = "Animations",
            Icon = "solar:stop-circle-bold",
            Box = true,
            BoxBorder = true,
            Opened = false,
        })
        AnimeSection:Toggle({
            Title = "Lock Position",
            Default = false,
            Callback = function(v)
                Lock.position = v
                if v then
                    Lock.cframe = nil
                else
                    unlockPosition()
                end
            end,
        })
        AnimeSection:Toggle({
            Title = "Disable Animation",
            Default = false,
            Callback = function(v)
                Lock.noAnim = v
                if v then
                    enableNoAnimation()
                else
                    disableNoAnimation()
                end
            end,
        })
        PlayerTab:Space({
            Columns = 0.5
        })
        local BypassSection = PlayerTab:Section({
            Title = "Movement Bypass",
            Icon = "solar:info-square-bold",
            Box = true,
            BoxBorder = true,
            Opened = false,
        })
        BypassSection:Toggle({
            Title = "TP Walk",
            Default = false,
            Callback = function(v)
                MV.isTpWalkEnabled = v
                if v then
                    startTpWalk()
                elseif tpWalkConn_MV then
                    tpWalkConn_MV:Disconnect()
                    tpWalkConn_MV = nil
                end
            end,
        })
        BypassSection:Slider({
            Title = "TP Walk Multiplier",
            Step = 1,
            Value = {
                Min = 1,
                Max = 50,
                Default = MV.tpWalkSpeed
            },
            Callback = function(v)
                MV.tpWalkSpeed = v
            end,
        })
    end

    local _toggleAntiAFK
    local _toggleAutoReconnect
    local _toggleAutoRejoinKick
    local antiAFK = _cfg.antiAfk or false
    local afkConn = nil
    local autoReconnect = _cfg.autoReconnect or false
    local autoRejoinOnKick = _cfg.autoRejoinKick or false
    do
        local MiscTab = MainCore:Tab({
            Title = "Utilities",
            Icon = "solar:settings-bold",
            IconColor = Color3.fromRGB(255, 255, 255),

        })
        local ConnectionSection = MiscTab:Section({
            Title = "Connection Features",
            Icon = "solar:login-2-bold",
            Box = true,
            Opened = false,
        })
        _toggleAntiAFK = ConnectionSection:Toggle({
            Flag = "antiAfk",
            Title = "Anti AFK",
            Default = _cfg.antiAfk or false,
            Callback = function(v)
                antiAFK = v
                _cfg.antiAfk = v
                _saveCfg()
                if v then
                    local VI_User = game:GetService("VirtualUser")
                    afkConn = LocalPlayer.Idled:Connect(function()
                        if antiAFK then
                            VI_User:CaptureController()
                            VI_User:ClickButton2(Vector2.new())
                        end
                    end)
                    WindUI:Notify({
                        Title = "Player",
                        Content = "Anti AFK enabled",
                        Duration = 2
                    })
                else
                    if afkConn then
                        afkConn:Disconnect()
                        afkConn = nil
                    end
                    WindUI:Notify({
                        Title = "Player",
                        Content = "Anti AFK disabled",
                        Duration = 2
                    })
                end
            end,
        })
        _toggleAutoReconnect = ConnectionSection:Toggle({
            Flag = "autoReconnect",
            Title = "Auto Reconnect",
            Default = _cfg.autoReconnect or false,
            Callback = function(v)
                autoReconnect = v
                _cfg.autoReconnect = v
                _saveCfg()
                WindUI:Notify({
                    Title = "Player",
                    Content = v and "Auto Reconnect enabled" or "Auto Reconnect disabled",
                    Duration = 2,
                })
            end,
        })
        task.spawn(function()
            local prompt = game.CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
            prompt.ChildAdded:Connect(function()
                if autoReconnect then
                    task.wait(2)
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    end)
                end
            end)
        end)

        _toggleAutoRejoinKick = ConnectionSection:Toggle({
            Flag     = "autoRejoinKick",
            Title    = "Auto Rejoin on Kick",
            Desc     = "Rejoin when kicked by server (not crash)",
            Default  = _cfg.autoRejoinKick or false,
            Callback = function(v)
                autoRejoinOnKick = v
                _cfg.autoRejoinKick = v
                _saveCfg()
                WindUI:Notify({
                    Title    = "Auto Rejoin",
                    Content  = v and "Will rejoin if kicked" or "Disabled",
                    Duration = 2,
                })
            end,
        })
        task.spawn(function()
            local kicked = false
            LocalPlayer.OnTeleport:Connect(function(state)
                if state == Enum.TeleportState.Started then
                    kicked = true
                end
            end)
            game.Close:Connect(function()
                if not autoRejoinOnKick then return end
                if kicked then return end
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
            end)
            pcall(function()
                local prompt = game.CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
                prompt.ChildAdded:Connect(function()
                    if not autoRejoinOnKick then return end
                    task.wait(2)
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    end)
                end)
            end)
        end)

        local instantInteract = false
        local _instantInteractConn = nil
        local function applyInstantInteract()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then
                    v.HoldDuration = 0
                end
            end
        end
        ConnectionSection:Toggle({
            Title = "Instant Interact",
            Default = false,
            Callback = function(v)
                instantInteract = v
                if v then
                    applyInstantInteract()
                    _instantInteractConn = workspace.DescendantAdded:Connect(function(d)
                        if instantInteract and d:IsA("ProximityPrompt") then
                            d.HoldDuration = 0
                        end
                    end)
                    WindUI:Notify({
                        Title = "Instant Interact",
                        Content = "Enabled",
                        Duration = 2
                    })
                else
                    if _instantInteractConn then
                        _instantInteractConn:Disconnect()
                        _instantInteractConn = nil
                    end
                    WindUI:Notify({
                        Title = "Instant Interact",
                        Content = "Disabled",
                        Duration = 2
                    })
                end
            end,
        })
        MiscTab:Space({
            Columns = 0.5
        })
        local ServerSection = MiscTab:Section({
            Title = "Server Features",
            Icon = "solar:slider-vertical-bold",
            Box = true,
            Opened = false,
        })
        local targetServerId = ""
        ServerSection:Button({
            Title = "Copy Server ID",
            Callback = function()
                local jobId = game.JobId
                setclipboard(jobId)
                WindUI:Notify({
                    Title = "Server ID",
                    Content = "Copied: " .. jobId,
                    Duration = 3
                })
            end,
        })
        ServerSection:Input({
            Title = "Server ID",
            Placeholder = "Paste Server ID...",
            Callback = function(v)
                targetServerId = v
            end,
        })
        ServerSection:Button({
            Title = "Join Server ID",
            Callback = function()
                if targetServerId == "" then
                    WindUI:Notify({
                        Title = "Join Server",
                        Content = "Input Server ID first",
                        Duration = 2
                    })
                    return
                end
                task.spawn(function()
                    WindUI:Notify({
                        Title = "Join Server",
                        Content = "Joining...",
                        Duration = 3
                    })
                    task.wait(1)
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServerId, LocalPlayer)
                    end)
                end)
            end,
        })
        ServerSection:Button({
            Title = "Server Hop",
            Callback = function()
                task.spawn(function()
                    WindUI:Notify({
                        Title = "Server Hop",
                        Content = "Finding new server...",
                        Duration = 3
                    })
                    local HS = game:GetService("HttpService")
                    local currentJob = game.JobId
                    local ok, result = pcall(function()
                        local response = game:HttpGet("https://games.roblox.com/v1/games/" ..
                            game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
                        return HS:JSONDecode(response)
                    end)
                    if not ok or type(result) ~= "table" or not result.data then
                        WindUI:Notify({
                            Title = "Server Hop",
                            Content = "Failed to fetch servers",
                            Duration = 3
                        })
                        return
                    end
                    for _, server in ipairs(result.data) do
                        if server.id ~= currentJob and server.playing and server.maxPlayers and server.playing < server.maxPlayers then
                            pcall(function()
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                            end)
                            return
                        end
                    end
                    WindUI:Notify({
                        Title = "Server Hop",
                        Content = "No available server found",
                        Duration = 3
                    })
                end)
            end,
        })
        ServerSection:Button({
            Title = "Rejoin Server",
            Callback = function()
                task.spawn(function()
                    WindUI:Notify({
                        Title = "Rejoin",
                        Content = "Attempting to rejoin...",
                        Duration = 3
                    })
                    task.wait(1)
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    end)
                end)
            end,
        })
        MiscTab:Space({
            Columns = 0.5
        })
        local AntiStaffSection = MiscTab:Section({
            Title = "Safety Features",
            Icon = "solar:shield-warning-bold",
            Box = true,
            BoxBorder = true,
            Opened = false,
        })
        AntiStaffSection:Toggle({
            Title = "Anti-Staff Protection",
            Desc = "Leave server when staff detected",
            Default = false,
            Callback = function(v)
                AS.toggleAntiStaff(v)
            end,
        })
        local fakeUsername = "Anonymous"
        local _realName = LocalPlayer.Name
        local _realDisplay = LocalPlayer.DisplayName
        local _realId = tostring(LocalPlayer.UserId)
        AntiStaffSection:Input({
            Title = "Fake Username",
            Placeholder = "Anonymous",
            Callback = function(v)
                if v and # v > 0 then
                    fakeUsername = v
                end
            end,
        })
        AntiStaffSection:Button({
            Title = "Hide Username",
            Icon = "solar:shield-check-bold",
            Color = Color3.fromHex("#6b31ff"),
            Callback = function()
                local function processtext(text)
                    if not text then
                        return ""
                    end
                    text = string.gsub(text, _realName, fakeUsername)
                    text = string.gsub(text, _realDisplay, fakeUsername)
                    text = string.gsub(text, _realId, "0")
                    return text
                end
                WindUI:Notify({
                    Title = "Username Hider",
                    Content = "Hidden as: " .. fakeUsername,
                    Duration = 3
                })
                pcall(function()
                    LocalPlayer.DisplayName = fakeUsername
                end)
                pcall(function()
                    LocalPlayer.CharacterAppearanceId = 13886182
                end)
                game.DescendantAdded:Connect(function(d)
                    if d:IsA("TextLabel") or d:IsA("TextBox") or d:IsA("TextButton") then
                        pcall(function()
                            d.Text = processtext(d.Text)
                            d.Name = processtext(d.Name)
                            d.Changed:Connect(function()
                                pcall(function()
                                    d.Text = processtext(d.Text)
                                    d.Name = processtext(d.Name)
                                end)
                            end)
                        end)
                    end
                end)
                task.spawn(function()
                    for i, v in ipairs(game:GetDescendants()) do
                        if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
                            pcall(function()
                                v.Text = processtext(v.Text)
                                v.Name = processtext(v.Name)
                            end)
                        end
                        if i % 100 == 0 then
                            task.wait()
                        end
                    end
                end)
            end,
        })
        MiscTab:Space({
            Columns = 0.5
        })
        local AntiLagSection = MiscTab:Section({
            Title = "Antilag Features",
            Icon = "solar:wind-bold",
            Box = true,
            BoxBorder = true,
            Opened = false,
        })
        AntiLagSection:Toggle({
            Title = "Remove Visual Effects",
            Type = "Checkbox",
            Default = false,
            Callback = function(v)
                if v then
                    AntiLag.removeVisualEffects()
                end
            end,
        })
        AntiLagSection:Toggle({
            Title = "Remove Textures",
            Type = "Checkbox",
            Default = false,
            Callback = function(v)
                if v then
                    AntiLag.removeAllTextures()
                end
            end,
        })
        AntiLagSection:Toggle({
            Title = "Simplify Meshes",
            Type = "Checkbox",
            Default = false,
            Callback = function(v)
                if v then
                    AntiLag.simplifyMeshes()
                end
            end,
        })
        local _lightingInit = false
        AntiLagSection:Toggle({
            Title = "Optimize Lighting",
            Type = "Checkbox",
            Default = false,
            Callback = function(v)
                if not _lightingInit then
                    _lightingInit = true
                    return
                end
                if v then
                    AntiLag.optimizeLighting()
                else
                    AntiLag.restoreLighting()
                end
            end,
        })
        AntiLagSection:Toggle({
            Title = "Remove Sounds",
            Type = "Checkbox",
            Default = false,
            Callback = function(v)
                if v then
                    AntiLag.removeAllSounds()
                end
            end,
        })

        MiscTab:Space({ Columns = 0.5 })
        local BoostSection = MiscTab:Section({
            Title  = "Performance Boost",
            Icon   = "solar:rocket-bold",
            Box    = true,
            BoxBorder = true,
            Opened = false,
        })
        BoostSection:Toggle({
            Title = "Light Boost",
            Desc  = "Disable particles / trails / beams",
            Default = false,
            Callback = function(on)
                state.lightBoost = on
                if on then
                    lightBoostObjects = {}
                    for _, v in ipairs(Workspace:GetDescendants()) do
                        if v:IsA("ParticleEmitter")
                            or v:IsA("Trail")
                            or v:IsA("Beam")
                            or v:IsA("Smoke")
                            or v:IsA("Fire")
                            or v:IsA("Sparkles")
                            or v:IsA("Highlight")
                        then
                            table.insert(lightBoostObjects, { obj = v, prop = "Enabled", old = v.Enabled })
                            pcall(function()
                                v.Enabled = false
                            end)
                        end
                    end
                    WindUI:Notify({ Title = "Misc", Content = "Light Boost ON", Duration = 2 })
                else
                    for _, entry in ipairs(lightBoostObjects) do
                        pcall(function()
                            entry.obj[entry.prop] = entry.old
                        end)
                    end
                    lightBoostObjects = {}
                    WindUI:Notify({ Title = "Misc", Content = "Light Boost OFF", Duration = 2 })
                end
            end,
        })
        BoostSection:Toggle({
            Title = "Full FPS Boost",
            Desc  = "Shadows off, terrain/water cheap, quality low",
            Default = false,
            Callback = function(on)
                state.fpsBoost = on
                if on then
                    fpsBoostObjects = {}
                    pcall(function()
                        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                    end)
                    pcall(function()
                        Lighting.GlobalShadows = false
                        Lighting.FogEnd = 9e9
                        Lighting.Brightness = 1
                    end)
                    local terrain = Workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        pcall(function()
                            terrain.WaterWaveSize = 0
                            terrain.WaterWaveSpeed = 0
                            terrain.WaterReflectance = 0
                            terrain.WaterTransparency = 1
                        end)
                    end
                    for _, v in ipairs(Workspace:GetDescendants()) do
                        if v:IsA("BasePart") then
                            table.insert(fpsBoostObjects, { obj = v, prop = "CastShadow", old = v.CastShadow })
                            pcall(function()
                                v.CastShadow = false
                            end)
                        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                            table.insert(fpsBoostObjects, { obj = v, prop = "Enabled", old = v.Enabled })
                            pcall(function()
                                v.Enabled = false
                            end)
                        end
                    end
                    WindUI:Notify({ Title = "Misc", Content = "FPS Boost ON", Duration = 2 })
                else
                    for _, entry in ipairs(fpsBoostObjects) do
                        pcall(function()
                            entry.obj[entry.prop] = entry.old
                        end)
                    end
                    fpsBoostObjects = {}
                    pcall(function()
                        settings().Rendering.QualityLevel = Enum.QualityLevel.Level10
                    end)
                    WindUI:Notify({ Title = "Misc", Content = "FPS Boost OFF", Duration = 2 })
                end
            end,
        })
        BoostSection:Toggle({
            Title = "Black Screen",
            Desc  = "Black screen and disable 3D render",
            Default = false,
            Callback = function(on)
                state.blackScreen = on
                if on then
                    if not blackScreenGui then
                        blackScreenGui = Instance.new("ScreenGui")
                        blackScreenGui.Name = "FAMBlackScreen"
                        blackScreenGui.IgnoreGuiInset = true
                        blackScreenGui.DisplayOrder = 2147483646
                        blackScreenGui.ResetOnSpawn = false
                        local frame = Instance.new("Frame")
                        frame.Size = UDim2.fromScale(1, 1)
                        frame.BackgroundColor3 = Color3.new(0, 0, 0)
                        frame.BorderSizePixel = 0
                        frame.Parent = blackScreenGui
                        pcall(function()
                            blackScreenGui.Parent = game:GetService("CoreGui")
                        end)
                        if not blackScreenGui.Parent then
                            blackScreenGui.Parent = PlayerGui
                        end
                    end
                    pcall(function()
                        RunService:Set3dRenderingEnabled(false)
                    end)
                else
                    if blackScreenGui then
                        blackScreenGui:Destroy()
                        blackScreenGui = nil
                    end
                    pcall(function()
                        RunService:Set3dRenderingEnabled(true)
                    end)
                end
            end,
        })

        MiscTab:Space({ Columns = 0.5 })
        local PingSection  = MiscTab:Section({
            Title  = "Ping Display",
            Icon   = "solar:chart-bold",
            Box    = true,
            Opened = false,
        })

        local _pingGui     = nil
        local _pingConn    = nil
        local _pingEnabled = false

        local function createPingGui()
            if _pingGui then
                pcall(function() _pingGui:Destroy() end)
            end
            local sg                                     = Instance.new("ScreenGui")
            sg.Name                                      = "KAL_PingDisplay"
            sg.ResetOnSpawn                              = false
            sg.DisplayOrder                              = 9998
            sg.ZIndexBehavior                            = Enum.ZIndexBehavior.Sibling
            sg.Parent                                    = PlayerGui

            local frame                                  = Instance.new("Frame")
            frame.Size                                   = UDim2.fromOffset(130, 54)
            frame.Position                               = UDim2.new(0, 12, 0, 12)
            frame.BackgroundColor3                       = Color3.fromRGB(15, 15, 18)
            frame.BackgroundTransparency                 = 0.25
            frame.BorderSizePixel                        = 0
            frame.ZIndex                                 = 9998
            frame.Parent                                 = sg
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
            local stroke                                 = Instance.new("UIStroke", frame)
            stroke.Color                                 = Color3.fromRGB(70, 70, 80)
            stroke.Thickness                             = 1

            local function makeRow(yOffset)
                local dot                                  = Instance.new("Frame")
                dot.Size                                   = UDim2.fromOffset(8, 8)
                dot.Position                               = UDim2.new(0, 10, 0, yOffset + 6)
                dot.BackgroundColor3                       = Color3.fromRGB(80, 220, 100)
                dot.BorderSizePixel                        = 0
                dot.ZIndex                                 = 9999
                dot.Parent                                 = frame
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

                local lbl                                  = Instance.new("TextLabel")
                lbl.Size                                   = UDim2.new(1, -28, 0, 20)
                lbl.Position                               = UDim2.new(0, 26, 0, yOffset + 2)
                lbl.BackgroundTransparency                 = 1
                lbl.Font                                   = Enum.Font.GothamBold
                lbl.TextSize                               = 12
                lbl.TextColor3                             = Color3.fromRGB(220, 220, 220)
                lbl.TextXAlignment                         = Enum.TextXAlignment.Left
                lbl.Text                                   = "--"
                lbl.ZIndex                                 = 9999
                lbl.Parent                                 = frame
                return dot, lbl
            end

            local divider            = Instance.new("Frame")
            divider.Size             = UDim2.new(1, -16, 0, 1)
            divider.Position         = UDim2.new(0, 8, 0, 27)
            divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            divider.BorderSizePixel  = 0
            divider.ZIndex           = 9999
            divider.Parent           = frame

            local pingDot, pingLabel = makeRow(4)
            local fpsDot, fpsLabel   = makeRow(29)

            pingLabel.Text           = "-- ms"
            fpsLabel.Text            = "-- fps"

            _pingGui                 = sg

            local _fpsLastTime       = tick()
            local _fpsFrameCount     = 0
            local _fpsConn           = RunService.RenderStepped:Connect(function()
                _fpsFrameCount = _fpsFrameCount + 1
            end)

            _pingConn                = task.spawn(function()
                while _pingEnabled and sg and sg.Parent do
                    task.wait(1)

                    local ms = math.round(LocalPlayer:GetNetworkPing() * 1000)
                    local pingColor
                    if ms < 80 then
                        pingColor = Color3.fromRGB(80, 220, 100)
                    elseif ms < 150 then
                        pingColor = Color3.fromRGB(240, 200, 60)
                    else
                        pingColor = Color3.fromRGB(230, 80, 80)
                    end
                    pingDot.BackgroundColor3 = pingColor
                    pingLabel.TextColor3     = pingColor
                    pingLabel.Text           = ms .. " ms"

                    local now                = tick()
                    local elapsed            = now - _fpsLastTime
                    local fps                = elapsed > 0 and math.round(_fpsFrameCount / elapsed) or 0
                    _fpsLastTime             = now
                    _fpsFrameCount           = 0

                    local fpsColor
                    if fps >= 55 then
                        fpsColor = Color3.fromRGB(80, 220, 100)
                    elseif fps >= 30 then
                        fpsColor = Color3.fromRGB(240, 200, 60)
                    else
                        fpsColor = Color3.fromRGB(230, 80, 80)
                    end
                    fpsDot.BackgroundColor3 = fpsColor
                    fpsLabel.TextColor3     = fpsColor
                    fpsLabel.Text           = fps .. " fps"
                end
                _fpsConn:Disconnect()
            end)
        end

        local function destroyPingGui()
            _pingEnabled = false
            if _pingGui then
                pcall(function() _pingGui:Destroy() end)
                _pingGui = nil
            end
        end

        PingSection:Toggle({
            Title    = "Show Ping",
            Default  = false,
            Callback = function(v)
                _pingEnabled = v
                if v then
                    createPingGui()
                    WindUI:Notify({ Title = "Ping Display", Content = "Enabled", Duration = 2 })
                else
                    destroyPingGui()
                    WindUI:Notify({ Title = "Ping Display", Content = "Disabled", Duration = 2 })
                end
            end,
        })
    end

    _uiReady = true

    task.defer(function()
        if _cfg.antiAfk        and _toggleAntiAFK        then _toggleAntiAFK:Set(true)        end
        if _cfg.autoReconnect  and _toggleAutoReconnect  then _toggleAutoReconnect:Set(true)  end
        if _cfg.autoRejoinKick and _toggleAutoRejoinKick then _toggleAutoRejoinKick:Set(true) end
    end)
end
