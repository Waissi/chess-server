table.delete = function(tab, element)
    for key, value in pairs(tab) do
        if value == element then
            table.remove(tab, key)
            return
        end
    end
end
