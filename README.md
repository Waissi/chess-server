# CHESS - server

A chess server written in Lua, interacting with [client](https://github.com/Waissi/chess-client), built with [Löve](https://love2d.org/).

## Build and run
### With löve
```
love .
```
### With Docker
```
zip server.love *.lua src/*
docker build -t chess-server .
docker run -p 6789:6789/udp chess-server
```

## Dependencies
- [Docker](https://www.docker.com/) - *optional*
