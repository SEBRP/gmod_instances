AddCSLuaFile("instancing/cl_instancing.lua")
if CLIENT then
    include("instancing/cl_instancing.lua")
else
    include("instancing/sv_instancing.lua")
end