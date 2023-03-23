INSTANCE = INSTANCE or {}
INSTANCE.current_instance = 1

net.Receive("Yolo.Instancing", function()
    local instance = net.ReadInt(4)
    INSTANCE.current_instance = instance

    local f = vgui.Create("DFrame")
    f:SetSize(200, 100)
    f:Center()
    f:MakePopup()

    local n = vgui.Create("DTextEntry", f)
    n:Dock(TOP)
    n:SetTall(50)
    n:SetFont("CloseCaption_Normal")
    n:SetNumeric(true)
    n:SetText(instance)

    local b = vgui.Create("DButton", f)
    b:Dock(FILL)
    b:SetText("Change")
    b.DoClick = function()
        f:Remove()
        net.Start("Yolo.Instancing")
            net.WriteInt(n:GetInt() or 1, 4)
        net.SendToServer()
    end
end)

net.Receive("Yolo.ChangeInstance", function()
    local instance = net.ReadInt(4)
    local to_stop_ents = net.ReadTable()

    INSTANCE.current_instance = instance
    for _, ent in ipairs(to_stop_ents) do
        ent:StopSound("*")
    end
end)