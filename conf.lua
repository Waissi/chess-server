io.stdout:setvbuf('no')
if arg[#arg] == "debug" then
    require("lldebugger").start()
end

function love.conf(t)
    t.modules.window = false
    t.modules.graphics = false
    t.modules.physics = false
    t.modules.audio = false
end
