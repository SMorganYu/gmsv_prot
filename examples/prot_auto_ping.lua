if not ProtNet or not ProtNet.WireName then return end

local route = "example.auto_ping"

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(route)
    net.Receive(route, function(bits, ply)
        if bits ~= 16 or not IsValid(ply) then return end
        local now = RealTime()
        if now < (ply.ProtAutoPingNext or 0) then return end
        ply.ProtAutoPingNext = now + 1

        local nonce = net.ReadUInt(16)
        net.Start(route)
        net.WriteUInt(nonce, 16)
        net.Send(ply)
    end)
else
    net.Receive(route, function(bits)
        if bits ~= 16 then return end
        print("[prot] auto pong", net.ReadUInt(16), ProtNet.WireName(route))
    end)

    concommand.Add("prot_auto_ping", function()
        if not ProtNet.WireName(route) then
            print("prot: route unavailable")
            return
        end

        net.Start(route)
        net.WriteUInt(1234, 16)
        net.SendToServer()
    end)
end
