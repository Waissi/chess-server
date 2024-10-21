---@type Modules
local M = import "modules"


return {
    new = function()
        local grid = {}
        for j = 1, 8 do
            grid[j] = {}
            for i = 1, 8 do
                grid[j][i] = M.square.new(i, j)
            end
        end
        return grid
    end
}
