return function(router)
    if router.WireName then return end

    local start = net.Start
    local pool = util.AddNetworkString
    local idFor = util.NetworkStringToID
    local stringFor = util.NetworkIDToString
    local markerPrefix = "prot_seed_v1_"
    local wirePrefix = "prot_net_"
    local aliases, originals = {}, {}
    local preserved = {}
    local seed
    local nextID = 1

    local function hexSuffix(name, prefix)
        if #name == #prefix + 32 and name:sub(1, #prefix) == prefix then
            local suffix = name:sub(#prefix + 1)
            if suffix:match("^[a-f0-9]+$") then return suffix end
        end
    end

    local function canAlias(name)
        if type(name) ~= "string" or name == "" or name:find("\0", 1, true) then return false end
        local lower = name:lower()
        return not preserved[lower]
            and lower ~= "prot_bootstrap_v1"
            and not hexSuffix(lower, "prot_")
            and not hexSuffix(lower, wirePrefix)
            and not hexSuffix(lower, markerPrefix)
    end

    if SERVER then
        seed = assert(ProtNative.Seed())
        assert((pool(markerPrefix .. seed) or 0) > 0, "prot: could not pool seed marker")
    end

    local function getSeed()
        -- The marker is replicated in the same table and precedes the aliases.
        while not seed and nextID <= 4095 do
            local name = stringFor(nextID)
            if not name or name == "" then break end
            nextID = nextID + 1
            seed = hexSuffix(name, markerPrefix)
        end
        return seed
    end

    local function aliasFor(name)
        local lower = name:lower()
        local alias = aliases[lower]
        if not alias then
            alias = wirePrefix .. util.SHA256(seed .. ":" .. lower):sub(1, 32):lower()
            aliases[lower] = alias
        end
        return alias
    end

    local function pooledAlias(name)
        if not canAlias(name) or not getSeed() then return end
        local alias = aliasFor(name)
        local id = idFor(alias)
        if (id or 0) > 0 then
            originals[alias] = originals[alias] or name
            return alias, id
        end
    end

    if SERVER then
        function util.AddNetworkString(name, ...)
            local _, id = pooledAlias(name)
            if id then return id end
            if not canAlias(name) or (idFor(name) or 0) > 0 then
                return pool(name, ...)
            end

            local alias = aliasFor(name)
            id = pool(alias, ...)
            if (id or 0) > 0 then originals[alias] = name end
            return id
        end
    end

    function net.Start(name, ...)
        return start(pooledAlias(name) or name, ...)
    end

    function util.NetworkStringToID(name, ...)
        local _, id = pooledAlias(name)
        if id then return id end
        return idFor(name, ...)
    end

    function util.NetworkIDToString(id, ...)
        local name = stringFor(id, ...)
        if not name or not hexSuffix(name, wirePrefix) then return name end
        if originals[name] then return originals[name] end
        if SERVER or not getSeed() then return name end

        -- Keep callbacks at their logical keys, including direct net.Receivers writes.
        for logical in pairs(net.Receivers) do
            if canAlias(logical) and aliasFor(logical) == name then
                originals[name] = logical
                return logical
            end
        end
        return name
    end

    function router.WireName(name)
        local alias = pooledAlias(name)
        if alias then return alias end
        local id = idFor(name)
        if (id or 0) > 0 then return stringFor(id) end
    end

    -- GMod also uses the net string table to replicate player class and drive mode IDs.
    local function preserveNames(register)
        return function(name, ...)
            if type(name) == "string" then preserved[name:lower()] = true end
            return register(name, ...)
        end
    end

    player_manager.RegisterClass = preserveNames(player_manager.RegisterClass)
    drive.Register = preserveNames(drive.Register)
end
