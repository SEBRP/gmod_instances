INSTANCE = INSTANCE or {}
INSTANCE.instance_table = INSTANCE.instance_table or {}

util.AddNetworkString("Yolo.Instancing")

local entmeta = FindMetaTable("Entity")
local plymeta = FindMetaTable("Player")

local default_instance = 1

local blacklist = {
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
    instance_table[self] = instance
    for _, ply in ipairs(player.GetAll()) do
        RecursiveSetPreventTransmit(self, ply, instance != ply:GetInstance())
    end
end

function entmeta:GetInstance()
    return instance_table[self] or default_instance
end

function plymeta:SetInstanceInternal(instance)
    local allow = true
    instance_table[self] = instance
    -- remove us from all other players who are not in our Instance
    for _, ply in ipairs(player.GetAll()) do
        RecursiveSetPreventTransmit(self, ply, instance != ply:GetInstance())
    end
    -- stop networking all entities who are not in our Instance
    for _, ent in ipairs(ents.GetAll()) do
        allow = true
        if (ent:CreatedByMap()) then
            allow = false
        end
        for k,v in ipairs(blacklist) do
            if (string.find(ent:GetClass(),v)) then
                allow = false
            end
        end
        if (allow) then
            RecursiveSetPreventTransmit(ent, self, instance != ent:GetInstance())
        end
    end
end

hook.Add("InitPostEntity", "Instancing_EnableCollisionCheck", function()
    timer.Simple(0, function()
        for _, ent in ipairs(ents.GetAll()) do
            ent:SetCustomCollisionCheck(true)
        end
    end)
end)

hook.Add( "OnEntityCreated", "Instancing_EnableCollisionCheck", function( ent )
    ent:SetCustomCollisionCheck(true)
end )

hook.Add("PlayerInitialSpawn", "Instancing_SetInstance", function(ply)
    ply:SetInstance(default_instance)
end)

local player_spawned_hooks = {"PlayerSpawnedEffect", "PlayerSpawnedProp", "PlayerSpawnedRagdoll"}
for _, name in ipairs(player_spawned_hooks) do
    hook.Add(name, "Instancing_Spawning", function(ply, mdl, ent)
        ent:SetInstance(ply:GetInstance())
    end)
end

player_spawned_hooks = {"PlayerSpawnedNPC", "PlayerSpawnedSENT", "PlayerSpawnedSWEP", "PlayerSpawnedVehicle"}
for _, name in ipairs(player_spawned_hooks) do
    hook.Add(name, "Instancing_Spawning", function(ply, ent)
        ent:SetInstance(ply:GetInstance())
    end)
end

local physgun_hooks = {"PhysgunPickup", "AllowPlayerPickup", "GravGunPickupAllowed", "PlayerCanPickupWeapon", "PlayerCanPickupItem", "PlayerCanHearPlayersVoice","CanPlayerUnfreeze"}
for _, name in ipairs(physgun_hooks) do
    hook.Add(name, "Instancing_NoInteraction", function(ply, ent)
        if ply:GetInstance() != ent:GetInstance() then return false end
    end)
end

hook.Add("PlayerCanSeePlayersChat", "Instancing_NoInteraction", function(text, teamOnly, receiver, sender)
    if receiver:GetInstance() != ent:GetInstance() then return false end
end)

hook.Add("CanTool", "Instancing_Tool", function(ply, trace)
    if ply:GetInstance() != trace.Entity:GetInstance() then
        if !trace.Entity:IsWorld() then
            return false
        end
    end
end)

hook.Add("ShouldCollide", "Instancing_NoCollide", function(ent1, ent2)
    if ent1:GetInstance() != ent2:GetInstance() then
        if !ent1:IsWorld() and !ent2:IsWorld() then
            return false
        end
    end
end)

local CAMI_in_use = false

hook.Add("Initialize", "Instancing_Init", function()
    timer.Simple(0, function()
        if CAMI and istable(CAMI) then
            CAMI.RegisterPrivilege({
                Name = "SwitchInstance",
                MinAccess = "superadmin",
                Description = "Allows player to switch instance",
            })
            CAMI_in_use = true
        end
    end)
end)

hook.Add("PlayerSay", "Instancing_OpenInstancePanel", function(ply, msg)
    local args = msg:Split(" ")
    local cmd = args[1]:lower()
    if cmd == "!instance" then
        if (CAMI_in_use and !CAMI.PlayerHasAccess(ply, "SwitchInstance")) or !ply:IsSuperAdmin() then return "" end
        net.Start("Yolo.Instancing")
            net.WriteInt(instance_table[ply] or default_instance, 4)
        net.Send(ply)

        return ""
    end
    if cmd == "!forceinstance" then
        if (CAMI_in_use and !CAMI.PlayerHasAccess(ply, "SwitchInstance")) or !ply:IsSuperAdmin() then return "" end
        local new_instance = args[2] or default_instance
        local trace_ent = ply:GetEyeTrace().Entity

        if !trace_ent or !IsValid(trace_ent) then return "" end
        trace_ent:SetInstance(new_instance)
        ply:ChatPrint("[INSTANCE]: Set instance of the " .. (trace_ent:IsPlayer() and "Player" or "Entity") .. " to " .. new_instance)
    end
end)

net.Receive("Yolo.Instancing", function(len, ply)
    if (CAMI_in_use and !CAMI.PlayerHasAccess(ply, "SwitchInstance")) or !ply:IsSuperAdmin() then return end
    local new_instance = net.ReadInt(4) or default_instance
    ply:SetInstance(new_instance)
end)
