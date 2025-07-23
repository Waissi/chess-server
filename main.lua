require "src.import"

---@type ConnectionModule
local connection = import "connection"

function love.update()
    connection.update()
end

function love.quit()
    print "===== Stopping Chess Server ====="
end

function love.load()
    print "===== Starting Chess Server ====="
end
