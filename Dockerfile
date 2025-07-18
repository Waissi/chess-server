FROM ubuntu:latest
RUN apt update && apt install -y software-properties-common
RUN add-apt-repository ppa:bartbes/love-stable
RUN apt update && apt install -y love
ENV XDG_RUNTIME_DIR=/run/user/
COPY server.love .
EXPOSE 6789
CMD ["love", "server.love"]
