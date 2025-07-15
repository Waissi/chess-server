require "src.import"

---@type ConnectionModule
local connection = import "connection"

function love.update()
    connection.update()
end

function love.quit()
    print "===== Stopping Chess Server ====="
    connection.quit()
end

function love.load()
    print "===== Starting Chess Server ====="
    connection.init()
    local thread = love.thread.newThread("src/healthcheck.lua")
    thread:start()
end
