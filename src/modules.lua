return setmetatable({},
    {
        __index = function(tab, index)
            tab[index] = import(index)
            return tab[index]
        end
    }
)
