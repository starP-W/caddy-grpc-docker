# caddy-grpc-docker
用docker-compose部署xray-vless-grpc服务端

## 用法
安装好Docker及Docker-compose，预留80、443、11514端口，然后
```
mkdir caddy-grpc && cd caddy-grpc
wget https://raw.githubusercontent.com/starP-W/caddy-grpc-docker/main/install.sh -O ./install.sh && bash install.sh
```
