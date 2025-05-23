zip server.love src/* main.lua conf.lua
docker build -t chess-server .
docker run --rm chess-server
