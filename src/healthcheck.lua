local socket = require("socket")
local server = assert(socket.bind("*", 80))
server:settimeout(0)

while true do
    local client = server:accept()
    if client then
        client:settimeout(1)
        local request = client:receive("*l")
        if request then
            local method, path = request:match("^(%S+)%s(%S+)")
            if method == "GET" and path == "/healthz" then
                local response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\n\r\nOK"
                client:send(response)
            else
                local response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
                client:send(response)
            end
        end
        client:close()
    end
    socket.sleep(0.1)
end
