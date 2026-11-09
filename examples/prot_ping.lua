local router = include("prot/router.lua")
local route = "example.ping"

if SERVER then
    AddCSLuaFile()
    router.Receive(route, function(bits, ply)
        if bits ~= 16 or not IsValid(ply) then return end

        local now = RealTime()
        if now < (ply.ProtPingNext or 0) then return end
        ply.ProtPingNext = now + 1

        local nonce = net.ReadUInt(16)
        if router.Start(route) then
            net.WriteUInt(nonce, 16)
            net.Send(ply)
        end
    end)
else
    router.Receive(route, function(bits)
        if bits ~= 16 then return end
        print("[prot] pong", net.ReadUInt(16), router.Name(route))
    end)

    concommand.Add("prot_ping", function()
        local ok, err = router.Start(route)
        if not ok then
            print(err)
            return
        end

        net.WriteUInt(1234, 16)
        net.SendToServer()
    end)
end
