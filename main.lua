require "src.import"

---@type ConnectionModule
local connection = import "connection"

function love.update()
    connection.update()
end

function love.quit()
    print "===== Stoping Chess Server ====="
end

print "===== Starting Chess Server ====="
