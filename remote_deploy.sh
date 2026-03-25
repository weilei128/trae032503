#!/bin/bash
set -e

echo "=== 服务器部署脚本开始 ==="

cd /opt/apps/memo-app

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

echo "Docker 版本: $(docker --version)"

# 检查端口 10013 是否被占用
echo "检查端口 10013 占用情况..."
container_id=$(docker ps -q --filter "publish=10013")
if [ ! -z "$container_id" ]; then
    echo "发现端口 10013 被容器 $container_id 占用，正在停止..."
    docker stop $container_id
    docker rm $container_id
    echo "已停止并删除旧容器"
else
    # 检查是否有使用 10013 端口的容器（包括停止的）
    old_container=$(docker ps -aq --filter "publish=10013")
    if [ ! -z "$old_container" ]; then
        echo "删除已停止的容器 $old_container"
        docker rm $old_container
    fi
fi

# 删除旧镜像
echo "删除旧镜像（如果存在）..."
docker rmi market-app:1.0.0 2>/dev/null || true

# 构建新镜像
echo "构建 Docker 镜像..."
docker build -f kimi_Dockerfile -t market-app:1.0.0 .

# 运行新容器
echo "启动容器..."
docker run -d \
    --name market-app \
    -p 10013:10013 \
    -v /opt/apps/memo-app/data:/app/data \
    --restart unless-stopped \
    market-app:1.0.0

# 等待服务启动
sleep 5

# 检查容器状态
echo "检查容器状态..."
container_status=$(docker ps -q --filter "name=market-app")
if [ ! -z "$container_status" ]; then
    echo "容器运行正常，ID: $container_status"
    echo ""
    echo "查看容器日志:"
    docker logs --tail 20 market-app
else
    echo "错误: 容器启动失败"
    echo ""
    echo "查看错误日志:"
    docker logs market-app 2>&1 || true
    exit 1
fi

echo ""
echo "=== 部署完成 ==="
echo "访问地址: http://49.235.161.106:10013"
