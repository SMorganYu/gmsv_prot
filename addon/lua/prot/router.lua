if SERVER then
    AddCSLuaFile("prot/router.lua")
end

if ProtNet then return ProtNet end

local router = {}
local bootstrap = "prot_bootstrap_v1"
local syncTimer = "prot.bootstrap.v1"
local seed
local aliases = {}

local function routeName(name)
    assert(type(name) == "string" and #name <= 64 and name:match("^[A-Za-z0-9_.%-]+$"),
        "prot: expected a route name of 1–64 ASCII letters, digits, dots, underscores or hyphens")
    return name:lower()
end

local function wireName(name)
    if not aliases[name] then
        aliases[name] = "prot_" .. util.SHA256(seed .. ":" .. name):sub(1, 32):lower()
    end
    return aliases[name]
end

function router.Name(name)
    name = routeName(name)
    if seed then return wireName(name) end
end

function router.Start(name, unreliable)
    local alias = router.Name(name)
    if not alias or util.NetworkStringToID(alias) == 0 then
        return nil, "prot: route unavailable"
    end

    net.Start(alias, unreliable)
    return true
end

if SERVER then
    if not ProtNative then require("prot") end
    seed = assert(ProtNative.Seed())
    assert((util.AddNetworkString(bootstrap) or 0) > 0, "prot: could not pool bootstrap channel")

    local registered = {}
    local routeCount = 0
    local clients = {}

    function router.Register(name)
        name = routeName(name)
        if registered[name] then return registered[name] end

        assert(routeCount < 256, "prot: 256 route limit reached")
        local alias = wireName(name)
        assert((util.AddNetworkString(alias) or 0) > 0, "prot: could not pool " .. name)
        registered[name] = alias
        routeCount = routeCount + 1
        return alias
    end

    function router.Ready(ply)
        local client = clients[ply]
        return client ~= nil and client.ready == true
    end

    function router.Receive(name, callback)
        assert(type(callback) == "function", "prot: expected a receiver function")
        net.Receive(router.Register(name), function(bits, ply)
            if router.Ready(ply) then callback(bits, ply) end
        end)
    end

    net.Receive(bootstrap, function(bits, ply)
        if bits ~= 8 or not IsValid(ply) then return end

        local opcode = net.ReadUInt(8)
        local client = clients[ply]
        if opcode == 1 then
            if client and not client.ready then
                client.ready = true
                hook.Run("ProtNetReady", ply)
            end
            return
        end
        if opcode ~= 0 then return end

        local now = RealTime()
        if client and now < client.nextRequest then return end
        client = client or {}
        client.nextRequest = now + 1
        clients[ply] = client

        net.Start(bootstrap)
        net.WriteData(seed, #seed)
        net.Send(ply)
    end)

    hook.Add("PlayerDisconnected", syncTimer, function(ply)
        clients[ply] = nil
    end)
else
    local receivers = {}

    function router.Ready()
        return seed ~= nil
    end

    function router.Receive(name, callback)
        name = routeName(name)
        assert(type(callback) == "function", "prot: expected a receiver function")
        receivers[name] = callback
        if seed then net.Receive(wireName(name), callback) end
    end

    net.Receive(bootstrap, function(bits)
        if seed or bits ~= 256 then return end
        local value = net.ReadData(32)
        if not value or #value ~= 32 or not value:match("^[0-9a-f]+$") then return end

        seed = value
        for name, callback in pairs(receivers) do
            net.Receive(wireName(name), callback)
        end

        timer.Remove(syncTimer)
        net.Start(bootstrap)
        net.WriteUInt(1, 8)
        net.SendToServer()
        hook.Run("ProtNetReady")
    end)

    local function requestSeed()
        if seed or not IsValid(LocalPlayer()) or util.NetworkStringToID(bootstrap) == 0 then return end
        net.Start(bootstrap)
        net.WriteUInt(0, 8)
        net.SendToServer()
    end

    timer.Create(syncTimer, 2, 0, requestSeed)
    hook.Add("InitPostEntity", syncTimer, requestSeed)
end

ProtNet = router
return router
