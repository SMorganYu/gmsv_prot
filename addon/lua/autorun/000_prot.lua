-- Install before other addons capture the original net functions.
if ProtNet then return end

if SERVER then
    require("prot")
    assert(ProtNative.Install())
else
    include("prot/embedded_router.lua")
end
