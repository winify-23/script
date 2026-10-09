--[[
    Server Library - Quản lý server Roblox
    Hỗ trợ: Rejoin, Hop, Join, Server Filtering, Server Browser, Private Server Join, Queue Skip

    Cách sử dụng:
        local Server = require(https://raw.githubusercontent.com/WiniFyCode/Roblox/refs/heads/main/libs/Server.lua)

        -- Rejoin (vào lại server hiện tại)
        Server.Rejoin()

        -- Hop (chuyển sang server mới) - tự động chọn server ít người
        Server.Hop()
        Server.Hop(true, {minPlayers = 2})  -- Ít nhất 2 người chơi
        Server.Hop(false, {maxPlayers = 10})  -- Nhiều nhất 10 người chơi

        -- Join server bằng PlaceId
        Server.Join(placeId)

        -- Join server bằng JobId (vào mời)
        Server.JoinByJobId(jobId)

        -- Lọc server theo điều kiện
        Server.FindServer({
            minPlayers = 2,
            maxPlayers = 10,
            maxAge = 300  -- Tối đa 300s tuổi server
        }, function(serverInfo)
            -- serverInfo chứa JobId, playersCount, age, ...
            print("Found:", serverInfo.JobId, serverInfo.playersCount)
        end)

        -- Server Browser - Tìm server có ping thấp nhất
        Server.BrowseLowPingServers(function(servers)
            -- servers là danh sách đã sắp xếp theo ping tăng dần
        end)

        -- Private Server Join - Vào server private bằng link mời
        Server.JoinPrivateServer("private-server-reservation-code")

        -- Queue Skip - Bỏ qua hàng đợi server
        Server.SkipQueue()  -- Cho server đang ở
--]]

local Server = {}

-- Services
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Job ID hiện tại
local currentJobId = game.JobId
local currentPlaceId = game.PlaceId
local LocalPlayer = Players.LocalPlayer

-- State variables
local hopFilters = nil
local findServerCallback = nil

local function normalizeServer(server)
    return {
        JobId = server.id or server.Id,
        PlayersCount = server.playing or server.PlayersCount or server.playersCount or 0,
        MaxPlayers = server.maxPlayers or server.MaxPlayers or 999,
        Age = server.age or server.Age or 0,
        Ping = server.ping or server.Ping or 0,
        ServerType = server.serverType or server.ServerType
    }
end

-- Rejoin - Vào lại server hiện tại
function Server.Rejoin()
    -- Thử dùng Teleport với job ID hiện tại
    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            currentPlaceId,
            currentJobId,
            LocalPlayer
        )
    end)

    if not success then
        -- Nếu thất bại, thử cách khác
        pcall(function()
            TeleportService:Teleport(currentPlaceId, LocalPlayer)
        end)
    end
end

-- Hop - Chuyển sang server mới
-- @param autoFilter: có tự động tìm server ít người không (mặc định true)
-- @param filters: {minPlayers, maxPlayers, maxAge} - bộ lọc server
function Server.Hop(autoFilter, filters)
    autoFilter = autoFilter ~= false        -- Mặc định true
    filters = filters or { maxPlayers = 5 } -- Mặc định tìm server ít người

    if autoFilter then
        -- Tìm server tốt trước khi chuyển
        Server.FindServer(filters, function(serverInfo)
            if serverInfo and serverInfo.JobId then
                Server.JoinByJobId(serverInfo.JobId)
            else
                -- Nếu không tìm thấy, chuyển ngẫu nhiên
                Server.Hop(false)
            end
        end)
    else
        -- Chuyển server ngẫu nhiên
        local success = pcall(function()
            TeleportService:Teleport(currentPlaceId, LocalPlayer)
        end)

        if not success then
            warn("Failed to hop server")
        end
    end
end

-- Join - Vào server bằng PlaceId
function Server.Join(placeId)
    local success = pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)

    if not success then
        warn("Failed to join place ID:", placeId)
    end
end

-- JoinByJobId - Vào server bằng JobId (dùng cho private server)
function Server.JoinByJobId(jobId)
    if not jobId or jobId == "" then
        warn("JobId không hợp lệ")
        return
    end

    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            currentPlaceId,
            jobId,
            LocalPlayer
        )
    end)

    if not success then
        warn("Failed to join job ID:", jobId)
    end
end

-- FindServer - Tìm server theo điều kiện lọc
-- @param filters: {minPlayers, maxPlayers, maxAge} - bộ lọc
-- @param callback: function(serverInfo) - callback khi tìm thấy
-- serverInfo = {JobId, playersCount, maxPlayers, age, ...}
function Server.FindServer(filters, callback)
    filters = filters or {}
    filters.minPlayers = filters.minPlayers or 0
    filters.maxPlayers = filters.maxPlayers or 999
    filters.maxAge = filters.maxAge or 999999

    local placeId = currentPlaceId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?placeId=" .. placeId

    spawn(function()
        local success, result = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if not success then
            warn("Failed to fetch server list")
            if callback then callback(nil) end
            return
        end

        local decoded = HttpService:JSONDecode(result)
        if not decoded or not decoded.data then
            if callback then callback(nil) end
            return
        end

        -- Lọc server theo điều kiện
        local bestServer = nil
        local bestPlayers = 999

        for _, rawServer in ipairs(decoded.data) do
            local server = normalizeServer(rawServer)

            -- Bỏ server đang ở
            if server.JobId == currentJobId then
                continue
            end

            -- Áp dụng bộ lọc
            local passMinPlayers = server.PlayersCount >= filters.minPlayers
            local passMaxPlayers = server.PlayersCount + 1 <= filters.maxPlayers -- +1 vì mình sẽ vào
            local passMaxAge = server.Age <= filters.maxAge

            if passMinPlayers and passMaxPlayers and passMaxAge then
                -- Chọn server có ít người nhất
                if server.PlayersCount < bestPlayers then
                    bestPlayers = server.PlayersCount
                    bestServer = server
                end
            end
        end

        -- Chuẩn bị server info cho callback
        if bestServer and callback then
            callback({
                JobId = bestServer.JobId,
                playersCount = bestServer.PlayersCount,
                maxPlayers = bestServer.MaxPlayers,
                age = bestServer.Age,
                ping = bestServer.Ping,
                serverType = bestServer.ServerType
            })
        else
            if callback then callback(nil) end
        end
    end)
end

-- GetServerStats - Lấy thống kê server hiện tại
function Server.GetServerStats()
    local servers = {}
    local url = "https://games.roblox.com/v1/games/" .. currentPlaceId .. "/servers/Public?placeId=" .. currentPlaceId

    local success, result = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if success then
        local decoded = HttpService:JSONDecode(result)
        if decoded and decoded.data then
            for _, server in ipairs(decoded.data) do
                table.insert(servers, normalizeServer(server))
            end
        end
    end

    return servers
end

-- Lấy danh sách server (shards) - cần HTTP enabled
function Server.GetServerList(placeId, callback)
    placeId = placeId or currentPlaceId

    spawn(function()
        -- Sử dụng API Roblox để lấy danh sách server
        -- Endpoint này trả về các shard đang hoạt động
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?placeId=" .. placeId

        local success, response = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if not success then
            warn("HTTP request failed - HTTP must be enabled")
            if callback then callback(nil) end
            return
        end

        local servers = HttpService:JSONDecode(response)
        if callback then
            callback(servers and servers.data or {})
        end
    end)
end

-- Thống kê server hiện tại
function Server.GetCurrentServerInfo()
    local stats = {
        JobId = currentJobId,
        PlaceId = currentPlaceId,
        PlayersCount = #Players:GetPlayers(),
        MaxPlayers = Players.MaxPlayers,
        ServerType = game.VIPServerId ~= "" and "VIP" or "Public",
        ServerName = game.VIPServerName or "Public Server"
    }
    return stats
end

-- GetServerStats - Lấy danh sách server khác (cho callback)
function Server.ListAllServers(callback)
    local url = "https://games.roblox.com/v1/games/" .. currentPlaceId .. "/servers/Public?placeId=" .. currentPlaceId

    spawn(function()
        local success, result = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if not success then
            if callback then callback(nil) end
            return
        end

        local decoded = HttpService:JSONDecode(result)
        if decoded and decoded.data then
            if callback then callback(decoded.data) end
        else
            if callback then callback(nil) end
        end
    end)
end

-- Server Browser - Tìm server có ping thấp nhất
-- @param callback: function(servers) - danh sách server đã sắp xếp theo ping
-- @param maxServers: số lượng server tối đa trả về (mặc định 50)
function Server.BrowseLowPingServers(callback, maxServers)
    maxServers = maxServers or 50
    local url = "https://games.roblox.com/v1/games/" ..
        currentPlaceId .. "/servers/Public?placeId=" .. currentPlaceId .. "&limit=" .. maxServers

    spawn(function()
        local success, result = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if not success then
            warn("Failed to browse servers")
            if callback then callback(nil) end
            return
        end

        local decoded = HttpService:JSONDecode(result)
        if not decoded or not decoded.data then
            if callback then callback(nil) end
            return
        end

        -- Lọc và sắp xếp server theo ping
        local validServers = {}
        for _, rawServer in ipairs(decoded.data) do
            local server = normalizeServer(rawServer)

            -- Bỏ server đang ở và server đầy
            if server.JobId ~= currentJobId and server.PlayersCount < server.MaxPlayers then
                table.insert(validServers, server)
            end
        end

        -- Sắp xếp theo ping tăng dần
        table.sort(validServers, function(a, b)
            return (a.Ping or 0) < (b.Ping or 0)
        end)

        if callback then callback(validServers) end
    end)
end

-- Private Server Join - Vào server private bằng reservation code
-- @param reservationCode: mã mời server private
function Server.JoinPrivateServer(reservationCode)
    if not reservationCode or reservationCode == "" then
        warn("Reservation code không hợp lệ")
        return false
    end

    local success = pcall(function()
        TeleportService:TeleportToPrivateServer(
            currentPlaceId,
            reservationCode,
            { LocalPlayer }
        )
    end)

    if not success then
        -- Thử như JobId nếu reservationCode thực ra là instance id
        success = pcall(function()
            TeleportService:TeleportToPlaceInstance(
                currentPlaceId,
                reservationCode,
                LocalPlayer
            )
        end)
    end

    return success
end

-- Queue Skip - Bỏ qua hàng đợi server đầy
-- Chuyển hướng đến server có chỗ trống nhất thay vì chờ hàng đợi
function Server.SkipQueue()
    -- Tìm server có chỗ trống
    Server.BrowseLowPingServers(function(servers)
        if servers and #servers > 0 then
            -- Chọn server đầu tiên (có ping thấp nhất và có chỗ trống)
            local bestServer = servers[1]
            Server.JoinByJobId(bestServer.JobId)
        else
            -- Nếu không có server nào, thử Teleport thường
            Server.Hop()
        end
    end, 10) -- Chỉ cần 10 server đầu tiên
end

-- Reconnect - Kết nối lại nhanh chóng
function Server.Reconnect()
    -- Đóng kết nối hiện tại và kết nối lại
    local placeId = currentPlaceId
    pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

return Server
