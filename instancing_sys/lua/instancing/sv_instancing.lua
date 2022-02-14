local entmeta = FindMetaTable("Entity")
local plymeta = FindMetaTable("Player")
util.AddNetworkString("Yolo.Instancing")

blacklist = {
"func",
"info",
"env",
"worldspawn,soundent",
"player_manager",
"gmod_gamerules",
"scene_manager",
"info_teleport_destination",
"trigger_teleport",
"logic",
"hint",
"filter_activator_name"
}

function RecursiveSetPreventTransmit(ent, ply, stopTransmitting)
    if ent != ply and IsValid(ent) and IsValid(ply) then
        ent:SetPreventTransmit(ply, stopTransmitting)
        local tab = ent:GetChildren()
        for i = 1, #tab do
            RecursiveSetPreventTransmit(tab[ i ], ply, stopTransmitting)
        end
    end
end

function RecursiveSetInstance(ent, instance)
    if ent and IsValid(ent) then
        ent:SetInstanceInternal(instance)
        local childs = ent:GetChildren()
        for i = 1, #childs do
            RecursiveSetInstance(childs[ i ], instance)
        end
    end
end

function entmeta:SetInstance(instance)
    RecursiveSetInstance(self, instance)
end

function entmeta:SetInstanceInternal(instance)
    self:SetNWInt("Instance", instance)
    for _, ply in ipairs(player.GetAll()) do
        RecursiveSetPreventTransmit(self, ply, instance != ply:GetInstance())
    end
end

function entmeta:GetInstance()
    return self:GetNWInt("Instance", 1 )
end

function plymeta:SetInstanceInternal(instance)
    local allow = true
    self:SetNWInt("Instance", instance)
    -- remove us from all other players who are not in our Instance
    for _, ply in ipairs(player.GetAll()) do
        RecursiveSetPreventTransmit(self, ply, instance != ply:GetInstance())
    end
    -- stopp networking all entities who are not in our Instance
    for _, ent in ipairs(ents.GetAll()) do
        allow = true
        if (ent:CreatedByMap()) then
            allow = false
        end
        for k,v in ipairs(blacklist) do
            if (string.find(ent:GetClass(),v)) then
                allow=false
            end
        end
        if (allow) then
            RecursiveSetPreventTransmit(ent, self, instance != ent:GetInstance())
        end
    end
end

for _, ent in ipairs(ents.GetAll()) do
    ent:SetCustomCollisionCheck(true)
end
hook.Add( "OnEntityCreated", "Enable Collision Check", function( ent )
    ent:SetCustomCollisionCheck(true)
end )

hook.Add("PlayerInitialSpawn", "SetInstance", function(ply)
    ply:SetInstance(1)
end)

local a = {"PlayerSpawnedEffect", "PlayerSpawnedProp", "PlayerSpawnedRagdoll"}
for _, name in ipairs(a) do
    hook.Add(name, "Instancing_Spawning", function(ply, mdl, ent)
        ent:SetInstance(ply:GetInstance())
    end)
end

local b = {"PlayerSpawnedNPC", "PlayerSpawnedSENT", "PlayerSpawnedSWEP", "PlayerSpawnedVehicle"}
for _, name in ipairs(b) do
    hook.Add(name, "Instancing_Spawning", function(ply, ent)
        ent:SetInstance(ply:GetInstance())
    end)
end

local c = {"PhysgunPickup", "AllowPlayerPickup", "GravGunPickupAllowed", "PlayerCanPickupWeapon", "PlayerCanPickupItem", "PlayerCanHearPlayersVoice"}
for _, name in ipairs(c) do
    hook.Add(name, "Instancing_NoInterAction", function(ply, ent)
        if ply:GetInstance() != ent:GetInstance() then return false end
    end)
end

hook.Add("ShouldCollide", "Instancing_NoCollide", function(ent1, ent2)
    if ent1:GetInstance() != ent2:GetInstance() then
        if !ent1:IsWorld() and !ent2:IsWorld() then
            return false
        end
    end
end)

net.Receive("Yolo.Instancing", function(len, ply)
    ply:SetInstance(net.ReadInt(4) or 1)
end)