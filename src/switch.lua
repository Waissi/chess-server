switch = function(tree)
    return function(index, ...)
        local case = tree[index] or tree.default
        if not case then return end
        return case(...)
    end
end
