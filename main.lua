require "src.import"

---@type ConnectionModule
local connection = import "connection"

function love.update()
    connection.update()
end

function love.quit()
    print "===== Stoping Chess Server ====="
    connection.quit()
end

function love.load()
    if not connection.init() then love.event.quit() end
    print "===== Starting Chess Server ====="
end
