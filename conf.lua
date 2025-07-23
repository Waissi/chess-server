io.stdout:setvbuf('no')

function love.conf(t)
    t.modules.window = false
    t.modules.graphics = false
    t.modules.physics = false
    t.modules.audio = false
    t.modules.mouse = false
    t.modules.keyboard = false
    t.modules.joystick = false
    t.modules.touch = false
end
