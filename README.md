# CHESS-server

A containerized chess server written in Lua for the [Löve](https://love2d.org/) framework, using the [ENet](https://leafo.net/lua-enet/) module for communication between the server and the [client](https://github.com/Waissi/chess-client)  

## Dependencies

- [lua https](https://github.com/love2d/lua-https)
- [json.lua](https://github.com/rxi/json.lua) (included)

## Running

### With Docker
```
zip server.love src/* main.lua conf.lua
docker build -t chess-server .
docker run --rm chess-server
```
### With löve
```
love .
```
