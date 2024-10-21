local paths = {}

local function set_paths(path, folderName)
    local itemList = love.filesystem.getDirectoryItems(path)
    for _, item in ipairs(itemList) do
        local itemPath = path .. '/' .. item
        if love.filesystem.getInfo(itemPath, "directory") then
            set_paths(itemPath, item)
        else
            if not (item:sub(1, 1) == ".") then
                if item:find("init.lua") then
                    paths[folderName] = path:gsub("/", ".")
                else
                    local itemWithoutExtension = item:gsub(".lua", "")
                    assert(not paths[itemWithoutExtension],
                        "File name should be unique! Change file name: " .. itemPath)
                    paths[itemWithoutExtension] = itemPath:gsub("/", "."):gsub(".lua", "")
                end
            end
        end
    end
end
set_paths("src", "src")

---@type fun(name: string): table
import = function(moduleName)
    assert(paths[moduleName], "The module " .. moduleName .. " does not exist")
    return require(paths[moduleName])
end
