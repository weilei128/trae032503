#!/bin/bash

cd /opt/apps/memo-app

echo "=== 1. 检测端口占用并停止容器 ==="
CONTAINER_ID=$(docker ps -a --format '{{.ID}} {{.Ports}}' | grep 10012 | awk '{print $1}')
if [ -n "$CONTAINER_ID" ]; then
    echo "停止容器: $CONTAINER_ID"
    docker stop $CONTAINER_ID
    docker rm $CONTAINER_ID
else
    echo "端口10012未被占用"
fi

echo ""
echo "=== 2. 删除旧容器（如存在） ==="
docker rm -f market-app 2>/dev/null || echo "无旧容器需要删除"

echo ""
echo "=== 3. 删除旧镜像（如存在） ==="
docker rmi market-app:1.0.0 2>/dev/null || echo "无旧镜像需要删除"

echo ""
echo "=== 4. 构建新镜像 ==="
docker build -t market-app:1.0.0 -f Dockerfile .

echo ""
echo "=== 5. 运行容器 ==="
docker run -d --name market-app -p 10012:10012 -e JVM_OPTS="-Xms256m -Xmx512m" --restart=unless-stopped market-app:1.0.0

echo ""
echo "=== 6. 查看容器状态 ==="
docker ps | grep market-app

echo ""
echo "=== 7. 查看容器日志（最近20行） ==="
sleep 3
docker logs --tail 20 market-app
